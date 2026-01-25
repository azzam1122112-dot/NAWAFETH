from django.urls import path
from . import views

app_name = "dashboard"

urlpatterns = [
    path("", views.dashboard_home, name="home"),
    path("requests/", views.requests_list, name="requests_list"),
    path("requests/<int:request_id>/", views.request_detail, name="request_detail"),

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
