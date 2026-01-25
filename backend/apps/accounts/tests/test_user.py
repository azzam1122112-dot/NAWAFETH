import pytest

from apps.accounts.models import User


@pytest.mark.django_db
def test_create_user():
    u = User.objects.create_user(phone="0501111111")
    assert u.phone == "0501111111"
    assert u.is_active is True
