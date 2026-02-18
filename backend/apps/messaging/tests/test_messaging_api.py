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


@pytest.mark.django_db
def test_thread_user_state_favorite_archive_and_unarchive_on_message():
    client_user = User.objects.create_user(phone="0502000001", role_state=UserRole.PHONE_ONLY)
    provider_user = User.objects.create_user(phone="0502000002", role_state=UserRole.PROVIDER)

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
    api.force_authenticate(user=client_user)

    r1 = api.post(f"/api/messaging/requests/{sr.id}/thread/", {}, format="json")
    assert r1.status_code == 200
    thread_id = r1.data.get("id")
    assert thread_id is not None

    fav = api.post(f"/api/messaging/thread/{thread_id}/favorite/", {}, format="json")
    assert fav.status_code == 200
    assert fav.data.get("is_favorite") is True

    states = api.get("/api/messaging/threads/states/")
    assert states.status_code == 200
    assert any(s.get("thread") == thread_id and s.get("is_favorite") is True for s in states.data)

    arch = api.post(f"/api/messaging/thread/{thread_id}/archive/", {}, format="json")
    assert arch.status_code == 200
    assert arch.data.get("is_archived") is True

    # Sending a message should unarchive for participants
    send = api.post(
        f"/api/messaging/requests/{sr.id}/messages/send/",
        {"body": "مرحبا"},
        format="json",
    )
    assert send.status_code == 201

    state_after = api.get(f"/api/messaging/thread/{thread_id}/state/")
    assert state_after.status_code == 200
    assert state_after.data.get("is_archived") is False


@pytest.mark.django_db
def test_block_prevents_peer_sending_request_and_direct():
    client_user = User.objects.create_user(phone="0503000001", role_state=UserRole.PHONE_ONLY)
    provider_user = User.objects.create_user(phone="0503000002", role_state=UserRole.PROVIDER)

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

    # Request thread block
    api.force_authenticate(user=client_user)
    r1 = api.post(f"/api/messaging/requests/{sr.id}/thread/", {}, format="json")
    assert r1.status_code == 200
    thread_id = r1.data.get("id")
    assert thread_id is not None

    b1 = api.post(f"/api/messaging/thread/{thread_id}/block/", {}, format="json")
    assert b1.status_code == 200
    assert b1.data.get("is_blocked") is True

    api.force_authenticate(user=provider_user)
    blocked_send = api.post(
        f"/api/messaging/requests/{sr.id}/messages/send/",
        {"body": "رسالة"},
        format="json",
    )
    assert blocked_send.status_code == 403

    # Direct thread block
    api.force_authenticate(user=client_user)
    d1 = api.post(
        "/api/messaging/direct/thread/",
        {"provider_id": provider.id},
        format="json",
    )
    assert d1.status_code == 200
    direct_thread_id = d1.data.get("id")
    assert direct_thread_id is not None

    b2 = api.post(f"/api/messaging/thread/{direct_thread_id}/block/", {}, format="json")
    assert b2.status_code == 200
    assert b2.data.get("is_blocked") is True

    api.force_authenticate(user=provider_user)
    blocked_direct_send = api.post(
        f"/api/messaging/direct/thread/{direct_thread_id}/messages/send/",
        {"body": "رسالة"},
        format="json",
    )
    assert blocked_direct_send.status_code == 403
