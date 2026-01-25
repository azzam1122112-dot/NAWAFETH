from __future__ import annotations

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .permissions import IsBackofficeAnalytics
from .filters import parse_dates
from .services import (
	kpis_summary,
	revenue_daily,
	revenue_monthly,
	requests_breakdown,
)
from .export import export_paid_invoices_csv


class DashboardKPIsView(APIView):
	permission_classes = [IsBackofficeAnalytics]

	def get(self, request):
		start_date, end_date = parse_dates(request.query_params)
		data = kpis_summary(start_date=start_date, end_date=end_date)
		return Response(data, status=status.HTTP_200_OK)


class RevenueDailyView(APIView):
	permission_classes = [IsBackofficeAnalytics]

	def get(self, request):
		start_date, end_date = parse_dates(request.query_params)
		data = revenue_daily(start_date=start_date, end_date=end_date)
		return Response(data, status=status.HTTP_200_OK)


class RevenueMonthlyView(APIView):
	permission_classes = [IsBackofficeAnalytics]

	def get(self, request):
		start_date, end_date = parse_dates(request.query_params)
		data = revenue_monthly(start_date=start_date, end_date=end_date)
		return Response(data, status=status.HTTP_200_OK)


class RequestsBreakdownView(APIView):
	permission_classes = [IsBackofficeAnalytics]

	def get(self, request):
		data = requests_breakdown()
		return Response(data, status=status.HTTP_200_OK)


class ExportPaidInvoicesCSVView(APIView):
	permission_classes = [IsBackofficeAnalytics]

	def get(self, request):
		return export_paid_invoices_csv()
