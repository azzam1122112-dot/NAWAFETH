from __future__ import annotations

from datetime import datetime, timedelta
import csv
import io
import json
import logging
from functools import wraps
from django.contrib import messages
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required
from django.core.exceptions import PermissionDenied, ValidationError
from django.core.paginator import Paginator
from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, render
from django.shortcuts import redirect
from django.utils.timezone import make_aware
from django.utils import timezone
from django.views.decorators.http import require_POST

from apps.marketplace.models import ServiceRequest
from apps.marketplace.services.actions import allowed_actions, execute_action
from apps.providers.models import ProviderProfile, ProviderService, Category, SubCategory
from apps.accounts.models import User
from apps.support.models import SupportTicket, SupportTicketStatus, SupportTeam
from apps.support.services import change_ticket_status, assign_ticket
from apps.billing.models import Invoice, InvoiceStatus, PaymentAttempt
from apps.verification.models import VerificationRequest, VerificationStatus, VerificationDocument
from apps.verification.services import finalize_request_and_create_invoice, activate_after_payment as activate_verification_after_payment
from apps.subscriptions.models import Subscription, SubscriptionStatus
from apps.subscriptions.services import refresh_subscription_status, activate_subscription_after_payment
from apps.promo.models import PromoRequest, PromoRequestStatus
from apps.promo.services import quote_and_create_invoice, reject_request, activate_after_payment as activate_promo_after_payment
from apps.extras.models import ExtraPurchase, ExtraPurchaseStatus
from apps.extras.services import activate_extra_after_payment
from apps.features.checks import has_feature
from apps.features.upload_limits import user_max_upload_mb
from apps.backoffice.models import UserAccessProfile
from .forms import AcceptAssignProviderForm, CategoryForm, SubCategoryForm

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


def _csv_response(filename: str, headers: list[str], rows: list[list]):
    stream = io.StringIO()
    writer = csv.writer(stream)
    writer.writerow(headers)
    for r in rows:
        writer.writerow(r)
    resp = HttpResponse(stream.getvalue(), content_type="text/csv; charset=utf-8")
    resp["Content-Disposition"] = f'attachment; filename="{filename}"'
    return resp


def _want_csv(request: HttpRequest) -> bool:
    return (request.GET.get("export") or "").strip().lower() == "csv"


def _dashboard_allowed(user, dashboard_code: str, write: bool = False) -> bool:
    if not getattr(user, "is_authenticated", False):
        return False
    if getattr(user, "is_superuser", False):
        return True
    if not getattr(user, "is_staff", False):
        return False

    ap = getattr(user, "access_profile", None)
    if not ap:
        # Backward compatibility: existing staff without profile still can access.
        return True

    if ap.is_revoked() or ap.is_expired():
        return False
    if write and ap.is_readonly():
        return False
    if ap.level in {"admin", "power"}:
        return True
    return ap.is_allowed(dashboard_code)


