from __future__ import annotations

from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.billing.models import Invoice
from .models import Subscription
from .services import activate_subscription_after_payment


@receiver(post_save, sender=Invoice)
def activate_subscription_on_paid(sender, instance: Invoice, created, **kwargs):
    if instance.status != "paid":
        return
    if instance.reference_type != "subscription":
        return

    sub_id = instance.reference_id
    if not sub_id:
        return

    sub = Subscription.objects.filter(pk=sub_id, invoice=instance).first()
    if not sub:
        sub = Subscription.objects.filter(pk=sub_id).first()

    if not sub:
        return

    try:
        activate_subscription_after_payment(sub=sub)
    except Exception:
        pass
