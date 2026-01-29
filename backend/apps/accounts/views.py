from django.conf import settings
from django.utils import timezone
from django.utils.timezone import timedelta
import logging
import secrets
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .models import OTP, User, UserRole, Wallet
from .serializers import (
    CompleteRegistrationSerializer,
    OTPSendSerializer,
    OTPVerifySerializer,
    WalletSerializer,
)

from .permissions import IsAtLeastPhoneOnly
from .otp import generate_otp_code, otp_expiry

logger = logging.getLogger(__name__)


def _client_ip(request) -> str | None:
    xff = (request.META.get("HTTP_X_FORWARDED_FOR") or "").strip()
    if xff:
        # First IP is the original client
        return xff.split(",")[0].strip() or None
    return (request.META.get("REMOTE_ADDR") or "").strip() or None


def _otp_test_authorized(request) -> bool:
    test_mode = bool(getattr(settings, "OTP_TEST_MODE", False))
    if not test_mode:
        return False

    test_key = (getattr(settings, "OTP_TEST_KEY", "") or "").strip()
    if not test_key:
        return False

    test_header = (
        getattr(settings, "OTP_TEST_HEADER", "X-OTP-TEST-KEY")
        or "X-OTP-TEST-KEY"
    ).strip()
    provided = (request.headers.get(test_header) or "").strip()
    return bool(provided) and secrets.compare_digest(provided, test_key)


def _issue_tokens_for_phone(phone: str):
    user, created = User.objects.get_or_create(
        phone=phone,
        defaults={"role_state": UserRole.PHONE_ONLY},
    )

    if not user.is_active:
        return None, created

    refresh = RefreshToken.for_user(user)
    payload = {
        "ok": True,
        "user_id": user.id,
        "role_state": user.role_state,
        "is_new_user": bool(created),
        "needs_completion": user.role_state in (UserRole.VISITOR, UserRole.PHONE_ONLY),
        "refresh": str(refresh),
        "access": str(refresh.access_token),
    }
    return payload, created


