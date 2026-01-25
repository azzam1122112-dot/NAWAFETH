import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
from apps.support.models import SupportTeam, SupportTicket


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def client_user():
    return User.objects.create_user(phone="0511111111", password="Pass12345!")


@pytest.fixture
def staff_user():
    u = User.objects.create_user(phone="0522222222", password="Pass12345!")
    UserAccessProfile.objects.create(user=u, level="admin")
    return u


@pytest.fixture
def teams():
    SupportTeam.objects.get_or_create(code="tech", defaults={"name_ar": "الدعم الفني", "sort_order": 10})
    return SupportTeam.objects.all()


def test_create_ticket(api, client_user):
    api.force_authenticate(user=client_user)
    r = api.post("/api/support/tickets/create/", data={
        "ticket_type": "tech",
        "description": "مشكلة في الدخول",
        "priority": "normal",
    }, format="json")
    assert r.status_code == 201
    assert r.data["code"].startswith("HD")


def test_backoffice_list(api, staff_user, client_user):
    SupportTicket.objects.create(requester=client_user, ticket_type="tech", description="test")
    api.force_authenticate(user=staff_user)
    r = api.get("/api/support/backoffice/tickets/")
    assert r.status_code == 200
    assert len(r.data) >= 1
