import pytest
from rest_framework.test import APIClient

from apps.accounts.models import OTP
from apps.marketplace.models import RequestStatus, RequestType, ServiceRequest
from apps.providers.models import Category, ProviderCategory, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_urgent_accept_locks_and_accepts_once_happy_path():
    # Arrange: create provider user via OTP, then provider_profile via providers/register
    client = APIClient()

    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000010"},
        format="json",
    )
    assert send.status_code == 200
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000010").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000010", "code": dev_code},
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
            "username": "user_0500000010",
            "email": "0500000010@example.com",
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
            "bio": "bio",
            "years_experience": 1,
            "city": "الرياض",
            "accepts_urgent": True,
        },
        format="json",
    )
    assert reg.status_code == 201

    provider = ProviderProfile.objects.get(display_name="محمد التصميم")

    # Arrange: create urgent request in NEW state (allowed by spec)
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)
    sr = ServiceRequest.objects.create(
        client=provider.user,
        subcategory=sub,
        title="طلب عاجل",
        description="desc",
        request_type=RequestType.URGENT,
        city="الرياض",
        is_urgent=True,
        status=RequestStatus.NEW,
    )

    ProviderCategory.objects.get_or_create(provider=provider, subcategory=sub)

    # Act: accept
    res = client.post(
        "/api/marketplace/requests/urgent/accept/",
        {"request_id": sr.id},
        format="json",
    )

    # Assert
    assert res.status_code == 200
    assert res.json()["ok"] is True
    assert res.json()["request_id"] == sr.id
    assert res.json()["status"] == "accepted"
    assert res.json()["provider"] == "محمد التصميم"
    sr.refresh_from_db()
    assert sr.status == RequestStatus.ACCEPTED
    assert sr.provider_id == provider.id


@pytest.mark.django_db
def test_urgent_accept_conflict_when_already_assigned():
    client = APIClient()

    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000020"},
        format="json",
    )
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000020").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000020", "code": dev_code},
        format="json",
    )
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # Complete registration (level 3) before registering provider
    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "مزود",
            "last_name": "اختبار",
            "username": "user_0500000020",
            "email": "0500000020@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    client.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "مزود 2",
            "bio": "bio",
            "years_experience": 1,
            "city": "الرياض",
            "accepts_urgent": True,
        },
        format="json",
    )
    provider = ProviderProfile.objects.get(display_name="مزود 2")

    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)
    sr = ServiceRequest.objects.create(
        client=provider.user,
        subcategory=sub,
        title="طلب عاجل",
        description="desc",
        request_type=RequestType.URGENT,
        city="الرياض",
        is_urgent=True,
        status=RequestStatus.NEW,
        provider=provider,
    )

    ProviderCategory.objects.get_or_create(provider=provider, subcategory=sub)

    res = client.post(
        "/api/marketplace/requests/urgent/accept/",
        {"request_id": sr.id},
        format="json",
    )

    assert res.status_code == 409


@pytest.mark.django_db
def test_urgent_accept_forbidden_for_non_provider_user():
    client = APIClient()

    # Create a normal user via OTP (no provider_profile)
    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000030"},
        format="json",
    )
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000030").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code
    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000030", "code": dev_code},
        format="json",
    )
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # Create an urgent request (any client is fine)
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)
    sr = ServiceRequest.objects.create(
        client_id=verify.json()["user_id"],
        subcategory=sub,
        title="طلب عاجل",
        description="desc",
        request_type=RequestType.URGENT,
        city="الرياض",
        is_urgent=True,
        status=RequestStatus.NEW,
    )

    res = client.post(
        "/api/marketplace/requests/urgent/accept/",
        {"request_id": sr.id},
        format="json",
    )

    assert res.status_code == 403


