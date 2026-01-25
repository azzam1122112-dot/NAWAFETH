from __future__ import annotations

from apps.subscriptions.services import user_has_feature
from apps.extras.services import user_has_active_extra


def has_feature(user, feature_key: str) -> bool:
    """
    فحص موحّد للميزة من:
    - الاشتراك
    - أو Extras/Add-ons
    """
    if not user or not user.is_authenticated:
        return False

    # 1) اشتراك
    if user_has_feature(user, feature_key):
        return True

    # 2) Extras fallback
    # mapping feature -> sku_prefix
    extra_map = {
        "promo_ads": "promo_",
        "extra_uploads": "uploads_",
        "priority_support": "vip_support_",
        "verify_blue": "verify_blue_",
        "verify_green": "verify_green_",
    }
    sku_prefix = extra_map.get(feature_key)
    if sku_prefix:
        return user_has_active_extra(user, sku_prefix)

    return False
