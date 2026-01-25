from __future__ import annotations

from decimal import Decimal
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.billing.models import Invoice, InvoiceStatus

from .models import (
    VerificationRequest, VerificationDocument,
    VerificationStatus, VerifiedBadge, VerificationBadgeType
)


def _safe_set_profile_flags(user, badge_type: str, active: bool):
    """
    محاولة تحديث ProviderProfile flags إن كانت موجودة في مشروعك.
    بدون كسر النظام لو ما كانت موجودة.
    """
    profile = getattr(user, "provider_profile", None) or getattr(user, "providerprofile", None)
    if not profile:
        return

    if badge_type == VerificationBadgeType.BLUE and hasattr(profile, "is_verified_blue"):
        profile.is_verified_blue = active
    if badge_type == VerificationBadgeType.GREEN and hasattr(profile, "is_verified_green"):
        profile.is_verified_green = active

    # اختياري: حفظ تاريخ انتهاء إن وجد
    if hasattr(profile, "verified_expires_at"):
        # لو عندك هذا الحقل مستقبلًا
        profile.verified_expires_at = None

    try:
        profile.save()
    except Exception:
        # لا نفشل التشغيل
        pass


def _fee_for_badge(badge_type: str) -> Decimal:
    """
    رسوم افتراضية (قابلة للتخصيص من settings لاحقًا).
    - الأزرق: 100
    - الأخضر: 50
    """
    blue_fee = getattr(settings, "VERIFY_BLUE_FEE", Decimal("100.00"))
    green_fee = getattr(settings, "VERIFY_GREEN_FEE", Decimal("50.00"))
    if badge_type == VerificationBadgeType.GREEN:
        return Decimal(str(green_fee))
    return Decimal(str(blue_fee))


@transaction.atomic
def decide_document(*, doc: VerificationDocument, is_approved: bool, note: str, by_user):
    doc = VerificationDocument.objects.select_for_update().get(pk=doc.pk)
    doc.is_approved = bool(is_approved)
    doc.decision_note = (note or "")[:300]
    doc.decided_by = by_user
    doc.decided_at = timezone.now()
    doc.save(update_fields=["is_approved", "decision_note", "decided_by", "decided_at"])
    return doc


@transaction.atomic
def finalize_request_and_create_invoice(*, vr: VerificationRequest, by_user):
    """
    اعتماد الطلب إذا:
    - كل المستندات تم اتخاذ قرار عليها
    - ولا يوجد أي مستند مرفوض
    ثم:
    - إنشاء فاتورة + تحويل الطلب إلى pending_payment
    """
    vr = VerificationRequest.objects.select_for_update().get(pk=vr.pk)

    docs = list(vr.documents.all())
    if not docs:
        raise ValueError("لا توجد مستندات مرفوعة لهذا الطلب.")

    undecided = [d for d in docs if d.is_approved is None]
    if undecided:
        raise ValueError("يوجد مستندات لم يتم اتخاذ قرار بشأنها بعد.")

    rejected = [d for d in docs if d.is_approved is False]
    if rejected:
        vr.status = VerificationStatus.REJECTED
        vr.reject_reason = "تم رفض بعض المستندات. الرجاء مراجعة البنود وإعادة الرفع."
        vr.reviewed_at = timezone.now()
        vr.save(update_fields=["status", "reject_reason", "reviewed_at", "updated_at"])
        return vr

    # كل شيء مقبول
    vr.status = VerificationStatus.APPROVED
    vr.approved_at = timezone.now()
    vr.reviewed_at = timezone.now()
    vr.save(update_fields=["status", "approved_at", "reviewed_at", "updated_at"])

    # إنشاء فاتورة
    if not vr.invoice_id:
        fee = _fee_for_badge(vr.badge_type)
        inv = Invoice.objects.create(
            user=vr.requester,
            title="رسوم التوثيق",
            description=f"توثيق {vr.get_badge_type_display()} لمدة سنة",
            subtotal=fee,
            reference_type="verify_request",
            reference_id=vr.code,
            status=InvoiceStatus.DRAFT,
        )
        inv.mark_pending()
        inv.save(update_fields=["status", "subtotal", "vat_percent", "vat_amount", "total", "updated_at"])
        vr.invoice = inv
        vr.status = VerificationStatus.PENDING_PAYMENT
        vr.save(update_fields=["invoice", "status", "updated_at"])

    return vr


@transaction.atomic
def activate_after_payment(*, vr: VerificationRequest):
    """
    تفعيل الشارة بعد الدفع:
    - إنشاء VerifiedBadge
    - تحديث flags على ProviderProfile إن وجد
    """
    vr = VerificationRequest.objects.select_for_update().get(pk=vr.pk)

    if not vr.invoice or vr.invoice.status != "paid":
        raise ValueError("الفاتورة غير مدفوعة بعد.")

    if vr.status == VerificationStatus.ACTIVE:
        return vr

    now = timezone.now()
    vr.activated_at = now
    vr.expires_at = now + vr.activation_window()
    vr.status = VerificationStatus.ACTIVE
    vr.save(update_fields=["activated_at", "expires_at", "status", "updated_at"])

    # إلغاء أي شارة سابقة من نفس النوع
    VerifiedBadge.objects.filter(
        user=vr.requester, badge_type=vr.badge_type, is_active=True
    ).update(is_active=False)

    VerifiedBadge.objects.create(
        user=vr.requester,
        badge_type=vr.badge_type,
        request=vr,
        activated_at=now,
        expires_at=vr.expires_at,
        is_active=True,
    )

    _safe_set_profile_flags(vr.requester, vr.badge_type, True)

    return vr
