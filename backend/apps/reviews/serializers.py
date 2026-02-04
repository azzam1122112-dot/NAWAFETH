from rest_framework import serializers

from apps.marketplace.models import ServiceRequest, RequestStatus

from .models import Review


class ReviewCreateSerializer(serializers.ModelSerializer):
    rating = serializers.IntegerField(required=False)
    response_speed = serializers.IntegerField(required=False, allow_null=True)
    cost_value = serializers.IntegerField(required=False, allow_null=True)
    quality = serializers.IntegerField(required=False, allow_null=True)
    credibility = serializers.IntegerField(required=False, allow_null=True)
    on_time = serializers.IntegerField(required=False, allow_null=True)

    class Meta:
        model = Review
        fields = (
            "rating",
            "response_speed",
            "cost_value",
            "quality",
            "credibility",
            "on_time",
            "comment",
        )

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("التقييم يجب أن يكون بين 1 و 5")
        return value

    def _validate_criteria(self, attrs):
        keys = [
            "response_speed",
            "cost_value",
            "quality",
            "credibility",
            "on_time",
        ]
        present = {k: attrs.get(k, None) for k in keys}
        any_present = any(v is not None for v in present.values())
        if not any_present:
            return

        # إذا بدأ يرسل تفصيل، نطلب كل المحاور
        missing = [k for k, v in present.items() if v is None]
        if missing:
            raise serializers.ValidationError({"detail": "حقول التقييم التفصيلية ناقصة"})

        for k, v in present.items():
            if v < 1 or v > 5:
                raise serializers.ValidationError({k: "يجب أن يكون بين 1 و 5"})

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

        # تحقق من التفصيل (إن وُجد)
        self._validate_criteria(attrs)

        # احسب rating من التفصيل إذا لم يُرسل
        if attrs.get("rating", None) is None:
            keys = [
                "response_speed",
                "cost_value",
                "quality",
                "credibility",
                "on_time",
            ]
            if all(attrs.get(k, None) is not None for k in keys):
                avg = sum(int(attrs[k]) for k in keys) / len(keys)
                attrs["rating"] = max(1, min(5, round(avg)))

        if attrs.get("rating", None) is None:
            raise serializers.ValidationError({"rating": "التقييم مطلوب"})

        return attrs


class ReviewListSerializer(serializers.ModelSerializer):
    client_phone = serializers.CharField(source="client.phone", read_only=True)

    class Meta:
        model = Review
        fields = (
            "id",
            "rating",
            "response_speed",
            "cost_value",
            "quality",
            "credibility",
            "on_time",
            "comment",
            "client_phone",
            "created_at",
        )


class ProviderRatingSummarySerializer(serializers.Serializer):
    provider_id = serializers.IntegerField()
    rating_avg = serializers.DecimalField(max_digits=3, decimal_places=2)
    rating_count = serializers.IntegerField()

    response_speed_avg = serializers.DecimalField(
        max_digits=3, decimal_places=2, allow_null=True, required=False
    )
    cost_value_avg = serializers.DecimalField(
        max_digits=3, decimal_places=2, allow_null=True, required=False
    )
    quality_avg = serializers.DecimalField(
        max_digits=3, decimal_places=2, allow_null=True, required=False
    )
    credibility_avg = serializers.DecimalField(
        max_digits=3, decimal_places=2, allow_null=True, required=False
    )
    on_time_avg = serializers.DecimalField(
        max_digits=3, decimal_places=2, allow_null=True, required=False
    )
