from django.urls import path

from .views import GetOrCreateThreadView, MarkThreadReadView, SendMessageView, ThreadMessagesListView, post_message

app_name = "messaging"

urlpatterns = [
    path("requests/<int:request_id>/thread/", GetOrCreateThreadView.as_view(), name="thread_get_or_create"),
    path("requests/<int:request_id>/messages/", ThreadMessagesListView.as_view(), name="messages_list"),
    path("requests/<int:request_id>/messages/send/", SendMessageView.as_view(), name="message_send"),
    path("requests/<int:request_id>/messages/read/", MarkThreadReadView.as_view(), name="thread_mark_read"),

    # Dashboard fallback (session + CSRF) for sending messages when WS is not connected
    path("thread/<int:thread_id>/post/", post_message, name="post_message"),
]
