from __future__ import annotations

from datetime import datetime
import logging
from django.contrib import messages
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.paginator import Paginator
from django.db.models import Count, Q
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, render
from django.shortcuts import redirect
from django.utils.timezone import make_aware
from django.views.decorators.http import require_POST

from apps.marketplace.models import ServiceRequest
from apps.marketplace.services.actions import allowed_actions, execute_action
from apps.providers.models import ProviderProfile, ProviderService
from .forms import AcceptAssignProviderForm

# إن كانت عندك Enums استوردها (عدّل حسب مشروعك)
try:
    from apps.marketplace.models import RequestStatus, RequestType
except Exception:
    RequestStatus = None
    RequestType = None


logger = logging.getLogger(__name__)


def _bool_param(v: str | None) -> bool | None:
    if v is None:
        return None
    v = v.strip().lower()
    if v in {"1", "true", "yes", "y", "on"}:
        return True
    if v in {"0", "false", "no", "n", "off"}:
        return False
    return None


def _parse_date_yyyy_mm_dd(value: str | None):
    """Parse 'YYYY-MM-DD' to aware datetime at 00:00. Returns None if invalid."""
    if not value:
        return None
    try:
        dt = datetime.strptime(value.strip(), "%Y-%m-%d")
        return make_aware(dt)
    except Exception:
        return None


def _status_value(name: str, fallback: str) -> str:
    """يحاول جلب قيمة الحالة من RequestStatus إن وجد، وإلا يستخدم fallback."""
    if RequestStatus:
        return getattr(RequestStatus, name, fallback)
    return fallback


def _type_value(name: str, fallback: str) -> str:
    if RequestType:
        return getattr(RequestType, name, fallback)
    return fallback


def _compute_actions(user, obj) -> dict:
    user_id = getattr(user, "id", None)
    status = (obj.status or "").lower()

    has_profile = False
    if status == "sent" and user_id:
        is_staff = bool(getattr(user, "is_staff", False))
        is_client = obj.client_id == user_id
        if not is_staff and not is_client:
            has_profile = ProviderProfile.objects.filter(user_id=user_id).exists()

    acts = allowed_actions(user, obj, has_provider_profile=has_profile)

    return {
        "can_accept": "accept" in acts,
        "can_start": "start" in acts,
        "can_complete": "complete" in acts,
        "can_cancel": "cancel" in acts,
        "can_send": "send" in acts,
    }


@staff_member_required
def dashboard_home(request):
    qs = ServiceRequest.objects.all()

    # KPIs عامة
    total = qs.count()
    by_status = qs.values("status").annotate(c=Count("id")).order_by("-c")
    by_type = qs.values("request_type").annotate(c=Count("id")).order_by("-c")

    # آخر 10 طلبات
    latest = (
        qs.select_related("client", "provider")
        .order_by("-id")[:10]
    )

    ctx = {
        "total_requests": total,
        "by_status": list(by_status),
        "by_type": list(by_type),
        "latest_requests": latest,
    }
    return render(request, "dashboard/home.html", ctx)


@staff_member_required
def requests_list(request):
    qs = (
        ServiceRequest.objects
        .select_related("client", "provider")
        .all()
        .order_by("-id")
    )

    # -------- Filters --------
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    type_val = (request.GET.get("type") or "").strip()
    city = (request.GET.get("city") or "").strip()
    date_from = _parse_date_yyyy_mm_dd(request.GET.get("from"))
    date_to = _parse_date_yyyy_mm_dd(request.GET.get("to"))

    if q:
        # بحث آمن على العنوان/الوصف/جوال العميل (إن وجد)
        qs = qs.filter(
            Q(title__icontains=q) |
            Q(description__icontains=q) |
            Q(client__phone__icontains=q)
        )

    if status_val:
        qs = qs.filter(status=status_val)

    if type_val:
        qs = qs.filter(request_type=type_val)

    if city:
        qs = qs.filter(city__icontains=city)

    if date_from:
        qs = qs.filter(created_at__gte=date_from)

    if date_to:
        # نهاية اليوم: نجعلها شاملة بإضافة 1 يوم عمليًا عبر <= (to + 1 day) عادة،
        # لكن لتجنب تعقيد، نستخدم <= 23:59:59 تقريبًا عبر +86400 ثانية. سنبقيها بسيطة.
        qs = qs.filter(created_at__lte=date_to)

    # -------- Pagination --------
    page_size = 20
    paginator = Paginator(qs, page_size)
    page_number = request.GET.get("page") or "1"
    page_obj = paginator.get_page(page_number)

    # خيارات فلاتر (لو عندك Enums استخدمها، وإلا اعرض الموجود)
    if RequestStatus:
        status_choices = getattr(RequestStatus, "choices", None) or []
    else:
        status_choices = []

    if RequestType:
        type_choices = getattr(RequestType, "choices", None) or []
    else:
        type_choices = []

    ctx = {
        "page_obj": page_obj,
        "q": q,
        "status_val": status_val,
        "type_val": type_val,
        "city": city,
        "from": request.GET.get("from") or "",
        "to": request.GET.get("to") or "",
        "status_choices": status_choices,
        "type_choices": type_choices,
    }
    return render(request, "dashboard/requests_list.html", ctx)


