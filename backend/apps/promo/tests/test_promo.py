import pytest
from datetime import timedelta
from rest_framework.test import APIClient

from django.utils import timezone

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
from apps.backoffice.models import Dashboard
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


@pytest.fixture
def promo_dashboard():
    Dashboard.objects.get_or_create(code="promo", defaults={"name_ar": "الترويج", "sort_order": 40})
    return Dashboard.objects.get(code="promo")


@pytest.fixture
def promo_operator_user(promo_dashboard):
    u = User.objects.create_user(phone="0588888888", password="Pass12345!")
    u.is_staff = True
    u.save(update_fields=["is_staff"])
    ap = UserAccessProfile.objects.create(user=u, level="user")
    ap.allowed_dashboards.add(promo_dashboard)
    return u


@pytest.fixture
def other_staff_user():
    u = User.objects.create_user(phone="0599999999", password="Pass12345!")
    u.is_staff = True
    u.save(update_fields=["is_staff"])
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


def test_user_operator_cannot_assign_to_other(api, promo_operator_user, other_staff_user, user):
    pr = PromoRequest.objects.create(
        requester=user,
        title="x",
        ad_type="banner_home",
        start_at="2026-02-01T10:00:00Z",
        end_at="2026-02-05T10:00:00Z",
        frequency="60s",
        position="normal",
    )

    api.force_authenticate(user=promo_operator_user)

    r = api.patch(f"/api/promo/backoffice/requests/{pr.id}/assign/", data={"assigned_to": other_staff_user.id}, format="json")
    assert r.status_code == 403

    r2 = api.patch(f"/api/promo/backoffice/requests/{pr.id}/assign/", data={"assigned_to": promo_operator_user.id}, format="json")
    assert r2.status_code == 200
    assert r2.data.get("assigned_to") in (promo_operator_user.id, None)
