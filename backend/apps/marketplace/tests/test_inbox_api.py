import pytest
from datetime import timedelta
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import OTP
from apps.marketplace.models import RequestStatus, RequestType, ServiceRequest
from apps.providers.models import Category, ProviderCategory, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_available_urgent_excludes_expired_requests():
    # Arrange: category/subcategory
    cat = Category.objects.create(name="خدمات", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="كهرباء", is_active=True)

    # Arrange: login as provider via OTP
    client = APIClient()
    send = client.post("/api/accounts/otp/send/", {"phone": "0500000101"}, format="json")
    assert send.status_code == 200
    payload = send.json()
    code = payload.get("dev_code") or OTP.objects.filter(phone="0500000101").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000101", "code": code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # Complete registration (level 3) before registering provider
    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "مزود",
            "last_name": "اختبار",
            "username": "user_0500000101",
            "email": "0500000101@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    # Create provider profile
    reg = client.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "مزود",
            "bio": "bio",
            "years_experience": 1,
            "city": "Riyadh",
            "accepts_urgent": True,
        },
        format="json",
    )
    assert reg.status_code in (201, 400)

    provider = ProviderProfile.objects.get(user_id=verify.json()["user_id"])
    ProviderCategory.objects.get_or_create(provider=provider, subcategory=sub)

    # Arrange: create an expired urgent request in matching city/subcategory
    expired = ServiceRequest.objects.create(
        client=provider.user,
        subcategory=sub,
        title="عاجل منتهي",
        description="desc",
        request_type=RequestType.URGENT,
        status=RequestStatus.SENT,
        city="Riyadh",
        is_urgent=True,
        expires_at=timezone.now() - timedelta(minutes=1),
    )

    # Arrange: create a valid urgent request in matching city/subcategory
    active = ServiceRequest.objects.create(
        client=provider.user,
        subcategory=sub,
        title="عاجل فعال",
        description="desc",
        request_type=RequestType.URGENT,
        status=RequestStatus.SENT,
        city="Riyadh",
        is_urgent=True,
        expires_at=timezone.now() + timedelta(minutes=10),
    )

    # Act
    res = client.get("/api/marketplace/provider/urgent/available/")

    # Assert
    assert res.status_code == 200
    ids = {item["id"] for item in res.json()}
    assert expired.id not in ids
    assert active.id in ids


@pytest.mark.django_db
def test_client_requests_lists_current_user_requests():
    # Arrange: category/subcategory
    cat = Category.objects.create(name="خدمات", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="نقاشة", is_active=True)

    client = APIClient()

    # Arrange: get JWT via OTP flow (as client)
    send = client.post("/api/accounts/otp/send/", {"phone": "0500000202"}, format="json")
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000202").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000202", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]

    # Create two requests for this client
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # Complete registration (level 3) before creating requests
    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "عميل",
            "last_name": "اختبار",
            "username": "user_0500000202",
            "email": "0500000202@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    r1 = client.post(
        "/api/marketplace/requests/create/",
        {
            "subcategory": sub.id,
            "title": "طلب 1",
            "description": "desc",
            "request_type": "competitive",
            "city": "الرياض",
        },
        format="json",
    )
    assert r1.status_code == 201

    r2 = client.post(
        "/api/marketplace/requests/create/",
        {
            "subcategory": sub.id,
            "title": "طلب 2",
            "description": "desc",
            "request_type": "urgent",
            "city": "الرياض",
        },
        format="json",
    )
    assert r2.status_code == 201

    # Act
    res = client.get("/api/marketplace/client/requests/")

    # Assert
    assert res.status_code == 200
    ids = [item["id"] for item in res.json()]
    assert r1.json()["id"] in ids
    assert r2.json()["id"] in ids
