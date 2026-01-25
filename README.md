# NAWAFETH

## Backend (Django) on Render

This repo contains:
- `backend/`: Django + DRF + Channels (WebSockets)
- `mobile/`: Flutter app

### Render deployment
A Render Blueprint is provided in `render.yaml`.

**Required Render environment variables**
- `DJANGO_SECRET_KEY`
- `DATABASE_URL` (Render Postgres)
- `REDIS_URL` (Render Redis) — required for Channels/WebSockets in production

**Recommended**
- `DJANGO_ALLOWED_HOSTS` (comma-separated) e.g. `nawafeth-backend.onrender.com,nawafeth.app,admin.nawafeth.app`
- `CORS_ALLOW_ALL=0`
- `CORS_ALLOWED_ORIGINS=https://nawafeth.app,https://admin.nawafeth.app`
- `DJANGO_CSRF_TRUSTED_ORIGINS=https://nawafeth.app,https://admin.nawafeth.app,https://*.onrender.com`

**Notes**
- Static files are served via WhiteNoise (collectstatic runs at build time).
- Media uploads in `backend/media/` are ephemeral on Render; use object storage (e.g. S3) for persistent media.