@staff_member_required
def providers_list(request: HttpRequest) -> HttpResponse:
    qs = (
        ProviderProfile.objects
        .select_related("user")
        .all()
        .order_by("-id")
    )

    q = (request.GET.get("q") or "").strip()
    city = (request.GET.get("city") or "").strip()
    verified = _bool_param(request.GET.get("verified"))
    accepts_urgent = _bool_param(request.GET.get("urgent"))

    if q:
        qs = qs.filter(
            Q(display_name__icontains=q)
            | Q(user__phone__icontains=q)
            | Q(bio__icontains=q)
        )

    if city:
        qs = qs.filter(city__icontains=city)

    if verified is not None:
        if verified:
            qs = qs.filter(Q(is_verified_blue=True) | Q(is_verified_green=True))
        else:
            qs = qs.filter(is_verified_blue=False, is_verified_green=False)

    if accepts_urgent is not None:
        qs = qs.filter(accepts_urgent=accepts_urgent)

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")

    ctx = {
        "page_obj": page_obj,
        "q": q,
        "city": city,
        "verified": request.GET.get("verified") or "",
        "urgent": request.GET.get("urgent") or "",
    }
    return render(request, "dashboard/providers_list.html", ctx)


@staff_member_required
def provider_detail(request: HttpRequest, provider_id: int) -> HttpResponse:
    provider = get_object_or_404(
        ProviderProfile.objects.select_related("user"),
        id=provider_id,
    )

    services = (
        ProviderService.objects
        .select_related("subcategory", "subcategory__category")
        .filter(provider_id=provider_id)
        .order_by("-updated_at")
    )

    ctx = {
        "provider": provider,
        "services": list(services),
    }
    return render(request, "dashboard/provider_detail.html", ctx)


@staff_member_required
@require_POST
def provider_service_toggle_active(request: HttpRequest, provider_id: int, service_id: int) -> HttpResponse:
    service = get_object_or_404(
        ProviderService,
        id=service_id,
        provider_id=provider_id,
    )
    service.is_active = not bool(service.is_active)
    service.save(update_fields=["is_active", "updated_at"])
    messages.success(request, "تم تحديث حالة الخدمة بنجاح")
    return redirect("dashboard:provider_detail", provider_id=provider_id)


@staff_member_required
def services_list(request: HttpRequest) -> HttpResponse:
    qs = (
        ProviderService.objects
        .select_related("provider", "provider__user", "subcategory", "subcategory__category")
        .all()
        .order_by("-updated_at")
    )

    q = (request.GET.get("q") or "").strip()
    active = _bool_param(request.GET.get("active"))
    city = (request.GET.get("city") or "").strip()

    if q:
        qs = qs.filter(
            Q(title__icontains=q)
            | Q(description__icontains=q)
            | Q(provider__display_name__icontains=q)
            | Q(provider__user__phone__icontains=q)
        )

    if active is not None:
        qs = qs.filter(is_active=active)

    if city:
        qs = qs.filter(provider__city__icontains=city)

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")

    ctx = {
        "page_obj": page_obj,
        "q": q,
        "active": request.GET.get("active") or "",
        "city": city,
    }
    return render(request, "dashboard/services_list.html", ctx)


