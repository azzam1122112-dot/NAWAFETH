from __future__ import annotations

from .models import AuditLog


def get_ip(request):
    xff = request.META.get("HTTP_X_FORWARDED_FOR")
    if xff:
        return xff.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def log_action(
    *,
    actor=None,
    action: str,
    reference_type: str = "",
    reference_id: str = "",
    request=None,
    extra: dict | None = None,
):
    ip = None
    ua = ""
    if request is not None:
        ip = get_ip(request)
        ua = (request.META.get("HTTP_USER_AGENT") or "")[:255]

    AuditLog.objects.create(
        actor=actor,
        action=action,
        reference_type=reference_type or "",
        reference_id=reference_id or "",
        ip_address=ip,
        user_agent=ua,
        extra=extra or {},
    )
