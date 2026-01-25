from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.billing.models import Invoice, InvoiceStatus

from .models import ExtraPurchase, ExtraPurchaseStatus, ExtraType


def get_extra_catalog() -> dict:
    """
    كتالوج الإضافات من settings (مبدئي)
    """
    return getattr(settings, "EXTRA_SKUS", {}) or {}


def sku_info(sku: str) -> dict:
    catalog = get_extra_catalog()
    if sku not in catalog:
        raise ValueError("SKU غير موجود.")
    return catalog[sku]


def infer_extra_type(sku: str) -> str:
    """
    تصنيف بسيط:
    - tickets_* => credits
    - غيره => time_based
    """
    if sku.startswith("tickets_"):
        return ExtraType.CREDIT_BASED
    return ExtraType.TIME_BASED


def infer_duration(sku: str) -> timedelta:
    """
    مدد افتراضية:
    - *_month => 30 يوم
    - *_7d => 7 أيام
    """
    if sku.endswith("_month"):
        return timedelta(days=30)
    if sku.endswith("_7d"):
        return timedelta(days=7)
    return timedelta(days=30)


def infer_credits(sku: str) -> int:
    """
    tickets_100 => 100
    """
    if sku.startswith("tickets_"):
        n = sku.replace("tickets_", "").strip()
        try:
            return int(n)
        except Exception:
            return 0
    return 0


@transaction.atomic
def create_extra_purchase_checkout(*, user, sku: str) -> ExtraPurchase:
    info = sku_info(sku)
    title = info.get("title", sku)
    price = Decimal(str(info.get("price", 0)))

    if price <= 0:
        raise ValueError("سعر الإضافة غير صحيح.")

    etype = infer_extra_type(sku)

    purchase = ExtraPurchase.objects.create(
        user=user,
        sku=sku,
        title=title,
        extra_type=etype,
        subtotal=price,
        status=ExtraPurchaseStatus.PENDING_PAYMENT,
    )

    # إعداد credits إن كانت credit-based
    if etype == ExtraType.CREDIT_BASED:
        purchase.credits_total = infer_credits(sku)
        purchase.save(update_fields=["credits_total", "updated_at"])

    inv = Invoice.objects.create(
        user=user,
        title="فاتورة إضافة مدفوعة",
        description=f"{title}",
        subtotal=purchase.subtotal,
        reference_type="extra_purchase",
        reference_id=str(purchase.pk),
        status=InvoiceStatus.DRAFT,
    )
    inv.mark_pending()
    inv.save(update_fields=["status", "subtotal", "vat_percent", "vat_amount", "total", "updated_at"])

    purchase.invoice = inv
    purchase.save(update_fields=["invoice", "updated_at"])
    return purchase


@transaction.atomic
def activate_extra_after_payment(*, purchase: ExtraPurchase) -> ExtraPurchase:
    purchase = ExtraPurchase.objects.select_for_update().get(pk=purchase.pk)

    if not purchase.invoice or purchase.invoice.status != "paid":
        raise ValueError("الفاتورة غير مدفوعة بعد.")

    if purchase.status == ExtraPurchaseStatus.ACTIVE:
        return purchase

    now = timezone.now()

    if purchase.extra_type == ExtraType.TIME_BASED:
        dur = infer_duration(purchase.sku)
        purchase.start_at = now
        purchase.end_at = now + dur
        purchase.status = ExtraPurchaseStatus.ACTIVE
        purchase.save(update_fields=["start_at", "end_at", "status", "updated_at"])
        return purchase

    # credit based
    if purchase.extra_type == ExtraType.CREDIT_BASED:
        purchase.status = ExtraPurchaseStatus.ACTIVE
        purchase.save(update_fields=["status", "updated_at"])
        return purchase

    return purchase


@transaction.atomic
def consume_credit(*, user, sku: str, amount: int = 1) -> bool:
    """
    استهلاك رصيد من أحدث عملية شراء فعالة للـ SKU (credits)
    """
    if amount <= 0:
        return True

    p = ExtraPurchase.objects.select_for_update().filter(
        user=user,
        sku=sku,
        extra_type=ExtraType.CREDIT_BASED,
        status=ExtraPurchaseStatus.ACTIVE,
    ).order_by("-id").first()

    if not p:
        return False

    if p.credits_left() < amount:
        return False

    p.credits_used += amount
    if p.credits_left() == 0:
        p.status = ExtraPurchaseStatus.CONSUMED

    p.save(update_fields=["credits_used", "status", "updated_at"])
    return True


def user_has_active_extra(user, sku_prefix: str) -> bool:
    """
    فحص وجود Add-on فعال (زمني أو credits) حسب بادئة sku
    """
    now = timezone.now()
    qs = ExtraPurchase.objects.filter(
        user=user,
        sku__startswith=sku_prefix,
        status=ExtraPurchaseStatus.ACTIVE,
    )
    for p in qs.order_by("-id")[:20]:
        if p.extra_type == ExtraType.TIME_BASED:
            if p.start_at and p.end_at and p.start_at <= now < p.end_at:
                return True
        else:
            if p.credits_left() > 0:
                return True
    return False
