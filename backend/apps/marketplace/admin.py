from django.contrib import admin

from .models import Offer, RequestStatusLog, ServiceRequest


@admin.register(ServiceRequest)
class ServiceRequestAdmin(admin.ModelAdmin):
	list_display = (
		"id",
		"title",
		"request_type",
		"status",
		"city",
		"created_at",
	)
	list_filter = ("request_type", "status", "city")
	search_fields = ("title", "description")


@admin.register(Offer)
class OfferAdmin(admin.ModelAdmin):
	list_display = ("id", "request", "provider", "price", "status", "created_at")
	list_filter = ("status",)


@admin.register(RequestStatusLog)
class RequestStatusLogAdmin(admin.ModelAdmin):
	list_display = ("id", "request", "actor", "from_status", "to_status", "created_at")
	list_filter = ("from_status", "to_status")
	search_fields = ("request__title", "actor__phone")
