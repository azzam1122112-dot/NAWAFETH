from django.contrib import admin

from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
	list_display = ("id", "action", "actor", "reference_type", "reference_id", "ip_address", "created_at")
	list_filter = ("action", "reference_type")
	search_fields = ("reference_id", "actor__phone", "ip_address")
	ordering = ("-id",)

# Register your models here.
