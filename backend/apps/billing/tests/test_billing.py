import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.billing.models import Invoice


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(phone="0533333333", password="Pass12345!")


def test_create_invoice(api, user):
    api.force_authenticate(user=user)
    r = api.post("/api/billing/invoices/", data={
        "title": "Test",
        "subtotal": "100.00",
        "reference_type": "x",
        "reference_id": "1",
    }, format="json")
    assert r.status_code == 201
    assert r.data["code"].startswith("IV")


def test_init_payment(api, user):
    api.force_authenticate(user=user)
    inv = Invoice.objects.create(user=user, title="T", subtotal="50.00", reference_type="x", reference_id="1")
    r = api.post(f"/api/billing/invoices/{inv.pk}/init-payment/", data={"provider": "mock"}, format="json")
    assert r.status_code == 200
    assert "checkout_url" in r.data
