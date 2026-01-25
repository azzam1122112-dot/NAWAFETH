from django.contrib import admin
from .models import PromoRequest, PromoAsset


class PromoAssetInline(admin.TabularInline):
    model = PromoAsset
    extra = 0


@admin.register(PromoRequest)
class PromoRequestAdmin(admin.ModelAdmin):
    list_display = ("code", "requester", "ad_type", "status", "start_at", "end_at", "subtotal", "invoice", "created_at")
    list_filter = ("ad_type", "status")
    search_fields = ("code", "title", "requester__phone")
    ordering = ("-id",)
    inlines = [PromoAssetInline]
