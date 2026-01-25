from __future__ import annotations

from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsBackofficeAnalytics(BasePermission):
    """
    - admin/power => كامل
    - user => حسب modules (finance/promo/verify)
    - QA => read-only
    """

    message = "غير مصرح للوصول للوحة التحليلات."

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        ap = getattr(user, "access_profile", None)
        if not ap:
            return False

        if ap.is_revoked() or ap.is_expired():
            return False

        # QA read-only
        if ap.is_readonly() and request.method not in SAFE_METHODS:
            self.message = "صلاحية QA للعرض فقط."
            return False

        # admin/power allow
        if ap.level in ("admin", "power"):
            return True

        # user allow if has any module
        return ap.is_allowed("finance") or ap.is_allowed("promo") or ap.is_allowed("verify")