def dashboard_access_required(dashboard_code: str, write: bool = False):
    def decorator(func):
        @wraps(func)
        def wrapped(request: HttpRequest, *args, **kwargs):
            if not _dashboard_allowed(request.user, dashboard_code, write=write):
                messages.error(request, "لا تملك صلاحية الوصول لهذه اللوحة.")
                return redirect("dashboard:home")
            return func(request, *args, **kwargs)
        return wrapped
    return decorator


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
@dashboard_access_required("analytics")
def dashboard_home(request):
    qs = ServiceRequest.objects.all()

    # KPIs عامة للطلبات
    total = qs.count()
    by_status = qs.values("status").annotate(c=Count("id")).order_by("-c")
    by_type = qs.values("request_type").annotate(c=Count("id")).order_by("-c")
    open_statuses = [
        _status_value("NEW", "new"),
        _status_value("SENT", "sent"),
        _status_value("ACCEPTED", "accepted"),
        _status_value("IN_PROGRESS", "in_progress"),
    ]
    open_requests = qs.filter(status__in=open_statuses).count()
    completed_requests = qs.filter(status=_status_value("COMPLETED", "completed")).count()
    cancelled_requests = qs.filter(status=_status_value("CANCELLED", "cancelled")).count()

    # آخر 10 طلبات
    latest = (
        qs.select_related("client", "provider")
        .order_by("-id")[:12]
    )

    # KPIs المزوّدين
    providers_qs = ProviderProfile.objects.all()
    total_providers = providers_qs.count()
    verified_providers = providers_qs.filter(
        Q(is_verified_blue=True) | Q(is_verified_green=True)
    ).count()
    urgent_providers = providers_qs.filter(accepts_urgent=True).count()

    # KPIs الفوترة (اختياري حسب التطبيقات المثبتة)
    pending_invoices = 0
    paid_invoices = 0
    failed_invoices = 0
    try:
        from apps.billing.models import Invoice, InvoiceStatus

        pending_invoices = Invoice.objects.filter(status=InvoiceStatus.PENDING).count()
        paid_invoices = Invoice.objects.filter(status=InvoiceStatus.PAID).count()
        failed_invoices = Invoice.objects.filter(status=InvoiceStatus.FAILED).count()
    except Exception:
        pass

    # KPIs التذاكر
    support_new = 0
    support_open = 0
    try:
        from apps.support.models import SupportTicket, SupportTicketStatus

        support_new = SupportTicket.objects.filter(status=SupportTicketStatus.NEW).count()
        support_open = SupportTicket.objects.exclude(status=SupportTicketStatus.CLOSED).count()
    except Exception:
        pass

    # KPIs التفعيل/الاشتراكات
    active_subscriptions = 0
    pending_verifications = 0
    active_promos = 0
    active_extras = 0
    try:
        from apps.subscriptions.models import Subscription, SubscriptionStatus

        active_subscriptions = Subscription.objects.filter(
            status=SubscriptionStatus.ACTIVE
        ).count()
    except Exception:
        pass
    try:
        from apps.verification.models import VerificationRequest, VerificationStatus

        pending_verifications = VerificationRequest.objects.filter(
            status__in=[VerificationStatus.NEW, VerificationStatus.IN_REVIEW, VerificationStatus.PENDING_PAYMENT]
        ).count()
    except Exception:
        pass
    try:
        from apps.promo.models import PromoRequest, PromoRequestStatus

        active_promos = PromoRequest.objects.filter(
            status=PromoRequestStatus.ACTIVE
        ).count()
    except Exception:
        pass
    try:
        from apps.extras.models import ExtraPurchase, ExtraPurchaseStatus

        active_extras = ExtraPurchase.objects.filter(
            status=ExtraPurchaseStatus.ACTIVE
        ).count()
    except Exception:
        pass

    status_labels = dict(getattr(RequestStatus, "choices", []) or [])
    type_labels = dict(getattr(RequestType, "choices", []) or [])

    for r in latest:
        r.status_label = status_labels.get(getattr(r, "status", ""), getattr(r, "status", "") or "—")
        r.type_label = type_labels.get(getattr(r, "request_type", ""), getattr(r, "request_type", "") or "—")

    # Trend charts (last 14 days)
    days = 14
    start_date = timezone.now().date() - timedelta(days=days - 1)
    labels = [(start_date + timedelta(days=i)).isoformat() for i in range(days)]

    req_by_day = {
        str(row["day"]): row["c"]
        for row in (
            ServiceRequest.objects.filter(created_at__date__gte=start_date)
            .annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(c=Count("id"))
            .order_by("day")
        )
    }
    inv_by_day = {
        str(row["day"]): row["c"]
        for row in (
            Invoice.objects.filter(created_at__date__gte=start_date)
            .annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(c=Count("id"))
            .order_by("day")
        )
    }
    sup_by_day = {
        str(row["day"]): row["c"]
        for row in (
            SupportTicket.objects.filter(created_at__date__gte=start_date)
            .annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(c=Count("id"))
            .order_by("day")
        )
    }

    request_series = [req_by_day.get(d, 0) for d in labels]
    invoice_series = [inv_by_day.get(d, 0) for d in labels]
    support_series = [sup_by_day.get(d, 0) for d in labels]

    ctx = {
        "total_requests": total,
        "open_requests": open_requests,
        "completed_requests": completed_requests,
        "cancelled_requests": cancelled_requests,
        "by_status": list(by_status),
        "by_type": list(by_type),
        "latest_requests": latest,
        "total_providers": total_providers,
        "verified_providers": verified_providers,
        "urgent_providers": urgent_providers,
        "pending_invoices": pending_invoices,
        "paid_invoices": paid_invoices,
        "failed_invoices": failed_invoices,
        "support_new": support_new,
        "support_open": support_open,
        "active_subscriptions": active_subscriptions,
        "pending_verifications": pending_verifications,
        "active_promos": active_promos,
        "active_extras": active_extras,
        "dashboard_now": timezone.now(),
        "chart_labels_json": json.dumps(labels, ensure_ascii=False),
        "request_series_json": json.dumps(request_series),
        "invoice_series_json": json.dumps(invoice_series),
        "support_series_json": json.dumps(support_series),
    }
    return render(request, "dashboard/home.html", ctx)


