# Quick AL Flutter App

## Run locally

Use `QUICKAL_API_BASE_URL` to point the app at the backend you want to test.

```bash
flutter run --dart-define=QUICKAL_API_BASE_URL=http://127.0.0.1:8080
```

Android emulator fallback is still `http://10.0.2.2:8080` when no value is provided.

## Release builds

Internal testing and production-style builds should point to a deployed HTTPS API.

```bash
flutter build appbundle --dart-define=QUICKAL_API_BASE_URL=https://your-api.example.com
```