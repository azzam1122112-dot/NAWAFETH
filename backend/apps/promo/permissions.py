from __future__ import annotations

from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsOwnerOrBackofficePromo(BasePermission):
    """
    - المالك يرى طلبه
    - فريق الإعلانات يتطلب وصول لوحة promo
    - QA عرض فقط
    """
    message = "غير مصرح."

    def _is_backoffice_request(self, request) -> bool:
        return "/backoffice/" in (getattr(request, "path", "") or "")

    def _has_backoffice_access(self, request) -> bool:
        ap = getattr(request.user, "access_profile", None)
        if not ap:
            return False
        if ap.is_revoked() or ap.is_expired():
            return False

        if ap.is_readonly() and request.method not in SAFE_METHODS:
            self.message = "حساب QA للعرض فقط."
            return False

        if ap.level in ("admin", "power"):
            return True

        return ap.is_allowed("promo")

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if self._is_backoffice_request(request):
            return self._has_backoffice_access(request)
        return True

    def has_object_permission(self, request, view, obj):
        user = request.user

        if self._is_backoffice_request(request):
            return self._has_backoffice_access(request)

        if obj.requester_id == user.id:
            return True

        return self._has_backoffice_access(request)
