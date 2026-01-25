from __future__ import annotations

from django.db.models import Count, Sum
from django.db.models.functions import TruncDate, TruncMonth

from apps.billing.models import Invoice
from apps.subscriptions.models import Subscription, SubscriptionStatus
from apps.verification.models import VerificationRequest
from apps.promo.models import PromoRequest


def kpis_summary(start_date=None, end_date=None):
    """
    مؤشرات عامة
    """
    inv_qs = Invoice.objects.all()
    if start_date:
        inv_qs = inv_qs.filter(paid_at__date__gte=start_date)
    if end_date:
        inv_qs = inv_qs.filter(paid_at__date__lte=end_date)

    paid = inv_qs.filter(status="paid")

    revenue_total = paid.aggregate(total=Sum("total"))["total"] or 0
    invoices_paid = paid.count()

    subs_active = Subscription.objects.filter(status=SubscriptionStatus.ACTIVE).count()
    subs_expired = Subscription.objects.filter(status=SubscriptionStatus.EXPIRED).count()

    ad_total = VerificationRequest.objects.count()
    md_total = PromoRequest.objects.count()

    return {
        "revenue_total": float(revenue_total),
        "invoices_paid": invoices_paid,
        "subs_active": subs_active,
        "subs_expired": subs_expired,
        "ad_requests": ad_total,
        "md_requests": md_total,
    }


def revenue_daily(start_date=None, end_date=None):
    """
    إيرادات يومية
    """
    qs = Invoice.objects.filter(status="paid").exclude(paid_at__isnull=True)

    if start_date:
        qs = qs.filter(paid_at__date__gte=start_date)
    if end_date:
        qs = qs.filter(paid_at__date__lte=end_date)

    data = (
        qs.annotate(d=TruncDate("paid_at"))
        .values("d")
        .annotate(total=Sum("total"), count=Count("id"))
        .order_by("d")
    )
    return [{"date": str(x["d"]), "total": float(x["total"] or 0), "count": x["count"]} for x in data]


def revenue_monthly(start_date=None, end_date=None):
    """
    إيرادات شهرية
    """
    qs = Invoice.objects.filter(status="paid").exclude(paid_at__isnull=True)

    if start_date:
        qs = qs.filter(paid_at__date__gte=start_date)
    if end_date:
        qs = qs.filter(paid_at__date__lte=end_date)

    data = (
        qs.annotate(m=TruncMonth("paid_at"))
        .values("m")
        .annotate(total=Sum("total"), count=Count("id"))
        .order_by("m")
    )

    out = []
    for x in data:
        m = x.get("m")
        if hasattr(m, "strftime"):
            month = m.strftime("%Y-%m")
        else:
            month = str(m)[:7]
        out.append({"month": month, "total": float(x["total"] or 0), "count": x["count"]})
    return out


def requests_breakdown():
    """
    توزيع الحالات AD/MD
    """
    ad = VerificationRequest.objects.values("status").annotate(count=Count("id")).order_by("-count")
    md = PromoRequest.objects.values("status").annotate(count=Count("id")).order_by("-count")

    return {
        "verification": list(ad),
        "promo": list(md),
    }
