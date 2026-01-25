from django.contrib import admin

from .models import Category, ProviderCategory, ProviderProfile, SubCategory


admin.site.register(Category)
admin.site.register(SubCategory)
admin.site.register(ProviderCategory)


@admin.register(ProviderProfile)
class ProviderProfileAdmin(admin.ModelAdmin):
	list_display = ("id", "display_name", "provider_type", "city", "accepts_urgent")
	search_fields = ("display_name", "city")
