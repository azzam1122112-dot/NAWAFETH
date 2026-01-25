from django.urls import path

from .views import (
    MyNotificationsView,
    UnreadCountView,
    MarkReadView,
    MarkAllReadView,
    RegisterDeviceTokenView,
    DeleteOldNotificationsView,
)

app_name = "notifications"

urlpatterns = [
    path("", MyNotificationsView.as_view(), name="list"),
    path("unread-count/", UnreadCountView.as_view(), name="unread_count"),
    path("mark-read/<int:notif_id>/", MarkReadView.as_view(), name="mark_read"),
    path("mark-all-read/", MarkAllReadView.as_view(), name="mark_all_read"),
    path("delete-old/", DeleteOldNotificationsView.as_view(), name="delete_old"),
    path("device-token/", RegisterDeviceTokenView.as_view(), name="device_token"),
]
