from .base import *  # noqa

import os

import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration

DEBUG = False

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

SECURE_HSTS_SECONDS = 60 * 60 * 24 * 30
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

X_FRAME_OPTIONS = "DENY"
SECURE_REFERRER_POLICY = "same-origin"

# CORS (Production)
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [
	"https://nawafeth.app",
	"https://admin.nawafeth.app",
]

# CSP (Production) - requires django-csp
INSTALLED_APPS += ["csp"]
if "csp.middleware.CSPMiddleware" not in MIDDLEWARE:
	# Place near the top (after SecurityMiddleware is typical)
	try:
		sec_i = MIDDLEWARE.index("django.middleware.security.SecurityMiddleware")
		MIDDLEWARE.insert(sec_i + 1, "csp.middleware.CSPMiddleware")
	except ValueError:
		MIDDLEWARE.insert(0, "csp.middleware.CSPMiddleware")

CSP_DEFAULT_SRC = ("'self'",)
CSP_IMG_SRC = ("'self'", "data:", "https:")
CSP_STYLE_SRC = ("'self'", "'unsafe-inline'", "https:")
CSP_SCRIPT_SRC = ("'self'", "'unsafe-inline'", "https:")

# Sentry
SENTRY_DSN = os.getenv("SENTRY_DSN", "")
if SENTRY_DSN:
	sentry_sdk.init(
		dsn=SENTRY_DSN,
		integrations=[DjangoIntegration()],
		traces_sample_rate=0.2,
		send_default_pii=False,
	)

# Structured logging
LOGGING = {
	"version": 1,
	"disable_existing_loggers": False,
	"handlers": {
		"console": {"class": "logging.StreamHandler"},
	},
	"root": {"handlers": ["console"], "level": "INFO"},
}
