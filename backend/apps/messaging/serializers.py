from rest_framework import serializers

from .models import Message, Thread


class ThreadSerializer(serializers.ModelSerializer):
    class Meta:
        model = Thread
        fields = ("id", "request", "created_at")
        read_only_fields = ("id", "created_at")


class MessageCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ("id", "body")
        read_only_fields = ("id",)

    def validate_body(self, value):
        value = (value or "").strip()
        if not value:
            raise serializers.ValidationError("نص الرسالة مطلوب")
        if len(value) > 2000:
            raise serializers.ValidationError("نص الرسالة طويل جدًا")
        return value


class MessageListSerializer(serializers.ModelSerializer):
    sender_phone = serializers.CharField(source="sender.phone", read_only=True)

    class Meta:
        model = Message
        fields = ("id", "sender", "sender_phone", "body", "created_at")
