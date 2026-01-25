from __future__ import annotations

from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.billing.models import Invoice

from .models import VerificationRequest
from .services import activate_after_payment


@receiver(post_save, sender=Invoice)
def activate_verification_on_invoice_paid(sender, instance: Invoice, created, **kwargs):
    """
    عند تحول الفاتورة إلى PAID:
    - إذا كانت مرتبطة بطلب توثيق، نفعل الشارة تلقائيًا
    """
    if instance.status != "paid":
        return

    # reference_type: verify_request
    if instance.reference_type != "verify_request":
        return

    vr = VerificationRequest.objects.filter(invoice=instance).order_by("-id").first()
    if not vr:
        # fallback: reference_id هو code
        vr = VerificationRequest.objects.filter(code=instance.reference_id).order_by("-id").first()

    if not vr:
        return

    try:
        activate_after_payment(vr=vr)
    except Exception:
        # لا نفشل الدفع بسبب خطأ داخلي
        pass
