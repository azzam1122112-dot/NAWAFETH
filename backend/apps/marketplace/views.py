from datetime import timedelta
import logging
from typing import Optional

from django.conf import settings
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from django.shortcuts import redirect, render
from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_POST
from django.core.exceptions import PermissionDenied, ValidationError
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.providers.models import ProviderCategory, ProviderProfile

from .models import (
	Offer,
	OfferStatus,
	RequestStatus,
	RequestStatusLog,
	RequestType,
	ServiceRequest,
)
from .serializers import (
	OfferCreateSerializer,
	OfferListSerializer,
	ProviderRequestDetailSerializer,
	RequestActionSerializer,
	ServiceRequestCreateSerializer,
	ServiceRequestListSerializer,
	UrgentRequestAcceptSerializer,
)

from apps.marketplace.services.actions import allowed_actions, execute_action

from apps.accounts.permissions import IsAtLeastClient


logger = logging.getLogger(__name__)



def _normalize_status_group(value: str) -> Optional[str]:
	v = (value or "").strip().lower()
	if not v:
		return None

	# English codes
	if v in {"new", "in_progress", "completed", "cancelled"}:
		return v

	# Common variants
	if v in {"canceled", "cancel", "cancelled"}:
		return "cancelled"

	# Arabic labels (mobile/UI)
	ar_map = {
		"جديد": "new",
		"تحت التنفيذ": "in_progress",
		"مكتمل": "completed",
		"ملغي": "cancelled",
	}
	return ar_map.get(value.strip())


def _status_group_to_statuses(group: str) -> list[str]:
	# Map unified user-facing groups to internal statuses.
	return {
		"new": [RequestStatus.NEW, RequestStatus.SENT],
		"in_progress": [RequestStatus.ACCEPTED, RequestStatus.IN_PROGRESS],
		"completed": [RequestStatus.COMPLETED],
		"cancelled": [RequestStatus.CANCELLED, RequestStatus.EXPIRED],
	}[group]


def _expire_urgent_requests() -> None:
	now = timezone.now()
	ServiceRequest.objects.filter(
		request_type=RequestType.URGENT,
		status__in=[RequestStatus.NEW, RequestStatus.SENT],
		expires_at__isnull=False,
		expires_at__lt=now,
	).update(status=RequestStatus.EXPIRED)


class ServiceRequestCreateView(generics.CreateAPIView):
	serializer_class = ServiceRequestCreateSerializer
	permission_classes = [IsAtLeastClient]

	def perform_create(self, serializer):
		request_type = serializer.validated_data["request_type"]

		is_urgent = request_type == RequestType.URGENT
		# Mobile expects the request to reach providers immediately.
		# - urgent: SENT (available inbox) + expiry
		# - competitive: SENT (providers can send offers)
		# - normal: SENT (targeted provider inbox)
		status_value = RequestStatus.SENT

		expires_at = None
		if is_urgent:
			minutes = getattr(settings, "URGENT_REQUEST_EXPIRY_MINUTES", 15)
			expires_at = timezone.now() + timedelta(minutes=minutes)

		serializer.save(
			client=self.request.user,
			is_urgent=is_urgent,
			status=status_value,
			expires_at=expires_at,
		)


class IsProviderPermission(permissions.BasePermission):
	def has_permission(self, request, view):
		return bool(getattr(request, "user", None)) and hasattr(request.user, "provider_profile")


