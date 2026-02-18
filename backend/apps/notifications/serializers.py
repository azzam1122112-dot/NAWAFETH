from rest_framework import serializers

from .models import Notification, DeviceToken, NotificationPreference


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = (
            "id",
            "title",
            "body",
            "kind",
            "url",
            "is_read",
            "is_pinned",
            "is_follow_up",
            "is_urgent",
            "created_at",
        )


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ("token", "platform")


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreference
        fields = ("key", "enabled", "tier", "updated_at")
