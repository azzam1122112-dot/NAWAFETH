from __future__ import annotations

from apps.subscriptions.models import Subscription
from apps.subscriptions.services import refresh_subscription_status


class SubscriptionRefreshMiddleware:
    """
    تحديث حالة الاشتراك بشكل خفيف عند كل Request
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        user = getattr(request, "user", None)
        if user and user.is_authenticated:
            sub = Subscription.objects.filter(user=user).order_by("-id").first()
            if sub:
                try:
                    refresh_subscription_status(sub=sub)
                except Exception:
                    pass

        return self.get_response(request)
