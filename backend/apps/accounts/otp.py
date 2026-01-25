import random
from datetime import timedelta
from django.utils import timezone

def generate_otp_code() -> str:
    return f"{random.randint(0, 9999):04d}"

def otp_expiry(minutes: int = 5):
    return timezone.now() + timedelta(minutes=minutes)
