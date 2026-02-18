from django.urls import path

from .views import (
    GetOrCreateThreadView,
    MarkThreadReadView,
    SendMessageView,
    ThreadMessagesListView,
    post_message,
    DirectThreadGetOrCreateView,
    DirectThreadMessagesListView,
    DirectThreadSendMessageView,
    DirectThreadMarkReadView,
    MyDirectThreadsListView,
    MyThreadStatesListView,
    ThreadStateDetailView,
    ThreadFavoriteView,
    ThreadArchiveView,
    ThreadBlockView,
    ThreadReportView,
)

app_name = "messaging"

urlpatterns = [
    path("requests/<int:request_id>/thread/", GetOrCreateThreadView.as_view(), name="thread_get_or_create"),
    path("requests/<int:request_id>/messages/", ThreadMessagesListView.as_view(), name="messages_list"),
    path("requests/<int:request_id>/messages/send/", SendMessageView.as_view(), name="message_send"),
    path("requests/<int:request_id>/messages/read/", MarkThreadReadView.as_view(), name="thread_mark_read"),

    # Dashboard fallback (session + CSRF) for sending messages when WS is not connected
    path("thread/<int:thread_id>/post/", post_message, name="post_message"),

    # Direct messaging (no request required)
    path("direct/thread/", DirectThreadGetOrCreateView.as_view(), name="direct_thread_get_or_create"),
    path("direct/thread/<int:thread_id>/messages/", DirectThreadMessagesListView.as_view(), name="direct_messages_list"),
    path("direct/thread/<int:thread_id>/messages/send/", DirectThreadSendMessageView.as_view(), name="direct_message_send"),
    path("direct/thread/<int:thread_id>/messages/read/", DirectThreadMarkReadView.as_view(), name="direct_thread_mark_read"),
    path("direct/threads/", MyDirectThreadsListView.as_view(), name="direct_threads_list"),

    # Per-user thread state (favorite / block / archive)
    path("threads/states/", MyThreadStatesListView.as_view(), name="my_thread_states"),
    path("thread/<int:thread_id>/state/", ThreadStateDetailView.as_view(), name="thread_state"),
    path("thread/<int:thread_id>/favorite/", ThreadFavoriteView.as_view(), name="thread_favorite"),
    path("thread/<int:thread_id>/archive/", ThreadArchiveView.as_view(), name="thread_archive"),
    path("thread/<int:thread_id>/block/", ThreadBlockView.as_view(), name="thread_block"),
    path("thread/<int:thread_id>/report/", ThreadReportView.as_view(), name="thread_report"),
]
