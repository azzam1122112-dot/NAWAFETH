from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta

from apps.accounts.models import OTP


class Command(BaseCommand):
    help = "Cleanup old OTP records and temporary data"

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(days=7)

        deleted, _ = OTP.objects.filter(created_at__lt=cutoff).delete()

        self.stdout.write(self.style.SUCCESS(f"✅ Deleted old OTP records: {deleted}"))
