#!/usr/bin/env bash
# One-time: generate the Android and iOS projects around the existing lib/ and pubspec.yaml,
# then apply the SmartBell-specific native settings. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter SDK (>= 3.27) is required: https://docs.flutter.dev/get-started/install"; exit 1; }

flutter create --platforms=android,ios --org com.mozack --project-name smartbell .
flutter pub get

python3 - <<'PY'
import re, pathlib

# --- Android: notification permission (Android 13+) and default channel for FCM ---
m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
if "POST_NOTIFICATIONS" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application', 1)
if "default_notification_channel_id" not in s:
    s = s.replace("</application>", '    <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="smartbell_bells"/>\n    </application>', 1)
s = s.replace('android:label="smartbell"', 'android:label="SmartBell"')
m.write_text(s)

# --- iOS: allow remote notifications in the background and set the display name ---
p = pathlib.Path("ios/Runner/Info.plist")
t = p.read_text()
if "UIBackgroundModes" not in t:
    t = t.replace("</dict>\n</plist>", "\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>remote-notification</string>\n\t</array>\n</dict>\n</plist>")
t = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*", r"\1SmartBell", t)
p.write_text(t)
print("Native settings applied.")
PY

cat <<'MSG'

Next (manual, see docs/FIREBASE.md and docs/BUILD.md):
  * Android: raise minSdk to 23 and enable core library desugaring in android/app/build.gradle(.kts)
    (required by flutter_local_notifications).
  * iOS: open ios/Runner.xcworkspace, add the "Push Notifications" and "Background Modes > Remote notifications"
    capabilities, set your signing team, and upload an APNs key in the Firebase console.
MSG