@staff_member_required
@dashboard_access_required("content")
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

    if _want_csv(request):
        rows = [
            [
                r.id,
                r.title or "",
                r.request_type,
                r.status,
                r.city or "",
                getattr(getattr(r, "client", None), "phone", ""),
                getattr(getattr(r, "provider", None), "display_name", ""),
                r.created_at.isoformat(),
            ]
            for r in qs[:2000]
        ]
        return _csv_response(
            "requests.csv",
            ["id", "title", "type", "status", "city", "client_phone", "provider", "created_at"],
            rows,
        )

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
@dashboard_access_required("content")
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

    if _want_csv(request):
        rows = [
            [
                p.id,
                p.display_name or "",
                getattr(getattr(p, "user", None), "phone", ""),
                p.city or "",
                bool(p.is_verified_blue or p.is_verified_green),
                bool(p.accepts_urgent),
                p.rating_avg,
                p.rating_count,
            ]
            for p in qs[:2000]
        ]
        return _csv_response(
            "providers.csv",
            ["id", "display_name", "phone", "city", "verified", "accepts_urgent", "rating_avg", "rating_count"],
            rows,
        )

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
@dashboard_access_required("content")
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
@dashboard_access_required("content", write=True)
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
@dashboard_access_required("content")
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

    if _want_csv(request):
        rows = [
            [
                s.id,
                s.title or "",
                getattr(getattr(s, "provider", None), "display_name", ""),
                getattr(getattr(getattr(s, "provider", None), "user", None), "phone", ""),
                getattr(getattr(s, "subcategory", None), "name", ""),
                bool(s.is_active),
                s.updated_at.isoformat() if s.updated_at else "",
            ]
            for s in qs[:2000]
        ]
        return _csv_response(
            "provider_services.csv",
            ["id", "title", "provider", "provider_phone", "subcategory", "is_active", "updated_at"],
            rows,
        )

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
@dashboard_access_required("content")
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
@dashboard_access_required("marketplace", write=True)
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
@dashboard_access_required("marketplace", write=True)
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
@dashboard_access_required("marketplace", write=True)
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
@dashboard_access_required("marketplace", write=True)
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
@dashboard_access_required("marketplace", write=True)
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


# =============================================================================
# Categories & Subcategories Management
# =============================================================================

@staff_member_required
@dashboard_access_required("content")
def categories_list(request: HttpRequest) -> HttpResponse:
    """عرض قائمة التصنيفات الرئيسية مع التصنيفات الفرعية"""
    q = request.GET.get("q", "").strip()
    active = request.GET.get("active", "").strip()

    categories = Category.objects.all()

    # البحث
    if q:
        categories = categories.filter(name__icontains=q)

    # فلتر الحالة
    if active:
        is_active = _bool_param(active)
        if is_active is not None:
            categories = categories.filter(is_active=is_active)

    # عدد التصنيفات الفرعية
    categories = categories.annotate(subcategories_count=Count("subcategories"))

    # الترتيب
    categories = categories.order_by("-is_active", "name")

    if _want_csv(request):
        rows = [
            [c.id, c.name, bool(c.is_active), c.subcategories_count]
            for c in categories[:2000]
        ]
        return _csv_response(
            "categories.csv",
            ["id", "name", "is_active", "subcategories_count"],
            rows,
        )

    # Pagination
    paginator = Paginator(categories, 25)
    page_number = request.GET.get("page", 1)
    page_obj = paginator.get_page(page_number)

    return render(
        request,
        "dashboard/categories_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "active": active,
        },
    )


@staff_member_required
@dashboard_access_required("content")
def category_detail(request: HttpRequest, category_id: int) -> HttpResponse:
    """عرض تفاصيل تصنيف رئيسي مع جميع التصنيفات الفرعية"""
    category = get_object_or_404(Category, id=category_id)
    subcategories = category.subcategories.all().order_by("-is_active", "name")

    return render(
        request,
        "dashboard/category_detail.html",
        {
            "category": category,
            "subcategories": subcategories,
        },
    )


@staff_member_required
@dashboard_access_required("content", write=True)
@require_POST
def category_toggle_active(request: HttpRequest, category_id: int) -> HttpResponse:
    """تفعيل/إيقاف تصنيف رئيسي"""
    category = get_object_or_404(Category, id=category_id)
    category.is_active = not category.is_active
    category.save()
    
    status = "مفعّل" if category.is_active else "موقوف"
    messages.success(request, f"تم تحديث حالة التصنيف إلى: {status}")
    
    return redirect("dashboard:category_detail", category_id=category.id)


