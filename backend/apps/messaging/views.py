import json
import logging
import mimetypes
import os

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_POST
from django.utils.html import strip_tags
from django.shortcuts import get_object_or_404
from django.utils import timezone
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import generics, permissions, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsAtLeastPhoneOnly, ROLE_LEVELS, role_level
from apps.marketplace.models import ServiceRequest
from apps.providers.models import ProviderProfile
from apps.support.models import SupportTicket, SupportTicketType, SupportPriority

from .models import Message, MessageRead, Thread, ThreadUserState
from .pagination import MessagePagination
from .permissions import IsRequestParticipant, IsThreadParticipant
from .serializers import (
	MessageCreateSerializer,
	MessageListSerializer,
	ThreadSerializer,
	DirectThreadSerializer,
	ThreadUserStateSerializer,
)


logger = logging.getLogger(__name__)

MAX_MESSAGE_LEN = 2000


def _infer_attachment_type(file_obj, requested_type: str | None = None) -> str:
	req_type = (requested_type or "").strip().lower()
	if req_type in {"audio", "image", "file"}:
		return req_type

	name = getattr(file_obj, "name", "") or ""
	mime, _ = mimetypes.guess_type(name)
	if mime:
		if mime.startswith("audio/"):
			return "audio"
		if mime.startswith("image/"):
			return "image"
	return "file"


def _can_access_request(user, sr: ServiceRequest) -> bool:
	if not user or not getattr(user, "is_authenticated", False):
		return False
	if getattr(user, "is_staff", False):
		return True
	is_client = sr.client_id == user.id
	is_provider = bool(sr.provider_id) and sr.provider.user_id == user.id
	return bool(is_client or is_provider)


def _thread_participant_users(thread: Thread):
	"""Return participants as user objects for direct and request threads."""
	if thread.is_direct:
		users = []
		if thread.participant_1_id:
			users.append(thread.participant_1)
		if thread.participant_2_id:
			users.append(thread.participant_2)
		return [u for u in users if u is not None]

	if thread.request_id and thread.request:
		users = [thread.request.client]
		if getattr(thread.request, "provider_id", None) and getattr(thread.request.provider, "user", None):
			users.append(thread.request.provider.user)
		return [u for u in users if u is not None]

	return []


def _unarchive_for_participants(thread: Thread):
	participants = _thread_participant_users(thread)
	if not participants:
		return
	ThreadUserState.objects.filter(thread=thread, user__in=participants, is_archived=True).update(
		is_archived=False,
		archived_at=None,
	)


def _is_blocked_by_other(thread: Thread, sender_user_id: int) -> bool:
	participants = _thread_participant_users(thread)
	other_ids = [u.id for u in participants if u and u.id and u.id != sender_user_id]
	if not other_ids:
		return False
	return ThreadUserState.objects.filter(thread=thread, user_id__in=other_ids, is_blocked=True).exists()


