from django.urls import path
from . import views

app_name = "dashboard"

urlpatterns = [
    path("", views.dashboard_home, name="home"),
    path("requests/", views.requests_list, name="requests_list"),
    path("requests/<int:request_id>/", views.request_detail, name="request_detail"),

    path("providers/", views.providers_list, name="providers_list"),
    path("providers/<int:provider_id>/", views.provider_detail, name="provider_detail"),

    path("services/", views.services_list, name="services_list"),

    # Actions (POST)
    path(
        "providers/<int:provider_id>/services/<int:service_id>/actions/toggle-active/",
        views.provider_service_toggle_active,
        name="provider_service_toggle_active",
    ),

    # Actions (POST)
    path(
        "requests/<int:request_id>/actions/accept/",
        views.request_accept,
        name="request_accept",
    ),
    path(
        "requests/<int:request_id>/actions/send/",
        views.request_send,
        name="request_send",
    ),
    path(
        "requests/<int:request_id>/actions/start/",
        views.request_start,
        name="request_start",
    ),
    path(
        "requests/<int:request_id>/actions/complete/",
        views.request_complete,
        name="request_complete",
    ),
    path(
        "requests/<int:request_id>/actions/cancel/",
        views.request_cancel,
        name="request_cancel",
    ),
]
