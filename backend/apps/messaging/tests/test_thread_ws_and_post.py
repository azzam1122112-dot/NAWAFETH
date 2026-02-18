import pytest
import asyncio
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from django.test import Client
from rest_framework.test import APIClient

from config.asgi import application
from apps.accounts.models import User, UserRole
from apps.providers.models import Category, SubCategory, ProviderProfile, ProviderCategory
from apps.marketplace.models import ServiceRequest, RequestType, RequestStatus
from apps.messaging.models import Thread, Message
from apps.messaging.models import ThreadUserState


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_thread_ws_connect_requires_token():
    communicator = WebsocketCommunicator(application, "/ws/thread/1/")
    connected, _ = await communicator.connect()
    assert connected is False
    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_thread_ws_forbidden_for_non_participant(mocker):
    client_user = await database_sync_to_async(User.objects.create_user)(phone="0521000001")
    provider_user = await database_sync_to_async(User.objects.create_user)(phone="0521000002")
    other_user = await database_sync_to_async(User.objects.create_user)(phone="0521000003")

    provider = await database_sync_to_async(ProviderProfile.objects.create)(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = await database_sync_to_async(Category.objects.create)(name="تصميم")
    sub = await database_sync_to_async(SubCategory.objects.create)(category=cat, name="شعار")
    await database_sync_to_async(ProviderCategory.objects.create)(provider=provider, subcategory=sub)

    sr = await database_sync_to_async(ServiceRequest.objects.create)(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
    )

    thread = await database_sync_to_async(Thread.objects.create)(request=sr)

    from apps.messaging import jwt_auth

    mocker.patch.object(jwt_auth, "get_user_for_token", return_value=other_user)

    communicator = WebsocketCommunicator(application, f"/ws/thread/{thread.id}/?token=fake")
    connected, _ = await communicator.connect()
    assert connected is False
    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_thread_ws_connect_and_send_message_as_participant(mocker):
    client_user = await database_sync_to_async(User.objects.create_user)(phone="0521000101")
    provider_user = await database_sync_to_async(User.objects.create_user)(phone="0521000102")

    provider = await database_sync_to_async(ProviderProfile.objects.create)(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = await database_sync_to_async(Category.objects.create)(name="برمجة")
    sub = await database_sync_to_async(SubCategory.objects.create)(category=cat, name="ويب")
    await database_sync_to_async(ProviderCategory.objects.create)(provider=provider, subcategory=sub)

    sr = await database_sync_to_async(ServiceRequest.objects.create)(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
    )

    thread = await database_sync_to_async(Thread.objects.create)(request=sr)
    initial_msg = await database_sync_to_async(Message.objects.create)(
        thread=thread,
        sender=provider_user,
        body="رسالة قديمة",
    )

    from apps.messaging import jwt_auth

    mocker.patch.object(jwt_auth, "get_user_for_token", return_value=client_user)

    communicator = WebsocketCommunicator(application, f"/ws/thread/{thread.id}/?token=fake")
    connected, _ = await communicator.connect()
    assert connected is True

    hello = await communicator.receive_json_from()
    assert hello["type"] == "connected"
    assert hello["thread_id"] == thread.id

    await communicator.send_json_to({"type": "message", "text": "مرحبا"})
    evt = await communicator.receive_json_from()
    assert evt["type"] == "message"
    assert evt["text"] == "مرحبا"
    assert evt["sender_id"] == client_user.id

    # mark-read should broadcast message_ids for precise receipts
    await communicator.send_json_to({"type": "read"})
    read_evt = await communicator.receive_json_from()
    assert read_evt["type"] == "read"
    assert read_evt["marked"] >= 1
    assert initial_msg.id in read_evt.get("message_ids", [])

    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_thread_ws_block_broadcast_closes_peer_immediately(mocker):
    client_user = await database_sync_to_async(User.objects.create_user)(
        phone="0522000101", role_state=UserRole.PHONE_ONLY
    )
    provider_user = await database_sync_to_async(User.objects.create_user)(
        phone="0522000102", role_state=UserRole.PROVIDER
    )

    provider = await database_sync_to_async(ProviderProfile.objects.create)(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = await database_sync_to_async(Category.objects.create)(name="كتابة")
    sub = await database_sync_to_async(SubCategory.objects.create)(category=cat, name="محتوى")
    await database_sync_to_async(ProviderCategory.objects.create)(provider=provider, subcategory=sub)

    sr = await database_sync_to_async(ServiceRequest.objects.create)(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
    )

    thread = await database_sync_to_async(Thread.objects.create)(request=sr)

    from apps.messaging import jwt_auth

    def _token_side_effect(token_str: str):
        if token_str == "client":
            return client_user
        if token_str == "provider":
            return provider_user
        return None

    mocker.patch.object(jwt_auth, "get_user_for_token", side_effect=_token_side_effect)

    comm_client = WebsocketCommunicator(application, f"/ws/thread/{thread.id}/?token=client")
    comm_provider = WebsocketCommunicator(application, f"/ws/thread/{thread.id}/?token=provider")

    connected1, _ = await comm_client.connect()
    connected2, _ = await comm_provider.connect()
    assert connected1 is True
    assert connected2 is True

    hello1 = await comm_client.receive_json_from()
    hello2 = await comm_provider.receive_json_from()
    assert hello1["type"] == "connected"
    assert hello2["type"] == "connected"

    # Block via REST; should broadcast to WS group and close peer immediately
    def _do_block():
        api = APIClient()
        api.force_authenticate(user=client_user)
        return api.post(
            f"/api/messaging/thread/{thread.id}/block/",
            {"action": "block"},
            format="json",
        )

    r = await database_sync_to_async(_do_block)()
    assert r.status_code == 200

    evt = await asyncio.wait_for(comm_provider.receive_json_from(), timeout=2)
    assert evt["type"] == "error"
    assert evt.get("code") == "blocked"

    # The blocker should remain connected and still be able to send/receive events
    await comm_client.send_json_to({"type": "typing", "is_typing": True})
    typing_evt = await asyncio.wait_for(comm_client.receive_json_from(), timeout=2)
    assert typing_evt["type"] == "typing"

    await comm_provider.disconnect()
    await comm_client.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_thread_ws_connect_denied_when_blocked_by_other(mocker):
    client_user = await database_sync_to_async(User.objects.create_user)(
        phone="0522000201", role_state=UserRole.PHONE_ONLY
    )
    provider_user = await database_sync_to_async(User.objects.create_user)(
        phone="0522000202", role_state=UserRole.PROVIDER
    )

    provider = await database_sync_to_async(ProviderProfile.objects.create)(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = await database_sync_to_async(Category.objects.create)(name="تصميم")
    sub = await database_sync_to_async(SubCategory.objects.create)(category=cat, name="بنر")
    await database_sync_to_async(ProviderCategory.objects.create)(provider=provider, subcategory=sub)

    sr = await database_sync_to_async(ServiceRequest.objects.create)(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
    )

    thread = await database_sync_to_async(Thread.objects.create)(request=sr)
    await database_sync_to_async(ThreadUserState.objects.create)(
        thread=thread,
        user=client_user,
        is_blocked=True,
    )

    from apps.messaging import jwt_auth

    mocker.patch.object(jwt_auth, "get_user_for_token", return_value=provider_user)

    communicator = WebsocketCommunicator(application, f"/ws/thread/{thread.id}/?token=provider")
    connected, _ = await communicator.connect()
    assert connected is False
    await communicator.disconnect()


@pytest.mark.django_db
def test_post_message_requires_auth_and_permissions():
    client_user = User.objects.create_user(phone="0530000001", role_state=UserRole.PHONE_ONLY)
    provider_user = User.objects.create_user(phone="0530000002", role_state=UserRole.PROVIDER)
    other_user = User.objects.create_user(phone="0530000003", role_state=UserRole.PHONE_ONLY)

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
    sub = SubCategory.objects.create(category=cat, name="شبكات")
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

    thread = Thread.objects.create(request=sr)

    c = Client()

    # anonymous
    r0 = c.post(f"/api/messaging/thread/{thread.id}/post/", {"text": "hi"})
    assert r0.status_code == 401

    # forbidden
    c.force_login(other_user)
    r1 = c.post(f"/api/messaging/thread/{thread.id}/post/", {"text": "hi"})
    assert r1.status_code == 403

    # allowed participant
    c.force_login(client_user)
    r2 = c.post(f"/api/messaging/thread/{thread.id}/post/", {"text": "مرحبا"})
    assert r2.status_code == 200
    data = r2.json()
    assert data["ok"] is True
    assert data["message"]["text"] == "مرحبا"

    assert Message.objects.filter(thread=thread).count() == 1
