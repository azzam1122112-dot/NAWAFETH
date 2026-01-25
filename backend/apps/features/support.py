from __future__ import annotations

from .checks import has_feature


def support_priority(user) -> str:
    """
    normal / high
    """
    if has_feature(user, "priority_support"):
        return "high"
    return "normal"
