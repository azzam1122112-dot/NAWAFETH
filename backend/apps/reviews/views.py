from django.shortcuts import get_object_or_404
from django.db.models import Avg
from rest_framework import permissions, status, generics
from rest_framework.views import APIView
from rest_framework.response import Response

from apps.marketplace.models import ServiceRequest
from apps.providers.models import ProviderProfile
from .models import Review
from .serializers import (
	ReviewCreateSerializer, ReviewListSerializer, ProviderRatingSummarySerializer
)

from apps.accounts.permissions import IsAtLeastClient


class CreateReviewView(APIView):
	permission_classes = [IsAtLeastClient]

	def post(self, request, request_id):
		sr = get_object_or_404(ServiceRequest, id=request_id)

		s = ReviewCreateSerializer(
			data=request.data,
			context={"service_request": sr, "user": request.user},
		)
		s.is_valid(raise_exception=True)

		review = Review.objects.create(
			request=sr,
			provider=sr.provider,
			client=request.user,
			rating=s.validated_data["rating"],
			response_speed=s.validated_data.get("response_speed"),
			cost_value=s.validated_data.get("cost_value"),
			quality=s.validated_data.get("quality"),
			credibility=s.validated_data.get("credibility"),
			on_time=s.validated_data.get("on_time"),
			comment=s.validated_data.get("comment", ""),
		)

		return Response(
			{"ok": True, "review_id": review.id},
			status=status.HTTP_201_CREATED
		)


class ProviderReviewsListView(generics.ListAPIView):
	permission_classes = [permissions.AllowAny]
	serializer_class = ReviewListSerializer

	def get_queryset(self):
		provider_id = self.kwargs["provider_id"]
		return Review.objects.filter(provider_id=provider_id).select_related("client").order_by("-id")


class ProviderRatingSummaryView(APIView):
	permission_classes = [permissions.AllowAny]

	def get(self, request, provider_id):
		provider = get_object_or_404(ProviderProfile, id=provider_id)

		# تفصيل متوسطات التقييم من جدول المراجعات (قد تكون None إذا لم تُستخدم المحاور)
		breakdown = Review.objects.filter(provider_id=provider_id).aggregate(
			response_speed_avg=Avg("response_speed"),
			cost_value_avg=Avg("cost_value"),
			quality_avg=Avg("quality"),
			credibility_avg=Avg("credibility"),
			on_time_avg=Avg("on_time"),
		)

		data = {
			"provider_id": provider.id,
			"rating_avg": provider.rating_avg,
			"rating_count": provider.rating_count,
			**breakdown,
		}
		return Response(ProviderRatingSummarySerializer(data).data, status=status.HTTP_200_OK)
