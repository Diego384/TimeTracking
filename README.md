# time_tracking

A Flutter time-tracking application for Cooperativa Oltre i Sogni.

## Sync Port

The web synchronisation feature communicates with a backend server via HTTP.
The backend server (built with FastAPI/Uvicorn) listens on **port 8000** by default.

When configuring the server URL in the app's setup screen, include the port in the URL:

```
http://<server-address>:8000
```

The app will POST data to `<server-url>/api/sync` using the API key provided.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
