import pytest
from django.contrib.auth import get_user_model

from apps.marketplace.models import RequestStatus, RequestType, ServiceRequest
from apps.marketplace.services.actions import execute_action

pytestmark = pytest.mark.django_db


def make_request(client, subcategory):
    return ServiceRequest.objects.create(
        client=client,
        subcategory=subcategory,
        title="Test",
        description="Desc",
        request_type=RequestType.COMPETITIVE,
        status=RequestStatus.NEW,
        city="Riyadh",
        is_urgent=False,
    )


def test_client_can_send_and_cancel(client_user, subcategory):
    sr = make_request(client_user, subcategory)

    execute_action(user=client_user, request_id=sr.id, action="send", provider_profile=None)
    sr.refresh_from_db()
    assert sr.status == RequestStatus.SENT

    execute_action(user=client_user, request_id=sr.id, action="cancel", provider_profile=None)
    sr.refresh_from_db()
    assert sr.status == RequestStatus.CANCELLED


def test_provider_can_accept_when_sent(provider_user, provider_profile, subcategory):
    client = get_user_model().objects.create_user(phone="0500000001", password="pass")
    sr = make_request(client, subcategory)

    # client sends
    execute_action(user=client, request_id=sr.id, action="send", provider_profile=None)
    sr.refresh_from_db()
    assert sr.status == RequestStatus.SENT

    # provider accepts
    execute_action(user=provider_user, request_id=sr.id, action="accept", provider_profile=provider_profile)
    sr.refresh_from_db()
    assert sr.status == RequestStatus.ACCEPTED
    assert sr.provider_id == provider_profile.id
