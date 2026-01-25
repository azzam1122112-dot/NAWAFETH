import pytest
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
        {"note": "بدء"},
        format="json",
    )
    assert r1.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.IN_PROGRESS

    r2 = api.post(
        f"/api/marketplace/requests/{sr.id}/complete/",
        {"note": "إنهاء"},
        format="json",
    )
    assert r2.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.COMPLETED


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
