import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from django.test import Client

from config.asgi import application
from apps.accounts.models import User
from apps.providers.models import Category, SubCategory, ProviderProfile, ProviderCategory
from apps.marketplace.models import ServiceRequest, RequestType, RequestStatus
from apps.messaging.models import Thread, Message


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

    await communicator.disconnect()


@pytest.mark.django_db
def test_post_message_requires_auth_and_permissions():
    client_user = User.objects.create_user(phone="0530000001")
    provider_user = User.objects.create_user(phone="0530000002")
    other_user = User.objects.create_user(phone="0530000003")

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