@require_POST
@csrf_protect
def post_message(request, thread_id: int):
	"""Fallback POST endpoint for the dashboard chat when WS is unavailable.

	Returns JSON and enforces the same access policy as WebSocket:
	- staff allowed
	- request.client or request.provider.user allowed
	"""
	try:
		user = request.user
		if not user or not user.is_authenticated:
			return JsonResponse({"ok": False, "error": "غير مصرح"}, status=401)
		if role_level(user) < ROLE_LEVELS["phone_only"]:
			return JsonResponse({"ok": False, "error": "غير مصرح"}, status=403)

		thread = (
			Thread.objects.select_related("request", "request__client", "request__provider__user")
			.filter(id=thread_id)
			.first()
		)
		if not thread:
			return JsonResponse({"ok": False, "error": "المحادثة غير موجودة"}, status=404)

		# Direct threads: check participant
		if thread.is_direct:
			if user.id not in (thread.participant_1_id, thread.participant_2_id):
				return JsonResponse({"ok": False, "error": "غير مصرح"}, status=403)
		elif thread.request:
			if not _can_access_request(user, thread.request):
				return JsonResponse({"ok": False, "error": "غير مصرح"}, status=403)
		else:
			return JsonResponse({"ok": False, "error": "غير مصرح"}, status=403)

		if _is_blocked_by_other(thread, user.id):
			return JsonResponse({"ok": False, "error": "تم حظرك من الطرف الآخر"}, status=403)

		# Accept form-encoded or JSON
		text = ""
		if (request.content_type or "").startswith("application/json"):
			try:
				payload = json.loads(request.body.decode("utf-8") or "{}")
				text = (payload.get("text") or payload.get("body") or "").strip()
			except Exception:
				text = ""
		else:
			text = (request.POST.get("text") or request.POST.get("body") or "").strip()

		text = strip_tags(text)
		if not text:
			return JsonResponse({"ok": False, "error": "الرسالة فارغة"}, status=400)
		if len(text) > MAX_MESSAGE_LEN:
			return JsonResponse({"ok": False, "error": "الرسالة طويلة جدًا"}, status=400)

		msg = Message.objects.create(thread=thread, sender=user, body=text, created_at=timezone.now())
		_unarchive_for_participants(thread)

		get_full_name = getattr(user, "get_full_name", None)
		if callable(get_full_name):
			sender_name = get_full_name() or ""
		else:
			sender_name = ""
		sender_name = sender_name or getattr(user, "phone", "") or str(user)

		return JsonResponse(
			{
				"ok": True,
				"message": {
					"id": msg.id,
					"text": msg.body,
					"sender_id": user.id,
					"sender_name": sender_name,
					"sent_at": msg.created_at.isoformat(),
				},
			},
			status=200,
		)
	except Exception:
		logger.exception("post_message error")
		return JsonResponse({"ok": False, "error": "حدث خطأ غير متوقع"}, status=500)


class GetOrCreateThreadView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsRequestParticipant]

	def get(self, request, request_id):
		service_request = get_object_or_404(ServiceRequest, id=request_id)
		thread, _ = Thread.objects.get_or_create(request=service_request)
		return Response(ThreadSerializer(thread).data, status=status.HTTP_200_OK)

	def post(self, request, request_id):
		# نفس سلوك GET (مفيد لبعض العملاء)
		return self.get(request, request_id)


class ThreadMessagesListView(generics.ListAPIView):
	permission_classes = [IsAtLeastPhoneOnly, IsRequestParticipant]
	serializer_class = MessageListSerializer
	pagination_class = MessagePagination

	def get_queryset(self):
		request_id = self.kwargs["request_id"]
		thread = get_object_or_404(Thread, request_id=request_id)
		return (
			Message.objects.select_related("sender")
			.prefetch_related("reads")
			.filter(thread=thread)
			.order_by("-id")
		)


class SendMessageView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsRequestParticipant]
	parser_classes = [JSONParser, MultiPartParser, FormParser]

	def post(self, request, request_id):
		service_request = get_object_or_404(ServiceRequest, id=request_id)
		thread, _ = Thread.objects.get_or_create(request=service_request)

		if _is_blocked_by_other(thread, request.user.id):
			return Response({"detail": "تم حظرك من الطرف الآخر"}, status=status.HTTP_403_FORBIDDEN)

		serializer = MessageCreateSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)
		attachment = serializer.validated_data.get("attachment")
		attachment_type = _infer_attachment_type(
			attachment,
			serializer.validated_data.get("attachment_type"),
		) if attachment else ""
		attachment_name = ""
		if attachment:
			attachment_name = os.path.basename(getattr(attachment, "name", "") or "").strip()
		message = Message.objects.create(
			thread=thread,
			sender=request.user,
			body=serializer.validated_data["body"],
			attachment=attachment,
			attachment_type=attachment_type,
			attachment_name=attachment_name,
			created_at=timezone.now(),
		)
		_unarchive_for_participants(thread)

		return Response(
			{"ok": True, "message_id": message.id},
			status=status.HTTP_201_CREATED,
		)


