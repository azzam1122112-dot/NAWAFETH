# Render deployment notes (backend)

## Health checks

- Liveness: `GET /health/live/` (always returns 200 when the process is up)
- Readiness: `GET /health/ready/` (checks DB + Redis and returns 503 if a dependency is down)

Render health checks should typically point at the liveness endpoint.

## Redis for Channels

`REDIS_URL` enables the Redis channel layer automatically.
On Render, define a Key Value instance and set `REDIS_URL` to its internal connection string.

## DB backups

Render Postgres backups are configured in the Render dashboard (not in code).
Recommended production setup:

- Upgrade Postgres to a plan that supports automated backups.
- Enable automated backups and verify retention settings.
- For extra safety, schedule periodic off-platform exports (e.g. `pg_dump`) to an external storage provider.

### Manual export

1. In Render, open your Postgres instance and copy the connection string.
2. Run `pg_dump` from your local machine:

- `pg_dump "<connection_string>" --format=custom --file backup.dump`

Keep the dump file in a safe location.

## OTP staging test mode (internal QA)

Production should use a real SMS provider.

For staging/internal testing only, you can enable a guarded test mode that returns `dev_code` from `POST /api/accounts/otp/send/` **only** when a secret header matches.

- Set env vars on the Render service (staging only):
	- `OTP_TEST_MODE=1`
	- `OTP_TEST_KEY=<random-long-secret>`
	- (optional) `OTP_TEST_HEADER=X-OTP-TEST-KEY`

Then call:

- `POST /api/accounts/otp/send/` with header `X-OTP-TEST-KEY: <OTP_TEST_KEY>`

Safety:

- This is forced off in production settings.
