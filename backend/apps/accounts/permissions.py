from __future__ import annotations

from rest_framework.permissions import BasePermission


ROLE_LEVELS: dict[str, int] = {
    # unauthenticated visitor is handled separately (0)
    "visitor": 0,
    "phone_only": 1,
    "client": 2,
    "provider": 3,
    "staff": 99,
}


def role_level(user) -> int:
    if not user or not getattr(user, "is_authenticated", False):
        return 0

    # Staff bypass
    if bool(getattr(user, "is_staff", False)):
        return ROLE_LEVELS["staff"]

    role_state = (getattr(user, "role_state", "") or "").strip().lower()
    return ROLE_LEVELS.get(role_state, 0)


class RoleAtLeast(BasePermission):
    """Require user to be authenticated and at least a given role level.

    Subclasses must set `min_level`.
    """

    min_level: int = 0

    def has_permission(self, request, view):
        return role_level(getattr(request, "user", None)) >= self.min_level


class IsAtLeastPhoneOnly(RoleAtLeast):
    min_level = ROLE_LEVELS["phone_only"]


class IsAtLeastClient(RoleAtLeast):
    min_level = ROLE_LEVELS["client"]


class IsAtLeastProvider(RoleAtLeast):
    min_level = ROLE_LEVELS["provider"]