class ThrottledTokenObtainPairView(TokenObtainPairView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"


class ThrottledTokenRefreshView(TokenRefreshView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "refresh"

@api_view(["GET", "DELETE"])
@permission_classes([IsAuthenticated])
def me_view(request):
    user = request.user

    if request.method == "DELETE":
        user.delete()
        return Response({"ok": True}, status=status.HTTP_200_OK)

    return Response(
        {
            "id": user.id,
            "phone": user.phone,
            "email": user.email,
            "username": user.username,
            "first_name": getattr(user, "first_name", None),
            "last_name": getattr(user, "last_name", None),
            "role_state": user.role_state,
        }
    )


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([ScopedRateThrottle])
def otp_send(request):
    s = OTPSendSerializer(data=request.data)
    s.is_valid(raise_exception=True)

    phone = s.validated_data["phone"].strip()
    client_ip = _client_ip(request)

    # Basic cooldown to prevent spam (professional default)
    cooldown_seconds = int(getattr(settings, "OTP_COOLDOWN_SECONDS", 60))
    last = OTP.objects.filter(phone=phone).order_by("-id").first()
    if last and (timezone.now() - last.created_at).total_seconds() < cooldown_seconds:
        return Response(
            {"detail": "يرجى الانتظار قبل إعادة إرسال الرمز"},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    # Per-phone hourly limit
    phone_hourly_limit = int(getattr(settings, "OTP_PHONE_HOURLY_LIMIT", 0) or 0)
    if phone_hourly_limit > 0:
        since = timezone.now() - timedelta(hours=1)
        cnt = OTP.objects.filter(phone=phone, created_at__gte=since).count()
        if cnt >= phone_hourly_limit:
            return Response(
                {"detail": "تم تجاوز حد إرسال الرموز لهذا الرقم مؤقتًا"},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

    # Per-phone daily limit
    phone_daily_limit = int(getattr(settings, "OTP_PHONE_DAILY_LIMIT", 0) or 0)
    if phone_daily_limit > 0:
        today_start = timezone.localtime().replace(hour=0, minute=0, second=0, microsecond=0)
        cnt = OTP.objects.filter(phone=phone, created_at__gte=today_start).count()
        if cnt >= phone_daily_limit:
            return Response(
                {"detail": "تم تجاوز الحد اليومي لإرسال الرموز لهذا الرقم"},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

    # Per-IP hourly limit (best-effort)
    ip_hourly_limit = int(getattr(settings, "OTP_IP_HOURLY_LIMIT", 0) or 0)
    if ip_hourly_limit > 0 and client_ip:
        since = timezone.now() - timedelta(hours=1)
        cnt = OTP.objects.filter(ip_address=client_ip, created_at__gte=since).count()
        if cnt >= ip_hourly_limit:
            return Response(
                {"detail": "تم تجاوز حد إرسال الرموز من هذا الجهاز/الشبكة مؤقتًا"},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

    # Generate a new code.
    # For staging QA only, you can force a fixed OTP via OTP_TEST_CODE (e.g. 0000)
    # but only when OTP_TEST_MODE is enabled and the secret header matches.
    test_code = (getattr(settings, "OTP_TEST_CODE", "") or "").strip()
    if test_code and _otp_test_authorized(request):
        code = test_code
    else:
        code = generate_otp_code()
    OTP.objects.create(
        phone=phone,
        ip_address=client_ip,
        code=code,
        expires_at=otp_expiry(5),
    )

    # Audit (اختياري)
    try:
        from apps.audit.services import log_action
        from apps.audit.models import AuditAction

        actor = User.objects.filter(phone=phone).first()
        log_action(
            actor=actor,
            action=AuditAction.LOGIN_OTP_SENT,
            reference_type="phone",
            reference_id=phone,
            request=request,
        )
    except Exception:
        pass

    # ✅ Dev/Test helpers
    # - DEBUG: return dev_code for local development only.
    # - OTP_TEST_MODE: staging-only helper guarded by a secret header.
    payload = {"ok": True}
    if bool(getattr(settings, "DEBUG", False)):
        payload["dev_code"] = code
    elif _otp_test_authorized(request):
        payload["dev_code"] = code
    return Response(payload, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([ScopedRateThrottle])
def otp_verify(request):
    s = OTPVerifySerializer(data=request.data)
    s.is_valid(raise_exception=True)

    phone = s.validated_data["phone"].strip()
    code = s.validated_data["code"].strip()
    client_ip = _client_ip(request)

    # Staging-only fixed code bypass (QA): accept OTP_TEST_CODE when authorized.
    test_code = (getattr(settings, "OTP_TEST_CODE", "") or "").strip()
    if test_code and code == test_code and _otp_test_authorized(request):
        # Validate format only
        if not (len(code) == 4 and code.isdigit()):
            return Response({"detail": "الكود يجب أن يكون 4 أرقام"}, status=status.HTTP_400_BAD_REQUEST)

        payload, created = _issue_tokens_for_phone(phone)
        if payload is None:
            return Response({"detail": "الحساب غير نشط"}, status=status.HTTP_400_BAD_REQUEST)

        # Best-effort cleanup: mark last OTP as used.
        otp = OTP.objects.filter(phone=phone, is_used=False).order_by("-id").first()
        if otp:
            otp.is_used = True
            otp.save(update_fields=["is_used"])

        return Response(payload, status=status.HTTP_200_OK)

    # Staging-only app QA bypass (no headers): accept ANY 4-digit code.
    # - Must be explicitly enabled via OTP_APP_BYPASS=1
    # - If allowlist is provided, only allow those phone numbers
    # - Requires an existing OTP record to keep send limits/cooldowns meaningful
    app_bypass = bool(getattr(settings, "OTP_APP_BYPASS", False))
    bypass_allowlist = list(getattr(settings, "OTP_APP_BYPASS_ALLOWLIST", []) or [])
    bypass_allowed_for_phone = (not bypass_allowlist) or (phone in bypass_allowlist)

    if app_bypass and bypass_allowed_for_phone:
        if not (len(code) == 4 and code.isdigit()):
            return Response({"detail": "الكود يجب أن يكون 4 أرقام"}, status=status.HTTP_400_BAD_REQUEST)

        otp = OTP.objects.filter(phone=phone, is_used=False).order_by("-id").first()
        if not otp or otp.expires_at < timezone.now():
            return Response(
                {"detail": "أعد طلب رمز جديد"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp.is_used = True
        otp.save(update_fields=["is_used"])

        logger.warning("OTP_APP_BYPASS used phone=%s ip=%s", phone, client_ip)

        payload, created = _issue_tokens_for_phone(phone)
        if payload is None:
            return Response({"detail": "الحساب غير نشط"}, status=status.HTTP_400_BAD_REQUEST)

        return Response(payload, status=status.HTTP_200_OK)

    # FORCE BYPASS if configured (Resolves user frustration with Development/Testing)
    # Check settings directly, default to False.
    dev_accept_any = getattr(settings, "OTP_DEV_ACCEPT_ANY_CODE", False)
    
    # Also considering DEBUG just to be consistent, but prioritized dev_accept_any
    # User request: Accept ANY random numbers without verification (bypassing strict check)
    if dev_accept_any or settings.DEBUG:
        # Validate format only
        if not (len(code) == 4 and code.isdigit()):
             return Response({"detail": "الكود يجب أن يكون 4 أرقام"}, status=status.HTTP_400_BAD_REQUEST)

        # Skip DB check, mark LAST OTP as used if exists (for cleanup)
        otp = OTP.objects.filter(phone=phone, is_used=False).order_by("-id").first()
        if otp:
            otp.is_used = True
            otp.save(update_fields=["is_used"])

        payload, created = _issue_tokens_for_phone(phone)
        if payload is None:
            return Response({"detail": "الحساب غير نشط"}, status=status.HTTP_400_BAD_REQUEST)

        return Response(payload, status=status.HTTP_200_OK)

    # Normal Production Logic

    otp = OTP.objects.filter(phone=phone, is_used=False).order_by("-id").first()
    if not otp:
        return Response({"detail": "الكود غير صحيح"}, status=status.HTTP_400_BAD_REQUEST)

    if otp.expires_at < timezone.now():
        return Response({"detail": "انتهت صلاحية الكود"}, status=status.HTTP_400_BAD_REQUEST)

    # Limit brute-force attempts
    max_attempts = int(getattr(settings, "OTP_MAX_ATTEMPTS", 5))
    if otp.attempts >= max_attempts:
        otp.is_used = True
        otp.save(update_fields=["is_used"])
        return Response(
            {"detail": "تم تجاوز عدد المحاولات، أعد طلب رمز جديد"},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    if otp.code != code:
        otp.attempts += 1
        if otp.attempts >= max_attempts:
            otp.is_used = True
            otp.save(update_fields=["attempts", "is_used"])
            return Response(
                {"detail": "تم تجاوز عدد المحاولات، أعد طلب رمز جديد"},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        otp.save(update_fields=["attempts"])
        return Response({"detail": "الكود غير صحيح"}, status=status.HTTP_400_BAD_REQUEST)

    otp.is_used = True
    otp.save(update_fields=["is_used"])

    payload, created = _issue_tokens_for_phone(phone)
    if payload is None:
        return Response({"detail": "الحساب غير نشط"}, status=status.HTTP_400_BAD_REQUEST)

    # Audit (اختياري)
    try:
        from apps.audit.services import log_action
        from apps.audit.models import AuditAction

        log_action(
            actor=User.objects.filter(phone=phone).first(),
            action=AuditAction.LOGIN_OTP_VERIFIED,
            reference_type="user",
            reference_id=str(payload.get("user_id")),
            request=request,
        )
    except Exception:
        pass

    payload["is_new_user"] = bool(created)
    return Response(payload, status=status.HTTP_200_OK)


# Needed for ScopedRateThrottle on function-based views
otp_send.throttle_scope = "otp"
otp_verify.throttle_scope = "otp"


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def complete_registration(request):
    """Upgrade PHONE_ONLY user to CLIENT (level 3) after collecting required data."""
    s = CompleteRegistrationSerializer(data=request.data)
    s.is_valid(raise_exception=True)

    user: User = request.user

    # Staff is already privileged; allow update but don't downgrade.
    if not getattr(user, "is_staff", False):
        # Only phone-only/visitor can be completed; already completed is idempotent.
        if user.role_state not in (UserRole.PHONE_ONLY, UserRole.VISITOR, UserRole.CLIENT, UserRole.PROVIDER):
            return Response({"detail": "حالة الحساب غير معروفة"}, status=status.HTTP_400_BAD_REQUEST)

    user.username = s.validated_data["username"]
    user.first_name = s.validated_data["first_name"]
    user.last_name = s.validated_data["last_name"]
    user.email = s.validated_data["email"]
    user.set_password(s.validated_data["password"])
    user.terms_accepted_at = timezone.now()

    # Upgrade to CLIENT if not already CLIENT/PROVIDER
    if user.role_state in (UserRole.VISITOR, UserRole.PHONE_ONLY):
        user.role_state = UserRole.CLIENT

    user.save(
        update_fields=[
            "username",
            "first_name",
            "last_name",
            "email",
            "password",
            "terms_accepted_at",
            "role_state",
        ]
    )
    return Response({"ok": True, "role_state": user.role_state}, status=status.HTTP_200_OK)


@api_view(["GET", "POST"])
@permission_classes([IsAtLeastPhoneOnly])
def wallet_view(request):
    """Open wallet (level 2+) and retrieve wallet info."""
    user: User = request.user
    wallet, _ = Wallet.objects.get_or_create(user=user)
    data = WalletSerializer(wallet).data
    return Response(data, status=status.HTTP_200_OK)
