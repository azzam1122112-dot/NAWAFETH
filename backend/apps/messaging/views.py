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

from apps.marketplace.models import ServiceRequest

from .models import Message, MessageRead, Thread
from .pagination import MessagePagination
from .permissions import IsRequestParticipant
from .serializers import MessageCreateSerializer, MessageListSerializer, ThreadSerializer


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

		thread = (
			Thread.objects.select_related("request", "request__client", "request__provider__user")
			.filter(id=thread_id)
			.first()
		)
		if not thread:
			return JsonResponse({"ok": False, "error": "المحادثة غير موجودة"}, status=404)

		if not _can_access_request(user, thread.request):
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
	permission_classes = [permissions.IsAuthenticated, IsRequestParticipant]

	def get(self, request, request_id):
		service_request = get_object_or_404(ServiceRequest, id=request_id)
		thread, _ = Thread.objects.get_or_create(request=service_request)
		return Response(ThreadSerializer(thread).data, status=status.HTTP_200_OK)

	def post(self, request, request_id):
		# نفس سلوك GET (مفيد لبعض العملاء)
		return self.get(request, request_id)


class ThreadMessagesListView(generics.ListAPIView):
	permission_classes = [permissions.IsAuthenticated, IsRequestParticipant]
	serializer_class = MessageListSerializer
	pagination_class = MessagePagination

	def get_queryset(self):
		request_id = self.kwargs["request_id"]
		thread = get_object_or_404(Thread, request_id=request_id)
		return (
			Message.objects.select_related("sender")
			.filter(thread=thread)
			.order_by("-id")
		)


class SendMessageView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsRequestParticipant]

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
	permission_classes = [permissions.IsAuthenticated, IsRequestParticipant]

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
			{"ok": True, "thread_id": thread.id, "marked": len(message_ids)},
			status=status.HTTP_200_OK,
		)
