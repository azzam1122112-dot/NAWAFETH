import pytest
from rest_framework.test import APIClient

from django.utils import timezone

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
from apps.backoffice.models import Dashboard
from apps.verification.models import VerificationRequest
from apps.subscriptions.models import SubscriptionPlan, Subscription, SubscriptionStatus


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(phone="0544444444", password="Pass12345!")


@pytest.fixture
def admin_user():
    u = User.objects.create_user(phone="0555555555", password="Pass12345!")
    UserAccessProfile.objects.create(user=u, level="admin")
    return u


@pytest.fixture
def verify_dashboard():
    Dashboard.objects.get_or_create(code="verify", defaults={"name_ar": "التوثيق", "sort_order": 50})
    return Dashboard.objects.get(code="verify")


@pytest.fixture
def verify_operator_user(verify_dashboard):
    u = User.objects.create_user(phone="0580000000", password="Pass12345!")
    u.is_staff = True
    u.save(update_fields=["is_staff"])
    ap = UserAccessProfile.objects.create(user=u, level="user")
    ap.allowed_dashboards.add(verify_dashboard)
    return u


@pytest.fixture
def other_staff_user():
    u = User.objects.create_user(phone="0580000001", password="Pass12345!")
    u.is_staff = True
    u.save(update_fields=["is_staff"])
    return u


def test_create_verification_request(api, user):
    plan = SubscriptionPlan.objects.create(code="PRO", title="Pro", features=["verify_blue"])
    Subscription.objects.create(
        user=user,
        plan=plan,
        status=SubscriptionStatus.ACTIVE,
        start_at=timezone.now(),
        end_at=timezone.now(),
    )

    api.force_authenticate(user=user)
    r = api.post("/api/verification/requests/create/", data={"badge_type": "blue"}, format="json")
    assert r.status_code == 201
    assert r.data["code"].startswith("AD")


def test_backoffice_list(api, admin_user, user):
    VerificationRequest.objects.create(requester=user, badge_type="blue")
    api.force_authenticate(user=admin_user)
    r = api.get("/api/verification/backoffice/requests/")
    assert r.status_code == 200
    assert len(r.data) >= 1


def test_backoffice_list_forbidden_without_access_profile(api, user):
    VerificationRequest.objects.create(requester=user, badge_type="blue")
    api.force_authenticate(user=user)
    r = api.get("/api/verification/backoffice/requests/")
    assert r.status_code == 403


def test_user_operator_cannot_assign_to_other(api, verify_operator_user, other_staff_user, user):
    vr = VerificationRequest.objects.create(requester=user, badge_type="blue")

    api.force_authenticate(user=verify_operator_user)

    r = api.patch(f"/api/verification/backoffice/requests/{vr.id}/assign/", data={"assigned_to": other_staff_user.id}, format="json")
    assert r.status_code == 403

    r2 = api.patch(f"/api/verification/backoffice/requests/{vr.id}/assign/", data={"assigned_to": verify_operator_user.id}, format="json")
    assert r2.status_code == 200
