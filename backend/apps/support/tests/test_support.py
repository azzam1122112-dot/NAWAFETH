import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
from apps.backoffice.models import Dashboard
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
def support_dashboard():
    Dashboard.objects.get_or_create(code="support", defaults={"name_ar": "الدعم", "sort_order": 10})
    return Dashboard.objects.get(code="support")


@pytest.fixture
def support_operator_user(support_dashboard):
    u = User.objects.create_user(phone="0533333333", password="Pass12345!")
    u.is_staff = True
    u.save(update_fields=["is_staff"])
    ap = UserAccessProfile.objects.create(user=u, level="user")
    ap.allowed_dashboards.add(support_dashboard)
    return u


@pytest.fixture
def other_staff_user():
    u = User.objects.create_user(phone="0533333334", password="Pass12345!")
    u.is_staff = True
    u.save(update_fields=["is_staff"])
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


def test_backoffice_list_forbidden_without_access_profile(api, client_user):
    SupportTicket.objects.create(requester=client_user, ticket_type="tech", description="test")
    api.force_authenticate(user=client_user)
    r = api.get("/api/support/backoffice/tickets/")
    assert r.status_code == 403


def test_user_operator_cannot_assign_to_other(api, support_operator_user, other_staff_user, client_user):
    t = SupportTicket.objects.create(requester=client_user, ticket_type="tech", description="test")
    api.force_authenticate(user=support_operator_user)
    r = api.patch(f"/api/support/backoffice/tickets/{t.id}/assign/", data={"assigned_to": other_staff_user.id}, format="json")
    assert r.status_code == 403

    r2 = api.patch(f"/api/support/backoffice/tickets/{t.id}/assign/", data={"assigned_to": support_operator_user.id}, format="json")
    assert r2.status_code == 200
