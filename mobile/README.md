# NAWAFETH Mobile

## API environment setup

The app now reads API configuration from `--dart-define` values.

Supported keys:
- `API_TARGET=auto|local|render`
- `API_BASE_URL=https://example.com` (highest priority if provided)
- `API_LOCAL_BASE_URL=http://192.168.1.10:8000` (optional local override)
- `API_RENDER_BASE_URL=https://nawafeth-backend.onrender.com` (optional render override)

Default behavior:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator / desktop: `http://127.0.0.1:8000`
- Web: `http://localhost:8000`

## Run commands

Use local backend API:

```bash
flutter run -d emulator-5554 --dart-define=API_TARGET=local
```

Use Render backend API:

```bash
flutter run -d emulator-5554 --dart-define=API_TARGET=render
```

Force a specific API URL (local or remote):

```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://nawafeth-backend.onrender.com
```
