from django.db import models
from django.conf import settings
from django.utils import timezone
from apps.marketplace.models import ServiceRequest

class Thread(models.Model):
    request = models.OneToOneField(
        ServiceRequest, on_delete=models.CASCADE, related_name="thread",
        null=True, blank=True,
    )
    # Direct messaging (no request required)
    participant_1 = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="direct_threads_as_p1", null=True, blank=True,
    )
    participant_2 = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name="direct_threads_as_p2", null=True, blank=True,
    )
    is_direct = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        indexes = [
            models.Index(fields=["participant_1", "participant_2"]),
        ]

    def __str__(self):
        if self.is_direct:
            return f"DirectThread #{self.id} ({self.participant_1_id} ↔ {self.participant_2_id})"
        return f"Thread for request #{self.request_id}"

    def is_participant(self, user) -> bool:
        """Check if user is a participant in this thread (direct or request-based)."""
        if self.is_direct:
            return user.id in (self.participant_1_id, self.participant_2_id)
        if self.request_id:
            sr = self.request
            if sr.client_id == user.id:
                return True
            if sr.provider_id and sr.provider.user_id == user.id:
                return True
        return False


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