class MarkThreadReadView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsRequestParticipant]

	def post(self, request, request_id):
		thread = get_object_or_404(Thread, request_id=request_id)

		message_ids = list(
			Message.objects.filter(thread=thread)
			.exclude(reads__user=request.user)
			.values_list("id", flat=True)
		)

		MessageRead.objects.bulk_create(
			[
				MessageRead(message_id=mid, user=request.user, read_at=timezone.now())
				for mid in message_ids
			],
			ignore_conflicts=True,
		)

		return Response(
			{
				"ok": True,
				"thread_id": thread.id,
				"marked": len(message_ids),
				"message_ids": message_ids,
			},
			status=status.HTTP_200_OK,
		)


# ─── Direct Messaging (no request required) ───────────────────────

class DirectThreadGetOrCreateView(APIView):
	"""Create or get an existing direct thread between the current user and a provider."""
	permission_classes = [IsAtLeastPhoneOnly]

	def post(self, request):
		provider_id = request.data.get("provider_id")
		if not provider_id:
			return Response({"error": "provider_id مطلوب"}, status=status.HTTP_400_BAD_REQUEST)

		provider_profile = ProviderProfile.objects.select_related("user").filter(id=provider_id).first()
		if not provider_profile:
			return Response({"error": "المزود غير موجود"}, status=status.HTTP_404_NOT_FOUND)

		provider_user = provider_profile.user
		me = request.user

		if me.id == provider_user.id:
			return Response({"error": "لا يمكنك محادثة نفسك"}, status=status.HTTP_400_BAD_REQUEST)

		from django.db.models import Q
		thread = Thread.objects.filter(
			is_direct=True,
		).filter(
			Q(participant_1=me, participant_2=provider_user) |
			Q(participant_1=provider_user, participant_2=me)
		).first()

		if not thread:
			thread = Thread.objects.create(
				is_direct=True,
				participant_1=me,
				participant_2=provider_user,
			)

		return Response(DirectThreadSerializer(thread).data, status=status.HTTP_200_OK)


class DirectThreadMessagesListView(generics.ListAPIView):
	"""List messages in a direct thread."""
	permission_classes = [IsAtLeastPhoneOnly]
	serializer_class = MessageListSerializer
	pagination_class = MessagePagination

	def get_queryset(self):
		thread_id = self.kwargs["thread_id"]
		thread = get_object_or_404(Thread, id=thread_id, is_direct=True)
		if not thread.is_participant(self.request.user):
			from rest_framework.exceptions import PermissionDenied
			raise PermissionDenied("غير مصرح")
		return (
			Message.objects.select_related("sender")
			.prefetch_related("reads")
			.filter(thread=thread)
			.order_by("-id")
		)