@staff_member_required
@dashboard_access_required("content", write=True)
@require_POST
def subcategory_toggle_active(
    request: HttpRequest, category_id: int, subcategory_id: int
) -> HttpResponse:
    """تفعيل/إيقاف تصنيف فرعي"""
    category = get_object_or_404(Category, id=category_id)
    subcategory = get_object_or_404(SubCategory, id=subcategory_id, category=category)
    
    subcategory.is_active = not subcategory.is_active
    subcategory.save()
    
    status = "مفعّل" if subcategory.is_active else "موقوف"
    messages.success(request, f"تم تحديث حالة التصنيف الفرعي إلى: {status}")
    
    return redirect("dashboard:category_detail", category_id=category.id)


@staff_member_required
@dashboard_access_required("content", write=True)
def category_create(request: HttpRequest) -> HttpResponse:
    """إضافة تصنيف رئيسي جديد"""
    if request.method == "POST":
        form = CategoryForm(request.POST)
        if form.is_valid():
            category = form.save()
            messages.success(request, f"تم إضافة التصنيف '{category.name}' بنجاح")
            return redirect("dashboard:category_detail", category_id=category.id)
    else:
        form = CategoryForm()
    
    return render(
        request,
        "dashboard/category_form.html",
        {
            "form": form,
            "title": "إضافة تصنيف رئيسي",
            "is_edit": False,
        },
    )


@staff_member_required
@dashboard_access_required("content", write=True)
def category_edit(request: HttpRequest, category_id: int) -> HttpResponse:
    """تعديل تصنيف رئيسي"""
    category = get_object_or_404(Category, id=category_id)
    
    if request.method == "POST":
        form = CategoryForm(request.POST, instance=category)
        if form.is_valid():
            category = form.save()
            messages.success(request, f"تم تحديث التصنيف '{category.name}' بنجاح")
            return redirect("dashboard:category_detail", category_id=category.id)
    else:
        form = CategoryForm(instance=category)
    
    return render(
        request,
        "dashboard/category_form.html",
        {
            "form": form,
            "category": category,
            "title": "تعديل التصنيف",
            "is_edit": True,
        },
    )


@staff_member_required
@dashboard_access_required("content", write=True)
def subcategory_create(request: HttpRequest) -> HttpResponse:
    """إضافة تصنيف فرعي جديد"""
    category_id = request.GET.get("category")
    
    if request.method == "POST":
        form = SubCategoryForm(request.POST)
        if form.is_valid():
            subcategory = form.save()
            messages.success(request, f"تم إضافة التصنيف الفرعي '{subcategory.name}' بنجاح")
            return redirect("dashboard:category_detail", category_id=subcategory.category.id)
    else:
        initial = {}
        if category_id:
            try:
                initial['category'] = int(category_id)
            except ValueError:
                pass
        form = SubCategoryForm(initial=initial)
    
    return render(
        request,
        "dashboard/subcategory_form.html",
        {
            "form": form,
            "title": "إضافة تصنيف فرعي",
            "is_edit": False,
        },
    )


@staff_member_required
@dashboard_access_required("content", write=True)
def subcategory_edit(request: HttpRequest, subcategory_id: int) -> HttpResponse:
    """تعديل تصنيف فرعي"""
    subcategory = get_object_or_404(SubCategory, id=subcategory_id)
    
    if request.method == "POST":
        form = SubCategoryForm(request.POST, instance=subcategory)
        if form.is_valid():
            subcategory = form.save()
            messages.success(request, f"تم تحديث التصنيف الفرعي '{subcategory.name}' بنجاح")
            return redirect("dashboard:category_detail", category_id=subcategory.category.id)
    else:
        form = SubCategoryForm(instance=subcategory)
    
    return render(
        request,
        "dashboard/subcategory_form.html",
        {
            "form": form,
            "subcategory": subcategory,
            "title": "تعديل التصنيف الفرعي",
            "is_edit": True,
        },
    )


# =============================================================================
# Operations / Full Platform Management
# =============================================================================

@staff_member_required
@dashboard_access_required("billing")
def billing_invoices_list(request: HttpRequest) -> HttpResponse:
    qs = Invoice.objects.select_related("user").all().order_by("-id")
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    ref_type = (request.GET.get("ref_type") or "").strip()
    if q:
        qs = qs.filter(Q(code__icontains=q) | Q(user__phone__icontains=q) | Q(title__icontains=q))
    if status_val:
        qs = qs.filter(status=status_val)
    if ref_type:
        qs = qs.filter(reference_type__icontains=ref_type)

    if _want_csv(request):
        rows = [
            [
                inv.id,
                inv.code or "",
                getattr(getattr(inv, "user", None), "phone", ""),
                inv.title or "",
                inv.total,
                inv.currency,
                inv.status,
                inv.reference_type or "",
                inv.reference_id or "",
                inv.created_at.isoformat(),
            ]
            for inv in qs[:2000]
        ]
        return _csv_response(
            "billing_invoices.csv",
            ["id", "code", "user_phone", "title", "total", "currency", "status", "reference_type", "reference_id", "created_at"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/billing_invoices_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "status_val": status_val,
            "ref_type": ref_type,
            "status_choices": InvoiceStatus.choices,
        },
    )


