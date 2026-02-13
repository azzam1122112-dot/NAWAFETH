from __future__ import annotations

from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.views import APIView

from django.db.models import Q
from django.shortcuts import get_object_or_404

from .models import PromoRequest, PromoAsset, PromoRequestStatus
from .serializers import (
    PromoRequestCreateSerializer,
    PromoRequestDetailSerializer,
    PromoAssetSerializer,
    PromoQuoteSerializer,
    PromoRejectSerializer,
)
from .permissions import IsOwnerOrBackofficePromo
from .services import quote_and_create_invoice, reject_request


# ---------- Client ----------

class PromoRequestCreateView(generics.CreateAPIView):
    permission_classes = [IsOwnerOrBackofficePromo]
    serializer_class = PromoRequestCreateSerializer

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx["request"] = self.request
        return ctx


class MyPromoRequestsListView(generics.ListAPIView):
    permission_classes = [IsOwnerOrBackofficePromo]
    serializer_class = PromoRequestDetailSerializer

    def get_queryset(self):
        return PromoRequest.objects.filter(requester=self.request.user).order_by("-id")


class PromoRequestDetailView(generics.RetrieveAPIView):
    permission_classes = [IsOwnerOrBackofficePromo]
    serializer_class = PromoRequestDetailSerializer
    queryset = PromoRequest.objects.all()

    def get_object(self):
        obj = super().get_object()
        self.check_object_permissions(self.request, obj)
        return obj


class PromoAddAssetView(generics.CreateAPIView):
    permission_classes = [IsOwnerOrBackofficePromo]
    parser_classes = [MultiPartParser, FormParser]
    serializer_class = PromoAssetSerializer

    def create(self, request, *args, **kwargs):
        pr = PromoRequest.objects.get(pk=kwargs["pk"])
        self.check_object_permissions(request, pr)

        if pr.status not in (PromoRequestStatus.NEW, PromoRequestStatus.IN_REVIEW, PromoRequestStatus.REJECTED):
            return Response({"detail": "لا يمكن رفع مواد الإعلان في هذه المرحلة."}, status=status.HTTP_400_BAD_REQUEST)

        file_obj = request.FILES.get("file")
        if not file_obj:
            return Response({"detail": "file مطلوب"}, status=status.HTTP_400_BAD_REQUEST)

        from django.core.exceptions import ValidationError as DjangoValidationError
        from apps.features.upload_limits import user_max_upload_mb
        from apps.uploads.validators import validate_user_file_size
        from .validators import validate_extension

        try:
            validate_extension(file_obj)
            validate_user_file_size(file_obj, user_max_upload_mb(request.user))
        except DjangoValidationError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        asset_type = (request.data.get("asset_type") or "image").strip()
        title = (request.data.get("title") or "").strip()

        asset = PromoAsset.objects.create(
            request=pr,
            asset_type=asset_type,
            title=title[:160],
            file=file_obj,
            uploaded_by=request.user,
        )

        # عند رفع جديد بعد رفض نعيد للمراجعة
        if pr.status == PromoRequestStatus.REJECTED:
            pr.status = PromoRequestStatus.IN_REVIEW
            pr.save(update_fields=["status", "updated_at"])

        return Response(PromoAssetSerializer(asset).data, status=status.HTTP_201_CREATED)


# ---------- Backoffice ----------

class BackofficePromoRequestsListView(generics.ListAPIView):
    permission_classes = [IsOwnerOrBackofficePromo]
    serializer_class = PromoRequestDetailSerializer

    def get_queryset(self):
        user = self.request.user
        qs = PromoRequest.objects.all().order_by("-id")

        ap = getattr(user, "access_profile", None)
        if not ap:
            return PromoRequest.objects.none()
        if ap and ap.level == "user":
            qs = qs.filter(status__in=[
                PromoRequestStatus.NEW,
                PromoRequestStatus.IN_REVIEW,
                PromoRequestStatus.PENDING_PAYMENT,
            ])

        status_q = self.request.query_params.get("status")
        ad_type_q = self.request.query_params.get("ad_type")
        q = self.request.query_params.get("q")

        if status_q:
            qs = qs.filter(status=status_q)
        if ad_type_q:
            qs = qs.filter(ad_type=ad_type_q)
        if q:
            qs = qs.filter(Q(code__icontains=q) | Q(title__icontains=q) | Q(requester__phone__icontains=q))

        return qs


class BackofficeQuoteView(APIView):
    permission_classes = [IsOwnerOrBackofficePromo]

    def post(self, request, pk: int):
        pr = get_object_or_404(PromoRequest, pk=pk)
        self.check_object_permissions(request, pr)

        ser = PromoQuoteSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        note = ser.validated_data.get("quote_note", "")

        try:
            pr = quote_and_create_invoice(pr=pr, by_user=request.user, quote_note=note)
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(PromoRequestDetailSerializer(pr).data, status=status.HTTP_200_OK)


class BackofficeRejectView(APIView):
    permission_classes = [IsOwnerOrBackofficePromo]

    def post(self, request, pk: int):
        pr = get_object_or_404(PromoRequest, pk=pk)
        self.check_object_permissions(request, pr)

        ser = PromoRejectSerializer(data=request.data)
        ser.is_valid(raise_exception=True)

        pr = reject_request(pr=pr, reason=ser.validated_data["reject_reason"], by_user=request.user)
        return Response(PromoRequestDetailSerializer(pr).data, status=status.HTTP_200_OK)