class DirectThreadSendMessageView(APIView):
	"""Send a message in a direct thread."""
	permission_classes = [IsAtLeastPhoneOnly]
	parser_classes = [JSONParser, MultiPartParser, FormParser]

	def post(self, request, thread_id):
		thread = get_object_or_404(Thread, id=thread_id, is_direct=True)
		if not thread.is_participant(request.user):
			return Response({"error": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

		if _is_blocked_by_other(thread, request.user.id):
			return Response({"detail": "تم حظرك من الطرف الآخر"}, status=status.HTTP_403_FORBIDDEN)

		serializer = MessageCreateSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)
		attachment = serializer.validated_data.get("attachment")
		attachment_type = _infer_attachment_type(
			attachment,
			serializer.validated_data.get("attachment_type"),
		) if attachment else ""
		attachment_name = ""
		if attachment:
			attachment_name = os.path.basename(getattr(attachment, "name", "") or "").strip()
		message = Message.objects.create(
			thread=thread,
			sender=request.user,
			body=serializer.validated_data["body"],
			attachment=attachment,
			attachment_type=attachment_type,
			attachment_name=attachment_name,
			created_at=timezone.now(),
		)

		return Response(
			{"ok": True, "message_id": message.id},
			status=status.HTTP_201_CREATED,
		)


class DirectThreadMarkReadView(APIView):
	"""Mark all messages in a direct thread as read."""
	permission_classes = [IsAtLeastPhoneOnly]

	def post(self, request, thread_id):
		thread = get_object_or_404(Thread, id=thread_id, is_direct=True)
		if not thread.is_participant(request.user):
			return Response({"error": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

		message_ids = list(
			Message.objects.filter(thread=thread)
			.exclude(reads__user=request.user)
			.values_list("id", flat=True)
		)

		MessageRead.objects.bulk_create(
			[
				MessageRead(message_id=mid, user=request.user, read_at=timezone.now())
				for mid in message_ids
			],
			ignore_conflicts=True,
		)

		return Response(
			{
				"ok": True,
				"thread_id": thread.id,
				"marked": len(message_ids),
				"message_ids": message_ids,
			},
			status=status.HTTP_200_OK,
		)


class MyDirectThreadsListView(APIView):
	"""List all direct threads for the current user."""
	permission_classes = [IsAtLeastPhoneOnly]

	def get(self, request):
		from django.db.models import Q, Max, Subquery, OuterRef
		me = request.user

		threads = (
			Thread.objects.filter(is_direct=True)
			.filter(Q(participant_1=me) | Q(participant_2=me))
			.select_related("participant_1", "participant_2")
			.annotate(last_message_at=Max("messages__created_at"))
			.order_by("-last_message_at")
		)

		result = []
		for t in threads:
			peer = t.participant_2 if t.participant_1_id == me.id else t.participant_1
			last_msg = t.messages.order_by("-id").first()
			unread = t.messages.exclude(sender=me).exclude(reads__user=me).count()

			# Get provider profile for peer if exists
			peer_provider = getattr(peer, "provider_profile", None)

			result.append({
				"thread_id": t.id,
				"peer_id": peer.id,
				"peer_provider_id": getattr(peer_provider, "id", None),
				"peer_name": (
					peer_provider.display_name if peer_provider
					else getattr(peer, "get_full_name", lambda: "")() or getattr(peer, "phone", str(peer))
				),
				"peer_phone": getattr(peer, "phone", ""),
				"last_message": last_msg.body if last_msg else "",
				"last_message_at": last_msg.created_at.isoformat() if last_msg else t.created_at.isoformat(),
				"unread_count": unread,
			})

		return Response(result, status=status.HTTP_200_OK)


class MyThreadStatesListView(APIView):
	permission_classes = [IsAtLeastPhoneOnly]

	def get(self, request):
		from django.db.models import Q
		me = request.user

		thread_ids = list(
			Thread.objects.filter(
				Q(is_direct=True, participant_1=me)
				| Q(is_direct=True, participant_2=me)
				| Q(request__client=me)
				| Q(request__provider__user=me)
			)
			.values_list("id", flat=True)
		)

		states = ThreadUserState.objects.filter(user=me, thread_id__in=thread_ids)
		return Response(ThreadUserStateSerializer(states, many=True).data, status=status.HTTP_200_OK)


class ThreadStateDetailView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def get(self, request, thread_id: int):
		obj, _ = ThreadUserState.objects.get_or_create(thread_id=thread_id, user=request.user)
		thread = (
			Thread.objects.select_related(
				"request",
				"request__client",
				"request__provider__user",
				"participant_1",
				"participant_2",
			)
			.filter(id=thread_id)
			.first()
		)
		data = ThreadUserStateSerializer(obj).data
		data["blocked_by_other"] = bool(thread and _is_blocked_by_other(thread, request.user.id))
		return Response(data, status=status.HTTP_200_OK)


class ThreadFavoriteView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def post(self, request, thread_id: int):
		action = (request.data.get("action") or "").strip().lower()
		obj, _ = ThreadUserState.objects.get_or_create(thread_id=thread_id, user=request.user)
		if action == "remove":
			obj.is_favorite = False
			obj.favorite_label = ""
		else:
			obj.is_favorite = True
		obj.save(update_fields=["is_favorite", "favorite_label", "updated_at"])
		return Response({"ok": True, "is_favorite": obj.is_favorite, "favorite_label": obj.favorite_label}, status=status.HTTP_200_OK)


class ThreadArchiveView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def post(self, request, thread_id: int):
		action = (request.data.get("action") or "").strip().lower()
		obj, _ = ThreadUserState.objects.get_or_create(thread_id=thread_id, user=request.user)

		if action == "remove":
			obj.is_archived = False
			obj.archived_at = None
		else:
			obj.is_archived = True
			obj.archived_at = timezone.now()

		obj.save(update_fields=["is_archived", "archived_at", "updated_at"])
		return Response({"ok": True, "is_archived": obj.is_archived}, status=status.HTTP_200_OK)


class ThreadBlockView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def post(self, request, thread_id: int):
		channel_layer = get_channel_layer()
		action = (request.data.get("action") or "").strip().lower()
		obj, _ = ThreadUserState.objects.get_or_create(thread_id=thread_id, user=request.user)

		if action == "remove":
			obj.is_blocked = False
			obj.blocked_at = None
		else:
			obj.is_blocked = True
			obj.blocked_at = timezone.now()

		obj.save(update_fields=["is_blocked", "blocked_at", "updated_at"])

		# Notify any active WS connections for this thread
		try:
			if channel_layer is not None:
				group = f"thread_{thread_id}"
				if obj.is_blocked:
					async_to_sync(channel_layer.group_send)(
						group,
						{
							"type": "broadcast.blocked",
							"thread_id": thread_id,
							"blocked_by": request.user.id,
						},
					)
				else:
					async_to_sync(channel_layer.group_send)(
						group,
						{
							"type": "broadcast.unblocked",
							"thread_id": thread_id,
							"unblocked_by": request.user.id,
						},
					)
		except Exception:
			# Best-effort only
			pass
		return Response({"ok": True, "is_blocked": obj.is_blocked}, status=status.HTTP_200_OK)


class ThreadReportView(APIView):
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def post(self, request, thread_id: int):
		thread = get_object_or_404(
			Thread.objects.select_related(
				"request",
				"request__client",
				"request__provider__user",
				"participant_1",
				"participant_2",
			),
			id=thread_id,
		)

		reason = (request.data.get("reason") or "").strip()
		details = (request.data.get("details") or "").strip()
		reported_label = (request.data.get("reported_label") or "").strip()
		legacy = (request.data.get("description") or request.data.get("text") or "").strip()
		if not details:
			details = legacy

		# Reason is required in the new UI (matches mobile screenshot).
		# For legacy clients that only send description/text, default reason to "أخرى".
		if not reason and details:
			reason = "أخرى"
		if not reason:
			return Response({"detail": "reason مطلوب"}, status=status.HTTP_400_BAD_REQUEST)

		prefix = f"بلاغ محادثة (Thread#{thread.id})"
		if thread.request_id:
			prefix += f" طلب#{thread.request_id}"

		reported_user_id = None
		try:
			if thread.is_direct:
				if thread.participant_1_id == request.user.id:
					reported_user_id = thread.participant_2_id
				else:
					reported_user_id = thread.participant_1_id
			elif thread.request_id and getattr(thread.request, "provider_id", None):
				reported_user_id = thread.request.provider.user_id
		except Exception:
			reported_user_id = None

		if reported_user_id:
			prefix += f" المبلغ_عنه#{reported_user_id}"

		full = f"{prefix} - السبب: {reason}"
		if details:
			full += f" - التفاصيل: {details}"
		if reported_label:
			full += f" - الاسم: {reported_label}"
		full = full.strip()[:300]

		ticket = SupportTicket.objects.create(
			requester=request.user,
			ticket_type=SupportTicketType.COMPLAINT,
			priority=SupportPriority.NORMAL,
			description=full,
		)

		return Response({"ok": True, "ticket_id": ticket.id, "ticket_code": ticket.code}, status=status.HTTP_201_CREATED)


class ThreadMarkUnreadView(APIView):
	"""Mark a thread as unread for the current user.

	Implementation detail: removes the MessageRead row for the latest message sent by the peer.
	This makes unread_count >= 1 without affecting the other participant.
	"""
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def post(self, request, thread_id: int):
		thread = get_object_or_404(Thread, id=thread_id)

		last_peer_message = (
			Message.objects.filter(thread=thread)
			.exclude(sender=request.user)
			.order_by("-created_at", "-id")
			.first()
		)

		if not last_peer_message:
			return Response(
				{"ok": True, "marked": 0, "detail": "لا توجد رسائل من الطرف الآخر"},
				status=status.HTTP_200_OK,
			)

		deleted, _ = MessageRead.objects.filter(message=last_peer_message, user=request.user).delete()
		return Response(
			{
				"ok": True,
				"marked": 1,
				"message_id": last_peer_message.id,
				"deleted": deleted,
			},
			status=status.HTTP_200_OK,
		)


class ThreadDeleteMessageView(APIView):
	"""Delete one message from a thread for both participants.

	Only the original sender can delete the message.
	"""
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	def post(self, request, thread_id: int, message_id: int):
		thread = get_object_or_404(Thread, id=thread_id)
		message = get_object_or_404(Message, id=message_id, thread=thread)

		if message.sender_id != request.user.id:
			return Response(
				{"detail": "يمكنك حذف الرسائل التي أرسلتها فقط"},
				status=status.HTTP_403_FORBIDDEN,
			)

		message.delete()

		# Best-effort realtime sync for active chat screens.
		try:
			channel_layer = get_channel_layer()
			if channel_layer is not None:
				async_to_sync(channel_layer.group_send)(
					f"thread_{thread_id}",
					{
						"type": "broadcast.message_deleted",
						"thread_id": thread_id,
						"message_id": message_id,
						"deleted_by": request.user.id,
					},
				)
		except Exception:
			pass

		return Response(
			{"ok": True, "thread_id": thread_id, "message_id": message_id},
			status=status.HTTP_200_OK,
		)


class ThreadFavoriteLabelView(APIView):
	"""Set the favorite label for a thread (potential_client / important_conversation / incomplete_contact)."""
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	VALID_LABELS = {"potential_client", "important_conversation", "incomplete_contact", ""}

	def post(self, request, thread_id: int):
		label = (request.data.get("label") or "").strip().lower()
		if label not in self.VALID_LABELS:
			return Response(
				{"detail": f"قيمة label غير صحيحة. القيم المقبولة: {', '.join(self.VALID_LABELS - {''})}"},
				status=status.HTTP_400_BAD_REQUEST,
			)
		obj, _ = ThreadUserState.objects.get_or_create(thread_id=thread_id, user=request.user)
		obj.favorite_label = label
		# Setting a label auto-marks as favorite
		if label:
			obj.is_favorite = True
		obj.save(update_fields=["favorite_label", "is_favorite", "updated_at"])
		return Response(
			{"ok": True, "favorite_label": obj.favorite_label, "is_favorite": obj.is_favorite},
			status=status.HTTP_200_OK,
		)


class ThreadClientLabelView(APIView):
	"""Tag a client in the thread as potential / current / past."""
	permission_classes = [IsAtLeastPhoneOnly, IsThreadParticipant]

	VALID_LABELS = {"potential", "current", "past", ""}

	def post(self, request, thread_id: int):
		label = (request.data.get("label") or "").strip().lower()
		if label not in self.VALID_LABELS:
			return Response(
				{"detail": f"قيمة label غير صحيحة. القيم المقبولة: {', '.join(self.VALID_LABELS - {''})}"},
				status=status.HTTP_400_BAD_REQUEST,
			)
		obj, _ = ThreadUserState.objects.get_or_create(thread_id=thread_id, user=request.user)
		obj.client_label = label
		obj.save(update_fields=["client_label", "updated_at"])
		return Response(
			{"ok": True, "client_label": obj.client_label},
			status=status.HTTP_200_OK,
		)
