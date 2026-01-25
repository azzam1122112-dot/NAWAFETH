# Nawafeth – Demo Smoke Test (Phase 1)

Date: 2026-01-23

## Prerequisites

- Backend running locally:
  - `cd backend`
  - `C:/Users/manso/nawafeth/.venv/Scripts/python.exe manage.py runserver 8000`

Important:
- Do not use `python manage.py ...` unless your terminal is using the project `.venv`.
- Using system Python will fail with missing packages (e.g. `rest_framework_simplejwt`).

Safe commands (Windows):
- `backend/runserver_local.cmd`
- `backend/runserver_lan.cmd`
- Mobile app:
  - Android Emulator (recommended) OR physical Android device on same network.

### Base URL note

The app uses a local API base URL logic:
- Android Emulator: `http://10.0.2.2:8000`
- Other platforms/devices: `http://127.0.0.1:8000`

If demo is on a physical phone, `127.0.0.1` will NOT reach your PC.
- Use an emulator, or
- Put phone and PC on same Wi‑Fi and build the APK with a LAN base URL override.

### Physical device (recommended demo setup)

1) Run backend bound to LAN:

- `cd backend`
- `C:/Users/manso/nawafeth/.venv/Scripts/python.exe manage.py runserver 0.0.0.0:8000`

Or simply:
- `backend/runserver_lan.ps1`

Most reliable (no PowerShell policy issues):
- `backend/runserver_lan.cmd`

2) Build APK with `--dart-define`:

- `cd mobile`
- `flutter build apk --debug --dart-define=API_BASE_URL=http://<YOUR_PC_LAN_IP>:8000`

Example:
- `flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.20:8000`

Notes:
- Ensure Windows Firewall allows inbound TCP 8000.
- The APK will keep using the baked-in base URL, so rebuild if the IP changes.

## Demo APK (Debug)

Built artifact:
- `mobile/build/app/outputs/flutter-apk/app-debug.apk`

## Smoke Test Flows

### 1) Login / OTP

1. Open app → go to Login.
2. Enter phone number.
3. Tap “Send OTP”.
4. Enter OTP.
5. Tap “Verify”.

Expected:
- Login succeeds.
- App navigates to Home.
- Subsequent API calls work (token attached automatically).

### 2) Orders + Filters

1. Go to “طلبات العميل”.
2. Confirm list loads.
3. Try search text, then Apply.
4. Try status filter (e.g. `new`, `accepted`), then Apply.
5. Try type filter (`competitive` / `urgent`), then Apply.

Expected:
- Results update according to filters.
- Empty state handled.

### 3) Order Details

1. Tap an order.

Expected:
- Details screen loads request info.
- Offers list loads (if any).

### 4) Chat (REST)

1. From order details, open Chat.
2. Confirm messages load.
3. Send a message.
4. Tap “تحميل المزيد” (if available) to paginate.

Expected:
- Messages show bubbles (mine vs others), with timestamp.
- Send works and the message appears.

### 5) Notifications

1. Go to Notifications.
2. Confirm list loads.
3. Verify read vs unread style difference.
4. Tap “تحديد كمقروء” on an unread item.
5. Tap “تحديد الكل كمقروء”.
6. Tap “تحميل المزيد” if there are multiple pages.

Expected:
- Marking read updates UI immediately.
- Pagination loads additional items.

## Troubleshooting

- If APIs fail with 401:
  - Re-login to refresh stored token.
- If build fails on Windows Android toolchain:
  - Run `flutter doctor -v` and fix Android SDK / JDK issues.
  - Re-run: `flutter build apk --debug`.