@staff_member_required
def request_detail(request, request_id: int):
    qs = ServiceRequest.objects
    try:
        qs = qs.select_related("client", "provider", "subcategory")
    except Exception:
        qs = qs.select_related("client", "provider")

    obj = (
        qs.filter(id=request_id)
        .first()
    )
    if not obj:
        obj = get_object_or_404(ServiceRequest, id=request_id)

    # ---- محاولات تحميل بيانات مرتبطة (حسب توفر موديلاتك) ----
    offers = []
    thread = None
    messages_page = None
    notifications_page = None
    review = None

    # Offers (إن كان تطبيق marketplace يحتوي Offer)
    try:
        from apps.marketplace.models import Offer

        offers = (
            Offer.objects
            .select_related("provider")
            .filter(request=obj)
            .order_by("-id")
        )
    except Exception:
        offers = []

    # Messaging Thread + Messages
    try:
        from apps.messaging.models import Thread, Message

        thread = Thread.objects.filter(request=obj).first()
        if thread:
            # نعرض آخر 30 رسالة فقط (سهل وسريع للويب)
            messages_page = (
                Message.objects
                .select_related("sender")
                .filter(thread=thread)
                .order_by("-id")[:30]
            )
    except Exception:
        thread = None
        messages_page = None

    # Notifications مرتبطة بالطلب (لو عندك ربط content_object أو request FK)
    try:
        from apps.notifications.models import Notification

        # إن كان عندك request FK:
        has_request_fk = False
        try:
            has_request_fk = any(f.name == "request" for f in Notification._meta.fields)
        except Exception:
            has_request_fk = hasattr(Notification, "request")

        if has_request_fk:
            notifications_page = (
                Notification.objects
                .filter(request=obj)
                .order_by("-id")[:30]
            )
        else:
            # fallback: نحاول نبحث نصيًا عن رقم الطلب في الرسالة (اختياري)
            notifications_page = (
                Notification.objects
                .filter(Q(title__icontains=str(obj.id)) | Q(message__icontains=str(obj.id)))
                .order_by("-id")[:30]
            )
    except Exception:
        notifications_page = None

    # Review (إن كان عندك Review OneToOne مع الطلب)
    try:
        from apps.reviews.models import Review

        review = Review.objects.filter(request=obj).first()
    except Exception:
        review = None

    tab = (request.GET.get("tab") or "details").strip()
    allowed_tabs = {"details", "offers", "chat", "notifications", "review"}
    if tab not in allowed_tabs:
        tab = "details"

    ctx = {
        "obj": obj,
        "tab": tab,
        "offers": offers,
        "thread": thread,
        "messages": messages_page,
        "notifications": notifications_page,
        "review": review,
    }
    providers = None
    if request.user.is_staff:
        providers = ProviderProfile.objects.select_related("user").order_by("id")

    ctx.update({
        "providers": providers,
    })
    ctx["actions"] = _compute_actions(request.user, obj)
    return render(request, "dashboard/request_detail.html", ctx)


@login_required
@require_POST
def request_accept(request: HttpRequest, request_id: int) -> HttpResponse:
    sr = get_object_or_404(ServiceRequest, id=request_id)
    try:
        user = request.user
        is_staff = bool(getattr(user, "is_staff", False))

        provider_profile = None

        if is_staff:
            # staff must choose provider from form
            form = AcceptAssignProviderForm(request.POST)
            if not form.is_valid():
                messages.warning(request, "اختر مزودًا لقبول الطلب")
                return redirect("dashboard:request_detail", request_id=sr.id)

            provider_profile = form.cleaned_data["provider"]
        else:
            # provider accepts using his own profile
            provider_profile = ProviderProfile.objects.filter(user=user).first()

        result = execute_action(
            user=user,
            request_id=sr.id,
            action="accept",
            provider_profile=provider_profile,
        )
        messages.success(request, result.message)
    except PermissionDenied:
        messages.error(request, "غير مصرح بتنفيذ هذا الإجراء")
    except ValidationError as e:
        msg = getattr(e, "message", None)
        if not msg and getattr(e, "messages", None):
            msg = e.messages[0]
        messages.warning(request, msg or "لا يمكن تنفيذ الإجراء")
    except Exception:
        logger.exception("dashboard request_accept error")
        messages.error(request, "حدث خطأ غير متوقع")
    return redirect("dashboard:request_detail", request_id=sr.id)


