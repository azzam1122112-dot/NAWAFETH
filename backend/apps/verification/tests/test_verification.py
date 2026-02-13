import pytest
from rest_framework.test import APIClient

from django.utils import timezone

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
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
