from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("-id",)
    list_display = ("id", "phone", "role_state", "is_active", "is_staff", "created_at")
    list_filter = ("role_state", "is_active", "is_staff")
    search_fields = ("phone", "email", "username")

    fieldsets = (
        (None, {"fields": ("phone", "password")}),
        ("معلومات الحساب", {"fields": ("email", "username", "role_state")}),
        ("الصلاحيات", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("التواريخ", {"fields": ("last_login", "created_at")}),
    )

    add_fieldsets = (
        (None, {
            "classes": ("wide",),
            "fields": ("phone", "password1", "password2", "role_state", "is_staff", "is_superuser"),
        }),
    )
