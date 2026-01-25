from __future__ import annotations

from rest_framework import serializers
from .models import ExtraPurchase


class ExtraCatalogItemSerializer(serializers.Serializer):
    sku = serializers.CharField()
    title = serializers.CharField()
    price = serializers.DecimalField(max_digits=12, decimal_places=2)


class ExtraPurchaseSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExtraPurchase
        fields = [
            "id", "sku", "title",
            "extra_type", "subtotal", "currency",
            "status",
            "start_at", "end_at",
            "credits_total", "credits_used",
            "invoice",
            "created_at",
        ]