@staff_member_required
@dashboard_access_required("support")
def support_tickets_list(request: HttpRequest) -> HttpResponse:
    qs = (
        SupportTicket.objects.select_related("requester", "assigned_team", "assigned_to")
        .all()
        .order_by("-id")
    )
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    type_val = (request.GET.get("type") or "").strip()
    priority_val = (request.GET.get("priority") or "").strip()
    if q:
        qs = qs.filter(Q(code__icontains=q) | Q(requester__phone__icontains=q) | Q(description__icontains=q))
    if status_val:
        qs = qs.filter(status=status_val)
    if type_val:
        qs = qs.filter(ticket_type=type_val)
    if priority_val:
        qs = qs.filter(priority=priority_val)

    if _want_csv(request):
        rows = [
            [
                t.id,
                t.code or "",
                getattr(getattr(t, "requester", None), "phone", ""),
                t.ticket_type,
                t.priority,
                t.status,
                getattr(getattr(t, "assigned_team", None), "name_ar", ""),
                getattr(getattr(t, "assigned_to", None), "phone", ""),
                t.created_at.isoformat(),
            ]
            for t in qs[:2000]
        ]
        return _csv_response(
            "support_tickets.csv",
            ["id", "code", "requester_phone", "type", "priority", "status", "assigned_team", "assigned_to", "created_at"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/support_tickets_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "status_val": status_val,
            "type_val": type_val,
            "priority_val": priority_val,
            "status_choices": SupportTicketStatus.choices,
            "type_choices": SupportTicket._meta.get_field("ticket_type").choices,
            "priority_choices": SupportTicket._meta.get_field("priority").choices,
        },
    )


@staff_member_required
@dashboard_access_required("support")
def support_ticket_detail(request: HttpRequest, ticket_id: int) -> HttpResponse:
    ticket = get_object_or_404(
        SupportTicket.objects.select_related("requester", "assigned_team", "assigned_to", "last_action_by"),
        id=ticket_id,
    )
    comments = ticket.comments.select_related("created_by").order_by("-id")
    logs = ticket.status_logs.select_related("changed_by").order_by("-id")
    teams = SupportTeam.objects.filter(is_active=True).order_by("sort_order", "id")
    staff_users = User.objects.filter(is_staff=True).order_by("-id")[:150]
    return render(
        request,
        "dashboard/support_ticket_detail.html",
        {
            "ticket": ticket,
            "comments": comments,
            "logs": logs,
            "teams": teams,
            "staff_users": staff_users,
            "status_choices": SupportTicketStatus.choices,
        },
    )


@staff_member_required
@dashboard_access_required("support", write=True)
@require_POST
def support_ticket_assign_action(request: HttpRequest, ticket_id: int) -> HttpResponse:
    ticket = get_object_or_404(SupportTicket, id=ticket_id)
    team_id = request.POST.get("assigned_team") or None
    assigned_to = request.POST.get("assigned_to") or None
    note = (request.POST.get("note") or "").strip()
    try:
        team_id = int(team_id) if team_id else None
    except Exception:
        team_id = None
    try:
        assigned_to = int(assigned_to) if assigned_to else None
    except Exception:
        assigned_to = None
    try:
        assign_ticket(
            ticket=ticket,
            team_id=team_id,
            user_id=assigned_to,
            by_user=request.user,
            note=note,
        )
        messages.success(request, "تم تحديث التعيين بنجاح")
    except Exception:
        logger.exception("support_ticket_assign_action error")
        messages.error(request, "تعذر تحديث التعيين")
    return redirect("dashboard:support_ticket_detail", ticket_id=ticket.id)


