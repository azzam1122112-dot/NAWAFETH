from django.contrib import admin
from .models import SubscriptionPlan, Subscription


@admin.register(SubscriptionPlan)
class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = ("code", "title", "period", "price", "is_active")
    list_filter = ("period", "is_active")
    search_fields = ("code", "title")


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "plan", "status", "start_at", "end_at", "grace_end_at", "auto_renew")
    list_filter = ("status", "auto_renew")
    search_fields = ("user__phone", "plan__code")
    ordering = ("-id",)
