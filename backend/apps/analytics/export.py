from __future__ import annotations

import csv
from django.http import HttpResponse

from apps.billing.models import Invoice


def export_paid_invoices_csv():
    qs = Invoice.objects.filter(status="paid").order_by("-paid_at")[:5000]

    resp = HttpResponse(content_type="text/csv")
    resp["Content-Disposition"] = 'attachment; filename="paid_invoices.csv"'

    writer = csv.writer(resp)
    writer.writerow(["invoice_code", "user_phone", "total", "paid_at"])

    for inv in qs:
        writer.writerow([inv.code, getattr(inv.user, "phone", ""), inv.total, inv.paid_at])

    return resp
