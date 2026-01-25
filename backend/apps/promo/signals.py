from __future__ import annotations

from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.billing.models import Invoice
from .models import PromoRequest
from .services import activate_after_payment


@receiver(post_save, sender=Invoice)
def activate_promo_on_invoice_paid(sender, instance: Invoice, created, **kwargs):
    if instance.status != "paid":
        return
    if instance.reference_type != "promo_request":
        return

    pr = PromoRequest.objects.filter(invoice=instance).order_by("-id").first()
    if not pr:
        pr = PromoRequest.objects.filter(code=instance.reference_id).order_by("-id").first()

    if not pr:
        return

    try:
        activate_after_payment(pr=pr)
    except Exception:
        pass
