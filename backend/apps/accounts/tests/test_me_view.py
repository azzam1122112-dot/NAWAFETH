import pytest
from rest_framework.test import APIClient

from apps.accounts.models import OTP, User


def _login_via_otp(client: APIClient, phone: str) -> str:
    send = client.post("/api/accounts/otp/send/", {"phone": phone}, format="json")
    assert send.status_code == 200
    payload = send.json()
    code = payload.get("dev_code") or OTP.objects.filter(phone=phone).order_by("-id").values_list("code", flat=True).first()
    assert code

    verify = client.post("/api/accounts/otp/verify/", {"phone": phone, "code": code}, format="json")
    assert verify.status_code == 200
    return verify.json()["access"]


def _complete_registration(client: APIClient, phone: str, username: str) -> None:
    res = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "Test",
            "last_name": "User",
            "username": username,
            "email": f"{phone}@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert res.status_code == 200


@pytest.mark.django_db
def test_me_view_blocks_username_change_after_registration():
    client = APIClient()
    phone = "0500000811"
    access = _login_via_otp(client, phone)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    _complete_registration(client, phone, "fixed_username")

    change = client.patch("/api/accounts/me/", {"username": "new_username"}, format="json")
    assert change.status_code == 400
    body = change.json()
    assert "username" in body

    user = User.objects.get(phone=phone)
    assert user.username == "fixed_username"


@pytest.mark.django_db
def test_me_view_allows_other_fields_update_while_username_locked():
    client = APIClient()
    phone = "0500000812"
    access = _login_via_otp(client, phone)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    _complete_registration(client, phone, "fixed_username_2")

    res = client.patch(
        "/api/accounts/me/",
        {
            "first_name": "Updated",
            "last_name": "Name",
            "email": "updated@example.com",
        },
        format="json",
    )
    assert res.status_code == 200
    payload = res.json()
    assert payload["first_name"] == "Updated"
    assert payload["last_name"] == "Name"
    assert payload["email"] == "updated@example.com"

    user = User.objects.get(phone=phone)
    assert user.username == "fixed_username_2"
