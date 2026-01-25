from django.urls import path

from .views import (
    PromoRequestCreateView,
    MyPromoRequestsListView,
    PromoRequestDetailView,
    PromoAddAssetView,

    BackofficePromoRequestsListView,
    BackofficeQuoteView,
    BackofficeRejectView,
)

urlpatterns = [
    # client
    path("requests/create/", PromoRequestCreateView.as_view(), name="create"),
    path("requests/my/", MyPromoRequestsListView.as_view(), name="my"),
    path("requests/<int:pk>/", PromoRequestDetailView.as_view(), name="detail"),
    path("requests/<int:pk>/assets/", PromoAddAssetView.as_view(), name="add_asset"),

    # backoffice
    path("backoffice/requests/", BackofficePromoRequestsListView.as_view(), name="bo_list"),
    path("backoffice/requests/<int:pk>/quote/", BackofficeQuoteView.as_view(), name="bo_quote"),
    path("backoffice/requests/<int:pk>/reject/", BackofficeRejectView.as_view(), name="bo_reject"),
]
