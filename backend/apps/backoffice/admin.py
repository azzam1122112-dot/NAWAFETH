from django.contrib import admin
from .models import Dashboard, UserAccessProfile


@admin.register(Dashboard)
class DashboardAdmin(admin.ModelAdmin):
    list_display = ("code", "name_ar", "is_active", "sort_order")
    list_filter = ("is_active",)
    search_fields = ("code", "name_ar")
    ordering = ("sort_order", "code")


@admin.register(UserAccessProfile)
class UserAccessProfileAdmin(admin.ModelAdmin):
    list_display = ("user", "level", "expires_at", "revoked_at", "created_at")
    list_filter = ("level",)
    search_fields = ("user__phone", "user__email")
    filter_horizontal = ("allowed_dashboards",)
