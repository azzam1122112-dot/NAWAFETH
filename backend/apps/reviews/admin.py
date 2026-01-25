from django.contrib import admin

from .models import Review


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
	list_display = ("id", "request", "provider", "client", "rating", "created_at")
	list_filter = ("rating",)
	search_fields = ("client__phone", "provider__display_name")
