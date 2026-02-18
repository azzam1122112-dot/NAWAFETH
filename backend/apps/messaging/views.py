import json
import logging

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_POST
from django.utils.html import strip_tags
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.permissions import IsAtLeastPhoneOnly, ROLE_LEVELS, role_level
from apps.marketplace.models import ServiceRequest
from apps.providers.models import ProviderProfile

from .models import Message, MessageRead, Thread
from .pagination import MessagePagination
from .permissions import IsRequestParticipant
from .serializers import MessageCreateSerializer, MessageListSerializer, ThreadSerializer, DirectThreadSerializer


logger = logging.getLogger(__name__)

MAX_MESSAGE_LEN = 2000


def _can_access_request(user, sr: ServiceRequest) -> bool:
	if not user or not getattr(user, "is_authenticated", False):
		return False
	if getattr(user, "is_staff", False):
		return True
	is_client = sr.client_id == user.id
	is_provider = bool(sr.provider_id) and sr.provider.user_id == user.id
	return bool(is_client or is_provider)


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

	def post(self, request, request_id):
		service_request = get_object_or_404(ServiceRequest, id=request_id)
		thread, _ = Thread.objects.get_or_create(request=service_request)

		serializer = MessageCreateSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		message = Message.objects.create(
			thread=thread,
			sender=request.user,
			body=serializer.validated_data["body"],
			created_at=timezone.now(),
		)

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

	def post(self, request, thread_id):
		thread = get_object_or_404(Thread, id=thread_id, is_direct=True)
		if not thread.is_participant(request.user):
			return Response({"error": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

		serializer = MessageCreateSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		message = Message.objects.create(
			thread=thread,
			sender=request.user,
			body=serializer.validated_data["body"],
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
