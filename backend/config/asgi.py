import os

# Ensure Django settings are configured before importing anything that touches
# django.conf.settings (e.g., authentication models).
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django
from django.core.asgi import get_asgi_application

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

django.setup()

http_app = get_asgi_application()

# Import websocket components only after Django is initialized.
from apps.messaging.jwt_auth import JwtAuthMiddleware  # noqa: E402
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
