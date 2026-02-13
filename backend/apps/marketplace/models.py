from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models, transaction
from django.utils import timezone

from apps.accounts.models import User
from apps.providers.models import ProviderProfile, SubCategory


class RequestType(models.TextChoices):
	NORMAL = "normal", "عادي"
	COMPETITIVE = "competitive", "تنافسي"
	URGENT = "urgent", "عاجل"


class RequestStatus(models.TextChoices):
	NEW = "new", "جديد"
	SENT = "sent", "أُرسل"
	ACCEPTED = "accepted", "مقبول"
	IN_PROGRESS = "in_progress", "تحت التنفيذ"
	COMPLETED = "completed", "مكتمل"
	CANCELLED = "cancelled", "ملغي"
	EXPIRED = "expired", "منتهي"


class ServiceRequest(models.Model):
	client = models.ForeignKey(
		User,
		on_delete=models.CASCADE,
		related_name="requests",
	)

	provider = models.ForeignKey(
		ProviderProfile,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
		related_name="assigned_requests",
	)

	subcategory = models.ForeignKey(SubCategory, on_delete=models.PROTECT)

	title = models.CharField(max_length=200)
	description = models.TextField(max_length=1000)

	request_type = models.CharField(
		max_length=20,
		choices=RequestType.choices,
	)

	status = models.CharField(
		max_length=20,
		choices=RequestStatus.choices,
		default=RequestStatus.NEW,
	)

	city = models.CharField(max_length=100)
	is_urgent = models.BooleanField(default=False)

	created_at = models.DateTimeField(auto_now_add=True)
	expires_at = models.DateTimeField(null=True, blank=True)
	expected_delivery_at = models.DateTimeField(null=True, blank=True)
	estimated_service_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
	received_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
	remaining_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
	delivered_at = models.DateTimeField(null=True, blank=True)
	actual_service_amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
	canceled_at = models.DateTimeField(null=True, blank=True)
	cancel_reason = models.CharField(max_length=255, blank=True)
	provider_inputs_approved = models.BooleanField(null=True, blank=True)
	provider_inputs_decided_at = models.DateTimeField(null=True, blank=True)
	provider_inputs_decision_note = models.CharField(max_length=255, blank=True)

	def mark_sent(self) -> None:
		if self.status != RequestStatus.NEW:
			raise ValidationError("لا يمكن إرسال الطلب في هذه الحالة")
		self.status = RequestStatus.SENT
		self.save(update_fields=["status"])

	def accept(self, provider: ProviderProfile) -> None:
		if self.status != RequestStatus.SENT:
			raise ValidationError("لا يمكن قبول الطلب الآن")
		self.provider = provider
		self.status = RequestStatus.ACCEPTED
		self.save(update_fields=["provider", "status"])

	def start(self) -> None:
		if self.status != RequestStatus.ACCEPTED:
			raise ValidationError("لا يمكن بدء التنفيذ في هذه الحالة")
		self.status = RequestStatus.IN_PROGRESS
		self.save(update_fields=["status"])

	def complete(self) -> None:
		if self.status != RequestStatus.IN_PROGRESS:
			raise ValidationError("لا يمكن الإكمال في هذه الحالة")
		self.status = RequestStatus.COMPLETED
		self.save(update_fields=["status"])

	def cancel(self) -> None:
		if self.status not in [RequestStatus.NEW, RequestStatus.SENT]:
			raise ValidationError("لا يمكن إلغاء الطلب في هذه الحالة")
		self.status = RequestStatus.CANCELLED
		self.save(update_fields=["status"])

	def __str__(self) -> str:
		return f"{self.title} ({self.get_status_display()})"


class OfferStatus(models.TextChoices):
	PENDING = "pending", "بانتظار"
	SELECTED = "selected", "مختار"
	REJECTED = "rejected", "مرفوض"


class Offer(models.Model):
	request = models.ForeignKey(
		ServiceRequest,
		on_delete=models.CASCADE,
		related_name="offers",
	)
	provider = models.ForeignKey(
		ProviderProfile,
		on_delete=models.CASCADE,
		related_name="offers",
	)

	price = models.DecimalField(max_digits=10, decimal_places=2)
	duration_days = models.PositiveIntegerField()
	note = models.TextField(max_length=500, blank=True)

	status = models.CharField(
		max_length=20,
		choices=OfferStatus.choices,
		default=OfferStatus.PENDING,
	)

	created_at = models.DateTimeField(auto_now_add=True)

	class Meta:
		unique_together = ("request", "provider")


class RequestStatusLog(models.Model):
	request = models.ForeignKey(
		"ServiceRequest",
		on_delete=models.CASCADE,
		related_name="status_logs",
	)
	actor = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
	)
	from_status = models.CharField(max_length=20)
	to_status = models.CharField(max_length=20)
	note = models.CharField(max_length=255, blank=True)
	created_at = models.DateTimeField(auto_now_add=True)

	class Meta:
		ordering = ("-id",)

	def __str__(self) -> str:
		return f"#{self.request_id}: {self.from_status} -> {self.to_status}"


class ServiceRequestAttachment(models.Model):
	request = models.ForeignKey(
		ServiceRequest,
		on_delete=models.CASCADE,
		related_name="attachments",
	)
	file = models.FileField(upload_to="requests/attachments/%Y/%m/%d/")
	file_type = models.CharField(max_length=20)  # image, video, audio, document
	created_at = models.DateTimeField(auto_now_add=True)

	def __str__(self):
		return f"Attachment {self.id} for Request #{self.request_id}"
