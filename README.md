# Olewser Android (Flutter)

Flutter Android app for Olewser with:
- built-in WebView browser
- draggable AI panel
- models: `Pro 3.0`, `Fast 3.0`, `Think 3.0`
- open-page analysis action
- basic ad/tracker blocking by host patterns

## Run

```bash
flutter pub get
flutter run \
  --dart-define=NVIDIA_API_KEY=your_nvidia_key \
  --dart-define=NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
```

## Build APK

```bash
flutter build apk --release \
  --dart-define=NVIDIA_API_KEY=your_nvidia_key \
  --dart-define=NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
```

## Notes

- API key is not hardcoded in source.
- If `NVIDIA_API_KEY` is missing, AI requests will fail with explicit error text in chat.
- Current package id: `com.oleksandrcorp.olewser_android`.
