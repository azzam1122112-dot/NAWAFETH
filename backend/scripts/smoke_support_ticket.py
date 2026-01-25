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
from rest_framework.test import APIClient


def main() -> None:
    client = APIClient()

    # Ensure common dev hosts are allowed (Django test client uses "testserver")
    allowed_hosts = list(getattr(settings, "ALLOWED_HOSTS", []) or [])
    for host in ("testserver", "127.0.0.1", "localhost"):
        if host not in allowed_hosts:
            allowed_hosts.append(host)
    settings.ALLOWED_HOSTS = allowed_hosts

    phone = f"050{random.randint(1000000, 9999999)}"

    send = client.post("/api/accounts/otp/send/", {"phone": phone}, format="json")
    print("OTP send:", send.status_code, send.json())
    if send.status_code != 200:
        raise SystemExit("OTP send failed")

    dev_code = send.json().get("dev_code")
    if not dev_code:
        raise SystemExit("No dev_code returned (is this dev environment?)")

    verify = client.post("/api/accounts/otp/verify/", {"phone": phone, "code": dev_code}, format="json")
    print("OTP verify:", verify.status_code, verify.json())
    if verify.status_code != 200:
        raise SystemExit("OTP verify failed")

    access = verify.json().get("access")
    if not access:
        raise SystemExit("No access token returned")

    client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")

    payload = {
        "ticket_type": "tech",
        "description": "عندي مشكلة في رفع المرفقات",
        "priority": "high",
    }

    create = client.post("/api/support/tickets/create/", payload, format="json")
    try:
        body = create.json()
    except Exception:
        body = create.content.decode("utf-8", errors="replace")

    print("Ticket create:", create.status_code, body)
    if create.status_code not in (200, 201):
        raise SystemExit("Ticket create failed")

    ticket_id = body.get("id") if isinstance(body, dict) else None

    mine = client.get("/api/support/tickets/my/")
    print("My tickets:", mine.status_code, mine.json() if mine.status_code == 200 else mine.content)

    if ticket_id:
        detail = client.get(f"/api/support/tickets/{ticket_id}/")
        print("Ticket detail:", detail.status_code, detail.json() if detail.status_code == 200 else detail.content)


if __name__ == "__main__":
    main()
