from django.db import models
from django.conf import settings
from django.utils import timezone


class EventType(models.TextChoices):
	REQUEST_CREATED = "request_created", "تم إنشاء طلب"
	REQUEST_ASSIGNED = "request_assigned", "تم إسناد الطلب"
	OFFER_CREATED = "offer_created", "تم تقديم عرض"
	OFFER_SELECTED = "offer_selected", "تم اختيار عرضك"
	STATUS_CHANGED = "status_changed", "تغيرت حالة الطلب"
	MESSAGE_NEW = "message_new", "رسالة جديدة"


class EventLog(models.Model):
	# سجل أحداث (مفيد للتدقيق/التتبّع)
	event_type = models.CharField(max_length=50, choices=EventType.choices)
	actor = models.ForeignKey(
		settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
	)
	target_user = models.ForeignKey(
		settings.AUTH_USER_MODEL,
		on_delete=models.SET_NULL,
		null=True,
		blank=True,
		related_name="targeted_events",
	)
	request_id = models.IntegerField(null=True, blank=True)
	offer_id = models.IntegerField(null=True, blank=True)
	message_id = models.IntegerField(null=True, blank=True)
	meta = models.JSONField(default=dict, blank=True)
	created_at = models.DateTimeField(default=timezone.now)

	class Meta:
		ordering = ("-id",)


class Notification(models.Model):
	user = models.ForeignKey(
		settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
	)

	title = models.CharField(max_length=200)
	body = models.CharField(max_length=500)
	kind = models.CharField(max_length=50, default="info")  # info/success/warn/error
	url = models.CharField(max_length=300, blank=True)  # deep link اختياري
	is_read = models.BooleanField(default=False)

	created_at = models.DateTimeField(default=timezone.now)

	class Meta:
		ordering = ("-id",)

	def __str__(self):
		return f"{self.user_id}: {self.title}"


class DeviceToken(models.Model):
	PLATFORM_CHOICES = (
		("android", "Android"),
		("ios", "iOS"),
		("web", "Web"),
	)

	user = models.ForeignKey(
		settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="device_tokens"
	)
	token = models.CharField(max_length=255, unique=True)
	platform = models.CharField(max_length=20, choices=PLATFORM_CHOICES)
	is_active = models.BooleanField(default=True)
	last_seen_at = models.DateTimeField(default=timezone.now)

	created_at = models.DateTimeField(default=timezone.now)

	class Meta:
		indexes = [
			models.Index(fields=["user", "platform", "is_active"]),
		]

	def __str__(self):
		return f"{self.user_id} - {self.platform}"
