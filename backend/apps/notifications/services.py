from django.db import transaction

from .models import Notification, EventLog, EventType


def create_notification(
    *,
    user,
    title: str,
    body: str,
    kind: str = "info",
    url: str = "",
    actor=None,
    event_type: str | None = None,
    request_id: int | None = None,
    offer_id: int | None = None,
    message_id: int | None = None,
    meta: dict | None = None,
):
    meta = meta or {}

    with transaction.atomic():
        notif = Notification.objects.create(
            user=user,
            title=title,
            body=body,
            kind=kind,
            url=url,
        )
        if event_type:
            EventLog.objects.create(
                event_type=event_type,
                actor=actor,
                target_user=user,
                request_id=request_id,
                offer_id=offer_id,
                message_id=message_id,
                meta=meta,
            )
    return notif
