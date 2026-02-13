from rest_framework import serializers

from .models import Offer, ServiceRequest, ServiceRequestAttachment
from apps.providers.models import ProviderCategory, ProviderProfile


class ServiceRequestCreateSerializer(serializers.ModelSerializer):
    provider = serializers.PrimaryKeyRelatedField(
        queryset=ProviderProfile.objects.all(),
        required=False,
        allow_null=True,
    )
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
            "provider",
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
        if value not in ("normal", "competitive", "urgent"):
            raise serializers.ValidationError("نوع الطلب غير صحيح")
        return value

    def validate(self, attrs):
        provider = attrs.get("provider")
        request_type = attrs.get("request_type")
        city = (attrs.get("city") or "").strip()
        subcategory = attrs.get("subcategory")

        # Competitive/Urgent requests are broadcast to matching providers.
        # They must NOT be targeted to a single provider.
        if request_type in ("competitive", "urgent") and provider is not None:
            raise serializers.ValidationError({
                "provider": "هذا النوع من الطلبات لا يدعم تحديد مزود خدمة."
            })

        if request_type == "normal" and provider is None:
            raise serializers.ValidationError({
                "provider": "طلب عادي يتطلب تحديد مزود خدمة"
            })

        if request_type == "normal" and provider is not None:
            # Ensure provider is eligible for this request (same city + same subcategory)
            if city and (getattr(provider, "city", None) or "").strip() and provider.city.strip() != city:
                raise serializers.ValidationError({
                    "city": "مدينة الطلب لا تطابق مدينة مزود الخدمة"
                })
            if subcategory is not None and not ProviderCategory.objects.filter(
                provider=provider, subcategory=subcategory
            ).exists():
                raise serializers.ValidationError({
                    "subcategory": "مزود الخدمة لا يدعم هذا التصنيف"
                })

        return attrs

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
    client_name = serializers.SerializerMethodField()
    provider_name = serializers.CharField(source="provider.display_name", read_only=True)
    provider_phone = serializers.CharField(source="provider.user.phone", read_only=True)
    status_group = serializers.SerializerMethodField()
    status_label = serializers.SerializerMethodField()

    def _status_group_value(self, raw: str) -> str:
        s = (raw or "").strip().lower()
        if s in ("new", "sent"):
            return "new"
        if s in ("accepted", "in_progress"):
            return "in_progress"
        if s == "completed":
            return "completed"
        if s in ("cancelled", "canceled", "expired"):
            return "cancelled"
        return "new"

    def get_status_group(self, obj):
        return self._status_group_value(getattr(obj, "status", ""))

    def get_status_label(self, obj):
        group = self.get_status_group(obj)
        return {
            "new": "جديد",
            "in_progress": "تحت التنفيذ",
            "completed": "مكتمل",
            "cancelled": "ملغي",
        }.get(group, "جديد")

    def get_client_name(self, obj):
        first = (getattr(obj.client, "first_name", "") or "").strip()
        last = (getattr(obj.client, "last_name", "") or "").strip()
        name = f"{first} {last}".strip()
        return name or "-"

    class Meta:
        model = ServiceRequest
        fields = (
            "id",
            "title",
            "description",
            "request_type",
            "status",
            "status_group",
            "status_label",
            "city",
            "created_at",
            "provider",
            "provider_name",
            "provider_phone",
            "subcategory",
            "subcategory_name",
            "category_name",
            "client_name",
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
