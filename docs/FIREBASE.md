# Firebase Cloud Messaging setup

The app only ever holds *client* identifiers. The Firebase **service-account key** lives on Render (backend) only — see the
backend's `docs/FIREBASE.md`.

1. Firebase console → create/open the project used by the backend.
2. Add an **Android app** with package `com.mozack.smartbell`, and an **iOS app** with bundle id `com.mozack.smartbell`.
3. From *Project settings → Your apps* copy: API key, project id, sender id (project number) and the two app ids into
   `firebase.env` (`FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_APP_ID_ANDROID`, `FIREBASE_APP_ID_IOS`).
   Firebase is initialised from these values in `lib/push/push_service.dart`, so `google-services.json` and
   `GoogleService-Info.plist` are not required (and are git-ignored if you add them).
4. **iOS / APNs:** Apple Developer → Keys → create an APNs Auth Key (.p8). Firebase console → Project settings →
   Cloud Messaging → *Apple app configuration* → upload the key with its Key ID and Team ID. In Xcode enable the
   *Push Notifications* capability and *Background Modes → Remote notifications*. Test on a real device (the simulator cannot receive APNs).
5. **Android 13+:** the app requests the notification permission after sign-in.

## How it works
* After sign-in the app registers its FCM token: `POST /api/v1/mobile/push-tokens {token, platform}`; `onTokenRefresh` re-registers it.
* Sign-out calls `POST /auth/logout` with the push token (backend deletes it), then deletes the token on the device.
* Pushes carry `data.route` (`notifications` | `timetable` | `announcements`); tapping one opens that screen,
  also from a cold start and when the tap happens before sign-in.
* Foreground pushes: iOS shows a banner; on Android the app shows a local notification on channel `smartbell_bells`
  and refreshes the dashboard, timetable and alerts.
