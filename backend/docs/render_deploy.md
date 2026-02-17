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
	- (optional) `OTP_TEST_CODE=0000` (forces a fixed code for QA)
	- (optional) `OTP_TEST_HEADER=X-OTP-TEST-KEY`

Then call:

- `POST /api/accounts/otp/send/` with header `X-OTP-TEST-KEY: <OTP_TEST_KEY>`

Safety:

- This is forced off in production settings.

## OTP app bypass (Flutter QA, staging/testing only)

⚠️ **For testing/staging environments ONLY** ⚠️

If your QA testers use the real Flutter app, sending a secret header is not practical.
For staging/testing only, you can enable an app bypass where `POST /api/accounts/otp/verify/` accepts **any** 4-digit code and issues JWT tokens **without headers**.

**Steps to enable on Render:**

1. Go to your Render Dashboard → **nawafeth-backend** service
2. Navigate to **Environment** tab
3. Add the following environment variable:
   - Key: `OTP_APP_BYPASS`
   - Value: `1`
4. (Optional) To restrict bypass to specific phone numbers, add:
   - Key: `OTP_APP_BYPASS_ALLOWLIST`
   - Value: `+9665xxxxxxx,+9665yyyyyyy` (comma-separated)
5. Click **Save Changes** (Render will auto-deploy)

**Behavior:**

- When allowlist is set, bypass works **only** for those phone numbers.
- Bypass requires an existing OTP record, so the client must still call `POST /api/accounts/otp/send/` first (this keeps cooldown/limits meaningful).
- Each bypass usage is logged with `phone` + `ip` for monitoring.

**Safety & Important Notes:**

- ⚠️ **SECURITY RISK**: Anyone can login with any 4 digits when enabled.
- ✅ Use ONLY for testing/staging environments with test data.
- ❌ **Remove or set to 0 before exposing to real users.**
- The setting is now configurable via environment variable (previously hardcoded off).

## Flutter QA test steps

1. `POST /api/accounts/otp/send/` with `{ "phone": "+9665..." }`
	- Expect `{ "ok": true }`
2. `POST /api/accounts/otp/verify/` with `{ "phone": "+9665...", "code": "1234" }`
	- In staging with `OTP_APP_BYPASS=1`, any 4 digits work
	- Expect `{ "access": "...", "refresh": "...", ... }`
3. `GET /api/accounts/me/` with header `Authorization: Bearer <access>`
	- Expect user profile JSON

Important:

- `OTP_TEST_MODE`, `OTP_TEST_CODE`, and `OTP_APP_BYPASS` must never be enabled in production.
