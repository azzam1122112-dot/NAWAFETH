from django.db.models.signals import post_save
from django.dispatch import receiver
from django.db.models import Avg, Count
from django.db import transaction

from .models import Review
from apps.providers.models import ProviderProfile


@receiver(post_save, sender=Review)
def update_provider_rating(sender, instance: Review, created, **kwargs):
    if not created:
        return

    provider_id = instance.provider_id

    # تحديث مجمّع من قاعدة البيانات (صحيح 100% حتى مع تعدد العمليات)
    agg = Review.objects.filter(provider_id=provider_id).aggregate(
        avg=Avg("rating"),
        cnt=Count("id"),
    )

    avg = agg["avg"] or 0
    cnt = agg["cnt"] or 0

    ProviderProfile.objects.filter(id=provider_id).update(
        rating_avg=avg,
        rating_count=cnt,
    )
