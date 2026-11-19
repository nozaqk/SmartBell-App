# Build guide

Requirements: Flutter >= 3.27 (Dart >= 3.6), Android Studio (Android SDK), Xcode 15+ for iOS (macOS only).

1. `./tool/setup_platforms.sh` scaffolds missing Android/iOS projects, generates their launcher icons and reapplies
   the INTERNET / POST_NOTIFICATIONS permissions, the FCM default icon and channel `smartbell_bells`, and the iOS
   `remote-notification` background mode. Rerun it after pulling a branding change, even in an existing checkout.
2. Android: `setup_platforms.sh` sets `minSdk = 23` and core library desugaring (needed by flutter_local_notifications); check the diff of `android/app/build.gradle(.kts)`.
3. Configuration is passed at build time (no secrets in the repo):
   `--dart-define-from-file=firebase.env` (see `firebase.env.example`). An omitted or empty `API_URL` uses
   `https://smartbell-backend.onrender.com`. To override it, use an HTTPS origin without `/api/v1` or a trailing slash.
   For local development on an Android emulator, use `API_URL=http://10.0.2.2:3000` to reach a backend on your computer.
4. Run / test: `flutter run --dart-define-from-file=firebase.env`, `flutter analyze`, `flutter test`.

## App icon
`assets/branding/supplied-icon.png` is the original artwork. The build uses an opaque, full-bleed version for iOS,
where the system applies the corner mask, and a rounded version for legacy Android and the sign-in screen.
Modern Android uses the transparent white bell over the artwork's teal (`#016A63`); themed icons and notification
small icons use the bell silhouette. `dart run flutter_launcher_icons` generates the native sizes from the inputs
in `pubspec.yaml`. Platform setup, local release builds and CI run it automatically; don't edit generated icons by hand.

## Release
* Android: create a keystore, put its details in `android/key.properties` (git-ignored), configure signing in
  `android/app/build.gradle(.kts)`, then `flutter build appbundle --dart-define-from-file=firebase.env` (Play Store)
  or `flutter build apk --release ...`.
* iOS: set the bundle id `com.mozack.smartbell` and signing team in Xcode, then
  `flutter build ipa --dart-define-from-file=firebase.env` and upload with Xcode Organizer / Transporter.

## Publish the Android APK
Open **Actions → Publish Android APK → Run workflow** and select the commit's branch. A normal run analyses, tests,
then builds one universal `latest.apk` and attaches it to a regular GitHub release marked **Latest**. Leave the tag
empty to use the app version (`1.0.0+1` → `v1.0.0`), enter a different `v`-prefixed tag, or trigger the workflow by
pushing a `v*` tag. For a new version, bump `version:` first. A tag must point at the commit being built.

* **Download:** [latest.apk](https://github.com/nozaqk/SmartBell-App/releases/latest/download/latest.apk) is the only APK kept across published GitHub releases. After a successful publish, the script checks that the new tag is **Latest** and its APK finished uploading, then removes the other `.apk` assets. Older release notes, tags, non-APK assets and unpublished drafts are preserved. GitHub's automatic ZIP and TAR.GZ source archives are not APKs.
* **Build without publishing:** check **Build without publishing** in the manual run. Use this for superseded versions rather than promoting them back to Latest. Download `latest-apk` under the run's **Artifacts** and unzip it to get `latest.apk` (retained for seven days).
* **Configuration:** the hosted backend is used by default. Optional repository secrets: `API_URL`, `SCHOOL_SLUG`, `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_APP_ID_ANDROID`. These are client configuration embedded in the APK; do not supply server credentials. The CI APK is debug-signed for testing, not Play Store distribution.

### Build locally instead
With Flutter, JDK 17, the Android SDK and `firebase.env` available, run `./tool/build_release.sh --no-publish`
to produce `build/latest.apk`. Omit `--no-publish` to publish it to this repository using the GitHub CLI (`gh auth login`).
