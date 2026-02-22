from __future__ import annotations

from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsRequesterOrBackofficeSupport(BasePermission):
    """
    - العميل يرى/يعدل تذكرته (ضمن حدود معينة)
    - فريق الدعم يتطلب Backoffice access للوحة support
    """

    message = "غير مصرح لك."

    def _is_backoffice_request(self, request) -> bool:
        return "/backoffice/" in (getattr(request, "path", "") or "")

    def _has_backoffice_access(self, request) -> bool:
        user = request.user
        ap = getattr(user, "access_profile", None)
        if not ap:
            return False

        if ap.is_revoked() or ap.is_expired():
            return False

        # QA read-only
        if ap.is_readonly() and request.method not in SAFE_METHODS:
            self.message = "حساب QA للعرض فقط."
            return False

        if ap.level in ("admin", "power"):
            return True

        return ap.is_allowed("support")

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        # Endpoints under /backoffice/ must always be protected by backoffice access.
        if self._is_backoffice_request(request):
            return self._has_backoffice_access(request)

        # Client-side support endpoints are available to authenticated users.
        return True

    def has_object_permission(self, request, view, obj):
        user = request.user

        # Backoffice objects require backoffice access even if requester matches.
        if self._is_backoffice_request(request):
            if not self._has_backoffice_access(request):
                return False

            ap = getattr(user, "access_profile", None)
            if ap and ap.level == "user":
                # User sees only assigned items (or unassigned pool).
                assigned_to_id = getattr(obj, "assigned_to_id", None)
                if assigned_to_id is not None and assigned_to_id != user.id:
                    self.message = "غير مصرح: هذه التذكرة ليست ضمن المهام المكلّف بها."
                    return False
            return True

        # مالك التذكرة
        if obj.requester_id == user.id:
            return True

        return self._has_backoffice_access(request)
