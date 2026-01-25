from __future__ import annotations

from functools import wraps
from django.contrib import messages
from django.shortcuts import redirect

from .checks import has_feature


def require_feature(feature_key: str, redirect_to: str = "home"):
    def decorator(view_func):
        @wraps(view_func)
        def _wrapped(request, *args, **kwargs):
            if not has_feature(request.user, feature_key):
                messages.error(request, "هذه الميزة غير متاحة في باقتك الحالية.")
                return redirect(redirect_to)
            return view_func(request, *args, **kwargs)

        return _wrapped

    return decorator
