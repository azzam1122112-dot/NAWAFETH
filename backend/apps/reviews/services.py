from __future__ import annotations

from apps.unified_requests.models import UnifiedRequestStatus, UnifiedRequestType
from apps.unified_requests.services import upsert_unified_request

from .models import Review, ReviewModerationStatus


def _review_status_to_unified(moderation_status: str) -> str:
    if moderation_status in {ReviewModerationStatus.REJECTED, ReviewModerationStatus.HIDDEN}:
        return UnifiedRequestStatus.CLOSED
    return UnifiedRequestStatus.NEW


def sync_review_to_unified(*, review: Review, changed_by=None, force_status: str | None = None):
    status = force_status or _review_status_to_unified(review.moderation_status)
    summary = (review.comment or "").strip()
    if not summary:
        summary = f"مراجعة للطلب #{review.request_id}"

    return upsert_unified_request(
        request_type=UnifiedRequestType.REVIEWS,
        requester=review.client,
        source_app="reviews",
        source_model="Review",
        source_object_id=review.id,
        status=status,
        priority="normal",
        summary=summary[:300],
        metadata={
            "review_id": review.id,
            "request_id": review.request_id,
            "provider_id": review.provider_id,
            "moderation_status": review.moderation_status,
            "rating": review.rating,
        },
        assigned_team_code="content",
        assigned_team_name="المحتوى والمراجعات",
        assigned_user=None,
        changed_by=changed_by,
    )