@staff_member_required
@dashboard_access_required("support", write=True)
@require_POST
def support_ticket_status_action(request: HttpRequest, ticket_id: int) -> HttpResponse:
    ticket = get_object_or_404(SupportTicket, id=ticket_id)
    status_new = (request.POST.get("status") or "").strip()
    note = (request.POST.get("note") or "").strip()
    if not status_new:
        messages.warning(request, "اختر حالة التذكرة")
        return redirect("dashboard:support_ticket_detail", ticket_id=ticket.id)
    try:
        change_ticket_status(ticket=ticket, new_status=status_new, by_user=request.user, note=note)
        messages.success(request, "تم تحديث حالة التذكرة")
    except Exception:
        logger.exception("support_ticket_status_action error")
        messages.error(request, "تعذر تحديث الحالة")
    return redirect("dashboard:support_ticket_detail", ticket_id=ticket.id)


@staff_member_required
@dashboard_access_required("verify")
def verification_requests_list(request: HttpRequest) -> HttpResponse:
    qs = VerificationRequest.objects.select_related("requester", "invoice").all().order_by("-id")
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    if q:
        qs = qs.filter(Q(code__icontains=q) | Q(requester__phone__icontains=q))
    if status_val:
        qs = qs.filter(status=status_val)

    if _want_csv(request):
        rows = [
            [
                vr.id,
                vr.code or "",
                getattr(getattr(vr, "requester", None), "phone", ""),
                vr.badge_type,
                vr.status,
                getattr(getattr(vr, "invoice", None), "code", ""),
                vr.requested_at.isoformat(),
            ]
            for vr in qs[:2000]
        ]
        return _csv_response(
            "verification_requests.csv",
            ["id", "code", "requester_phone", "badge_type", "status", "invoice_code", "requested_at"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/verification_requests_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "status_val": status_val,
            "status_choices": VerificationStatus.choices,
        },
    )


@staff_member_required
@dashboard_access_required("verify")
def verification_request_detail(request: HttpRequest, verification_id: int) -> HttpResponse:
    vr = get_object_or_404(
        VerificationRequest.objects.select_related("requester", "invoice"),
        id=verification_id,
    )
    docs = VerificationDocument.objects.filter(request=vr).select_related("decided_by").order_by("-id")
    return render(
        request,
        "dashboard/verification_request_detail.html",
        {"vr": vr, "docs": docs},
    )


@staff_member_required
@dashboard_access_required("verify", write=True)
@require_POST
def verification_finalize_action(request: HttpRequest, verification_id: int) -> HttpResponse:
    vr = get_object_or_404(VerificationRequest, id=verification_id)
    try:
        vr = finalize_request_and_create_invoice(vr=vr, by_user=request.user)
        messages.success(request, f"تمت معالجة الطلب: {vr.get_status_display()}")
    except Exception as e:
        messages.error(request, str(e) or "تعذر إنهاء طلب التوثيق")
    return redirect("dashboard:verification_request_detail", verification_id=verification_id)


@staff_member_required
@dashboard_access_required("verify", write=True)
@require_POST
def verification_activate_action(request: HttpRequest, verification_id: int) -> HttpResponse:
    vr = get_object_or_404(VerificationRequest, id=verification_id)
    try:
        activate_verification_after_payment(vr=vr)
        messages.success(request, "تم تفعيل التوثيق بنجاح")
    except Exception as e:
        messages.error(request, str(e) or "تعذر تفعيل طلب التوثيق")
    return redirect("dashboard:verification_request_detail", verification_id=verification_id)


@staff_member_required
@dashboard_access_required("promo")
def promo_requests_list(request: HttpRequest) -> HttpResponse:
    qs = PromoRequest.objects.select_related("requester", "invoice").all().order_by("-id")
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    ad_type = (request.GET.get("ad_type") or "").strip()
    if q:
        qs = qs.filter(Q(code__icontains=q) | Q(title__icontains=q) | Q(requester__phone__icontains=q))
    if status_val:
        qs = qs.filter(status=status_val)
    if ad_type:
        qs = qs.filter(ad_type=ad_type)

    if _want_csv(request):
        rows = [
            [
                pr.id,
                pr.code or "",
                getattr(getattr(pr, "requester", None), "phone", ""),
                pr.title or "",
                pr.ad_type,
                pr.status,
                pr.subtotal,
                getattr(getattr(pr, "invoice", None), "code", ""),
                pr.created_at.isoformat(),
            ]
            for pr in qs[:2000]
        ]
        return _csv_response(
            "promo_requests.csv",
            ["id", "code", "requester_phone", "title", "ad_type", "status", "subtotal", "invoice_code", "created_at"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/promo_requests_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "status_val": status_val,
            "ad_type": ad_type,
            "status_choices": PromoRequestStatus.choices,
            "ad_type_choices": PromoRequest._meta.get_field("ad_type").choices,
        },
    )


