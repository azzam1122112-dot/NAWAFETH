from __future__ import annotations

import secrets
from django.db import transaction
from django.utils import timezone

from .models import (
    Invoice, PaymentAttempt, WebhookEvent,
    InvoiceStatus, PaymentAttemptStatus
)


def _make_checkout_url(provider: str, attempt_id: str) -> str:
    """
    رابط تجريبي (Mock).
    لاحقًا سيتم استبداله برابط بوابة الدفع الحقيقي.
    """
    return f"https://example-pay.local/checkout/{provider}/{attempt_id}"


@transaction.atomic
def init_payment(*, invoice: Invoice, provider: str, by_user, idempotency_key: str | None = None):
    """
    إنشاء محاولة دفع مع idempotency:
    - إذا وصل نفس idempotency_key لنفس الفاتورة ولم تنجح/تفشل بشكل نهائي => نعيد نفس المحاولة
    """
    invoice = Invoice.objects.select_for_update().get(pk=invoice.pk)

    if invoice.status == InvoiceStatus.PAID:
        raise ValueError("الفاتورة مدفوعة بالفعل.")

    if not idempotency_key:
        idempotency_key = secrets.token_urlsafe(24)

    existing = PaymentAttempt.objects.filter(
        invoice=invoice,
        idempotency_key=idempotency_key,
    ).order_by("-created_at").first()

    if existing:
        return existing

    invoice.status = InvoiceStatus.PENDING
    invoice.save(update_fields=["status", "updated_at"])

    attempt = PaymentAttempt.objects.create(
        invoice=invoice,
        provider=provider,
        status=PaymentAttemptStatus.INITIATED,
        idempotency_key=idempotency_key,
        amount=invoice.total,
        currency=invoice.currency,
        created_by=by_user,
        request_payload={"invoice_code": invoice.code, "total": str(invoice.total)},
    )

    # في المزود الحقيقي هنا سننشئ Session/Intent ثم نخزن checkout_url + provider_reference
    attempt.checkout_url = _make_checkout_url(provider, str(attempt.id))
    attempt.provider_reference = f"mock_ref_{attempt.id.hex[:12]}"
    attempt.status = PaymentAttemptStatus.REDIRECTED
    attempt.save(update_fields=["checkout_url", "provider_reference", "status"])

    return attempt


@transaction.atomic
def handle_webhook(*, provider: str, payload: dict, signature: str = "", event_id: str = ""):
    """
    معالجة webhook بشكل عام:
    - نحفظ الحدث في WebhookEvent
    - نحدد الفاتورة عبر provider_reference أو invoice_code
    - نحدث حالة attempt والفاتورة
    """
    # حفظ الحدث raw
    WebhookEvent.objects.create(
        provider=provider,
        event_id=(event_id or "")[:120],
        signature=(signature or "")[:200],
        payload=payload or {},
    )

    provider_reference = (payload.get("provider_reference") or payload.get("reference") or "").strip()
    invoice_code = (payload.get("invoice_code") or "").strip()
    status_str = (payload.get("status") or "").lower().strip()

    attempt = None
    if provider_reference:
        attempt = PaymentAttempt.objects.select_for_update().filter(
            provider=provider,
            provider_reference=provider_reference,
        ).order_by("-created_at").first()

    if not attempt and invoice_code:
        attempt = PaymentAttempt.objects.select_for_update().filter(
            invoice__code=invoice_code
        ).order_by("-created_at").first()

    if not attempt:
        # لا نكسر النظام: نخزن الحدث فقط
        return {"ok": False, "detail": "attempt not found"}

    invoice = Invoice.objects.select_for_update().get(pk=attempt.invoice_id)

    # خريطة حالات عامة
    if status_str in ("paid", "success", "succeeded"):
        attempt.status = PaymentAttemptStatus.SUCCESS
        attempt.response_payload = payload
        attempt.save(update_fields=["status", "response_payload"])

        invoice.mark_paid(when=timezone.now())
        invoice.save(update_fields=["status", "paid_at", "updated_at"])

        # Audit
        try:
            from apps.audit.services import log_action
            from apps.audit.models import AuditAction

            log_action(
                actor=invoice.user,
                action=AuditAction.INVOICE_PAID,
                reference_type="invoice",
                reference_id=invoice.code,
                request=None,
                extra={"total": str(invoice.total)},
            )
        except Exception:
            pass

        return {"ok": True, "invoice": invoice.code, "status": "paid"}

    if status_str in ("failed", "error"):
        attempt.status = PaymentAttemptStatus.FAILED
        attempt.response_payload = payload
        attempt.save(update_fields=["status", "response_payload"])

        invoice.mark_failed()
        invoice.save(update_fields=["status", "updated_at"])
        return {"ok": True, "invoice": invoice.code, "status": "failed"}

    if status_str in ("cancelled", "canceled"):
        attempt.status = PaymentAttemptStatus.CANCELLED
        attempt.response_payload = payload
        attempt.save(update_fields=["status", "response_payload"])

        invoice.mark_cancelled()
        invoice.save(update_fields=["status", "cancelled_at", "updated_at"])
        return {"ok": True, "invoice": invoice.code, "status": "cancelled"}

    # status unknown
    attempt.response_payload = payload
    attempt.save(update_fields=["response_payload"])
    return {"ok": True, "invoice": invoice.code, "status": "ignored"}
