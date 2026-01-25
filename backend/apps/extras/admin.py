from django.contrib import admin
from .models import ExtraPurchase


@admin.register(ExtraPurchase)
class ExtraPurchaseAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "sku", "extra_type", "status", "subtotal", "start_at", "end_at", "credits_total", "credits_used")
    list_filter = ("extra_type", "status", "sku")
    search_fields = ("user__phone", "sku", "title")
    ordering = ("-id",)
