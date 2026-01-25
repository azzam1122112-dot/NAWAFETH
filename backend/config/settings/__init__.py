"""Settings package.

This project uses settings modules under config/settings/ (base/dev/prod).
Some entrypoints (e.g. ASGI/WSGI) may reference DJANGO_SETTINGS_MODULE=config.settings,
so we default to loading dev settings unless DJANGO_ENV=prod is set.
"""

import os


env = os.getenv("DJANGO_ENV", "dev").lower().strip()

if env == "prod":
	from .prod import *  # noqa
elif env == "base":
	from .base import *  # noqa
else:
	from .dev import *  # noqa
