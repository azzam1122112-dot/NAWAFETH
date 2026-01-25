from __future__ import annotations

from rest_framework.permissions import BasePermission, SAFE_METHODS


class BackofficeAccessPermission(BasePermission):
    """
    صلاحيات Backoffice:
    - يجب أن يكون المستخدم authenticated
    - يجب أن يكون staff أو لديه access_profile
    - إذا QA => يسمح فقط بالقراءة
    - يمنع الدخول إذا revoked أو expired
    """

    message = "لا تملك صلاحية الوصول لهذه اللوحة."

    def has_permission(self, request, view) -> bool:
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return False

        # staff بدون access_profile لا نعطيه صلاحية تلقائية هنا
        access_profile = getattr(user, "access_profile", None)
        if not access_profile:
            return False

        if access_profile.is_revoked() or access_profile.is_expired():
            self.message = "صلاحيتك منتهية أو تم إيقافها."
            return False

        # QA => قراءة فقط
        if access_profile.is_readonly() and request.method not in SAFE_METHODS:
            self.message = "حساب QA يسمح بالعرض فقط."
            return False

        return True
