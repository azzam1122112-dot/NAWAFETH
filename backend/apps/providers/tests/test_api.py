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


def _register_and_auth_provider(client: APIClient, phone: str = "0500000000") -> str:
    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": phone},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone=phone).order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": phone, "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]

    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "Test",
            "last_name": "Provider",
            "username": f"user_{phone}",
            "email": f"{phone}@example.com",
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
    return access


@pytest.mark.django_db
def test_provider_services_requires_auth():
    client = APIClient()
    res = client.get("/api/providers/me/services/")
    assert res.status_code in (401, 403)


@pytest.mark.django_db
def test_provider_services_crud_and_public_list():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client = APIClient()
    _register_and_auth_provider(client, phone="0500000001")

    create = client.post(
        "/api/providers/me/services/",
        {
            "title": "تصميم شعار احترافي",
            "description": "3 نماذج + تسليم الملفات المفتوحة",
            "price_from": "250.00",
            "price_to": "500.00",
            "price_unit": "fixed",
            "is_active": True,
            "subcategory_id": sub.id,
        },
        format="json",
    )
    assert create.status_code == 201
    service = create.json()
    assert service["title"] == "تصميم شعار احترافي"
    assert service["subcategory"]["id"] == sub.id
    service_id = service["id"]

    me_list = client.get("/api/providers/me/services/")
    assert me_list.status_code == 200
    assert isinstance(me_list.json(), list)
    assert len(me_list.json()) == 1

    patch = client.patch(
        f"/api/providers/me/services/{service_id}/",
        {"title": "تصميم شعار (محدث)"},
        format="json",
    )
    assert patch.status_code == 200
    assert patch.json()["title"] == "تصميم شعار (محدث)"

    provider_id = ProviderProfile.objects.first().id
    public_list = client.get(f"/api/providers/{provider_id}/services/")
    assert public_list.status_code == 200
    assert len(public_list.json()) == 1

    delete = client.delete(f"/api/providers/me/services/{service_id}/")
    assert delete.status_code in (200, 204)

    public_list2 = client.get(f"/api/providers/{provider_id}/services/")
    assert public_list2.status_code == 200
    assert len(public_list2.json()) == 0
