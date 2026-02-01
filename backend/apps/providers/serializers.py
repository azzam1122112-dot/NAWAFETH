from rest_framework import serializers

from apps.accounts.models import User

from .models import Category, ProviderPortfolioItem, ProviderProfile, SubCategory


class SubCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = SubCategory
        fields = ("id", "name")


class CategorySerializer(serializers.ModelSerializer):
    subcategories = SubCategorySerializer(many=True, read_only=True)

    class Meta:
        model = Category
        fields = ("id", "name", "subcategories")


class ProviderProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderProfile
        fields = "__all__"
        read_only_fields = ("user", "is_verified_blue", "is_verified_green")


class ProviderProfileMeSerializer(serializers.ModelSerializer):
    """Provider profile for the authenticated owner (read + update).

    Keep sensitive/computed fields read-only.
    """

    class Meta:
        model = ProviderProfile
        fields = (
            "id",
            "provider_type",
            "display_name",
            "bio",
            "years_experience",
            "whatsapp",
            "city",
            "lat",
            "lng",
            "coverage_radius_km",
            "accepts_urgent",
            "is_verified_blue",
            "is_verified_green",
            "rating_avg",
            "rating_count",
            "created_at",
        )
        read_only_fields = (
            "id",
            "is_verified_blue",
            "is_verified_green",
            "rating_avg",
            "rating_count",
            "created_at",
        )


class ProviderPublicSerializer(serializers.ModelSerializer):
    followers_count = serializers.IntegerField(read_only=True)
    likes_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = ProviderProfile
        fields = (
            "id",
            "display_name",
            "bio",
            "years_experience",
            "city",
            "accepts_urgent",
            "is_verified_blue",
            "is_verified_green",
            "rating_avg",
            "rating_count",
            "created_at",
            "followers_count",
            "likes_count",
        )


class ProviderPortfolioItemSerializer(serializers.ModelSerializer):
    provider_id = serializers.IntegerField(source="provider.id", read_only=True)
    provider_display_name = serializers.CharField(source="provider.display_name", read_only=True)
    provider_username = serializers.CharField(source="provider.user.username", read_only=True)
    file_url = serializers.FileField(source="file", read_only=True)

    class Meta:
        model = ProviderPortfolioItem
        fields = (
            "id",
            "provider_id",
            "provider_display_name",
            "provider_username",
            "file_type",
            "file_url",
            "caption",
            "created_at",
        )


class ProviderPortfolioItemCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProviderPortfolioItem
        fields = (
            "id",
            "file_type",
            "file",
            "caption",
            "created_at",
        )
        read_only_fields = ("id", "created_at")


class UserPublicSerializer(serializers.ModelSerializer):
    display_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "display_name",
        )

    def get_display_name(self, obj: User) -> str:
        first = (getattr(obj, "first_name", "") or "").strip()
        last = (getattr(obj, "last_name", "") or "").strip()
        if first or last:
            return (f"{first} {last}").strip()
        username = (getattr(obj, "username", "") or "").strip()
        return username or "مستخدم"
