from django.contrib import admin

from .models import Notification, DeviceToken, EventLog, NotificationPreference


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
	list_display = ("id", "user", "title", "kind", "is_read", "is_pinned", "is_follow_up", "is_urgent", "created_at")
	list_filter = ("kind", "is_read", "is_pinned", "is_follow_up", "is_urgent")
	search_fields = ("title", "body", "user__phone")


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
	list_display = ("id", "user", "platform", "is_active", "last_seen_at", "created_at")
	list_filter = ("platform", "is_active")
	search_fields = ("token", "user__phone")


@admin.register(EventLog)
class EventLogAdmin(admin.ModelAdmin):
	list_display = ("id", "event_type", "actor", "target_user", "request_id", "created_at")
	list_filter = ("event_type",)


@admin.register(NotificationPreference)
class NotificationPreferenceAdmin(admin.ModelAdmin):
	list_display = ("id", "user", "key", "enabled", "tier", "updated_at")
	list_filter = ("tier", "enabled")
	search_fields = ("user__phone", "key")
