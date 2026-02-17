import pytest
from datetime import timedelta
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.marketplace.models import RequestStatus, RequestStatusLog, RequestType, ServiceRequest
from apps.notifications.models import Notification
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


@pytest.mark.django_db
def test_provider_progress_update_creates_log_and_client_notification():
    client_user = User.objects.create_user(phone="0500000301")
    provider_user = User.objects.create_user(phone="0500000302")
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
    sub = SubCategory.objects.create(category=cat, name="تكييف")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type=RequestType.NORMAL,
        status=RequestStatus.IN_PROGRESS,
        city="الرياض",
        expected_delivery_at=timezone.now(),
        estimated_service_amount="500.00",
        received_amount="100.00",
        remaining_amount="400.00",
    )

    api = APIClient()
    api.force_authenticate(user=provider_user)
    res = api.post(
        f"/api/marketplace/provider/requests/{sr.id}/progress-update/",
        {
            "note": "تم إنجاز 50٪ من العمل",
            "estimated_service_amount": "600.00",
            "received_amount": "200.00",
        },
        format="json",
    )
    assert res.status_code == 200

    sr.refresh_from_db()
    assert str(sr.estimated_service_amount) == "600.00"
    assert str(sr.received_amount) == "200.00"
    assert str(sr.remaining_amount) == "400.00"

    log = RequestStatusLog.objects.filter(request=sr).order_by("-id").first()
    assert log is not None
    assert log.from_status == RequestStatus.IN_PROGRESS
    assert log.to_status == RequestStatus.IN_PROGRESS
    assert "50" in (log.note or "")

    notif = Notification.objects.filter(user=client_user, request_id=sr.id).order_by("-id").first()
    assert notif is not None
    assert notif.title == "تحديث على الطلب"


@pytest.mark.django_db
def test_client_can_patch_request_details_and_notify_provider():
    client_user = User.objects.create_user(phone="0500000401")
    provider_user = User.objects.create_user(phone="0500000402")
    provider = ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = Category.objects.create(name="تنظيف")
    sub = SubCategory.objects.create(category=cat, name="منازل")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب قديم",
        description="وصف قديم",
        request_type=RequestType.NORMAL,
        status=RequestStatus.SENT,
        city="الرياض",
    )

    api = APIClient()
    api.force_authenticate(user=client_user)
    res = api.patch(
        f"/api/marketplace/client/requests/{sr.id}/",
        {"title": "طلب محدث", "description": "وصف محدث"},
        format="json",
    )
    assert res.status_code == 200

    sr.refresh_from_db()
    assert sr.title == "طلب محدث"
    assert sr.description == "وصف محدث"

    log = RequestStatusLog.objects.filter(request=sr).order_by("-id").first()
    assert log is not None
    assert log.from_status == sr.status
    assert log.to_status == sr.status
    assert "تحديث بيانات الطلب من العميل" in (log.note or "")

    notif = Notification.objects.filter(user=provider_user, request_id=sr.id).order_by("-id").first()
    assert notif is not None
    assert notif.title == "تحديث على الطلب"


@pytest.mark.django_db
def test_client_cannot_patch_request_details_when_in_progress():
    client_user = User.objects.create_user(phone="0500000411")
    provider_user = User.objects.create_user(phone="0500000412")
    provider = ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = Category.objects.create(name="نظافة")
    sub = SubCategory.objects.create(category=cat, name="مكاتب")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب جاري",
        description="وصف جاري",
        request_type=RequestType.NORMAL,
        status=RequestStatus.IN_PROGRESS,
        city="الرياض",
    )

    api = APIClient()
    api.force_authenticate(user=client_user)
    res = api.patch(
        f"/api/marketplace/client/requests/{sr.id}/",
        {"title": "عنوان جديد"},
        format="json",
    )
    assert res.status_code == 400
    sr.refresh_from_db()
    assert sr.title == "طلب جاري"


@pytest.mark.django_db
def test_client_cannot_patch_request_details_when_accepted():
    client_user = User.objects.create_user(phone="0500000413")
    provider_user = User.objects.create_user(phone="0500000414")
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
    sub = SubCategory.objects.create(category=cat, name="مكيفات")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب بانتظار الاعتماد",
        description="وصف",
        request_type=RequestType.NORMAL,
        status=RequestStatus.ACCEPTED,
        city="الرياض",
    )

    api = APIClient()
    api.force_authenticate(user=client_user)
    res = api.patch(
        f"/api/marketplace/client/requests/{sr.id}/",
        {"description": "وصف جديد"},
        format="json",
    )
    assert res.status_code == 400
    sr.refresh_from_db()
    assert sr.description == "وصف"


@pytest.mark.django_db
def test_client_can_reopen_cancelled_request_as_new_with_new_created_at():
    client_user = User.objects.create_user(phone="0500000501")
    provider_user = User.objects.create_user(phone="0500000502")
    provider = ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        years_experience=1,
        city="الرياض",
        accepts_urgent=True,
    )

    cat = Category.objects.create(name="نقل")
    sub = SubCategory.objects.create(category=cat, name="أثاث")
    ProviderCategory.objects.create(provider=provider, subcategory=sub)

    sr = ServiceRequest.objects.create(
        client=client_user,
        provider=provider,
        subcategory=sub,
        title="طلب ملغي",
        description="وصف",
        request_type=RequestType.NORMAL,
        status=RequestStatus.CANCELLED,
        city="الرياض",
        canceled_at=timezone.now(),
        cancel_reason="تم الإلغاء",
    )
    old_created = sr.created_at

    api = APIClient()
    api.force_authenticate(user=client_user)
    res = api.post(
        f"/api/marketplace/requests/{sr.id}/reopen/",
        {"note": "إعادة فتح"},
        format="json",
    )
    assert res.status_code == 200

    sr.refresh_from_db()
    assert sr.status == RequestStatus.SENT
    assert sr.created_at >= old_created
    assert sr.canceled_at is None
    assert sr.cancel_reason == ""


@pytest.mark.django_db
def test_client_can_reopen_expired_request():
    client_user = User.objects.create_user(phone="0500000503")

    cat = Category.objects.create(name="نقل سريع")
    sub = SubCategory.objects.create(category=cat, name="مستعجل")

    sr = ServiceRequest.objects.create(
        client=client_user,
        subcategory=sub,
        title="طلب منتهي",
        description="وصف",
        request_type=RequestType.URGENT,
        status=RequestStatus.EXPIRED,
        city="الرياض",
        expires_at=timezone.now() - timedelta(minutes=5),
    )

    api = APIClient()
    api.force_authenticate(user=client_user)
    res = api.post(
        f"/api/marketplace/requests/{sr.id}/reopen/",
        {},
        format="json",
    )
    assert res.status_code == 200
    sr.refresh_from_db()
    assert sr.status == RequestStatus.SENT
    assert sr.expires_at is not None
