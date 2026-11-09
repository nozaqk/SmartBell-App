# Build guide

Requirements: Flutter >= 3.27 (Dart >= 3.6), Android Studio (Android SDK), Xcode 15+ for iOS (macOS only).

1. `./tool/setup_platforms.sh` — runs `flutter create --platforms=android,ios --org com.mozack --project-name smartbell .`
   (keeps `lib/` and `pubspec.yaml`), adds the INTERNET / POST_NOTIFICATIONS permissions, the FCM default channel
   `smartbell_bells` and the iOS `remote-notification` background mode.
2. Android: `setup_platforms.sh` sets `minSdk = 23` and core library desugaring (needed by flutter_local_notifications); check the diff of `android/app/build.gradle(.kts)`.
3. Configuration is passed at build time (no secrets in the repo):
   `--dart-define-from-file=firebase.env` (see `firebase.env.example`). `API_URL` must be the HTTPS backend URL in release builds.
   On the Android emulator the default `http://10.0.2.2:3000` reaches a backend running on your computer.
4. Run / test: `flutter run --dart-define-from-file=firebase.env`, `flutter analyze`, `flutter test`.

## Release
* Android: create a keystore, put its details in `android/key.properties` (git-ignored), configure signing in
  `android/app/build.gradle(.kts)`, then `flutter build appbundle --dart-define-from-file=firebase.env` (Play Store)
  or `flutter build apk --release ...`.
* iOS: set the bundle id `com.mozack.smartbell` and signing team in Xcode, then
  `flutter build ipa --dart-define-from-file=firebase.env` and upload with Xcode Organizer / Transporter.

## GitHub pre-release (no GitHub Actions)
`./tool/build_release.sh` analyses, tests, builds the release APK and publishes it as a **pre-release** (`v<version>-pre`)
with the GitHub CLI. Run it where Flutter, the Android SDK and `gh auth login` are available (your computer or a Codespace).
Bump `version:` in `pubspec.yaml` for each release. Use `--no-publish` to build only. The APK embeds the Firebase client keys
and API URL from `firebase.env`, so publish it only from a repository you are comfortable sharing those with.
