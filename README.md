# SmartBell mobile app

**Android download:** [latest.apk](https://github.com/nozaqk/SmartBell-App/releases/latest/download/latest.apk) · [Release notes](https://github.com/nozaqk/SmartBell-App/releases/latest).
One universal APK for sideload testing; not a Play Store build.

One Flutter app (Android + iOS) for **students and lecturers**. After sign-in the backend returns the user's role
and the app shows the matching experience; the backend enforces permissions on every request
(see [SmartBell-Backend](https://github.com/mozack777/SmartBell-Backend) `docs/API.md`).

| | Student | Lecturer |
|---|---|---|
| Sign-in | student ID + password | staff ID + password |
| Home | greeting, next-class countdown (course, code, lecturer, room), today's classes, latest alerts | next-lecture countdown (course, code, room, class group), today's lectures, my courses, latest alerts |
| Timetable | weekly timetable, day picker, cancelled classes | weekly teaching timetable |
| Alerts | bell / break / lunch, class starting & ending, cancellations, room changes, history, mark read | bell, upcoming lecture, timetable changes, cancellations, history |
| Extras | exam timetable, announcements | announcements + publish to a class group they teach |
| Profile | ID, programme, level, class groups, sign-out | ID, department, courses, sign-out |

Push (FCM → APNs on iOS): foreground, background and terminated handling, tap-to-open navigation
(`route` in the push data), token registration after sign-in, token refresh, token removal on sign-out.
Tokens: refresh token in Keychain / EncryptedSharedPreferences, access token in memory only, automatic rotation on 401.

## Verification
The Android workflow runs `flutter analyze`, `flutter test` and a release APK build. The API tests use a mock HTTP
client; a passing build does not verify sign-in against the live backend, push delivery on a device, or the iOS build.

## Quick start
```bash
./tool/setup_platforms.sh                 # once: generates android/ and ios/ and applies SmartBell settings
cp firebase.env.example firebase.env      # fill in
flutter run --dart-define-from-file=firebase.env
flutter analyze && flutter test
```
By default the app uses `https://smartbell-backend.onrender.com`. To use a different backend, set `API_URL` in
`firebase.env` to its origin (no trailing slash or `/api/v1`). Without Firebase values, push is disabled.
See [the build and CI guide](docs/BUILD.md) and [Firebase setup](docs/FIREBASE.md).
