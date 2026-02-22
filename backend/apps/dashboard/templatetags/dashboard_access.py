from __future__ import annotations

from django import template

register = template.Library()


@register.simple_tag
def can_access(user, dashboard_code: str, write: bool = False) -> bool:
    if not getattr(user, "is_authenticated", False):
        return False
    if getattr(user, "is_superuser", False):
        return True
    if not getattr(user, "is_staff", False):
        return False

    access_profile = getattr(user, "access_profile", None)
    if not access_profile:
        return False

    if access_profile.is_revoked() or access_profile.is_expired():
        return False
    if write and access_profile.is_readonly():
        return False
    if access_profile.level in {"admin", "power"}:
        return True

    return access_profile.allowed_dashboards.filter(
        code=dashboard_code,
        is_active=True,
    ).exists()
