import pytest
from django.contrib.auth import get_user_model

from apps.providers.models import Category, ProviderProfile, SubCategory


@pytest.fixture
def client_user():
    User = get_user_model()
    return User.objects.create_user(phone="0501000001")


@pytest.fixture
def provider_user():
    User = get_user_model()
    return User.objects.create_user(phone="0501000002")


@pytest.fixture
def provider_profile(provider_user):
    return ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        city="الرياض",
        years_experience=0,
    )


@pytest.fixture
def subcategory():
    cat = Category.objects.create(name="تصميم", is_active=True)
    return SubCategory.objects.create(category=cat, name="شعارات", is_active=True)
