import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from django.conf import settings

from config.asgi import application
from apps.accounts.models import User
from apps.providers.models import Category, SubCategory, ProviderProfile, ProviderCategory
from apps.marketplace.models import ServiceRequest, RequestType, RequestStatus


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_connect_requires_token():
    # بدون token => Anonymous => 4401
    communicator = WebsocketCommunicator(application, "/ws/requests/1/")
    connected, _ = await communicator.connect()
    assert connected is False
    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_forbidden_for_non_participant(mocker):
    # تجهيز مستخدمين
    client_user = await database_sync_to_async(User.objects.create_user)(phone="0520000001")
    provider_user = await database_sync_to_async(User.objects.create_user)(phone="0520000002")
    other_user = await database_sync_to_async(User.objects.create_user)(phone="0520000003")

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

    # نحقن User داخل middleware بدل توليد JWT حقيقي:
    # أسهل: نعمل patch لدالة get_user_for_token داخل Jwt middleware لتعيد other_user
    from apps.messaging import jwt_auth

    mocker.patch.object(jwt_auth, "get_user_for_token", return_value=other_user)

    communicator = WebsocketCommunicator(application, f"/ws/requests/{sr.id}/?token=fake")
    connected, _ = await communicator.connect()
    assert connected is False  # 4403
    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_connect_and_send_message_as_participant(mocker):
    client_user = await database_sync_to_async(User.objects.create_user)(phone="0520000101")
    provider_user = await database_sync_to_async(User.objects.create_user)(phone="0520000102")

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

    from apps.messaging import jwt_auth

    mocker.patch.object(jwt_auth, "get_user_for_token", return_value=client_user)

    communicator = WebsocketCommunicator(application, f"/ws/requests/{sr.id}/?token=fake")
    connected, _ = await communicator.connect()
    assert connected is True

    # يستقبل connected packet
    msg = await communicator.receive_json_from()
    assert msg["type"] == "connected"
    assert msg["request_id"] == sr.id

    # إرسال رسالة
    await communicator.send_json_to({"action": "send", "body": "مرحبا"})
    evt = await communicator.receive_json_from()
    assert evt["type"] == "message"
    assert evt["body"] == "مرحبا"
    assert evt["sender_id"] == client_user.id

    await communicator.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_ws_reject_if_no_provider_assigned(mocker):
    client_user = await database_sync_to_async(User.objects.create_user)(phone="0520000201")

    # طلب بدون provider => يجب رفض الاتصال 4400
    cat = await database_sync_to_async(Category.objects.create)(name="صيانة")
    sub = await database_sync_to_async(SubCategory.objects.create)(category=cat, name="شبكات")

    sr = await database_sync_to_async(ServiceRequest.objects.create)(
        client=client_user,
        provider=None,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.SENT,
        city="الرياض",
    )

    from apps.messaging import jwt_auth

    mocker.patch.object(jwt_auth, "get_user_for_token", return_value=client_user)

    communicator = WebsocketCommunicator(application, f"/ws/requests/{sr.id}/?token=fake")
    connected, _ = await communicator.connect()
    assert connected is False
    await communicator.disconnect()