@staff_member_required
@dashboard_access_required("promo")
def promo_request_detail(request: HttpRequest, promo_id: int) -> HttpResponse:
    pr = get_object_or_404(
        PromoRequest.objects.select_related("requester", "invoice"),
        id=promo_id,
    )
    assets = pr.assets.all().order_by("-id")
    return render(
        request,
        "dashboard/promo_request_detail.html",
        {"pr": pr, "assets": assets},
    )


@staff_member_required
@dashboard_access_required("promo", write=True)
@require_POST
def promo_quote_action(request: HttpRequest, promo_id: int) -> HttpResponse:
    pr = get_object_or_404(PromoRequest, id=promo_id)
    note = (request.POST.get("quote_note") or "").strip()
    try:
        quote_and_create_invoice(pr=pr, by_user=request.user, quote_note=note)
        messages.success(request, "تم التسعير وإنشاء الفاتورة")
    except Exception as e:
        messages.error(request, str(e) or "تعذر تسعير الطلب")
    return redirect("dashboard:promo_request_detail", promo_id=promo_id)


@staff_member_required
@dashboard_access_required("promo", write=True)
@require_POST
def promo_reject_action(request: HttpRequest, promo_id: int) -> HttpResponse:
    pr = get_object_or_404(PromoRequest, id=promo_id)
    reason = (request.POST.get("reject_reason") or "").strip()
    if not reason:
        messages.warning(request, "سبب الرفض مطلوب")
        return redirect("dashboard:promo_request_detail", promo_id=promo_id)
    try:
        reject_request(pr=pr, reason=reason, by_user=request.user)
        messages.success(request, "تم رفض الطلب")
    except Exception as e:
        messages.error(request, str(e) or "تعذر رفض الطلب")
    return redirect("dashboard:promo_request_detail", promo_id=promo_id)


@staff_member_required
@dashboard_access_required("promo", write=True)
@require_POST
def promo_activate_action(request: HttpRequest, promo_id: int) -> HttpResponse:
    pr = get_object_or_404(PromoRequest, id=promo_id)
    try:
        activate_promo_after_payment(pr=pr)
        messages.success(request, "تم تفعيل الحملة")
    except Exception as e:
        messages.error(request, str(e) or "تعذر تفعيل الحملة")
    return redirect("dashboard:promo_request_detail", promo_id=promo_id)


@staff_member_required
@dashboard_access_required("subs")
def subscriptions_list(request: HttpRequest) -> HttpResponse:
    qs = Subscription.objects.select_related("user", "plan", "invoice").all().order_by("-id")
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    if q:
        qs = qs.filter(Q(user__phone__icontains=q) | Q(plan__title__icontains=q) | Q(plan__code__icontains=q))
    if status_val:
        qs = qs.filter(status=status_val)

    if _want_csv(request):
        rows = [
            [
                s.id,
                getattr(getattr(s, "user", None), "phone", ""),
                getattr(getattr(s, "plan", None), "code", ""),
                s.status,
                s.start_at.isoformat() if s.start_at else "",
                s.end_at.isoformat() if s.end_at else "",
                getattr(getattr(s, "invoice", None), "code", ""),
            ]
            for s in qs[:2000]
        ]
        return _csv_response(
            "subscriptions.csv",
            ["id", "user_phone", "plan_code", "status", "start_at", "end_at", "invoice_code"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/subscriptions_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "status_val": status_val,
            "status_choices": SubscriptionStatus.choices,
        },
    )


@staff_member_required
@dashboard_access_required("subs", write=True)
@require_POST
def subscription_refresh_action(request: HttpRequest, subscription_id: int) -> HttpResponse:
    sub = get_object_or_404(Subscription, id=subscription_id)
    try:
        refresh_subscription_status(sub=sub)
        messages.success(request, "تم تحديث حالة الاشتراك")
    except Exception as e:
        messages.error(request, str(e) or "تعذر تحديث الاشتراك")
    return redirect("dashboard:subscriptions_list")


@staff_member_required
@dashboard_access_required("subs", write=True)
@require_POST
def subscription_activate_action(request: HttpRequest, subscription_id: int) -> HttpResponse:
    sub = get_object_or_404(Subscription, id=subscription_id)
    try:
        activate_subscription_after_payment(sub=sub)
        messages.success(request, "تم تفعيل الاشتراك")
    except Exception as e:
        messages.error(request, str(e) or "تعذر تفعيل الاشتراك")
    return redirect("dashboard:subscriptions_list")


