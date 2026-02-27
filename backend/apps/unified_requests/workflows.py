from __future__ import annotations

from .models import UnifiedRequestStatus, UnifiedRequestType


THREE_STAGE_ALLOWED_STATUSES: tuple[str, ...] = (
    UnifiedRequestStatus.NEW,
    UnifiedRequestStatus.IN_PROGRESS,
    UnifiedRequestStatus.COMPLETED,
)

HELPDESK_ALLOWED_STATUSES: tuple[str, ...] = (
    UnifiedRequestStatus.NEW,
    UnifiedRequestStatus.IN_PROGRESS,
    UnifiedRequestStatus.RETURNED,
    UnifiedRequestStatus.CLOSED,
)


THREE_STAGE_TRANSITIONS: dict[str, set[str]] = {
    UnifiedRequestStatus.NEW: {UnifiedRequestStatus.IN_PROGRESS},
    UnifiedRequestStatus.IN_PROGRESS: {UnifiedRequestStatus.COMPLETED},
    UnifiedRequestStatus.COMPLETED: set(),
}

HELPDESK_TRANSITIONS: dict[str, set[str]] = {
    UnifiedRequestStatus.NEW: {
        UnifiedRequestStatus.IN_PROGRESS,
        UnifiedRequestStatus.RETURNED,
        UnifiedRequestStatus.CLOSED,
    },
    UnifiedRequestStatus.IN_PROGRESS: {
        UnifiedRequestStatus.RETURNED,
        UnifiedRequestStatus.CLOSED,
    },
    UnifiedRequestStatus.RETURNED: {
        UnifiedRequestStatus.IN_PROGRESS,
        UnifiedRequestStatus.CLOSED,
    },
    UnifiedRequestStatus.CLOSED: set(),
}


def allowed_statuses_for_request_type(request_type: str) -> tuple[str, ...]:
    if request_type in {
        UnifiedRequestType.PROMO,
        UnifiedRequestType.SUBSCRIPTION,
        UnifiedRequestType.EXTRAS,
    }:
        return THREE_STAGE_ALLOWED_STATUSES
    if request_type in {UnifiedRequestType.HELPDESK, UnifiedRequestType.REVIEWS}:
        return HELPDESK_ALLOWED_STATUSES
    return tuple(v for v, _ in UnifiedRequestStatus.choices)


def is_valid_transition(*, request_type: str, from_status: str, to_status: str) -> bool:
    if from_status == to_status:
        return True
    if request_type in {
        UnifiedRequestType.PROMO,
        UnifiedRequestType.SUBSCRIPTION,
        UnifiedRequestType.EXTRAS,
    }:
        return to_status in THREE_STAGE_TRANSITIONS.get(from_status, set())
    if request_type in {UnifiedRequestType.HELPDESK, UnifiedRequestType.REVIEWS}:
        return to_status in HELPDESK_TRANSITIONS.get(from_status, set())
    return True