class UrgentRequestAcceptView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

	def post(self, request):
		_expire_urgent_requests()
		serializer = UrgentRequestAcceptSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		request_id = serializer.validated_data["request_id"]
		provider: ProviderProfile = request.user.provider_profile

		with transaction.atomic():
			# 🔒 قفل الصف
			service_request = (
				ServiceRequest.objects.select_for_update()
				.filter(id=request_id)
				.first()
			)

			if not service_request:
				return Response(
					{"detail": "الطلب غير موجود"},
					status=status.HTTP_404_NOT_FOUND,
				)

			# ✅ تحقق أنه عاجل
			if service_request.request_type != RequestType.URGENT:
				return Response(
					{"detail": "هذا الطلب ليس عاجلًا"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			# ✅ تحقق من الانتهاء
			now = timezone.now()
			if service_request.expires_at and service_request.expires_at < now:
				service_request.status = RequestStatus.EXPIRED
				service_request.save(update_fields=["status"])
				return Response(
					{"detail": "انتهت صلاحية الطلب"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			# ✅ تحقق من الحالة
			if service_request.status not in (RequestStatus.SENT, RequestStatus.NEW):
				return Response(
					{"detail": "لا يمكن قبول الطلب في هذه الحالة"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			# ❌ إذا قُبل مسبقًا
			if service_request.provider is not None:
				return Response(
					{"detail": "تم قبول الطلب بالفعل"},
					status=status.HTTP_409_CONFLICT,
				)

			# ✅ تأكيد أهلية المزود (أمان/نزاهة): نفس المدينة + نفس التصنيف + يقبل العاجل
			if not getattr(provider, "accepts_urgent", False):
				return Response(
					{"detail": "هذا المزود لا يقبل الطلبات العاجلة"},
					status=status.HTTP_403_FORBIDDEN,
				)
			if (service_request.city or "").strip() and (provider.city or "").strip() and service_request.city.strip() != provider.city.strip():
				return Response(
					{"detail": "هذا الطلب خارج نطاق مدينتك"},
					status=status.HTTP_403_FORBIDDEN,
				)
			if not ProviderCategory.objects.filter(provider=provider, subcategory_id=service_request.subcategory_id).exists():
				return Response(
					{"detail": "هذا الطلب لا يطابق تخصصاتك"},
					status=status.HTTP_403_FORBIDDEN,
				)

			# ✅ قبول الطلب
			service_request.provider = provider
			service_request.status = RequestStatus.ACCEPTED
			service_request.save(update_fields=["provider", "status"])

		return Response(
			{
				"ok": True,
				"request_id": service_request.id,
				"status": service_request.status,
				"provider": provider.display_name,
			},
			status=status.HTTP_200_OK,
		)


class AvailableUrgentRequestsView(generics.ListAPIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]
	serializer_class = ServiceRequestListSerializer

	def get_queryset(self):
		_expire_urgent_requests()
		provider = self.request.user.provider_profile

		# subcategories التي يعمل بها مقدم الخدمة
		provider_subcats = ProviderCategory.objects.filter(provider=provider).values_list(
			"subcategory_id",
			flat=True,
		)

		now = timezone.now()

		qs = (
			ServiceRequest.objects.select_related("client", "subcategory", "subcategory__category")
			.filter(
				request_type=RequestType.URGENT,
				provider__isnull=True,
				status__in=[RequestStatus.NEW, RequestStatus.SENT],
				city=provider.city,
				subcategory_id__in=provider_subcats,
			)
			.exclude(expires_at__isnull=False, expires_at__lt=now)
			.order_by("-created_at")
		)

		# إن كان مقدم الخدمة لا يقبل العاجل، نرجع نتيجة فارغة
		if not provider.accepts_urgent:
			return ServiceRequest.objects.none()

		return qs


class AvailableCompetitiveRequestsView(generics.ListAPIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]
	serializer_class = ServiceRequestListSerializer

	def get_queryset(self):
		provider = self.request.user.provider_profile

		provider_subcats = ProviderCategory.objects.filter(provider=provider).values_list(
			"subcategory_id",
			flat=True,
		)

		return (
			ServiceRequest.objects.select_related("client", "subcategory", "subcategory__category")
			.filter(
				request_type=RequestType.COMPETITIVE,
				provider__isnull=True,
				status=RequestStatus.SENT,
				city=provider.city,
				subcategory_id__in=provider_subcats,
			)
			.order_by("-created_at")
		)


class MyProviderRequestsView(generics.ListAPIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]
	serializer_class = ServiceRequestListSerializer

	def get_queryset(self):
		_expire_urgent_requests()
		provider = self.request.user.provider_profile
		qs = (
			ServiceRequest.objects.select_related("client", "subcategory", "subcategory__category")
			.filter(provider=provider)
			.order_by("-created_at")
		)

		group_value = _normalize_status_group(self.request.query_params.get("status_group") or "")
		if group_value:
			qs = qs.filter(status__in=_status_group_to_statuses(group_value))

		return qs


class ProviderRequestDetailView(generics.RetrieveAPIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]
	serializer_class = ProviderRequestDetailSerializer
	lookup_url_kwarg = "request_id"

	def get_queryset(self):
		return ServiceRequest.objects.select_related(
			"client",
			"provider",
			"provider__user",
			"subcategory",
			"subcategory__category",
		).prefetch_related("attachments", "status_logs", "status_logs__actor")

	def get_object(self):
		obj = super().get_object()
		provider = self.request.user.provider_profile

		# Assigned request: provider can always view it.
		if obj.provider_id == provider.id:
			return obj

		# Requests assigned to another provider are forbidden.
		if obj.provider_id is not None:
			raise PermissionDenied("غير مصرح")

		# Unassigned request must still be actionable and relevant to this provider.
		if obj.status not in (RequestStatus.NEW, RequestStatus.SENT):
			raise PermissionDenied("غير مصرح")

		if obj.request_type == RequestType.NORMAL:
			raise PermissionDenied("غير مصرح")

		if obj.request_type == RequestType.URGENT and not provider.accepts_urgent:
			raise PermissionDenied("غير مصرح")

		if (obj.city or "").strip() and (provider.city or "").strip() and obj.city.strip() != provider.city.strip():
			raise PermissionDenied("غير مصرح")

		if not ProviderCategory.objects.filter(
			provider=provider,
			subcategory_id=obj.subcategory_id,
		).exists():
			raise PermissionDenied("غير مصرح")

		return obj


class MyClientRequestsView(generics.ListAPIView):
	permission_classes = [IsAtLeastClient]
	serializer_class = ServiceRequestListSerializer

	def get_queryset(self):
		_expire_urgent_requests()
		qs = (
			ServiceRequest.objects.select_related("provider", "subcategory", "subcategory__category")
			.filter(client=self.request.user)
			.order_by("-created_at")
		)

		group_value = _normalize_status_group(self.request.query_params.get("status_group") or "")
		if group_value:
			qs = qs.filter(status__in=_status_group_to_statuses(group_value))

		status_value = (self.request.query_params.get("status") or "").strip()
		if status_value:
			allowed = {c.value for c in RequestStatus}
			if status_value in allowed:
				qs = qs.filter(status=status_value)

		type_value = (self.request.query_params.get("type") or "").strip()
		if type_value:
			allowed = {c.value for c in RequestType}
			if type_value in allowed:
				qs = qs.filter(request_type=type_value)

		q = (self.request.query_params.get("q") or "").strip()
		if q:
			qs = qs.filter(
				Q(title__icontains=q)
				| Q(description__icontains=q)
				| Q(subcategory__name__icontains=q)
				| Q(subcategory__category__name__icontains=q)
			)

		return qs


class ProviderAssignedRequestAcceptView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

	def post(self, request, request_id: int):
		_expire_urgent_requests()
		provider = request.user.provider_profile

		with transaction.atomic():
			sr = (
				ServiceRequest.objects.select_for_update()
				.select_related("client", "provider")
				.filter(id=request_id)
				.first()
			)

			if not sr:
				return Response({"detail": "الطلب غير موجود"}, status=status.HTTP_404_NOT_FOUND)

			if sr.provider_id != provider.id:
				return Response({"detail": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

			if sr.request_type == RequestType.COMPETITIVE:
				return Response({"detail": "هذا الطلب تنافسي ويتم التعامل معه عبر العروض"}, status=status.HTTP_400_BAD_REQUEST)

			if sr.status not in (RequestStatus.NEW, RequestStatus.SENT):
				return Response({"detail": "لا يمكن قبول الطلب في هذه الحالة"}, status=status.HTTP_400_BAD_REQUEST)

			old = sr.status
			sr.status = RequestStatus.ACCEPTED
			sr.save(update_fields=["status"])
			RequestStatusLog.objects.create(
				request=sr,
				actor=request.user,
				from_status=old,
				to_status=sr.status,
				note="قبول من المزود",
			)

		return Response({"ok": True, "request_id": sr.id, "status": sr.status}, status=status.HTTP_200_OK)


class ProviderAssignedRequestRejectView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

	def post(self, request, request_id: int):
		_expire_urgent_requests()
		provider = request.user.provider_profile
		s = RequestActionSerializer(data=request.data)
		s.is_valid(raise_exception=True)
		note = s.validated_data.get("note", "")

		with transaction.atomic():
			sr = (
				ServiceRequest.objects.select_for_update()
				.select_related("client", "provider")
				.filter(id=request_id)
				.first()
			)

			if not sr:
				return Response({"detail": "الطلب غير موجود"}, status=status.HTTP_404_NOT_FOUND)

			if sr.provider_id != provider.id:
				return Response({"detail": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

			if sr.request_type == RequestType.COMPETITIVE:
				return Response({"detail": "هذا الطلب تنافسي ويتم التعامل معه عبر العروض"}, status=status.HTTP_400_BAD_REQUEST)

			if sr.status not in (RequestStatus.NEW, RequestStatus.SENT):
				return Response({"detail": "لا يمكن رفض الطلب في هذه الحالة"}, status=status.HTTP_400_BAD_REQUEST)

			old = sr.status
			sr.status = RequestStatus.CANCELLED
			sr.save(update_fields=["status"])
			RequestStatusLog.objects.create(
				request=sr,
				actor=request.user,
				from_status=old,
				to_status=sr.status,
				note=note or "رفض من المزود",
			)

		return Response({"ok": True, "request_id": sr.id, "status": sr.status}, status=status.HTTP_200_OK)


class MyClientRequestDetailView(generics.RetrieveAPIView):
	permission_classes = [IsAtLeastClient]
	serializer_class = ServiceRequestListSerializer
	lookup_url_kwarg = "request_id"

	def get_queryset(self):
		return ServiceRequest.objects.select_related(
			"provider",
			"subcategory",
			"subcategory__category",
		).filter(client=self.request.user)


class CreateOfferView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

	def post(self, request, request_id):
		provider = request.user.provider_profile
		service_request = get_object_or_404(ServiceRequest, id=request_id)

		# تحقق من نوع الطلب
		if service_request.request_type != RequestType.COMPETITIVE:
			return Response(
				{"detail": "هذا الطلب ليس تنافسيًا"},
				status=status.HTTP_400_BAD_REQUEST,
			)

		# تحقق من الحالة
		if service_request.status != RequestStatus.SENT:
			return Response(
				{"detail": "لا يمكن إرسال عرض في هذه الحالة"},
				status=status.HTTP_400_BAD_REQUEST,
			)

		# ✅ تأكيد أهلية المزود (أمان/نزاهة): نفس المدينة + نفس التصنيف
		if (service_request.city or "").strip() and (provider.city or "").strip() and service_request.city.strip() != provider.city.strip():
			return Response(
				{"detail": "هذا الطلب خارج نطاق مدينتك"},
				status=status.HTTP_403_FORBIDDEN,
			)
		if not ProviderCategory.objects.filter(provider=provider, subcategory_id=service_request.subcategory_id).exists():
			return Response(
				{"detail": "هذا الطلب لا يطابق تخصصاتك"},
				status=status.HTTP_403_FORBIDDEN,
			)

		serializer = OfferCreateSerializer(data=request.data)
		serializer.is_valid(raise_exception=True)

		offer, created = Offer.objects.get_or_create(
			request=service_request,
			provider=provider,
			defaults=serializer.validated_data,
		)

		if not created:
			return Response(
				{"detail": "تم إرسال عرض مسبقًا"},
				status=status.HTTP_409_CONFLICT,
			)

		return Response(
			{"ok": True, "offer_id": offer.id},
			status=status.HTTP_201_CREATED,
		)


class RequestOffersListView(generics.ListAPIView):
	permission_classes = [IsAtLeastClient]
	serializer_class = OfferListSerializer

	def get_queryset(self):
		request_id = self.kwargs["request_id"]
		return (
			Offer.objects.select_related("provider")
			.filter(request_id=request_id, request__client=self.request.user)
			.order_by("-created_at")
		)


class AcceptOfferView(APIView):
	permission_classes = [permissions.IsAuthenticated]

	def post(self, request, offer_id):
		with transaction.atomic():
			offer = (
				Offer.objects.select_for_update()
				.select_related("request", "provider")
				.get(id=offer_id)
			)

			service_request = offer.request

			if service_request.client != request.user:
				return Response(
					{"detail": "غير مصرح"},
					status=status.HTTP_403_FORBIDDEN,
				)

			if service_request.status != RequestStatus.SENT:
				return Response(
					{"detail": "لا يمكن اختيار عرض الآن"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			# تحديث الطلب
			service_request.provider = offer.provider
			service_request.status = RequestStatus.ACCEPTED
			service_request.save(update_fields=["provider", "status"])

			# تحديث العروض
			Offer.objects.filter(request=service_request).exclude(id=offer.id).update(
				status=OfferStatus.REJECTED,
			)
			offer.status = OfferStatus.SELECTED
			offer.save(update_fields=["status"])

		return Response(
			{"ok": True, "request_id": service_request.id},
			status=status.HTTP_200_OK,
		)


class RequestStartView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

	def post(self, request, request_id):
		s = RequestActionSerializer(data=request.data)
		s.is_valid(raise_exception=True)
		note = s.validated_data.get("note", "")

		provider = request.user.provider_profile

		with transaction.atomic():
			sr = (
				ServiceRequest.objects.select_for_update()
				.select_related("client", "provider")
				.filter(id=request_id)
				.first()
			)

			if not sr:
				return Response({"detail": "الطلب غير موجود"}, status=status.HTTP_404_NOT_FOUND)

			if sr.provider_id != provider.id:
				return Response({"detail": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

			if sr.status != RequestStatus.ACCEPTED:
				return Response(
					{"detail": "لا يمكن بدء التنفيذ في هذه الحالة"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			old = sr.status
			sr.status = RequestStatus.IN_PROGRESS
			sr.save(update_fields=["status"])

			RequestStatusLog.objects.create(
				request=sr,
				actor=request.user,
				from_status=old,
				to_status=sr.status,
				note=note or "بدء التنفيذ",
			)

		return Response(
			{"ok": True, "request_id": sr.id, "status": sr.status},
			status=status.HTTP_200_OK,
		)


class RequestCompleteView(APIView):
	permission_classes = [permissions.IsAuthenticated, IsProviderPermission]

	def post(self, request, request_id):
		s = RequestActionSerializer(data=request.data)
		s.is_valid(raise_exception=True)
		note = s.validated_data.get("note", "")

		provider = request.user.provider_profile

		with transaction.atomic():
			sr = (
				ServiceRequest.objects.select_for_update()
				.select_related("client", "provider")
				.filter(id=request_id)
				.first()
			)

			if not sr:
				return Response({"detail": "الطلب غير موجود"}, status=status.HTTP_404_NOT_FOUND)

			if sr.provider_id != provider.id:
				return Response({"detail": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

			if sr.status != RequestStatus.IN_PROGRESS:
				return Response(
					{"detail": "لا يمكن الإكمال في هذه الحالة"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			old = sr.status
			sr.status = RequestStatus.COMPLETED
			sr.save(update_fields=["status"])

			RequestStatusLog.objects.create(
				request=sr,
				actor=request.user,
				from_status=old,
				to_status=sr.status,
				note=note or "تم الإكمال",
			)

		return Response(
			{"ok": True, "request_id": sr.id, "status": sr.status},
			status=status.HTTP_200_OK,
		)


class RequestCancelView(APIView):
	permission_classes = [permissions.IsAuthenticated]

	def post(self, request, request_id):
		s = RequestActionSerializer(data=request.data)
		s.is_valid(raise_exception=True)
		note = s.validated_data.get("note", "")

		with transaction.atomic():
			sr = (
				ServiceRequest.objects.select_for_update()
				.select_related("client", "provider")
				.filter(id=request_id)
				.first()
			)

			if not sr:
				return Response({"detail": "الطلب غير موجود"}, status=status.HTTP_404_NOT_FOUND)

			# فقط مالك الطلب
			if sr.client_id != request.user.id:
				return Response({"detail": "غير مصرح"}, status=status.HTTP_403_FORBIDDEN)

			# شروط الإلغاء (MVP) - يسمح بالإلغاء قبل التنفيذ
			if sr.status not in (RequestStatus.NEW, RequestStatus.SENT, RequestStatus.ACCEPTED):
				return Response(
					{"detail": "لا يمكن الإلغاء في هذه الحالة"},
					status=status.HTTP_400_BAD_REQUEST,
				)

			old = sr.status
			sr.status = RequestStatus.CANCELLED
			sr.save(update_fields=["status"])

			RequestStatusLog.objects.create(
				request=sr,
				actor=request.user,
				from_status=old,
				to_status=sr.status,
				note=note or "إلغاء من العميل",
			)

		return Response(
			{"ok": True, "request_id": sr.id, "status": sr.status},
			status=status.HTTP_200_OK,
		)


@login_required
def request_detail(request, request_id: int):
	obj = get_object_or_404(
		ServiceRequest.objects.select_related("client", "provider", "provider__user"),
		id=request_id,
	)

	provider_profile = ProviderProfile.objects.filter(user=request.user).first()

	# صلاحية عرض بسيطة: staff أو العميل أو المزوّد المعيّن
	if not getattr(request.user, "is_staff", False):
		is_client = obj.client_id == request.user.id
		is_provider = bool(obj.provider_id) and (obj.provider.user_id == request.user.id)
		if not (is_client or is_provider):
			raise PermissionDenied

	acts = allowed_actions(request.user, obj, has_provider_profile=(provider_profile is not None))

	context = {
		"obj": obj,
		"can_send": "send" in acts,
		"can_cancel": "cancel" in acts,
		"can_accept": "accept" in acts,
		"can_start": "start" in acts,
		"can_complete": "complete" in acts,
	}
	return render(request, "marketplace/request_detail.html", context)


@login_required
@require_POST
@csrf_protect
def request_action(request, request_id: int):
	sr = get_object_or_404(ServiceRequest, id=request_id)

	action = (request.POST.get("action") or "").strip()

	provider_profile = None
	try:
		provider_profile = ProviderProfile.objects.filter(user=request.user).first()

		result = execute_action(
			user=request.user,
			request_id=sr.id,
			action=action,
			provider_profile=provider_profile,
		)
		messages.success(request, result.message)

	except PermissionDenied:
		messages.error(request, "غير مصرح بتنفيذ هذا الإجراء")
	except ValidationError as e:
		msg = None
		if hasattr(e, "messages") and e.messages:
			msg = e.messages[0]
		elif hasattr(e, "message"):
			msg = e.message
		messages.warning(request, msg or "لا يمكن تنفيذ الإجراء")
	except Exception:
		logger.exception("marketplace request_action error")
		messages.error(request, "حدث خطأ غير متوقع")

	return redirect("marketplace:request_detail", request_id=sr.id)


@login_required
def provider_requests(request):
	"""
	Provider dashboard (marketplace side):
	- tab=available: SENT requests provider can accept
	- tab=assigned: requests assigned to this provider
	- tab=all: staff-only, all requests
	"""
	user = request.user
	provider = ProviderProfile.objects.select_related("user").filter(user=user).first()

	# إذا المستخدم ليس مزودًا
	if not provider and not getattr(user, "is_staff", False):
		return render(request, "marketplace/provider_not_found.html", status=403)

	tab = (request.GET.get("tab") or "available").strip().lower()
	q = (request.GET.get("q") or "").strip()
	city = (request.GET.get("city") or "").strip()
	status = (request.GET.get("status") or "").strip().lower()
	page = request.GET.get("page") or "1"

	qs = (
		ServiceRequest.objects.select_related("client", "provider", "provider__user", "subcategory")
		.order_by("-id")
	)

	# staff: يرى كل شيء فقط عند tab=all
	if getattr(user, "is_staff", False) and tab == "all":
		pass
	else:
		if tab == "assigned":
			if provider:
				qs = qs.filter(provider=provider)
			else:
				# staff without provider profile: show assigned requests
				qs = qs.filter(provider__isnull=False)
		else:
			# available
			qs = qs.filter(status=RequestStatus.SENT, provider__isnull=True)

			# فلترة حسب subcategories المزود عبر ProviderCategory
			if provider:
				sub_ids = list(
					ProviderCategory.objects.filter(provider=provider).values_list(
						"subcategory_id",
						flat=True,
					)
				)
				if sub_ids:
					qs = qs.filter(subcategory_id__in=sub_ids)

	# فلاتر آمنة
	if q:
		qs = qs.filter(Q(title__icontains=q) | Q(description__icontains=q))
	if city:
		qs = qs.filter(city__icontains=city)
	if status:
		valid = {c[0] for c in RequestStatus.choices}
		if status in valid:
			qs = qs.filter(status=status)

	paginator = Paginator(qs, 12)
	page_obj = paginator.get_page(page)

	context = {
		"tab": tab,
		"q": q,
		"city": city,
		"status": status,
		"page_obj": page_obj,
		"provider": provider,
	}
	return render(request, "marketplace/provider_requests.html", context)
