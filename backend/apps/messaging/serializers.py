from rest_framework import serializers

from .models import Message, Thread, ThreadUserState


class ThreadSerializer(serializers.ModelSerializer):
    class Meta:
        model = Thread
        fields = ("id", "request", "is_direct", "created_at")
        read_only_fields = ("id", "created_at")


class DirectThreadSerializer(serializers.ModelSerializer):
    participant_1_id = serializers.IntegerField(source="participant_1.id", read_only=True)
    participant_2_id = serializers.IntegerField(source="participant_2.id", read_only=True)

    class Meta:
        model = Thread
        fields = ("id", "is_direct", "participant_1_id", "participant_2_id", "created_at")
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
    read_by_ids = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ("id", "sender", "sender_phone", "body", "created_at", "read_by_ids")

    def get_read_by_ids(self, obj):
        try:
            return list(obj.reads.values_list("user_id", flat=True))
        except Exception:
            return []


class ThreadUserStateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ThreadUserState
        fields = (
            "thread",
            "is_favorite",
            "is_archived",
            "is_blocked",
            "blocked_at",
            "archived_at",
        )
        read_only_fields = fields
