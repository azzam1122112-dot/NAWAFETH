import datetime

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import OTP
from apps.providers.models import ProviderPortfolioItem, ProviderProfile


def _login_via_otp(client: APIClient, phone: str) -> str:
    send = client.post("/api/accounts/otp/send/", {"phone": phone}, format="json")
    assert send.status_code == 200

    payload = send.json()
    code = payload.get("dev_code") or OTP.objects.filter(phone=phone).order_by("-id").values_list("code", flat=True).first()
    assert code

    verify = client.post("/api/accounts/otp/verify/", {"phone": phone, "code": code}, format="json")
    assert verify.status_code == 200
    return verify.json()["access"]


def _complete_registration(client: APIClient, access: str, phone: str) -> None:
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
    res = client.post(
        "/api/accounts/complete/",
        {
            "first_name": "Test",
            "last_name": "User",
            "username": f"user_{phone}",
            "email": f"{phone}@example.com",
            "password": "StrongPass123!",
            "password_confirm": "StrongPass123!",
            "accept_terms": True,
        },
        format="json",
    )
    assert res.status_code == 200


def _register_provider(client: APIClient) -> ProviderProfile:
    res = client.post(
        "/api/providers/register/",
        {
            "provider_type": "individual",
            "display_name": "مزود تجريبي",
            "bio": "bio",
            "years_experience": 1,
            "city": "Riyadh",
            "accepts_urgent": True,
        },
        format="json",
    )
    assert res.status_code in (201, 400)
    return ProviderProfile.objects.get(user__phone=res.wsgi_request.user.phone)


@pytest.mark.django_db
def test_client_favorites_returns_liked_portfolio_media(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path

    # Provider creates a portfolio item
    provider_api = APIClient()
    provider_phone = "0500000701"
    provider_access = _login_via_otp(provider_api, provider_phone)
    _complete_registration(provider_api, provider_access, provider_phone)
    provider_profile = _register_provider(provider_api)

    png_bytes = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        b"\x00\x00\x00\x0cIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfeA\x89\x1e\x1b\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    upload = SimpleUploadedFile("tiny.png", png_bytes, content_type="image/png")

    create = provider_api.post(
        "/api/providers/me/portfolio/",
        {
            "file_type": "image",
            "caption": "لقطة",
            "file": upload,
        },
        format="multipart",
    )
    assert create.status_code == 201
    item_id = create.json()["id"]

    # Client likes it -> appears in favorites
    client_api = APIClient()
    client_phone = "0500000702"
    client_access = _login_via_otp(client_api, client_phone)
    _complete_registration(client_api, client_access, client_phone)

    like = client_api.post(f"/api/providers/portfolio/{item_id}/like/")
    assert like.status_code == 200

    favorites = client_api.get("/api/providers/me/favorites/")
    assert favorites.status_code == 200

    payload = favorites.json()
    assert isinstance(payload, list)
    assert any(x["id"] == item_id for x in payload)

    item = next(x for x in payload if x["id"] == item_id)
    assert item["file_type"] == "image"
    assert item["provider_id"] == provider_profile.id
    assert item["file_url"]


@pytest.mark.django_db
def test_following_is_ordered_by_latest_activity(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path

    client_api = APIClient()
    client_phone = "0500000710"
    client_access = _login_via_otp(client_api, client_phone)
    _complete_registration(client_api, client_access, client_phone)

    # Two providers
    p1_api = APIClient()
    p1_phone = "0500000711"
    p1_access = _login_via_otp(p1_api, p1_phone)
    _complete_registration(p1_api, p1_access, p1_phone)
    p1 = _register_provider(p1_api)

    p2_api = APIClient()
    p2_phone = "0500000712"
    p2_access = _login_via_otp(p2_api, p2_phone)
    _complete_registration(p2_api, p2_access, p2_phone)
    p2 = _register_provider(p2_api)

    # Client follows both via API
    follow1 = client_api.post(f"/api/providers/{p1.id}/follow/")
    assert follow1.status_code == 200
    follow2 = client_api.post(f"/api/providers/{p2.id}/follow/")
    assert follow2.status_code == 200

    # Force timestamps: p2 has newer updated_at, but p1 has a newer portfolio item.
    now = timezone.now()
    dt_p1 = now - datetime.timedelta(days=3)
    dt_p2 = now - datetime.timedelta(days=2)
    dt_item = now - datetime.timedelta(days=1)

    ProviderProfile.objects.filter(id=p1.id).update(updated_at=dt_p1)
    ProviderProfile.objects.filter(id=p2.id).update(updated_at=dt_p2)

    png_bytes = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        b"\x00\x00\x00\x0cIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfeA\x89\x1e\x1b\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    upload = SimpleUploadedFile("tiny2.png", png_bytes, content_type="image/png")
    created = p1_api.post(
        "/api/providers/me/portfolio/",
        {"file_type": "image", "caption": "new", "file": upload},
        format="multipart",
    )
    assert created.status_code == 201
    item_id = created.json()["id"]
    ProviderPortfolioItem.objects.filter(id=item_id).update(created_at=dt_item)

    following = client_api.get("/api/providers/me/following/")
    assert following.status_code == 200
    providers = following.json()
    assert [p["id"] for p in providers][:2] == [p1.id, p2.id]


@pytest.mark.django_db
def test_provider_can_delete_own_portfolio_item(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path

    provider_api = APIClient()
    provider_phone = "0500000721"
    provider_access = _login_via_otp(provider_api, provider_phone)
    _complete_registration(provider_api, provider_access, provider_phone)
    _register_provider(provider_api)

    png_bytes = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        b"\x00\x00\x00\x0cIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfeA\x89\x1e\x1b\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    upload = SimpleUploadedFile("tiny_del.png", png_bytes, content_type="image/png")
    created = provider_api.post(
        "/api/providers/me/portfolio/",
        {"file_type": "image", "caption": "to delete", "file": upload},
        format="multipart",
    )
    assert created.status_code == 201
    item_id = created.json()["id"]

    deleted = provider_api.delete(f"/api/providers/me/portfolio/{item_id}/")
    assert deleted.status_code == 204
    assert not ProviderPortfolioItem.objects.filter(id=item_id).exists()
