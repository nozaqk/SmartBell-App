# SmartBell mobile app

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

## Status — read this
This code was written in an environment **without the Flutter/Dart SDK** (pub.dev and Google storage were
unreachable), so it has **not been compiled, analysed or run**, and the tests in `test/` have **not been executed**.
Before shipping, run `flutter pub get`, `flutter analyze` and `flutter test` and fix anything they report.
Push delivery on real Android and iOS devices is likewise unverified.

## Quick start
```bash
./tool/setup_platforms.sh                 # once: generates android/ and ios/ and applies SmartBell settings
cp firebase.env.example firebase.env      # fill in
flutter run --dart-define-from-file=firebase.env
flutter analyze && flutter test
```
Without Firebase values the app still works; push is simply disabled. Details: [docs/BUILD.md](docs/BUILD.md),
[docs/FIREBASE.md](docs/FIREBASE.md). No GitHub Actions are used.
