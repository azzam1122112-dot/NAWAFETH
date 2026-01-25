from .base import *  # noqa

import os

import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration

DEBUG = False

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

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

# CSRF trusted origins (Render/custom domains)
_csrf_env = os.getenv("DJANGO_CSRF_TRUSTED_ORIGINS", "").strip()
CSRF_TRUSTED_ORIGINS = [
	"https://*.onrender.com",
	"https://nawafeth.app",
	"https://admin.nawafeth.app",
]
if _csrf_env:
	CSRF_TRUSTED_ORIGINS = [o.strip() for o in _csrf_env.split(",") if o.strip()]

# CSP (Production) - django-csp v4+ format
INSTALLED_APPS += ["csp"]
if "csp.middleware.CSPMiddleware" not in MIDDLEWARE:
	# Place near the top (after SecurityMiddleware is typical)
	try:
		sec_i = MIDDLEWARE.index("django.middleware.security.SecurityMiddleware")
		MIDDLEWARE.insert(sec_i + 1, "csp.middleware.CSPMiddleware")
	except ValueError:
		MIDDLEWARE.insert(0, "csp.middleware.CSPMiddleware")

CONTENT_SECURITY_POLICY = {
	"DIRECTIVES": {
		"default-src": ("'self'",),
		"img-src": ("'self'", "data:", "https:"),
		"style-src": ("'self'", "'unsafe-inline'", "https:"),
		"script-src": ("'self'", "'unsafe-inline'", "https:"),
	}
}

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
