from rest_framework import serializers

from .models import Offer, ServiceRequest, ServiceRequestAttachment


class ServiceRequestCreateSerializer(serializers.ModelSerializer):
    images = serializers.ListField(
        child=serializers.FileField(), required=False, write_only=True
    )
    videos = serializers.ListField(
        child=serializers.FileField(), required=False, write_only=True
    )
    files = serializers.ListField(
        child=serializers.FileField(), required=False, write_only=True
    )
    audio = serializers.FileField(required=False, write_only=True)

    class Meta:
        model = ServiceRequest
        fields = (
            "id",
            "subcategory",
            "title",
            "description",
            "request_type",
            "city",
            "images",
            "videos",
            "files",
            "audio",
        )

    def validate_request_type(self, value):
        if value not in ("competitive", "urgent"):
            raise serializers.ValidationError("نوع الطلب غير صحيح")
        return value

    def create(self, validated_data):
        images = validated_data.pop("images", [])
        videos = validated_data.pop("videos", [])
        files = validated_data.pop("files", [])
        audio = validated_data.pop("audio", None)

        request = super().create(validated_data)

        # Save attachments
        attachments = []
        for img in images:
            attachments.append(
                ServiceRequestAttachment(
                    request=request, file=img, file_type="image"
                )
            )
        for vid in videos:
            attachments.append(
                ServiceRequestAttachment(
                    request=request, file=vid, file_type="video"
                )
            )
        for f in files:
            attachments.append(
                ServiceRequestAttachment(
                    request=request, file=f, file_type="document"
                )
            )
        if audio:
            attachments.append(
                ServiceRequestAttachment(
                    request=request, file=audio, file_type="audio"
                )
            )

        if attachments:
            ServiceRequestAttachment.objects.bulk_create(attachments)

        return request


class UrgentRequestAcceptSerializer(serializers.Serializer):
    request_id = serializers.IntegerField()


class ServiceRequestListSerializer(serializers.ModelSerializer):
    subcategory_name = serializers.CharField(source="subcategory.name", read_only=True)
    category_name = serializers.CharField(source="subcategory.category.name", read_only=True)
    client_phone = serializers.CharField(source="client.phone", read_only=True)

    class Meta:
        model = ServiceRequest
        fields = (
            "id",
            "title",
            "description",
            "request_type",
            "status",
            "city",
            "created_at",
            "subcategory",
            "subcategory_name",
            "category_name",
            "client_phone",
        )


class OfferCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Offer
        fields = ("id", "price", "duration_days", "note")


class OfferListSerializer(serializers.ModelSerializer):
    provider_name = serializers.CharField(source="provider.display_name", read_only=True)

    class Meta:
        model = Offer
        fields = (
            "id",
            "provider",
            "provider_name",
            "price",
            "duration_days",
            "note",
            "status",
            "created_at",
        )


class RequestActionSerializer(serializers.Serializer):
    note = serializers.CharField(max_length=255, required=False, allow_blank=True)
