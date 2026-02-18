import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User, UserRole
from apps.marketplace.models import RequestStatus, RequestType, ServiceRequest
from apps.providers.models import Category, ProviderCategory, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_messaging_flow_participants_only():
    client_user = User.objects.create_user(phone="0501000001", role_state=UserRole.PHONE_ONLY)
    provider_user = User.objects.create_user(phone="0501000002", role_state=UserRole.PROVIDER)
    other_user = User.objects.create_user(phone="0501000003", role_state=UserRole.PHONE_ONLY)

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
    sent_message_id = r2.data.get("message_id")
    assert sent_message_id is not None

    # مزود يقرأ الرسائل
    api.force_authenticate(user=provider_user)
    r3 = api.get(f"/api/messaging/requests/{sr.id}/messages/")
    assert r3.status_code == 200
    results = r3.data.get("results", []) if isinstance(r3.data, dict) else r3.data
    assert len(results) >= 1
    first = results[0]
    assert "read_by_ids" in first
    assert provider_user.id not in first.get("read_by_ids", [])

    r4 = api.post(f"/api/messaging/requests/{sr.id}/messages/read/", {}, format="json")
    assert r4.status_code == 200
    assert r4.data.get("marked", 0) >= 1
    assert sent_message_id in r4.data.get("message_ids", [])

    # بعد التعليم كمقروء يجب أن يظهر provider ضمن read_by_ids
    r5 = api.get(f"/api/messaging/requests/{sr.id}/messages/")
    assert r5.status_code == 200
    results_after = r5.data.get("results", []) if isinstance(r5.data, dict) else r5.data
    target = next((m for m in results_after if m.get("id") == sent_message_id), None)
    assert target is not None
    assert provider_user.id in target.get("read_by_ids", [])


@pytest.mark.django_db
def test_direct_thread_requires_phone_only_or_higher():
    visitor_user = User.objects.create_user(phone="0501000011", role_state=UserRole.VISITOR)
    phone_only_user = User.objects.create_user(phone="0501000012", role_state=UserRole.PHONE_ONLY)
    provider_user = User.objects.create_user(phone="0501000013", role_state=UserRole.PROVIDER)

    ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود مباشر",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    api = APIClient()

    api.force_authenticate(user=visitor_user)
    forbidden = api.post(
        "/api/messaging/direct/thread/",
        {"provider_id": provider_user.provider_profile.id},
        format="json",
    )
    assert forbidden.status_code == 403

    api.force_authenticate(user=phone_only_user)
    ok = api.post(
        "/api/messaging/direct/thread/",
        {"provider_id": provider_user.provider_profile.id},
        format="json",
    )
    assert ok.status_code == 200
