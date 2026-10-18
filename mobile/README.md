# Veritus AI: Android app

A Flutter app for checking claims on your phone, built around WhatsApp: share a forward into the app and get evidence back.

<p align="center">
  <img src="../docs/screenshots/mobile-splash.jpg" alt="Splash" width="160" />
  <img src="../docs/screenshots/mobile-home.jpg" alt="Home" width="160" />
  <img src="../docs/screenshots/mobile-check.jpg" alt="Check" width="160" />
  <img src="../docs/screenshots/mobile-result.jpg" alt="Result" width="160" />
  <img src="../docs/screenshots/mobile-radar.jpg" alt="Rumor Radar" width="160" />
</p>

## Features

- **Three tabs:** Home, Check and Radar, with a floating glass tab bar and the same look as the website.
- **Check:** paste text or a forward. Results show a verdict chip, confidence range and tappable evidence cards (tap to open, hold to copy).
- **Share to check:** Veritus appears in Android's share sheet. Share text from WhatsApp or a browser and it opens on the Check tab and runs.
- **Scan:** pick a screenshot and the text is read on the device (English and Roman Urdu), then checked.
- **Listen:** reads the result aloud.
- **Rumor Radar:** the same list as the website, with "Why it's here" and source links. Pull down to refresh.
- **Private:** the app stores only an anonymous install token on the device.

<p align="center"><img src="../docs/screenshots/mobile-result-detail.jpg" alt="Result with Listen and evidence" width="200" /></p>

## Requirements

Flutter with Dart 3.7 or newer, Android Studio (SDK and Java), and `flutter doctor` showing a green Android toolchain.

## Run

```bash
cd mobile
flutter pub get
flutter run
```

The app talks to `https://verifi.fastapicloud.dev` by default. To use a local backend (phone and PC on the same Wi-Fi):

```bash
flutter run --dart-define=API_BASE=http://<your-pc-lan-ip>:8000
```

## Build the APK

1. Make sure `pubspec.yaml` declares the logo asset:
   ```yaml
   flutter:
     assets:
       - assets/icon/icon.png
   ```
2. In `android/app/src/main/AndroidManifest.xml`, keep `<uses-permission android:name="android.permission.INTERNET"/>` above `<application`. Release builds fail to reach the network without it.
3. In `android/app/build.gradle.kts`, turn the code shrinker off inside `buildTypes { release { ... } }`:
   ```kotlin
   isMinifyEnabled = false
   isShrinkResources = false
   ```
   With it on, release builds crash the `shared_preferences` plugin (`NoSuchMethodError`) and every check fails, while debug builds work.
4. Build:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```
   The file is `build/app/outputs/flutter-apk/app-release.apk`. Copy it to the phone and install it (allow unknown sources).

### App icon from the logo

```bash
dart run flutter_launcher_icons
```

with this in `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#05060F"
  adaptive_icon_foreground: "assets/icon/icon.png"
```

## Project structure

```
lib/main.dart          App entry, Check tab, error messages
lib/splash.dart        Animated splash with the logo
lib/shell.dart         Tab bar and navigation
lib/home_page.dart     Home tab, particle field
lib/radar_page.dart    Rumor Radar tab
lib/result_card.dart   Result view, evidence tiles, Listen button
lib/glass.dart         Colours, glass cards, buttons, gradient text
lib/api_client.dart    Backend client: token, retry after 401, timeouts
lib/ocr.dart           On-device screenshot text reading
lib/fingerprint.dart, simhash.dart, normalize.dart   Claim fingerprinting
```

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| "Something went wrong" on the installed APK, works from `flutter run` | The shrinker is on. Turn it off (step 3 above) and rebuild |
| Every check fails with a network error | Missing INTERNET permission, or the installed APK is old and still points at a local IP. Rebuild and reinstall |
| First check takes up to a minute | The free backend was asleep. The client waits up to 60 seconds |
| R8 "Missing classes" error with ML Kit | Use the shrinker-off setting above, or add `-dontwarn com.google.mlkit.vision.text.**` rules |
| Kotlin Gradle Plugin warning from `flutter_tts` | Harmless for now |
