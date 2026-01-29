from django.conf import settings
from django.utils import timezone
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

    # Basic cooldown to prevent spam (professional default)
    cooldown_seconds = int(getattr(settings, "OTP_COOLDOWN_SECONDS", 60))
    last = OTP.objects.filter(phone=phone).order_by("-id").first()
    if last and (timezone.now() - last.created_at).total_seconds() < cooldown_seconds:
        return Response(
            {"detail": "يرجى الانتظار قبل إعادة إرسال الرمز"},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    # توليد كود جديد
    # ملاحظة: لا نستخدم كود ثابت (مثل 1234). في التطوير يمكن تفعيل قبول أي 4 أرقام عبر OTP_DEV_ACCEPT_ANY_CODE.
    code = generate_otp_code()
    OTP.objects.create(
        phone=phone,
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

    # ✅ في التطوير فقط نُرجع الكود لتسهيل الاختبار
    # في الإنتاج: اربط بمزود SMS ولا تُرجع الرمز.
    payload = {"ok": True}
    if bool(getattr(settings, "DEBUG", False)):
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

        user, created = User.objects.get_or_create(
            phone=phone,
            defaults={"role_state": UserRole.PHONE_ONLY},
        )

        if not user.is_active:
            return Response({"detail": "الحساب غير نشط"}, status=status.HTTP_400_BAD_REQUEST)

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "ok": True,
                "user_id": user.id,
                "role_state": user.role_state,
                "is_new_user": bool(created),
                "needs_completion": user.role_state in (UserRole.VISITOR, UserRole.PHONE_ONLY),
                "refresh": str(refresh),
                "access": str(refresh.access_token),
            },
            status=status.HTTP_200_OK,
        )

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

    # إنشاء المستخدم لو غير موجود
    user, created = User.objects.get_or_create(
        phone=phone,
        defaults={"role_state": UserRole.PHONE_ONLY},
    )

    if not user.is_active:
        return Response({"detail": "الحساب غير نشط"}, status=status.HTTP_400_BAD_REQUEST)

    refresh = RefreshToken.for_user(user)

    # Audit (اختياري)
    try:
        from apps.audit.services import log_action
        from apps.audit.models import AuditAction

        log_action(
            actor=user,
            action=AuditAction.LOGIN_OTP_VERIFIED,
            reference_type="user",
            reference_id=str(user.id),
            request=request,
        )
    except Exception:
        pass

    return Response(
        {
            "ok": True,
            "user_id": user.id,
            "role_state": user.role_state,
            "is_new_user": bool(created),
            # Frontend can use this to decide whether to show a completion step (level 3)
            "needs_completion": user.role_state in (UserRole.VISITOR, UserRole.PHONE_ONLY),
            "refresh": str(refresh),
            "access": str(refresh.access_token),
        },
        status=status.HTTP_200_OK,
    )


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
