# GeoSnap

GeoSnap is an Android-first Flutter app for capturing live camera photos and permanently stamping GPS coordinates, accuracy, timestamp, optional resolved address, and an optional map preview onto the saved image.

It has no ads, subscriptions, analytics, tracking SDKs, sign-in, or cloud storage. Capture, GPS, watermarking, saving, and gallery browsing work offline. Address lookup and map thumbnails are best-effort only and never block saving.

## Features

- **Animated Splash Screen**: Verification of permissions with early native GPS warm-up and high-end transition animations.
- **Glassmorphic Live Viewfinder Overlay**: Camera controls overlay on live preview with rule-of-thirds grid alignment.
- **Camera Configurations**: Dynamic flash mode toggle (On, Off, Auto) and lens selection (Front vs Back camera) saved across sessions.
- **Fast Location Warm-Up**: Utilizes Kotlin `FusedLocationProviderClient` to query current precise location immediately alongside active stream updates.
- Live camera capture only, with no gallery import
- GPS status and accuracy display
- Capture lock until accuracy is below 20 meters
- Reverse geocoding when available
- Three watermark templates
- Configurable watermark position and visible fields
- Optional static map thumbnail when internet is available
- Public Android save location: `Pictures/GeoSnap/`
- In-app gallery with date search, preview, share, and delete
- Material 3 UI with Provider state management

## Requirements

- Flutter latest stable channel (compatible with Flutter 3.44.0+)
- Dart SDK `>=3.12.0 <4.0.0`
- Android SDK 36
- Java 17
- Gradle 8.14+ or a regenerated official Gradle wrapper

## Setup

```bash
flutter pub get
flutter run
```

## Main Dependencies

- Native Android CameraX `ImageCapture` for low-latency live capture
- `geolocator` and `geocoding` for GPS and address lookup
- Native Kotlin Canvas rendering for permanent JPEG watermarks
- `provider` for app state
- `permission_handler` for runtime permissions
- `share_plus` for gallery sharing
- `connectivity_plus` and `http` for optional map thumbnails
- `shared_preferences` for local settings

## Build APK

```bash
flutter build apk --release
```

The APK will be created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Android Permissions

The app requests camera, precise location, internet/network state for optional address/map features, and media image access where Android requires it. Saving uses Android MediaStore so photos appear in `Pictures/GeoSnap/` without broad file access.

## Privacy

GeoSnap does not include analytics, advertising SDKs, crash reporting SDKs, tracking, cloud sync, user accounts, or remote configuration.
