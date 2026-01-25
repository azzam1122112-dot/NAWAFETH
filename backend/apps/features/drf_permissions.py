from __future__ import annotations

from rest_framework.permissions import BasePermission
from .checks import has_feature


class HasFeature(BasePermission):
    """
    استخدمه عبر:
    permission_classes = [HasFeature.with_key("promo_ads")]
    """

    feature_key = None

    @classmethod
    def with_key(cls, key: str):
        class _K(cls):
            feature_key = key
        return _K

    def has_permission(self, request, view):
        if not self.feature_key:
            return False
        return has_feature(request.user, self.feature_key)
