from __future__ import annotations

from rest_framework import serializers
from .models import SubscriptionPlan, Subscription


class PlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = ["id", "code", "title", "description", "period", "price", "features", "is_active"]


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = PlanSerializer(read_only=True)

    class Meta:
        model = Subscription
        fields = ["id", "plan", "status", "start_at", "end_at", "grace_end_at", "auto_renew", "invoice", "created_at"]
