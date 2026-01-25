import os

import django
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from django.core.asgi import get_asgi_application

from apps.messaging.jwt_auth import JwtAuthMiddleware

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

django.setup()

http_app = get_asgi_application()

import apps.messaging.routing  # noqa: E402

application = ProtocolTypeRouter(
	{
		"http": http_app,
		"websocket": JwtAuthMiddleware(
			AuthMiddlewareStack(
				URLRouter(apps.messaging.routing.websocket_urlpatterns)
			)
		),
	}
)
