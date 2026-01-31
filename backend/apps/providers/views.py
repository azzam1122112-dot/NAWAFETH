from rest_framework import generics, permissions, status
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Count

from apps.accounts.models import User

from apps.accounts.models import UserRole
from apps.accounts.permissions import IsAtLeastClient, IsAtLeastPhoneOnly, IsAtLeastProvider

from .models import Category, ProviderFollow, ProviderLike, ProviderProfile
from .serializers import (
	CategorySerializer,
	ProviderProfileSerializer,
	ProviderProfileMeSerializer,
	ProviderPublicSerializer,
	UserPublicSerializer,
)


class MyProviderProfileView(generics.RetrieveUpdateAPIView):
	"""Get/update the current user's provider profile."""

	serializer_class = ProviderProfileMeSerializer
	permission_classes = [IsAtLeastClient]

	def get_object(self):
		provider_profile = getattr(self.request.user, "provider_profile", None)
		if not provider_profile:
			raise NotFound("provider_profile_not_found")
		return provider_profile


class CategoryListView(generics.ListAPIView):
	queryset = Category.objects.filter(is_active=True)
	serializer_class = CategorySerializer
	permission_classes = [permissions.AllowAny]


class ProviderCreateView(generics.CreateAPIView):
	serializer_class = ProviderProfileSerializer
	# Allow PHONE_ONLY users to become providers via OTP login without forcing
	# complete_registration first.
	permission_classes = [IsAtLeastPhoneOnly]

	def perform_create(self, serializer):
		profile = serializer.save(user=self.request.user)
		# Upgrade role to PROVIDER (level 4) after registering as provider
		user = self.request.user
		if not getattr(user, "is_staff", False) and getattr(user, "role_state", None) != UserRole.PROVIDER:
			user.role_state = UserRole.PROVIDER
			user.save(update_fields=["role_state"])
		return profile


class ProviderListView(generics.ListAPIView):
    """Public provider list/search (visitor allowed)."""
    serializer_class = ProviderPublicSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        # Annotate with counts
        qs = ProviderProfile.objects.annotate(
            followers_count=Count("followers"),
            likes_count=Count("likes")
        ).order_by("-id")
        
        q = (self.request.query_params.get("q") or "").strip()
        city = (self.request.query_params.get("city") or "").strip()
        if q:
            qs = qs.filter(display_name__icontains=q)
        if city:
            qs = qs.filter(city__icontains=city)
        return qs


class ProviderDetailView(generics.RetrieveAPIView):
    serializer_class = ProviderPublicSerializer
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        return ProviderProfile.objects.annotate(
            followers_count=Count("followers"),
            likes_count=Count("likes")
        )


class MyFollowingProvidersView(generics.ListAPIView):
	"""Providers the current user follows."""
	serializer_class = ProviderPublicSerializer
	permission_classes = [IsAtLeastPhoneOnly]

	def get_queryset(self):
		return (
			ProviderProfile.objects.filter(followers__user=self.request.user)
			.annotate(followers_count=Count("followers"), likes_count=Count("likes"))
			.distinct()
			.order_by("-id")
		)


class MyLikedProvidersView(generics.ListAPIView):
	"""Providers the current user liked (used as Favorites in the app)."""
	serializer_class = ProviderPublicSerializer
	permission_classes = [IsAtLeastPhoneOnly]

	def get_queryset(self):
		return (
			ProviderProfile.objects.filter(likes__user=self.request.user)
			.annotate(followers_count=Count("followers"), likes_count=Count("likes"))
			.distinct()
			.order_by("-id")
		)


class MyProviderFollowersView(generics.ListAPIView):
	"""Users who follow the current user's provider profile (if exists)."""
	serializer_class = UserPublicSerializer
	permission_classes = [IsAtLeastProvider]

	def get_queryset(self):
		provider_profile = getattr(self.request.user, "provider_profile", None)
		if not provider_profile:
			return User.objects.none()

		return (
			User.objects.filter(provider_follows__provider=provider_profile)
			.distinct()
			.order_by("-id")
		)


class MyProviderLikersView(generics.ListAPIView):
	"""Users who liked the current user's provider profile (if exists)."""
	serializer_class = UserPublicSerializer
	permission_classes = [IsAtLeastProvider]

	def get_queryset(self):
		provider_profile = getattr(self.request.user, "provider_profile", None)
		if not provider_profile:
			return User.objects.none()

		return (
			User.objects.filter(provider_likes__provider=provider_profile)
			.distinct()
			.order_by("-id")
		)


class FollowProviderView(APIView):
	permission_classes = [IsAtLeastPhoneOnly]

	def post(self, request, provider_id: int):
		provider = generics.get_object_or_404(ProviderProfile, id=provider_id)
		ProviderFollow.objects.get_or_create(user=request.user, provider=provider)
		return Response({"ok": True}, status=status.HTTP_200_OK)


class UnfollowProviderView(APIView):
	permission_classes = [IsAtLeastPhoneOnly]

	def post(self, request, provider_id: int):
		ProviderFollow.objects.filter(user=request.user, provider_id=provider_id).delete()
		return Response({"ok": True}, status=status.HTTP_200_OK)


class LikeProviderView(APIView):
	permission_classes = [IsAtLeastPhoneOnly]

	def post(self, request, provider_id: int):
		provider = generics.get_object_or_404(ProviderProfile, id=provider_id)
		ProviderLike.objects.get_or_create(user=request.user, provider=provider)
		return Response({"ok": True}, status=status.HTTP_200_OK)


class UnlikeProviderView(APIView):
	permission_classes = [IsAtLeastPhoneOnly]

	def post(self, request, provider_id: int):
		ProviderLike.objects.filter(user=request.user, provider_id=provider_id).delete()
		return Response({"ok": True}, status=status.HTTP_200_OK)
