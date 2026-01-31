from django.urls import path

from .views import (
    CategoryListView,
    FollowProviderView,
    LikeProviderView,
    MyFollowingProvidersView,
    MyLikedProvidersView,
    MyProviderFollowersView,
    MyProviderLikersView,
    MyProviderProfileView,
    ProviderCreateView,
    ProviderDetailView,
    ProviderListView,
    UnfollowProviderView,
    UnlikeProviderView,
)

app_name = "providers"

urlpatterns = [
    path("categories/", CategoryListView.as_view(), name="categories"),
    path("list/", ProviderListView.as_view(), name="provider_list"),
    path("me/profile/", MyProviderProfileView.as_view(), name="my_profile"),
    path("me/following/", MyFollowingProvidersView.as_view(), name="my_following"),
    path("me/likes/", MyLikedProvidersView.as_view(), name="my_likes"),
    path("me/followers/", MyProviderFollowersView.as_view(), name="my_followers"),
    path("me/likers/", MyProviderLikersView.as_view(), name="my_likers"),
    path("<int:pk>/", ProviderDetailView.as_view(), name="provider_detail"),
    path("register/", ProviderCreateView.as_view(), name="provider_register"),

    # Level-2+ social actions
    path("<int:provider_id>/follow/", FollowProviderView.as_view(), name="follow"),
    path("<int:provider_id>/unfollow/", UnfollowProviderView.as_view(), name="unfollow"),
    path("<int:provider_id>/like/", LikeProviderView.as_view(), name="like"),
    path("<int:provider_id>/unlike/", UnlikeProviderView.as_view(), name="unlike"),
]
