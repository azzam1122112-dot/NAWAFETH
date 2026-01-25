from rest_framework import serializers

from .models import Category, ProviderProfile, SubCategory


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
