# SmartBell mobile app

**Android download:** [latest.apk](https://github.com/nozaqk/SmartBell-App/releases/latest/download/latest.apk) · [Release notes](https://github.com/nozaqk/SmartBell-App/releases/latest).
Only the Latest release keeps an APK: one universal build for sideload testing, not for the Play Store.

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
| Profile | ID, department, stream (if returned), programme, level, class groups, sign-out | ID, department, courses, sign-out |

Push (FCM → APNs on iOS): foreground, background and terminated handling, tap-to-open navigation
(`route` in the push data), token registration after sign-in, token refresh, token removal on sign-out.
Tokens: refresh token in Keychain / EncryptedSharedPreferences, access token in memory only, automatic rotation on 401.

## Signing in and accounts
* The login screen has a **Student / Staff** selector. The choice is sent to the server, which rejects an ID used on the wrong tab (after the password is verified).
* **Create a student account** is available on the Student tab only (`lib/ui/register_screen.dart`). Staff accounts are created by administrators on the web dashboard; the sign-up endpoint cannot create anything but students. A school can switch sign-up off (school setting `studentSelfRegistration: false`).
  1. Enter name, student ID, phone, optional email and password. **Continue to review** keeps the draft in memory; it does not create an account or select a class.
  2. Check or edit name, student ID and email, **choose or type a department**, and select **Regular**, **Weekend** or **Evening**. Back keeps the draft; only **Create account** submits it.
* **Forgot password** (`lib/ui/forgot_password_screen.dart`) texts a 6-digit code to the phone number on the account and then sets the new password. It needs the backend's `SMS_PROVIDER` configured; otherwise the screen tells the user to ask the administrator.

### Student registration API contract
`GET /api/v1/auth/options` can supply a school-specific `departments` list (names or objects with a `name`).
If it is missing or empty, the app offers example suggestions; students can always type the actual name.
The final `POST /api/v1/auth/register-student` includes the reviewed identity, phone, password, `department`
(free text) and `stream` (`Regular`, `Weekend` or `Evening`). Blank email is omitted. No `classGroupId` or role is sent.
The backend must validate and persist both academic fields and return `student.department` and `student.stream`
in `/api/v1/mobile/me` for them to appear in Profile. Class assignment for timetables is separate.

## Verification
The Android workflow runs `flutter analyze`, `flutter test` and a release APK build. API and widget tests use a
mock HTTP client to check role selection, both registration steps (including validation, back, retries and the
final request), and SMS reset. They do not verify that a deployed backend persists the new fields, live account
creation, SMS or push delivery on a device, or the iOS build.

## Quick start
```bash
./tool/setup_platforms.sh                 # scaffold platforms and apply the SmartBell icons/settings
cp firebase.env.example firebase.env      # fill in
flutter run --dart-define-from-file=firebase.env
flutter analyze && flutter test
```
By default the app uses `https://smartbell-backend.onrender.com`. To use a different backend, set `API_URL` in
`firebase.env` to its origin (no trailing slash or `/api/v1`). Without Firebase values, push is disabled.
See [the build and CI guide](docs/BUILD.md) and [Firebase setup](docs/FIREBASE.md).
