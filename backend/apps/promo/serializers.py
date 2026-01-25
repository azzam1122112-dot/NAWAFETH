from __future__ import annotations

from rest_framework import serializers
from django.utils import timezone

from .models import (
    PromoRequest, PromoAsset,
    PromoRequestStatus,
    PromoAdType, PromoFrequency, PromoPosition,
)


class PromoAssetSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromoAsset
        fields = ["id", "asset_type", "title", "file", "uploaded_by", "uploaded_at"]
        read_only_fields = ["uploaded_by", "uploaded_at"]


class PromoRequestCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromoRequest
        fields = [
            "id", "code",
            "title", "ad_type",
            "start_at", "end_at",
            "frequency", "position",
            "target_category", "target_city",
            "redirect_url",
        ]
        read_only_fields = ["id", "code"]

    def validate(self, attrs):
        from apps.features.checks import has_feature

        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user is not None and user.is_authenticated:
            if not has_feature(user, "promo_ads"):
                raise serializers.ValidationError("ميزة الإعلانات (Promo) غير متاحة في باقتك الحالية.")

        start_at = attrs.get("start_at")
        end_at = attrs.get("end_at")

        if not start_at or not end_at:
            raise serializers.ValidationError("start_at و end_at مطلوبان.")

        if end_at <= start_at:
            raise serializers.ValidationError("تاريخ النهاية يجب أن يكون بعد البداية.")

        if start_at < timezone.now():
            raise serializers.ValidationError("لا يمكن بدء حملة بتاريخ ماضي.")

        ad_type = attrs.get("ad_type")
        if ad_type not in PromoAdType.values:
            raise serializers.ValidationError("نوع الإعلان غير صحيح.")

        frequency = attrs.get("frequency")
        if frequency not in PromoFrequency.values:
            raise serializers.ValidationError("معدل الظهور غير صحيح.")

        position = attrs.get("position")
        if position not in PromoPosition.values:
            raise serializers.ValidationError("موقع الظهور غير صحيح.")

        return attrs

    def create(self, validated_data):
        request = self.context["request"]
        user = request.user
        pr = PromoRequest.objects.create(
            requester=user,
            status=PromoRequestStatus.NEW,
            **validated_data,
        )

        # Audit
        try:
            from apps.audit.services import log_action
            from apps.audit.models import AuditAction

            log_action(
                actor=user,
                action=AuditAction.PROMO_REQUEST_CREATED,
                reference_type="promo_request",
                reference_id=pr.code,
                request=request,
            )
        except Exception:
            pass

        return pr


class PromoRequestDetailSerializer(serializers.ModelSerializer):
    assets = PromoAssetSerializer(many=True, read_only=True)

    class Meta:
        model = PromoRequest
        fields = [
            "id", "code",
            "title", "ad_type",
            "start_at", "end_at",
            "frequency", "position",
            "target_category", "target_city",
            "redirect_url",
            "status",
            "subtotal", "total_days",
            "quote_note", "reject_reason",
            "invoice",
            "reviewed_at", "activated_at",
            "created_at", "updated_at",
            "assets",
        ]


class PromoQuoteSerializer(serializers.Serializer):
    """
    للموظف: يضيف ملاحظة أو يستخدم التسعير التلقائي فقط
    """
    quote_note = serializers.CharField(required=False, allow_blank=True, max_length=300)


class PromoRejectSerializer(serializers.Serializer):
    reject_reason = serializers.CharField(required=True, max_length=300)