@login_required
@require_POST
def request_start(request: HttpRequest, request_id: int) -> HttpResponse:
    sr = get_object_or_404(ServiceRequest, id=request_id)
    try:
        provider_profile = ProviderProfile.objects.filter(user=request.user).first()
        result = execute_action(
            user=request.user,
            request_id=sr.id,
            action="start",
            provider_profile=provider_profile,
        )
        messages.success(request, result.message)
    except PermissionDenied:
        messages.error(request, "غير مصرح بتنفيذ هذا الإجراء")
    except ValidationError as e:
        msg = getattr(e, "message", None)
        if not msg and getattr(e, "messages", None):
            msg = e.messages[0]
        messages.warning(request, msg or "لا يمكن تنفيذ الإجراء")
    except Exception:
        logger.exception("dashboard request_start error")
        messages.error(request, "حدث خطأ غير متوقع")
    return redirect("dashboard:request_detail", request_id=sr.id)


@login_required
@require_POST
def request_complete(request: HttpRequest, request_id: int) -> HttpResponse:
    sr = get_object_or_404(ServiceRequest, id=request_id)
    try:
        provider_profile = ProviderProfile.objects.filter(user=request.user).first()
        result = execute_action(
            user=request.user,
            request_id=sr.id,
            action="complete",
            provider_profile=provider_profile,
        )
        messages.success(request, result.message)
    except PermissionDenied:
        messages.error(request, "غير مصرح بتنفيذ هذا الإجراء")
    except ValidationError as e:
        msg = getattr(e, "message", None)
        if not msg and getattr(e, "messages", None):
            msg = e.messages[0]
        messages.warning(request, msg or "لا يمكن تنفيذ الإجراء")
    except Exception:
        logger.exception("dashboard request_complete error")
        messages.error(request, "حدث خطأ غير متوقع")
    return redirect("dashboard:request_detail", request_id=sr.id)


@login_required
@require_POST
def request_cancel(request: HttpRequest, request_id: int) -> HttpResponse:
    sr = get_object_or_404(ServiceRequest, id=request_id)
    try:
        provider_profile = ProviderProfile.objects.filter(user=request.user).first()
        result = execute_action(
            user=request.user,
            request_id=sr.id,
            action="cancel",
            provider_profile=provider_profile,
        )
        messages.success(request, result.message)
    except PermissionDenied:
        messages.error(request, "غير مصرح بتنفيذ هذا الإجراء")
    except ValidationError as e:
        msg = getattr(e, "message", None)
        if not msg and getattr(e, "messages", None):
            msg = e.messages[0]
        messages.warning(request, msg or "لا يمكن تنفيذ الإجراء")
    except Exception:
        logger.exception("dashboard request_cancel error")
        messages.error(request, "حدث خطأ غير متوقع")
    return redirect("dashboard:request_detail", request_id=sr.id)


@login_required
@require_POST
def request_send(request: HttpRequest, request_id: int) -> HttpResponse:
    sr = get_object_or_404(ServiceRequest, id=request_id)
    try:
        provider_profile = ProviderProfile.objects.filter(user=request.user).first()
        result = execute_action(
            user=request.user,
            request_id=sr.id,
            action="send",
            provider_profile=provider_profile,
        )
        messages.success(request, result.message)
    except PermissionDenied:
        messages.error(request, "غير مصرح بتنفيذ هذا الإجراء")
    except ValidationError as e:
        msg = getattr(e, "message", None)
        if not msg and getattr(e, "messages", None):
            msg = e.messages[0]
        messages.warning(request, msg or "لا يمكن تنفيذ الإجراء")
    except Exception:
        logger.exception("dashboard request_send error")
        messages.error(request, "حدث خطأ غير متوقع")
    return redirect("dashboard:request_detail", request_id=sr.id)
