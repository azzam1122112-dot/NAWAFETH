from decimal import Decimal

from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.accounts.models import User

class Category(models.Model):
    name = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)

    def __str__(self) -> str:
        return self.name


class SubCategory(models.Model):
    category = models.ForeignKey(
        Category,
        on_delete=models.CASCADE,
        related_name="subcategories",
    )
    name = models.CharField(max_length=100)
    is_active = models.BooleanField(default=True)

    def __str__(self) -> str:
        return f"{self.category.name} - {self.name}"


class ProviderProfile(models.Model):
    PROVIDER_TYPE_CHOICES = (
        ("individual", "فرد"),
        ("company", "منشأة"),
    )

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="provider_profile",
    )

    provider_type = models.CharField(max_length=20, choices=PROVIDER_TYPE_CHOICES)
    display_name = models.CharField(max_length=150)
    bio = models.TextField(max_length=300)
    years_experience = models.PositiveIntegerField(default=0)

    whatsapp = models.CharField(max_length=30, null=True, blank=True)

    city = models.CharField(max_length=100)
    lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    coverage_radius_km = models.PositiveIntegerField(default=10)

    accepts_urgent = models.BooleanField(default=False)

    is_verified_blue = models.BooleanField(default=False)
    is_verified_green = models.BooleanField(default=False)

    rating_avg = models.DecimalField(
        max_digits=3,
        decimal_places=2,
        default=Decimal("0.00"),
    )
    rating_count = models.PositiveIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return self.display_name


class ProviderPortfolioItem(models.Model):
    FILE_TYPE_CHOICES = (
        ("image", "صورة"),
        ("video", "فيديو"),
    )

    provider = models.ForeignKey(
        ProviderProfile,
        on_delete=models.CASCADE,
        related_name="portfolio_items",
    )
    file_type = models.CharField(max_length=20, choices=FILE_TYPE_CHOICES)
    file = models.FileField(upload_to="providers/portfolio/%Y/%m/")
    caption = models.CharField(max_length=200, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"PortfolioItem {self.pk} ({self.file_type}) for Provider {self.provider_id}"


class ProviderPortfolioLike(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="portfolio_likes",
    )
    item = models.ForeignKey(
        ProviderPortfolioItem,
        on_delete=models.CASCADE,
        related_name="likes",
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "item"], name="uniq_like_user_portfolio_item"),
        ]


class ProviderCategory(models.Model):
    provider = models.ForeignKey(ProviderProfile, on_delete=models.CASCADE)
    subcategory = models.ForeignKey(SubCategory, on_delete=models.CASCADE)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["provider", "subcategory"],
                name="uniq_provider_subcategory",
            )
        ]


class ProviderFollow(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="provider_follows",
    )
    provider = models.ForeignKey(
        ProviderProfile,
        on_delete=models.CASCADE,
        related_name="followers",
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "provider"], name="uniq_follow_user_provider"),
        ]


class ProviderLike(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="provider_likes",
    )
    provider = models.ForeignKey(
        ProviderProfile,
        on_delete=models.CASCADE,
        related_name="likes",
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "provider"], name="uniq_like_user_provider"),
        ]
