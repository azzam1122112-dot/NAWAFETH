from rest_framework import serializers

from apps.marketplace.models import ServiceRequest, RequestStatus

from .models import Review


class ReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ("rating", "comment")

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("التقييم يجب أن يكون بين 1 و 5")
        return value

    def validate_comment(self, value):
        value = (value or "").strip()
        if len(value) > 500:
            raise serializers.ValidationError("التعليق طويل جدًا")
        return value

    def validate(self, attrs):
        request_obj: ServiceRequest = self.context["service_request"]
        user = self.context["user"]

        # فقط مالك الطلب
        if request_obj.client_id != user.id:
            raise serializers.ValidationError({"detail": "غير مصرح"})

        # لا تقييم إلا بعد الإكمال
        if request_obj.status != RequestStatus.COMPLETED:
            raise serializers.ValidationError({"detail": "لا يمكن التقييم قبل اكتمال الطلب"})

        # لازم يكون فيه مزود معيّن
        if not request_obj.provider_id:
            raise serializers.ValidationError({"detail": "لا يوجد مزود لتقييمه"})

        # منع التكرار (OneToOne سيمنع، لكن نرجع رسالة واضحة)
        if hasattr(request_obj, "review"):
            raise serializers.ValidationError({"detail": "تم تقييم هذا الطلب مسبقًا"})

        return attrs


class ReviewListSerializer(serializers.ModelSerializer):
    client_phone = serializers.CharField(source="client.phone", read_only=True)

    class Meta:
        model = Review
        fields = ("id", "rating", "comment", "client_phone", "created_at")


class ProviderRatingSummarySerializer(serializers.Serializer):
    provider_id = serializers.IntegerField()
    rating_avg = serializers.DecimalField(max_digits=3, decimal_places=2)
    rating_count = serializers.IntegerField()
