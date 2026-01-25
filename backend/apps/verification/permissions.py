from __future__ import annotations

from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsOwnerOrBackofficeVerify(BasePermission):
    """
    - المالك يرى طلبه
    - فريق التوثيق يتطلب وصول لوحة verify
    - QA عرض فقط
    """
    message = "غير مصرح."

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return True

    def has_object_permission(self, request, view, obj):
        user = request.user

        # owner
        if obj.requester_id == user.id:
            return True

        # backoffice
        ap = getattr(user, "access_profile", None)
        if not ap:
            return False
        if ap.is_revoked() or ap.is_expired():
            return False

        if ap.is_readonly() and request.method not in SAFE_METHODS:
            self.message = "حساب QA للعرض فقط."
            return False

        if ap.level in ("admin", "power"):
            return True

        return ap.is_allowed("verify")
