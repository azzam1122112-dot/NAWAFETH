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
    body = serializers.CharField(required=False, allow_blank=True)
    attachment = serializers.FileField(required=False, allow_null=True)

    class Meta:
        model = Message
        fields = ("id", "body", "attachment", "attachment_type", "attachment_name")
        read_only_fields = ("id",)

    def validate_body(self, value):
        value = (value or "").strip()
        if len(value) > 2000:
            raise serializers.ValidationError("نص الرسالة طويل جدًا")
        return value

    def validate(self, attrs):
        body = (attrs.get("body") or "").strip()
        attachment = attrs.get("attachment")
        if not body and not attachment:
            raise serializers.ValidationError("نص الرسالة أو المرفق مطلوب")
        attrs["body"] = body
        return attrs


class MessageListSerializer(serializers.ModelSerializer):
    sender_phone = serializers.CharField(source="sender.phone", read_only=True)
    read_by_ids = serializers.SerializerMethodField()
    attachment_url = serializers.FileField(source="attachment", read_only=True)

    class Meta:
        model = Message
        fields = (
            "id",
            "sender",
            "sender_phone",
            "body",
            "attachment_url",
            "attachment_type",
            "attachment_name",
            "created_at",
            "read_by_ids",
        )

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
            "favorite_label",
            "client_label",
            "is_archived",
            "is_blocked",
            "blocked_at",
            "archived_at",
        )
        read_only_fields = fields
