from __future__ import annotations

from apps.features.checks import has_feature
from apps.extras.services import user_has_active_extra


def user_max_upload_mb(user) -> int:
    """
    حدود مبدئية:
    - Basic: 10MB
    - Pro: 50MB
    - Extra Uploads: 100MB
    """
    if not user or not getattr(user, "is_authenticated", False):
        return 10

    # Extra uploads (اشتراك أو add-on)
    if has_feature(user, "extra_uploads") or user_has_active_extra(user, "uploads_"):
        return 100

    # Pro-ish features
    if has_feature(user, "promo_ads") or has_feature(user, "verify_blue"):
        return 50

    return 10
