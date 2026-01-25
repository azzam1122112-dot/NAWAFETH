from django.contrib import admin
from .models import Invoice, PaymentAttempt, WebhookEvent


@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display = ("code", "user", "status", "subtotal", "vat_amount", "total", "currency", "paid_at", "created_at")
    list_filter = ("status", "currency")
    search_fields = ("code", "user__phone", "reference_type", "reference_id")
    ordering = ("-id",)


@admin.register(PaymentAttempt)
class PaymentAttemptAdmin(admin.ModelAdmin):
    list_display = ("id", "invoice", "provider", "status", "amount", "currency", "created_at")
    list_filter = ("provider", "status", "currency")
    search_fields = ("provider_reference", "idempotency_key", "invoice__code")
    ordering = ("-created_at",)


@admin.register(WebhookEvent)
class WebhookEventAdmin(admin.ModelAdmin):
    list_display = ("provider", "event_id", "received_at")
    list_filter = ("provider",)
    search_fields = ("event_id",)
    ordering = ("-received_at",)
