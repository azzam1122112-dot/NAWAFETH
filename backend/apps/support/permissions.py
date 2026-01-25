from __future__ import annotations

from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsRequesterOrBackofficeSupport(BasePermission):
    """
    - العميل يرى/يعدل تذكرته (ضمن حدود معينة)
    - فريق الدعم يتطلب Backoffice access للوحة support
    """

    message = "غير مصرح لك."

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False

        # السماح للعميل بإنشاء تذكرة
        if request.method == "POST":
            return True

        # غير POST: يحتاج يا (owner) أو backoffice
        return True

    def has_object_permission(self, request, view, obj):
        user = request.user

        # مالك التذكرة
        if obj.requester_id == user.id:
            # العميل لا يقدر يغير status/assignment عبر endpoints التشغيل
            return True

        # backoffice support check
        ap = getattr(user, "access_profile", None)
        if not ap:
            return False

        if ap.is_revoked() or ap.is_expired():
            return False

        # QA read-only
        if ap.is_readonly() and request.method not in SAFE_METHODS:
            self.message = "حساب QA للعرض فقط."
            return False

        # admin/power يشوف كله
        if ap.level in ("admin", "power"):
            return True

        # user يحتاج وصول للوحة support
        return ap.is_allowed("support")
