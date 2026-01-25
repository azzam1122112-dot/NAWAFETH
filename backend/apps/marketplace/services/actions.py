import logging
from dataclasses import dataclass

from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction

from apps.marketplace.models import RequestStatus, ServiceRequest
from apps.providers.models import ProviderProfile

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ActionResult:
    ok: bool
    message: str
    new_status: str | None = None


def _role_flags(user, sr: ServiceRequest):
    is_staff = bool(getattr(user, "is_staff", False))
    user_id = getattr(user, "id", None)
    is_client = bool(user_id) and (sr.client_id == user_id)
    is_provider = bool(user_id) and bool(sr.provider_id) and (sr.provider.user_id == user_id)
    return is_staff, is_client, is_provider


def allowed_actions(user, sr: ServiceRequest, *, has_provider_profile: bool | None = None) -> list[str]:
    """
    Returns actions allowed for a given user and service request.

    Perf note:
    - If you are calling this for many objects (list page), pass has_provider_profile to avoid extra queries.
    """
    is_staff, is_client, is_provider = _role_flags(user, sr)
    acts: list[str] = []

    if is_staff:
        # staff can do everything operationally (you can tighten later)
        return ["send", "cancel", "accept", "start", "complete"]

    if is_client:
        if sr.status == RequestStatus.NEW:
            acts.extend(["send", "cancel"])
        elif sr.status == RequestStatus.SENT:
            acts.append("cancel")
        return acts

    # Provider (even if not assigned yet) may accept when SENT
    if sr.status == RequestStatus.SENT:
        user_id = getattr(user, "id", None)
        if user_id:
            if has_provider_profile is None:
                has_provider_profile = ProviderProfile.objects.filter(user_id=user_id).exists()
            if has_provider_profile:
                acts.append("accept")

    # Assigned provider actions
    if is_provider:
        if sr.status == RequestStatus.ACCEPTED:
            acts.append("start")
        elif sr.status == RequestStatus.IN_PROGRESS:
            acts.append("complete")
        return acts

    return acts


@transaction.atomic
def execute_action(
    *,
    user,
    request_id: int,
    action: str,
    provider_profile: ProviderProfile | None = None,
) -> ActionResult:
    sr = (
        ServiceRequest.objects.select_for_update()
        .select_related("client", "provider", "provider__user")
        .get(id=request_id)
    )

    is_staff, is_client, is_provider = _role_flags(user, sr)

    # send
    if action == "send":
        if not (is_staff or is_client):
            raise PermissionDenied("غير مصرح")
        sr.mark_sent()
        return ActionResult(True, "تم إرسال الطلب", sr.status)

    # cancel
    if action == "cancel":
        if not (is_staff or is_client):
            raise PermissionDenied("غير مصرح")
        sr.cancel()
        return ActionResult(True, "تم إلغاء الطلب", sr.status)

    # accept
    if action == "accept":
        if sr.status != RequestStatus.SENT:
            raise ValidationError("لا يمكن قبول الطلب الآن")

        # staff must choose provider (avoid ACCEPTED with no provider)
        if is_staff:
            if not provider_profile:
                raise ValidationError("اختر مزودًا لقبول الطلب")
            sr.accept(provider_profile)
            return ActionResult(True, "تم قبول الطلب وإسناده", sr.status)

        # provider must accept with their provider_profile
        if not provider_profile:
            raise ValidationError("لا يوجد ملف مزود مرتبط بهذا الحساب")

        sr.accept(provider_profile)
        return ActionResult(True, "تم قبول الطلب", sr.status)

    # start
    if action == "start":
        if not (is_staff or is_provider):
            raise PermissionDenied("غير مصرح")
        sr.start()
        return ActionResult(True, "تم بدء التنفيذ", sr.status)

    # complete
    if action == "complete":
        if not (is_staff or is_provider):
            raise PermissionDenied("غير مصرح")
        sr.complete()
        return ActionResult(True, "تم إكمال الطلب", sr.status)

    raise ValidationError("إجراء غير معروف")
