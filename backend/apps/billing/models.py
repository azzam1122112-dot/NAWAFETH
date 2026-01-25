from __future__ import annotations

import uuid
from decimal import Decimal, ROUND_HALF_UP

from django.conf import settings
from django.db import models
from django.utils import timezone


def money_round(val: Decimal) -> Decimal:
    """
    تقريب الأموال لرقمين عشريين
    """
    return (val or Decimal("0.00")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


class InvoiceStatus(models.TextChoices):
    DRAFT = "draft", "مسودة"
    PENDING = "pending", "بانتظار الدفع"
    PAID = "paid", "مدفوعة"
    FAILED = "failed", "فشلت"
    CANCELLED = "cancelled", "ملغاة"
    REFUNDED = "refunded", "مسترجعة"


class PaymentAttemptStatus(models.TextChoices):
    INITIATED = "initiated", "بدأت"
    REDIRECTED = "redirected", "تم التحويل"
    SUCCESS = "success", "ناجحة"
    FAILED = "failed", "فشلت"
    CANCELLED = "cancelled", "ملغاة"


class PaymentProvider(models.TextChoices):
    MANUAL = "manual", "تحويل يدوي"
    MOCK = "mock", "اختبار"
    # لاحقًا: moyasar / hyperpay / tap / stcpay


class Invoice(models.Model):
    """
    فاتورة عامة قابلة للربط بأي خدمة عبر reference fields
    """
    code = models.CharField(max_length=20, unique=True, blank=True)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="invoices",
    )

    title = models.CharField(max_length=160, default="فاتورة")
    description = models.CharField(max_length=300, blank=True)

    currency = models.CharField(max_length=10, default="SAR")

    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    vat_percent = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal("15.00"))
    vat_amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    total = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))

    status = models.CharField(max_length=20, choices=InvoiceStatus.choices, default=InvoiceStatus.DRAFT)

    # ربط عام
    reference_type = models.CharField(max_length=50, blank=True)  # verify_request / promo_request / subs / extras ...
    reference_id = models.CharField(max_length=50, blank=True)

    paid_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def recalc(self):
        st = money_round(Decimal(self.subtotal))
        vp = Decimal(self.vat_percent or 0)
        va = money_round((st * vp) / Decimal("100"))
        tt = money_round(st + va)
        self.subtotal = st
        self.vat_amount = va
        self.total = tt

    def mark_pending(self):
        if self.status == InvoiceStatus.DRAFT:
            self.status = InvoiceStatus.PENDING

    def mark_paid(self, when=None):
        self.status = InvoiceStatus.PAID
        self.paid_at = when or timezone.now()

    def mark_failed(self):
        if self.status not in (InvoiceStatus.PAID, InvoiceStatus.CANCELLED):
            self.status = InvoiceStatus.FAILED

    def mark_cancelled(self):
        if self.status != InvoiceStatus.PAID:
            self.status = InvoiceStatus.CANCELLED
            self.cancelled_at = timezone.now()

    def _ensure_code(self):
        if not self.code and self.pk:
            self.code = f"IV{self.pk:06d}"
            Invoice.objects.filter(pk=self.pk).update(code=self.code)

    def save(self, *args, **kwargs):
        self.recalc()
        is_new = self.pk is None
        super().save(*args, **kwargs)
        if is_new:
            # توليد code بعد pk
            self._ensure_code()

    def __str__(self):
        return self.code or f"Invoice#{self.pk}"


class PaymentAttempt(models.Model):
    """
    محاولة دفع مرتبطة بفواتير.
    Idempotency مهم لتجنب تكرار الدفع.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    invoice = models.ForeignKey(Invoice, on_delete=models.CASCADE, related_name="attempts")

    provider = models.CharField(max_length=30, choices=PaymentProvider.choices, default=PaymentProvider.MOCK)
    status = models.CharField(max_length=20, choices=PaymentAttemptStatus.choices, default=PaymentAttemptStatus.INITIATED)

    idempotency_key = models.CharField(max_length=80, blank=True)  # من الكلاينت أو يولد تلقائيًا

    amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal("0.00"))
    currency = models.CharField(max_length=10, default="SAR")

    # روابط الدفع
    checkout_url = models.URLField(blank=True)
    provider_reference = models.CharField(max_length=120, blank=True)

    request_payload = models.JSONField(default=dict, blank=True)
    response_payload = models.JSONField(default=dict, blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="payment_attempts",
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["provider", "provider_reference"]),
            models.Index(fields=["idempotency_key"]),
        ]

    def __str__(self):
        return f"{self.provider} attempt {self.id} ({self.status})"


class WebhookEvent(models.Model):
    """
    حفظ webhook raw لحماية idempotency + التدقيق
    """
    provider = models.CharField(max_length=30, choices=PaymentProvider.choices, default=PaymentProvider.MOCK)
    event_id = models.CharField(max_length=120, blank=True)
    signature = models.CharField(max_length=200, blank=True)

    payload = models.JSONField(default=dict, blank=True)

    received_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["provider", "event_id"]),
        ]

    def __str__(self):
        return f"{self.provider} webhook {self.event_id or self.pk}"
