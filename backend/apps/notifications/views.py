from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response

from .models import Notification, DeviceToken
from .pagination import NotificationPagination
from .serializers import NotificationSerializer, DeviceTokenSerializer

from apps.accounts.permissions import IsAtLeastClient, IsAtLeastPhoneOnly


class MyNotificationsView(generics.ListAPIView):
    permission_classes = [IsAtLeastPhoneOnly]
    serializer_class = NotificationSerializer
    pagination_class = NotificationPagination

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user).order_by("-id")


class UnreadCountView(APIView):
    permission_classes = [IsAtLeastPhoneOnly]

    def get(self, request):
        count = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({"unread": count}, status=status.HTTP_200_OK)


class MarkReadView(APIView):
    permission_classes = [IsAtLeastPhoneOnly]

    def post(self, request, notif_id):
        updated = Notification.objects.filter(id=notif_id, user=request.user).update(
            is_read=True
        )
        if not updated:
            return Response({"detail": "غير موجود"}, status=status.HTTP_404_NOT_FOUND)
        return Response({"ok": True}, status=status.HTTP_200_OK)


class MarkAllReadView(APIView):
    permission_classes = [IsAtLeastPhoneOnly]

    def post(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({"ok": True}, status=status.HTTP_200_OK)


class RegisterDeviceTokenView(APIView):
	"""
	يسجّل توكن FCM للجوال. (للاستخدام لاحقًا)
	"""

	permission_classes = [IsAtLeastClient]

	def post(self, request):
		s = DeviceTokenSerializer(data=request.data)
		s.is_valid(raise_exception=True)
		token = s.validated_data["token"]
		platform = s.validated_data["platform"]

		DeviceToken.objects.update_or_create(
			token=token,
			defaults={
				"user": request.user,
				"platform": platform,
				"is_active": True,
				"last_seen_at": timezone.now(),
			},
		)
		return Response({"ok": True}, status=status.HTTP_200_OK)


class DeleteOldNotificationsView(APIView):
	permission_classes = [IsAtLeastClient]

	def post(self, request):
		days = getattr(settings, "NOTIFICATIONS_RETENTION_DAYS", 90)
		cutoff = timezone.now() - timedelta(days=days)

		deleted, _ = Notification.objects.filter(
			user=request.user,
			created_at__lt=cutoff,
		).delete()

		return Response(
			{"ok": True, "deleted": deleted, "retention_days": days},
			status=status.HTTP_200_OK,
		)
