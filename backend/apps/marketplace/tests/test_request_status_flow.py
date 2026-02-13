import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.marketplace.models import RequestStatus, RequestType, ServiceRequest
from apps.providers.models import Category, ProviderCategory, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_provider_start_and_complete_flow():
    client_user = User.objects.create_user(phone="0500000001")
    provider_user = User.objects.create_user(phone="0500000002")
    provider = ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = Category.objects.create(name="تصميم")
    sub = SubCategory.objects.create(category=cat, name="شعار")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
    )

    api = APIClient()
    api.force_authenticate(user=provider_user)

    r1 = api.post(
        f"/api/marketplace/requests/{sr.id}/start/",
        {
            "note": "بدء",
            "expected_delivery_at": "2026-03-01T10:00:00Z",
            "estimated_service_amount": "1000.00",
            "received_amount": "400.00",
        },
        format="json",
    )
    assert r1.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.ACCEPTED
    assert sr.expected_delivery_at is not None
    assert str(sr.estimated_service_amount) == "1000.00"
    assert str(sr.received_amount) == "400.00"
    assert str(sr.remaining_amount) == "600.00"
    assert sr.provider_inputs_approved is None

    api.force_authenticate(user=client_user)
    r2 = api.post(
        f"/api/marketplace/requests/{sr.id}/provider-inputs/decision/",
        {"approved": True, "note": "تم الاعتماد"},
        format="json",
    )
    assert r2.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.IN_PROGRESS

    api.force_authenticate(user=provider_user)
    r3 = api.post(
        f"/api/marketplace/requests/{sr.id}/complete/",
        {
            "note": "إنهاء",
            "delivered_at": "2026-03-02T12:00:00Z",
            "actual_service_amount": "950.00",
        },
        format="json",
    )
    assert r3.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.COMPLETED
    assert sr.delivered_at is not None
    assert str(sr.actual_service_amount) == "950.00"


@pytest.mark.django_db
def test_client_cancel_allowed_only_before_in_progress():
    client_user = User.objects.create_user(phone="0500000011")
    other_user = User.objects.create_user(phone="0500000012")

    cat = Category.objects.create(name="برمجة")
    sub = SubCategory.objects.create(category=cat, name="ويب")

    sr = ServiceRequest.objects.create(
        client=client_user,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.SENT,
        city="الرياض",
    )

    api = APIClient()

    # غير المالك ممنوع
    api.force_authenticate(user=other_user)
    r0 = api.post(
        f"/api/marketplace/requests/{sr.id}/cancel/",
        {"note": "x"},
        format="json",
    )
    assert r0.status_code == 403

    # المالك يسمح
    api.force_authenticate(user=client_user)
    r1 = api.post(
        f"/api/marketplace/requests/{sr.id}/cancel/",
        {"note": "إلغاء"},
        format="json",
    )
    assert r1.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.CANCELLED


@pytest.mark.django_db
def test_provider_reject_requires_cancel_fields_and_saves_them():
    client_user = User.objects.create_user(phone="0500000201")
    provider_user = User.objects.create_user(phone="0500000202")
    provider = ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = Category.objects.create(name="صيانة")
    sub = SubCategory.objects.create(category=cat, name="سباكة")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.NORMAL,
        status=RequestStatus.SENT,
        city="الرياض",
    )

    api = APIClient()
    api.force_authenticate(user=provider_user)

    bad = api.post(
        f"/api/marketplace/provider/requests/{sr.id}/reject/",
        {"note": "إلغاء"},
        format="json",
    )
    assert bad.status_code == 400

    ok = api.post(
        f"/api/marketplace/provider/requests/{sr.id}/reject/",
        {"canceled_at": "2026-03-03T10:30:00Z", "cancel_reason": "تعذر التنفيذ"},
        format="json",
    )
    assert ok.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.CANCELLED
    assert sr.canceled_at is not None
    assert sr.cancel_reason == "تعذر التنفيذ"


@pytest.mark.django_db
def test_client_can_decide_provider_inputs_when_accepted():
    client_user = User.objects.create_user(phone="0500000101")
    provider_user = User.objects.create_user(phone="0500000102")
    provider = ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = Category.objects.create(name="صيانة")
    sub = SubCategory.objects.create(category=cat, name="كهرباء")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.NORMAL,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
        expected_delivery_at=timezone.now(),
        estimated_service_amount="1200.00",
        received_amount="300.00",
        remaining_amount="900.00",
    )

    api = APIClient()
    api.force_authenticate(user=client_user)
    res = api.post(
        f"/api/marketplace/requests/{sr.id}/provider-inputs/decision/",
        {"approved": True, "note": "تم الاعتماد"},
        format="json",
    )
    assert res.status_code == 200

    sr.refresh_from_db()
    assert sr.status == RequestStatus.IN_PROGRESS
    assert sr.provider_inputs_approved is True
    assert sr.provider_inputs_decision_note == "تم الاعتماد"
