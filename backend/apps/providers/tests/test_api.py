import pytest
from rest_framework.test import APIClient

from apps.accounts.models import OTP
from apps.providers.models import Category, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_get_categories_returns_active_with_subcategories():
    active = Category.objects.create(name="تصميم", is_active=True)
    SubCategory.objects.create(category=active, name="شعارات", is_active=True)

    Category.objects.create(name="غير نشط", is_active=False)

    client = APIClient()
    res = client.get("/api/providers/categories/")

    assert res.status_code == 200
    assert isinstance(res.json(), list)

    payload = res.json()
    assert len(payload) == 1
    assert payload[0]["name"] == "تصميم"
    assert payload[0]["subcategories"][0]["name"] == "شعارات"


@pytest.mark.django_db
def test_provider_register_flow_via_otp_and_jwt():
    client = APIClient()

    # 1) OTP send
    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000000"},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000000").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    # 2) OTP verify -> JWT
    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000000", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]

    # 3) Authenticated register provider
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # 2.5) Complete registration (level 3)
    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "Test",
            "last_name": "Provider",
            "username": "user_0500000000",
            "email": "0500000000@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    reg = client.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "محمد التصميم",
            "bio": "مصمم جرافيك محترف",
            "years_experience": 5,
            "city": "الرياض",
            "accepts_urgent": True,
        },
        format="json",
    )

    assert reg.status_code == 201
    assert ProviderProfile.objects.count() == 1
    profile = ProviderProfile.objects.first()
    assert profile is not None
    assert profile.display_name == "محمد التصميم"
    assert profile.city == "الرياض"
