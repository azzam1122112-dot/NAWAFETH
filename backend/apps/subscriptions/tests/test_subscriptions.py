import pytest
from rest_framework.test import APIClient
from decimal import Decimal

from apps.accounts.models import User
from apps.subscriptions.models import SubscriptionPlan, PlanPeriod


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(phone="0588888888", password="Pass12345!")


def test_plans_list(api, user):
    SubscriptionPlan.objects.create(code="BASIC", title="Basic", period=PlanPeriod.MONTH, price=Decimal("10.00"), features=["verify_green"])
    api.force_authenticate(user=user)
    r = api.get("/api/subscriptions/plans/")
    assert r.status_code == 200
    assert len(r.data) >= 1


def test_subscribe(api, user):
    plan = SubscriptionPlan.objects.create(code="PRO", title="Pro", period=PlanPeriod.MONTH, price=Decimal("25.00"), features=["verify_blue"])
    api.force_authenticate(user=user)
    r = api.post(f"/api/subscriptions/subscribe/{plan.pk}/")
    assert r.status_code == 201
    assert r.data["invoice"] is not None
