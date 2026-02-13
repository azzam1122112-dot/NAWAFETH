import pytest
from datetime import timedelta
from rest_framework.test import APIClient

from django.utils import timezone

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
from apps.promo.models import PromoRequest
from apps.subscriptions.models import SubscriptionPlan, Subscription, SubscriptionStatus


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(phone="0566666666", password="Pass12345!")


@pytest.fixture
def admin_user():
    u = User.objects.create_user(phone="0577777777", password="Pass12345!")
    UserAccessProfile.objects.create(user=u, level="admin")
    return u


def test_create_promo_request(api, user):
    plan = SubscriptionPlan.objects.create(code="PRO", title="Pro", features=["promo_ads"])
    Subscription.objects.create(
        user=user,
        plan=plan,
        status=SubscriptionStatus.ACTIVE,
        start_at=timezone.now(),
        end_at=timezone.now(),
    )

    start_at = timezone.now() + timedelta(days=1)
    end_at = timezone.now() + timedelta(days=5)
    api.force_authenticate(user=user)
    r = api.post("/api/promo/requests/create/", data={
        "title": "test",
        "ad_type": "banner_home",
        "start_at": start_at.isoformat(),
        "end_at": end_at.isoformat(),
        "frequency": "60s",
        "position": "normal",
        "target_city": "Riyadh",
        "redirect_url": "",
    }, format="json")
    assert r.status_code == 201
    assert r.data["code"].startswith("MD")


def test_backoffice_list(api, admin_user, user):
    PromoRequest.objects.create(
        requester=user,
        title="x",
        ad_type="banner_home",
        start_at="2026-02-01T10:00:00Z",
        end_at="2026-02-05T10:00:00Z",
        frequency="60s",
        position="normal",
    )
    api.force_authenticate(user=admin_user)
    r = api.get("/api/promo/backoffice/requests/")
    assert r.status_code == 200
    assert len(r.data) >= 1


def test_backoffice_list_forbidden_without_access_profile(api, user):
    PromoRequest.objects.create(
        requester=user,
        title="x",
        ad_type="banner_home",
        start_at="2026-02-01T10:00:00Z",
        end_at="2026-02-05T10:00:00Z",
        frequency="60s",
        position="normal",
    )
    api.force_authenticate(user=user)
    r = api.get("/api/promo/backoffice/requests/")
    assert r.status_code == 403
