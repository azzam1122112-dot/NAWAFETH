from __future__ import annotations

from django.conf import settings
from django.db import models


class AuditAction(models.TextChoices):
	INVOICE_CREATED = "invoice_created", "إنشاء فاتورة"
	INVOICE_PAID = "invoice_paid", "دفع فاتورة"
	SUBSCRIPTION_STARTED = "subscription_started", "بدء اشتراك"
	SUBSCRIPTION_ACTIVE = "subscription_active", "تفعيل اشتراك"

	VERIFY_REQUEST_CREATED = "verify_request_created", "طلب توثيق"
	VERIFY_REQUEST_APPROVED = "verify_request_approved", "اعتماد توثيق"
	VERIFY_REQUEST_REJECTED = "verify_request_rejected", "رفض توثيق"

	PROMO_REQUEST_CREATED = "promo_request_created", "طلب إعلان"
	PROMO_REQUEST_QUOTED = "promo_request_quoted", "تسعير إعلان"
	PROMO_REQUEST_ACTIVE = "promo_request_active", "تفعيل إعلان"

	EXTRA_PURCHASE_CREATED = "extra_purchase_created", "شراء إضافة"
	EXTRA_PURCHASE_ACTIVE = "extra_purchase_active", "تفعيل إضافة"

	ACCESS_PROFILE_UPDATED = "access_profile_updated", "تحديث صلاحيات تشغيل"
	ACCESS_PROFILE_CREATED = "access_profile_created", "إنشاء صلاحيات تشغيل"
	ACCESS_PROFILE_REVOKED = "access_profile_revoked", "سحب صلاحيات تشغيل"
	ACCESS_PROFILE_UNREVOKED = "access_profile_unrevoked", "إلغاء سحب صلاحيات تشغيل"

	LOGIN_OTP_SENT = "login_otp_sent", "إرسال OTP"
	LOGIN_OTP_VERIFIED = "login_otp_verified", "تأكيد OTP"


class AuditLog(models.Model):
	actor = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
		related_name="audit_logs",
	)

	action = models.CharField(max_length=60, choices=AuditAction.choices)

	reference_type = models.CharField(max_length=60, blank=True)
	reference_id = models.CharField(max_length=60, blank=True)

	ip_address = models.GenericIPAddressField(null=True, blank=True)
	user_agent = models.CharField(max_length=255, blank=True)

	extra = models.JSONField(default=dict, blank=True)

	created_at = models.DateTimeField(auto_now_add=True)

	class Meta:
		ordering = ["-id"]
		indexes = [
			models.Index(fields=["action"]),
			models.Index(fields=["reference_type", "reference_id"]),
			models.Index(fields=["created_at"]),
		]

	def __str__(self):
		return f"{self.action} - {self.reference_type}:{self.reference_id}"

# Create your models here.
