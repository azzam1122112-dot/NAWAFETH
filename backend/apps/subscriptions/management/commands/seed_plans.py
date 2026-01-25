from decimal import Decimal
from django.core.management.base import BaseCommand

from apps.subscriptions.models import SubscriptionPlan, PlanPeriod


class Command(BaseCommand):
    help = "Seed default subscription plans"

    def handle(self, *args, **options):
        plans = [
            {
                "code": "BASIC_MONTH",
                "title": "أساسية",
                "description": "مناسبة للبداية",
                "period": PlanPeriod.MONTH,
                "price": Decimal("49.00"),
                "features": ["verify_green"],
            },
            {
                "code": "PRO_MONTH",
                "title": "احترافية",
                "description": "للعملاء النشطين",
                "period": PlanPeriod.MONTH,
                "price": Decimal("99.00"),
                "features": ["verify_blue", "promo_ads", "priority_support"],
            },
            {
                "code": "PRO_YEAR",
                "title": "احترافية سنوية",
                "description": "خصم سنوي",
                "period": PlanPeriod.YEAR,
                "price": Decimal("999.00"),
                "features": ["verify_blue", "promo_ads", "priority_support", "advanced_analytics"],
            },
        ]

        for p in plans:
            SubscriptionPlan.objects.update_or_create(code=p["code"], defaults=p)

        self.stdout.write(self.style.SUCCESS("✅ Plans seeded successfully"))