@staff_member_required
@dashboard_access_required("extras")
def extras_list(request: HttpRequest) -> HttpResponse:
    qs = ExtraPurchase.objects.select_related("user", "invoice").all().order_by("-id")
    q = (request.GET.get("q") or "").strip()
    status_val = (request.GET.get("status") or "").strip()
    if q:
        qs = qs.filter(Q(user__phone__icontains=q) | Q(sku__icontains=q) | Q(title__icontains=q))
    if status_val:
        qs = qs.filter(status=status_val)

    if _want_csv(request):
        rows = [
            [
                e.id,
                getattr(getattr(e, "user", None), "phone", ""),
                e.sku,
                e.extra_type,
                e.status,
                e.subtotal,
                getattr(getattr(e, "invoice", None), "code", ""),
                e.created_at.isoformat(),
            ]
            for e in qs[:2000]
        ]
        return _csv_response(
            "extras.csv",
            ["id", "user_phone", "sku", "extra_type", "status", "subtotal", "invoice_code", "created_at"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/extras_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "status_val": status_val,
            "status_choices": ExtraPurchaseStatus.choices,
        },
    )


@staff_member_required
@dashboard_access_required("extras", write=True)
@require_POST
def extra_activate_action(request: HttpRequest, extra_id: int) -> HttpResponse:
    purchase = get_object_or_404(ExtraPurchase, id=extra_id)
    try:
        activate_extra_after_payment(purchase=purchase)
        messages.success(request, "تم تفعيل الإضافة")
    except Exception as e:
        messages.error(request, str(e) or "تعذر تفعيل الإضافة")
    return redirect("dashboard:extras_list")


@staff_member_required
@dashboard_access_required("analytics")
def features_overview(request: HttpRequest) -> HttpResponse:
    users_qs = User.objects.all().order_by("-id")
    q = (request.GET.get("q") or "").strip()
    if q:
        users_qs = users_qs.filter(Q(phone__icontains=q) | Q(username__icontains=q) | Q(email__icontains=q))
    paginator = Paginator(users_qs, 20)
    page_obj = paginator.get_page(request.GET.get("page") or "1")

    rows = []
    for user in page_obj.object_list:
        rows.append(
            {
                "user": user,
                "verify_blue": has_feature(user, "verify_blue"),
                "verify_green": has_feature(user, "verify_green"),
                "promo_ads": has_feature(user, "promo_ads"),
                "priority_support": has_feature(user, "priority_support"),
                "extra_uploads": has_feature(user, "extra_uploads"),
                "max_upload_mb": user_max_upload_mb(user),
            }
        )

    if _want_csv(request):
        csv_rows = [
            [
                row["user"].id,
                row["user"].phone or "",
                row["verify_blue"],
                row["verify_green"],
                row["promo_ads"],
                row["priority_support"],
                row["extra_uploads"],
                row["max_upload_mb"],
            ]
            for row in rows
        ]
        return _csv_response(
            "features_overview.csv",
            ["user_id", "phone", "verify_blue", "verify_green", "promo_ads", "priority_support", "extra_uploads", "max_upload_mb"],
            csv_rows,
        )

    return render(
        request,
        "dashboard/features_overview.html",
        {
            "page_obj": page_obj,
            "rows": rows,
            "q": q,
        },
    )


@staff_member_required
@dashboard_access_required("access")
def access_profiles_list(request: HttpRequest) -> HttpResponse:
    qs = (
        UserAccessProfile.objects.select_related("user")
        .prefetch_related("allowed_dashboards")
        .all()
        .order_by("-updated_at")
    )
    q = (request.GET.get("q") or "").strip()
    level = (request.GET.get("level") or "").strip()
    if q:
        qs = qs.filter(Q(user__phone__icontains=q) | Q(user__username__icontains=q) | Q(user__email__icontains=q))
    if level:
        qs = qs.filter(level=level)

    if _want_csv(request):
        rows = []
        for ap in qs[:2000]:
            dashboards = ",".join(ap.allowed_dashboards.values_list("code", flat=True))
            rows.append(
                [
                    ap.user_id,
                    ap.user.phone or "",
                    ap.level,
                    bool(ap.revoked_at),
                    ap.expires_at.isoformat() if ap.expires_at else "",
                    dashboards,
                    ap.updated_at.isoformat() if ap.updated_at else "",
                ]
            )
        return _csv_response(
            "access_profiles.csv",
            ["user_id", "phone", "level", "is_revoked", "expires_at", "dashboards", "updated_at"],
            rows,
        )

    paginator = Paginator(qs, 25)
    page_obj = paginator.get_page(request.GET.get("page") or "1")
    return render(
        request,
        "dashboard/access_profiles_list.html",
        {
            "page_obj": page_obj,
            "q": q,
            "level": level,
            "level_choices": UserAccessProfile._meta.get_field("level").choices,
        },
    )
