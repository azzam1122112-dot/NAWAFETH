import pytest
from rest_framework.test import APIClient
from decimal import Decimal

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile
from apps.billing.models import Invoice


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def admin_user():
    u = User.objects.create_user(phone="0511111111", password="Pass12345!")
    UserAccessProfile.objects.create(user=u, level="admin")
    return u


def test_kpis(api, admin_user):
    Invoice.objects.create(user=admin_user, title="x", subtotal=Decimal("10.00"), total=Decimal("11.50"), status="paid")
    api.force_authenticate(user=admin_user)
    r = api.get("/api/analytics/kpis/")
    assert r.status_code == 200
    assert "revenue_total" in r.data
