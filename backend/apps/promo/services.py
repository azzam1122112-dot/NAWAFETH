from __future__ import annotations

from decimal import Decimal
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.billing.models import Invoice, InvoiceStatus

from .models import (
    PromoRequest, PromoRequestStatus,
    PromoAdType, PromoPosition, PromoFrequency
)


def _get_base_price(ad_type: str) -> Decimal:
    base_prices = getattr(settings, "PROMO_BASE_PRICES", {})
    val = base_prices.get(ad_type, 300)
    return Decimal(str(val))


def _get_position_multiplier(position: str) -> Decimal:
    mp = getattr(settings, "PROMO_POSITION_MULTIPLIER", {})
    val = mp.get(position, 1.0)
    return Decimal(str(val))


def _get_frequency_multiplier(freq: str) -> Decimal:
    mf = getattr(settings, "PROMO_FREQUENCY_MULTIPLIER", {})
    val = mf.get(freq, 1.0)
    return Decimal(str(val))


def calc_promo_quote(*, pr: PromoRequest) -> dict:
    """
    تسعير بسيط قابل للتطوير:
    السعر = base(ad_type) * position_multiplier * frequency_multiplier * days
    """
    start = pr.start_at
    end = pr.end_at

    days = (end.date() - start.date()).days
    if days <= 0:
        days = 1

    base = _get_base_price(pr.ad_type)
    pos_mul = _get_position_multiplier(pr.position)
    freq_mul = _get_frequency_multiplier(pr.frequency)

    subtotal = base * pos_mul * freq_mul * Decimal(str(days))

    # تقريب لمنطقي
    subtotal = subtotal.quantize(Decimal("0.01"))

    return {"subtotal": subtotal, "days": days}


@transaction.atomic
def quote_and_create_invoice(*, pr: PromoRequest, by_user, quote_note: str = "") -> PromoRequest:
    pr = PromoRequest.objects.select_for_update().get(pk=pr.pk)

    if pr.status in (PromoRequestStatus.ACTIVE, PromoRequestStatus.EXPIRED):
        raise ValueError("لا يمكن تسعير حملة مفعلة/منتهية.")

    # لابد وجود مواد
    if not pr.assets.exists():
        raise ValueError("لا يمكن التسعير قبل رفع مواد الإعلان.")

    q = calc_promo_quote(pr=pr)
    pr.subtotal = q["subtotal"]
    pr.total_days = q["days"]
    pr.quote_note = (quote_note or "")[:300]
    pr.reviewed_at = timezone.now()

    # إنشاء فاتورة إذا غير موجودة
    if not pr.invoice_id:
        inv = Invoice.objects.create(
            user=pr.requester,
            title="فاتورة إعلان وترويج",
            description=f"حملة {pr.get_ad_type_display()} لمدة {pr.total_days} يوم",
            subtotal=pr.subtotal,
            reference_type="promo_request",
            reference_id=pr.code,
            status=InvoiceStatus.DRAFT,
        )
        inv.mark_pending()
        inv.save(update_fields=["status", "subtotal", "vat_percent", "vat_amount", "total", "updated_at"])

        pr.invoice = inv

    pr.status = PromoRequestStatus.PENDING_PAYMENT
    pr.save(update_fields=[
        "subtotal", "total_days", "quote_note",
        "reviewed_at", "invoice", "status", "updated_at"
    ])
    return pr


@transaction.atomic
def reject_request(*, pr: PromoRequest, reason: str, by_user) -> PromoRequest:
    pr = PromoRequest.objects.select_for_update().get(pk=pr.pk)
    pr.status = PromoRequestStatus.REJECTED
    pr.reject_reason = (reason or "")[:300]
    pr.reviewed_at = timezone.now()
    pr.save(update_fields=["status", "reject_reason", "reviewed_at", "updated_at"])
    return pr


@transaction.atomic
def activate_after_payment(*, pr: PromoRequest) -> PromoRequest:
    pr = PromoRequest.objects.select_for_update().get(pk=pr.pk)

    if not pr.invoice or pr.invoice.status != "paid":
        raise ValueError("الفاتورة غير مدفوعة بعد.")

    now = timezone.now()

    # تفعيل فقط داخل فترة الحملة
    if pr.end_at <= now:
        pr.status = PromoRequestStatus.EXPIRED
        pr.save(update_fields=["status", "updated_at"])
        return pr

    pr.status = PromoRequestStatus.ACTIVE
    pr.activated_at = now
    pr.save(update_fields=["status", "activated_at", "updated_at"])

    # Audit
    try:
        from apps.audit.services import log_action
        from apps.audit.models import AuditAction

        log_action(
            actor=pr.requester,
            action=AuditAction.PROMO_REQUEST_ACTIVE,
            reference_type="promo_request",
            reference_id=pr.code,
        )
    except Exception:
        pass

    return pr
