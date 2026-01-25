from __future__ import annotations

from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.billing.models import Invoice
from .models import ExtraPurchase
from .services import activate_extra_after_payment


@receiver(post_save, sender=Invoice)
def activate_extra_on_paid(sender, instance: Invoice, created, **kwargs):
    if instance.status != "paid":
        return
    if instance.reference_type != "extra_purchase":
        return

    pid = instance.reference_id
    if not pid:
        return

    purchase = ExtraPurchase.objects.filter(pk=pid).first()
    if not purchase:
        return

    try:
        activate_extra_after_payment(purchase=purchase)
    except Exception:
        pass
