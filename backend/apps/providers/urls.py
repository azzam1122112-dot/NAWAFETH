from django.urls import path

from .views import (
    CategoryListView,
    FollowProviderView,
    LikeProviderView,
    LikePortfolioItemView,
    MyFollowingProvidersView,
    MyLikedProvidersView,
    MyLikedPortfolioItemsView,
    MyProviderFollowersView,
    MyProviderLikersView,
    MyProviderProfileView,
    MyProviderServiceDetailView,
    MyProviderServicesListCreateView,
    MyProviderSubcategoriesView,
    MyProviderPortfolioListCreateView,
    ProviderServicesPublicListView,
    ProviderCreateView,
    ProviderDetailView,
    ProviderFollowersView,
    ProviderFollowingView,
    ProviderListView,
    ProviderPortfolioListView,
    UnfollowProviderView,
    UnlikeProviderView,
    UnlikePortfolioItemView,
)

app_name = "providers"

urlpatterns = [
    path("categories/", CategoryListView.as_view(), name="categories"),
    path("list/", ProviderListView.as_view(), name="provider_list"),
    path("me/profile/", MyProviderProfileView.as_view(), name="my_profile"),
    path("me/subcategories/", MyProviderSubcategoriesView.as_view(), name="my_subcategories"),
    path("me/services/", MyProviderServicesListCreateView.as_view(), name="my_services"),
    path("me/services/<int:pk>/", MyProviderServiceDetailView.as_view(), name="my_service_detail"),
    path("me/following/", MyFollowingProvidersView.as_view(), name="my_following"),
    path("me/likes/", MyLikedProvidersView.as_view(), name="my_likes"),
    path("me/followers/", MyProviderFollowersView.as_view(), name="my_followers"),
    path("me/likers/", MyProviderLikersView.as_view(), name="my_likers"),

    # Portfolio (provider projects/media)
    path("me/portfolio/", MyProviderPortfolioListCreateView.as_view(), name="my_portfolio"),
    path("me/favorites/", MyLikedPortfolioItemsView.as_view(), name="my_favorites_media"),
    path("<int:provider_id>/portfolio/", ProviderPortfolioListView.as_view(), name="provider_portfolio"),
    path("<int:provider_id>/services/", ProviderServicesPublicListView.as_view(), name="provider_services"),
    path("<int:provider_id>/followers/", ProviderFollowersView.as_view(), name="provider_followers"),
    path("<int:provider_id>/following/", ProviderFollowingView.as_view(), name="provider_following"),
    path("portfolio/<int:item_id>/like/", LikePortfolioItemView.as_view(), name="portfolio_like"),
    path("portfolio/<int:item_id>/unlike/", UnlikePortfolioItemView.as_view(), name="portfolio_unlike"),
    path("<int:pk>/", ProviderDetailView.as_view(), name="provider_detail"),
    path("register/", ProviderCreateView.as_view(), name="provider_register"),

    # Level-2+ social actions
    path("<int:provider_id>/follow/", FollowProviderView.as_view(), name="follow"),
    path("<int:provider_id>/unfollow/", UnfollowProviderView.as_view(), name="unfollow"),
    path("<int:provider_id>/like/", LikeProviderView.as_view(), name="like"),
    path("<int:provider_id>/unlike/", UnlikeProviderView.as_view(), name="unlike"),
]
