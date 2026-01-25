from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone

from .validators import validate_file_size, validate_extension


class VerificationBadgeType(models.TextChoices):
    BLUE = "blue", "شارة زرقاء"
    GREEN = "green", "شارة خضراء"


class VerificationStatus(models.TextChoices):
    NEW = "new", "جديد"
    IN_REVIEW = "in_review", "قيد المراجعة"
    REJECTED = "rejected", "مرفوض"
    APPROVED = "approved", "معتمد"
    PENDING_PAYMENT = "pending_payment", "بانتظار الدفع"
    ACTIVE = "active", "مفعل"
    EXPIRED = "expired", "منتهي"


class VerificationDocType(models.TextChoices):
    ID = "id", "هوية وطنية/إقامة"
    CR = "cr", "سجل تجاري"
    IBAN = "iban", "آيبان/حساب بنكي"
    LICENSE = "license", "ترخيص/تصريح"
    OTHER = "other", "مستند إضافي"


class VerificationRequest(models.Model):
    """
    ADxxxx - طلب توثيق
    """
    code = models.CharField(max_length=20, unique=True, blank=True)

    requester = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="verification_requests",
    )

    badge_type = models.CharField(max_length=20, choices=VerificationBadgeType.choices)

    status = models.CharField(max_length=25, choices=VerificationStatus.choices, default=VerificationStatus.NEW)

    admin_note = models.CharField(max_length=300, blank=True)
    reject_reason = models.CharField(max_length=300, blank=True)

    # ربط الفاتورة (Sprint 3)
    invoice = models.ForeignKey(
        "billing.Invoice",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verification_requests",
    )

    requested_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    approved_at = models.DateTimeField(null=True, blank=True)

    activated_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    def _ensure_code(self):
        if not self.code and self.pk:
            self.code = f"AD{self.pk:06d}"
            VerificationRequest.objects.filter(pk=self.pk).update(code=self.code)

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        super().save(*args, **kwargs)
        if is_new:
            # لا نعتمد على on_commit لأن اختبارات pytest تعمل داخل transaction
            # وقد تؤخر توليد code حتى نهاية الاختبار.
            self._ensure_code()

    def __str__(self) -> str:
        return self.code or f"AD-request-{self.pk}"

    def activation_window(self):
        # سنة كاملة
        return timedelta(days=365)


class VerificationDocument(models.Model):
    """
    مستند ضمن طلب التوثيق + قرار (approve/reject)
    """
    request = models.ForeignKey(VerificationRequest, on_delete=models.CASCADE, related_name="documents")

    doc_type = models.CharField(max_length=30, choices=VerificationDocType.choices)
    title = models.CharField(max_length=160, blank=True)

    file = models.FileField(
        upload_to="verification/docs/%Y/%m/",
        validators=[validate_file_size, validate_extension],
    )

    # قرار المراجع
    is_approved = models.BooleanField(null=True, blank=True)  # None => لم يقرر
    decision_note = models.CharField(max_length=300, blank=True)
    decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="verification_doc_decisions",
    )
    decided_at = models.DateTimeField(null=True, blank=True)

    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"{self.request.code} doc#{self.pk}"


class VerifiedBadge(models.Model):
    """
    سجل تفعيل الشارات (مرجعي وإداري)
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="badges")

    badge_type = models.CharField(max_length=20, choices=VerificationBadgeType.choices)
    request = models.ForeignKey(VerificationRequest, on_delete=models.CASCADE, related_name="badges")

    activated_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField()

    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "badge_type", "is_active"]),
        ]

    def __str__(self):
        return f"{self.user_id} {self.badge_type} active={self.is_active}"
