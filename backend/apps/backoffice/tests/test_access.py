import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.backoffice.models import UserAccessProfile, Dashboard, AccessLevel


pytestmark = pytest.mark.django_db


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def dashboards():
    items = [
        ("support", "الدعم والمساعدة", 10),
        ("content", "إدارة المحتوى", 20),
    ]
    for code, name_ar, order in items:
        Dashboard.objects.get_or_create(code=code, defaults={"name_ar": name_ar, "sort_order": order})
    return Dashboard.objects.all()


@pytest.fixture
def user():
    return User.objects.create_user(phone="0500000000", password="Pass12345!")


@pytest.fixture
def access_profile(user, dashboards):
    ap = UserAccessProfile.objects.create(user=user, level=AccessLevel.USER)
    ap.allowed_dashboards.set(list(dashboards))
    return ap


def test_requires_auth(api_client):
    r = api_client.get("/api/backoffice/me/access/")
    assert r.status_code in (401, 403)


def test_my_access_ok(api_client, user, access_profile):
    api_client.force_authenticate(user=user)
    r = api_client.get("/api/backoffice/me/access/")
    assert r.status_code == 200
    assert r.data["level"] == "user"
    assert len(r.data["dashboards"]) >= 1


def test_qa_readonly_denies_write(api_client, user, dashboards):
    ap = UserAccessProfile.objects.create(user=user, level=AccessLevel.QA)
    ap.allowed_dashboards.set(list(dashboards))

    api_client.force_authenticate(user=user)

    # هذا endpoint read-only لكنه كفحص: لو صار عندنا endpoint write مستقبلاً
    # نستخدم نفس Permission ويمنع أي POST/PATCH/DELETE
    r = api_client.post("/api/backoffice/me/access/", data={})
    assert r.status_code in (403, 405)
