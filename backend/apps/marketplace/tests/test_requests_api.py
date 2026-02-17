import pytest
from rest_framework.test import APIClient

from apps.accounts.models import OTP
from apps.marketplace.models import RequestStatus, ServiceRequest
from apps.providers.models import Category, ProviderCategory, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_create_urgent_service_request_auto_sends_and_sets_expiry():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client = APIClient()

    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000001"},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000001").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000001", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]

    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "عميل",
            "last_name": "اختبار",
            "username": "user_0500000001",
            "email": "0500000001@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    res = client.post(
        "/api/marketplace/requests/create/",
        {
            "subcategory": sub.id,
            "title": "تصميم شعار",
            "description": "أحتاج تصميم شعار احترافي",
            "request_type": "urgent",
            "city": "الرياض",
        },
        format="json",
    )
    assert res.status_code == 201

    sr = ServiceRequest.objects.get(id=res.json()["id"])
    assert sr.status == RequestStatus.SENT
    assert sr.is_urgent is True
    assert sr.expires_at is not None


@pytest.mark.django_db
def test_create_normal_request_can_target_provider():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client = APIClient()

    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000002"},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000002").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000002", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "عميل",
            "last_name": "اختبار",
            "username": "user_0500000002",
            "email": "0500000002@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    from apps.accounts.models import User  # local import

    p_user = User.objects.create(phone="0500000099", username="provider_99")
    provider = ProviderProfile.objects.create(
        user=p_user,
        provider_type="individual",
        display_name="مزود تجريبي",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )
    ProviderCategory.objects.get_or_create(provider=provider, subcategory=sub)

    res = client.post(
        "/api/marketplace/requests/create/",
        {
            "provider": provider.id,
            "subcategory": sub.id,
            "title": "تصميم شعار لمزود محدد",
            "description": "طلب خاص",
            "request_type": "normal",
            "city": "الرياض",
        },
        format="json",
    )

    assert res.status_code == 201
    sr = ServiceRequest.objects.get(id=res.json()["id"])
    assert sr.provider_id == provider.id
    assert sr.request_type == "normal"


@pytest.mark.django_db
def test_create_competitive_request_rejects_target_provider():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client = APIClient()

    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000004"},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000004").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000004", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "عميل",
            "last_name": "اختبار",
            "username": "user_0500000004",
            "email": "0500000004@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    from apps.accounts.models import User  # local import

    p_user = User.objects.create(phone="0500000199", username="provider_199")
    provider = ProviderProfile.objects.create(
        user=p_user,
        provider_type="individual",
        display_name="مزود تنافسي مستهدف",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )
    ProviderCategory.objects.get_or_create(provider=provider, subcategory=sub)

    res = client.post(
        "/api/marketplace/requests/create/",
        {
            "provider": provider.id,
            "subcategory": sub.id,
            "title": "طلب تنافسي لمزود محدد",
            "description": "desc",
            "request_type": "competitive",
            "city": "الرياض",
        },
        format="json",
    )

    assert res.status_code == 400


@pytest.mark.django_db
def test_create_normal_request_requires_provider():
    cat = Category.objects.create(name="خدمات", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="سباكة", is_active=True)

    client = APIClient()

    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000003"},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000003").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000003", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "عميل",
            "last_name": "اختبار",
            "username": "user_0500000003",
            "email": "0500000003@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    res = client.post(
        "/api/marketplace/requests/create/",
        {
            "subcategory": sub.id,
            "title": "طلب عادي بدون مزود",
            "description": "desc",
            "request_type": "normal",
            "city": "الرياض",
        },
        format="json",
    )

    assert res.status_code == 400


@pytest.mark.django_db
def test_create_urgent_allows_blank_city_when_dispatch_all():
    cat = Category.objects.create(name="خدمات", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="كهرباء", is_active=True)

    client = APIClient()
    send = client.post("/api/accounts/otp/send/", {"phone": "0500000005"}, format="json")
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000005").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000005", "code": dev_code},
        format="json",
    )
    assert verify.status_code == 200
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "عميل",
            "last_name": "بدون مدينة",
            "username": "user_0500000005",
            "email": "0500000005@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    res = client.post(
        "/api/marketplace/requests/create/",
        {
            "subcategory": sub.id,
            "title": "طلب عاجل بدون مدينة",
            "description": "desc",
            "request_type": "urgent",
            "dispatch_mode": "all",
            "city": "",
        },
        format="json",
    )

    assert res.status_code == 201
    sr = ServiceRequest.objects.get(id=res.json()["id"])
    assert sr.city == ""
    assert sr.request_type == "urgent"
