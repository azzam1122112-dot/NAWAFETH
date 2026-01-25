from django.urls import path

from .views import (
    VerificationRequestCreateView,
    MyVerificationRequestsListView,
    VerificationRequestDetailView,
    VerificationAddDocumentView,

    BackofficeVerificationRequestsListView,
    BackofficeDecideDocumentView,
    BackofficeFinalizeRequestView,
)

urlpatterns = [
    # client
    path("requests/create/", VerificationRequestCreateView.as_view(), name="create"),
    path("requests/my/", MyVerificationRequestsListView.as_view(), name="my"),
    path("requests/<int:pk>/", VerificationRequestDetailView.as_view(), name="detail"),
    path("requests/<int:pk>/documents/", VerificationAddDocumentView.as_view(), name="add_document"),

    # backoffice
    path("backoffice/requests/", BackofficeVerificationRequestsListView.as_view(), name="bo_list"),
    path("backoffice/documents/<int:doc_id>/decision/", BackofficeDecideDocumentView.as_view(), name="bo_decide_doc"),
    path("backoffice/requests/<int:pk>/finalize/", BackofficeFinalizeRequestView.as_view(), name="bo_finalize"),
]
