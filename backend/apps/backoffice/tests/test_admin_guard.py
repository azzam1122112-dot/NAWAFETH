import pytest
from django.contrib.admin.sites import AdminSite
from django.core.exceptions import PermissionDenied
from django.test import RequestFactory

from apps.accounts.models import User
from apps.backoffice.admin import UserAccessProfileAdmin
from apps.backoffice.models import UserAccessProfile, AccessLevel


pytestmark = pytest.mark.django_db


def _request_with_superuser():
    rf = RequestFactory()
    req = rf.post("/admin/backoffice/useraccessprofile/")
    req.user = User.objects.create_superuser(
        phone="0599999999",
        password="Pass12345!",
    )
    return req


def test_admin_guard_prevents_demoting_last_active_admin():
    request = _request_with_superuser()
    target_user = User.objects.create_user(phone="0501111111", password="Pass12345!", is_staff=True)
    ap = UserAccessProfile.objects.create(user=target_user, level=AccessLevel.ADMIN)

    admin_obj = UserAccessProfileAdmin(UserAccessProfile, AdminSite())
    ap.level = AccessLevel.USER
    with pytest.raises(PermissionDenied):
        admin_obj.save_model(request, ap, form=None, change=True)

    ap.refresh_from_db()
    assert ap.level == AccessLevel.ADMIN


def test_admin_guard_prevents_deleting_last_active_admin():
    request = _request_with_superuser()
    target_user = User.objects.create_user(phone="0502222222", password="Pass12345!", is_staff=True)
    ap = UserAccessProfile.objects.create(user=target_user, level=AccessLevel.ADMIN)

    admin_obj = UserAccessProfileAdmin(UserAccessProfile, AdminSite())
    with pytest.raises(PermissionDenied):
        admin_obj.delete_model(request, ap)

    assert UserAccessProfile.objects.filter(id=ap.id).exists()


def test_admin_guard_allows_demotion_when_another_active_admin_exists():
    request = _request_with_superuser()
    u1 = User.objects.create_user(phone="0503333333", password="Pass12345!", is_staff=True)
    u2 = User.objects.create_user(phone="0504444444", password="Pass12345!", is_staff=True)
    ap1 = UserAccessProfile.objects.create(user=u1, level=AccessLevel.ADMIN)
    UserAccessProfile.objects.create(user=u2, level=AccessLevel.ADMIN)

    admin_obj = UserAccessProfileAdmin(UserAccessProfile, AdminSite())
    ap1.level = AccessLevel.USER
    admin_obj.save_model(request, ap1, form=None, change=True)

    ap1.refresh_from_db()
    assert ap1.level == AccessLevel.USER
