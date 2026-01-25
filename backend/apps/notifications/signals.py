from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.marketplace.models import Offer, OfferStatus, ServiceRequest, RequestStatusLog
from apps.messaging.models import Message

from .models import EventType
from .services import create_notification


@receiver(post_save, sender=Offer)
def notify_offer_created(sender, instance: Offer, created, **kwargs):
    if not created:
        return
    sr = instance.request
    # إشعار للعميل فقط
    create_notification(
        user=sr.client,
        title="وصل عرض جديد",
        body=f"تم تقديم عرض على طلبك: {sr.title}",
        kind="info",
        url=f"/requests/{sr.id}",
        actor=instance.provider.user,
        event_type=EventType.OFFER_CREATED,
        request_id=sr.id,
        offer_id=instance.id,
        meta={"price": str(instance.price), "duration_days": instance.duration_days},
    )


@receiver(post_save, sender=Offer)
def notify_offer_selected(sender, instance: Offer, created, **kwargs):
    # نطلق إشعار فقط إذا أصبح SELECTED
    if instance.status != OfferStatus.SELECTED:
        return
    sr = instance.request
    create_notification(
        user=instance.provider.user,
        title="تم اختيار عرضك",
        body=f"العميل اختار عرضك على الطلب: {sr.title}",
        kind="success",
        url=f"/requests/{sr.id}",
        actor=sr.client,
        event_type=EventType.OFFER_SELECTED,
        request_id=sr.id,
        offer_id=instance.id,
    )


@receiver(post_save, sender=Message)
def notify_new_message(sender, instance: Message, created, **kwargs):
    if not created:
        return
    sr = instance.thread.request

    # الطرف الآخر فقط
    if sr.provider_id and instance.sender_id == sr.client_id:
        target = sr.provider.user
    elif sr.provider_id and instance.sender_id == sr.provider.user_id:
        target = sr.client
    else:
        return

    create_notification(
        user=target,
        title="رسالة جديدة",
        body="لديك رسالة جديدة على طلبك.",
        kind="info",
        url=f"/requests/{sr.id}/chat",
        actor=instance.sender,
        event_type=EventType.MESSAGE_NEW,
        request_id=sr.id,
        message_id=instance.id,
    )
