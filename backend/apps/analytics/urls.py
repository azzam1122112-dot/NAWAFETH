from django.urls import path

from .views import (
    DashboardKPIsView,
    RevenueDailyView,
    RevenueMonthlyView,
    RequestsBreakdownView,
    ExportPaidInvoicesCSVView,
)

urlpatterns = [
    path("kpis/", DashboardKPIsView.as_view(), name="kpis"),
    path("revenue/daily/", RevenueDailyView.as_view(), name="revenue_daily"),
    path("revenue/monthly/", RevenueMonthlyView.as_view(), name="revenue_monthly"),
    path("requests/breakdown/", RequestsBreakdownView.as_view(), name="requests_breakdown"),
    path("export/paid-invoices.csv", ExportPaidInvoicesCSVView.as_view(), name="export_paid_invoices_csv"),
]
