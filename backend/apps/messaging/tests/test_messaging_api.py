import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.marketplace.models import RequestStatus, RequestType, ServiceRequest
from apps.providers.models import Category, ProviderCategory, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_messaging_flow_participants_only():
    client_user = User.objects.create_user(phone="0501000001")
    provider_user = User.objects.create_user(phone="0501000002")
    other_user = User.objects.create_user(phone="0501000003")

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

    # غير مشارك ممنوع
    api.force_authenticate(user=other_user)
    r0 = api.post(f"/api/messaging/requests/{sr.id}/thread/", {}, format="json")
    assert r0.status_code == 403

    # عميل ينشئ/يجلب الثريد
    api.force_authenticate(user=client_user)
    r1 = api.post(f"/api/messaging/requests/{sr.id}/thread/", {}, format="json")
    assert r1.status_code == 200

    # يرسل رسالة
    r2 = api.post(
        f"/api/messaging/requests/{sr.id}/messages/send/",
        {"body": "مرحبا"},
        format="json",
    )
    assert r2.status_code == 201

    # مزود يقرأ الرسائل
    api.force_authenticate(user=provider_user)
    r3 = api.get(f"/api/messaging/requests/{sr.id}/messages/")
    assert r3.status_code == 200
    assert len(r3.data) >= 1

    r4 = api.post(f"/api/messaging/requests/{sr.id}/messages/read/", {}, format="json")
    assert r4.status_code == 200
