import pytest
from django.core.exceptions import PermissionDenied, ValidationError

from apps.accounts.models import User
from apps.marketplace.models import RequestStatus, ServiceRequest
from apps.marketplace.services.actions import allowed_actions, execute_action
from apps.providers.models import Category, ProviderProfile, SubCategory


@pytest.mark.django_db
def test_allowed_actions_client_can_send_when_new():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client_user = User.objects.create_user(phone="0500000101")
    sr = ServiceRequest.objects.create(
        client=client_user,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type="competitive",
        status=RequestStatus.NEW,
        city="الرياض",
    )

    acts = allowed_actions(client_user, sr)
    assert "send" in acts


@pytest.mark.django_db
def test_execute_action_send_by_client_marks_sent():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client_user = User.objects.create_user(phone="0500000102")
    sr = ServiceRequest.objects.create(
        client=client_user,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type="competitive",
        status=RequestStatus.NEW,
        city="الرياض",
    )

    res = execute_action(user=client_user, request_id=sr.id, action="send")
    sr.refresh_from_db()
    assert res.ok is True
    assert sr.status == RequestStatus.SENT


@pytest.mark.django_db
def test_execute_action_send_forbidden_for_random_user():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client_user = User.objects.create_user(phone="0500000103")
    other_user = User.objects.create_user(phone="0500000104")

    sr = ServiceRequest.objects.create(
        client=client_user,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type="competitive",
        status=RequestStatus.NEW,
        city="الرياض",
    )

    with pytest.raises(PermissionDenied):
        execute_action(user=other_user, request_id=sr.id, action="send")


@pytest.mark.django_db
def test_allowed_actions_provider_unassigned_can_accept_when_sent():
    cat = Category.objects.create(name="تصميم", is_active=True)
    sub = SubCategory.objects.create(category=cat, name="شعارات", is_active=True)

    client_user = User.objects.create_user(phone="0500000105")
    provider_user = User.objects.create_user(phone="0500000106")

    ProviderProfile.objects.create(
        user=provider_user,
        provider_type="individual",
        display_name="مزود",
        bio="bio",
        city="الرياض",
        years_experience=0,
    )

    sr = ServiceRequest.objects.create(
        client=client_user,
        subcategory=sub,
        title="طلب",
        description="وصف",
        request_type="competitive",
        status=RequestStatus.SENT,
        city="الرياض",
    )

    acts = allowed_actions(provider_user, sr)
    assert "accept" in acts
