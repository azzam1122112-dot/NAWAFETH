from django.db import models
from django.conf import settings
from django.utils import timezone
from apps.marketplace.models import ServiceRequest

class Thread(models.Model):
    request = models.OneToOneField(ServiceRequest, on_delete=models.CASCADE, related_name="thread")
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"Thread for request #{self.request_id}"


class Message(models.Model):
    thread = models.ForeignKey(Thread, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sent_messages")
    body = models.TextField(max_length=2000)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ("id",)

    def __str__(self):
        return f"Msg #{self.id} by {self.sender_id}"


class MessageRead(models.Model):
    message = models.ForeignKey(Message, on_delete=models.CASCADE, related_name="reads")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="message_reads")
    read_at = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ("message", "user")
        indexes = [
            models.Index(fields=["user", "read_at"]),
        ]
