from datetime import timedelta

from django.conf import settings
from django.db.models import Case, IntegerField, Value, When
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response

from .models import Notification, DeviceToken
from .pagination import NotificationPagination
from .serializers import (
    NotificationSerializer,
    DeviceTokenSerializer,
    NotificationPreferenceSerializer,
)
from .services import NOTIFICATION_CATALOG, get_or_create_notification_preferences, _is_pref_locked

from apps.accounts.permissions import IsAtLeastClient, IsAtLeastPhoneOnly


class MyNotificationsView(generics.ListAPIView):
    permission_classes = [IsAtLeastPhoneOnly]
    serializer_class = NotificationSerializer
    pagination_class = NotificationPagination

    def get_queryset(self):
        return (
            Notification.objects.filter(user=self.request.user)
            .annotate(
                _sort_priority=Case(
                    When(is_pinned=True, then=Value(2)),
                    When(is_urgent=True, then=Value(1)),
                    default=Value(0),
                    output_field=IntegerField(),
                )
            )
            .order_by("-_sort_priority", "-id")
        )


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


class NotificationActionView(APIView):
    permission_classes = [IsAtLeastPhoneOnly]

    def post(self, request, notif_id: int):
        action = (request.data.get("action") or "").strip().lower()
        notif = Notification.objects.filter(id=notif_id, user=request.user).first()
        if not notif:
            return Response({"detail": "غير موجود"}, status=status.HTTP_404_NOT_FOUND)

        if action == "pin":
            notif.is_pinned = not notif.is_pinned
            notif.save(update_fields=["is_pinned"])
            return Response({"ok": True, "is_pinned": notif.is_pinned}, status=status.HTTP_200_OK)

        if action == "follow_up":
            notif.is_follow_up = not notif.is_follow_up
            notif.save(update_fields=["is_follow_up"])
            return Response({"ok": True, "is_follow_up": notif.is_follow_up}, status=status.HTTP_200_OK)

        return Response({"detail": "إجراء غير مدعوم"}, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, notif_id: int):
        deleted, _ = Notification.objects.filter(id=notif_id, user=request.user).delete()
        if not deleted:
            return Response({"detail": "غير موجود"}, status=status.HTTP_404_NOT_FOUND)
        return Response({"ok": True}, status=status.HTTP_200_OK)


class NotificationPreferencesView(APIView):
    permission_classes = [IsAtLeastPhoneOnly]

    def get(self, request):
        prefs = get_or_create_notification_preferences(request.user)
        data = []
        for p in prefs:
            cfg = NOTIFICATION_CATALOG.get(p.key, {})
            data.append(
                {
                    "key": p.key,
                    "title": cfg.get("title", p.key),
                    "enabled": bool(p.enabled),
                    "tier": p.tier,
                    "locked": bool(_is_pref_locked(request.user, p.key)),
                    "updated_at": p.updated_at,
                }
            )
        return Response({"results": data}, status=status.HTTP_200_OK)

    def patch(self, request):
        prefs = get_or_create_notification_preferences(request.user)
        by_key = {p.key: p for p in prefs}
        updates = request.data.get("updates") or []
        if not isinstance(updates, list):
            return Response({"detail": "صيغة updates غير صحيحة"}, status=status.HTTP_400_BAD_REQUEST)

        changed = 0
        for raw in updates:
            if not isinstance(raw, dict):
                continue
            key = (raw.get("key") or "").strip()
            if not key or key not in by_key:
                continue
            if _is_pref_locked(request.user, key):
                continue
            enabled = raw.get("enabled")
            if not isinstance(enabled, bool):
                continue
            obj = by_key[key]
            if obj.enabled == enabled:
                continue
            obj.enabled = enabled
            obj.save(update_fields=["enabled", "updated_at"])
            changed += 1

        serialized = NotificationPreferenceSerializer(
            get_or_create_notification_preferences(request.user),
            many=True,
        )
        return Response({"ok": True, "changed": changed, "results": serialized.data}, status=status.HTTP_200_OK)


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
