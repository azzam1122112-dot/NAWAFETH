from django.urls import path

from .views import CreateReviewView, ProviderReviewsListView, ProviderRatingSummaryView

app_name = "reviews"

urlpatterns = [
    path("requests/<int:request_id>/review/", CreateReviewView.as_view(), name="create_review"),
    path("providers/<int:provider_id>/reviews/", ProviderReviewsListView.as_view(), name="provider_reviews"),
    path("providers/<int:provider_id>/rating/", ProviderRatingSummaryView.as_view(), name="provider_rating"),
]
