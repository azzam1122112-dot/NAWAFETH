import os
import random
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")

import django

django.setup()

from django.conf import settings

allowed_hosts = list(getattr(settings, "ALLOWED_HOSTS", []) or [])
for host in ("testserver", "127.0.0.1", "localhost"):
    if host not in allowed_hosts:
        allowed_hosts.append(host)
settings.ALLOWED_HOSTS = allowed_hosts

from rest_framework.test import APIClient


def main() -> None:
    client = APIClient()
    phone = f"050{random.randint(1000000, 9999999)}"

    send = client.post("/api/accounts/otp/send/", {"phone": phone}, format="json")
    print("OTP send:", send.status_code, send.json())
    code = send.json().get("dev_code")

    verify = client.post(
        "/api/accounts/otp/verify/",
        {"phone": phone, "code": code},
        format="json",
    )
    print("OTP verify:", verify.status_code, verify.json())

    access = verify.json().get("access")
    if not access:
        raise SystemExit("No access token returned")

    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    # Complete registration (level 3) before registering provider
    complete = client.post(
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
    print("Complete registration:", complete.status_code, complete.json())

    prov_payload = {
        "provider_type": "individual",
        "display_name": "Test Provider",
        "bio": "Test bio",
        "years_experience": 1,
        "city": "Riyadh",
        "accepts_urgent": True,
    }
    prov = client.post("/api/providers/register/", prov_payload, format="json")
    print("Provider register:", prov.status_code, prov.json())

    avail = client.get("/api/marketplace/provider/urgent/available/")
    if avail.status_code == 200:
        print("Available urgent:", avail.status_code, "count=", len(avail.json()))
    else:
        print("Available urgent:", avail.status_code, avail.json())

    mine = client.get("/api/marketplace/provider/requests/")
    if mine.status_code == 200:
        print("My provider requests:", mine.status_code, "count=", len(mine.json()))
    else:
        print("My provider requests:", mine.status_code, mine.json())


if __name__ == "__main__":
    main()