@pytest.mark.django_db
def test_urgent_accept_rejects_non_urgent_request():
    client = APIClient()

    # Provider user
    send = client.post(
        "/api/accounts/otp/send/",
        {"phone": "0500000040"},
        format="json",
    )
    payload = send.json()
    dev_code = payload.get("dev_code") or OTP.objects.filter(phone="0500000040").order_by("-id").values_list(
        "code", flat=True
    ).first()
    assert dev_code
    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": "0500000040", "code": dev_code},
        format="json",
    )
    access = verify.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # Complete registration (level 3) before registering provider
    complete = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "مزود",
            "last_name": "اختبار",
            "username": "user_0500000040",
            "email": "0500000040@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete.status_code == 200

    client.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "مزود غير عاجل",
            "bio": "bio",
            "years_experience": 1,
            "city": "الرياض",
            "accepts_urgent": True,
        },
        format="json",
    )
    provider = ProviderProfile.objects.get(display_name="مزود غير عاجل")

    # Non-urgent request
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)
    sr = ServiceRequest.objects.create(
        client=provider.user,
        subcategory=sub,
        title="طلب غير عاجل",
        description="desc",
        request_type=RequestType.COMPETITIVE,
        city="الرياض",
        is_urgent=False,
        status=RequestStatus.NEW,
    )

    res = client.post(
        "/api/marketplace/requests/urgent/accept/",
        {"request_id": sr.id},
        format="json",
    )

    assert res.status_code == 400
    assert res.json()["detail"] == "هذا الطلب ليس عاجلًا"


@pytest.mark.django_db
def test_urgent_request_disappears_from_available_for_other_providers_after_accept():
    client = APIClient()

    # Provider #1
    send1 = client.post("/api/accounts/otp/send/", {"phone": "0500000051"}, format="json")
    assert send1.status_code == 200
    code1 = send1.json().get("dev_code") or OTP.objects.filter(phone="0500000051").order_by("-id").values_list("code", flat=True).first()
    assert code1
    verify1 = client.post("/api/accounts/otp/verify/", {"phone": "0500000051", "code": code1}, format="json")
    assert verify1.status_code == 200
    access1 = verify1.json()["access"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access1}")
    complete1 = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "مزود",
            "last_name": "أول",
            "username": "provider_urgent_0051",
            "email": "0500000051@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete1.status_code in (200, 400)
    reg1 = client.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "مزود عاجل 1",
            "bio": "bio",
            "years_experience": 1,
            "city": "الرياض",
            "accepts_urgent": True,
        },
        format="json",
    )
    assert reg1.status_code in (201, 400)
    p1 = ProviderProfile.objects.get(display_name="مزود عاجل 1")

    # Provider #2
    client2 = APIClient()
    send2 = client2.post("/api/accounts/otp/send/", {"phone": "0500000052"}, format="json")
    assert send2.status_code == 200
    code2 = send2.json().get("dev_code") or OTP.objects.filter(phone="0500000052").order_by("-id").values_list("code", flat=True).first()
    assert code2
    verify2 = client2.post("/api/accounts/otp/verify/", {"phone": "0500000052", "code": code2}, format="json")
    assert verify2.status_code == 200
    access2 = verify2.json()["access"]
    client2.credentials(HTTP_AUTHORIZATION=f"Bearer {access2}")
    complete2 = client2.post(
        "/api/accounts/complete/",
        {
            "first_name": "مزود",
            "last_name": "ثان",
            "username": "provider_urgent_0052",
            "email": "0500000052@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert complete2.status_code in (200, 400)
    reg2 = client2.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "مزود عاجل 2",
            "bio": "bio",
            "years_experience": 1,
            "city": "الرياض",
            "accepts_urgent": True,
        },
        format="json",
    )
    assert reg2.status_code in (201, 400)
    p2 = ProviderProfile.objects.get(display_name="مزود عاجل 2")

    cat = Category.objects.create(name="صيانة", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="كهرباء", is_active=True)
    ProviderCategory.objects.get_or_create(provider=p1, subcategory=sub)
    ProviderCategory.objects.get_or_create(provider=p2, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=p1.user,
        subcategory=sub,
        title="طلب عاجل مشترك",
        description="desc",
        request_type=RequestType.URGENT,
        city="الرياض",
        is_urgent=True,
        status=RequestStatus.SENT,
    )

    before_1 = client.get("/api/marketplace/provider/urgent/available/")
    assert before_1.status_code == 200
    assert sr.id in {item["id"] for item in before_1.json()}

    before_2 = client2.get("/api/marketplace/provider/urgent/available/")
    assert before_2.status_code == 200
    assert sr.id in {item["id"] for item in before_2.json()}

    accepted = client.post(
        "/api/marketplace/requests/urgent/accept/",
        {"request_id": sr.id},
        format="json",
    )
    assert accepted.status_code == 200

    sr.refresh_from_db()
    assert sr.provider_id == p1.id
    assert sr.status == RequestStatus.ACCEPTED

    after_2 = client2.get("/api/marketplace/provider/urgent/available/")
    assert after_2.status_code == 200
    assert sr.id not in {item["id"] for item in after_2.json()}
