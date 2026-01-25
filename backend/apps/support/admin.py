from django.contrib import admin
from .models import SupportTicket, SupportAttachment, SupportComment, SupportTeam, SupportStatusLog


@admin.register(SupportTeam)
class SupportTeamAdmin(admin.ModelAdmin):
    list_display = ("code", "name_ar", "is_active", "sort_order")
    list_filter = ("is_active",)
    search_fields = ("code", "name_ar")
    ordering = ("sort_order", "code")


class SupportAttachmentInline(admin.TabularInline):
    model = SupportAttachment
    extra = 0


class SupportCommentInline(admin.TabularInline):
    model = SupportComment
    extra = 0


class SupportStatusLogInline(admin.TabularInline):
    model = SupportStatusLog
    extra = 0
    readonly_fields = ("from_status", "to_status", "changed_by", "note", "created_at")


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ("code", "ticket_type", "status", "priority", "requester", "assigned_team", "assigned_to", "created_at")
    list_filter = ("ticket_type", "status", "priority")
    search_fields = ("code", "description", "requester__phone")
    inlines = [SupportAttachmentInline, SupportCommentInline, SupportStatusLogInline]
    ordering = ("-id",)
