import pytest
from rest_framework.test import APIClient

from apps.accounts.models import User


pytestmark = pytest.mark.django_db


@pytest.fixture
def api():
    return APIClient()


@pytest.fixture
def user():
    return User.objects.create_user(phone="0599999999", password="Pass12345!")


def test_catalog(api, user, settings):
    settings.EXTRA_SKUS = {"uploads_10gb_month": {"title": "10GB", "price": 59}}
    api.force_authenticate(user=user)
    r = api.get("/api/extras/catalog/")
    assert r.status_code == 200
    assert len(r.data) == 1


def test_buy_extra(api, user, settings):
    settings.EXTRA_SKUS = {"uploads_10gb_month": {"title": "10GB", "price": 59}}
    api.force_authenticate(user=user)
    r = api.post("/api/extras/buy/uploads_10gb_month/")
    assert r.status_code == 201
    assert r.data["invoice"] is not None
