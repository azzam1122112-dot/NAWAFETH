from django.urls import re_path

from .consumers import RequestChatConsumer, ThreadConsumer

websocket_urlpatterns = [
	re_path(r"ws/requests/(?P<request_id>\d+)/$", RequestChatConsumer.as_asgi()),
	re_path(r"ws/thread/(?P<thread_id>\d+)/$", ThreadConsumer.as_asgi()),
]
