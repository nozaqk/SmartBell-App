#!/usr/bin/env bash
# Scaffold missing Android/iOS projects, then refresh the SmartBell icons and native settings.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter SDK (>= 3.27) is required: https://docs.flutter.dev/get-started/install"; exit 1; }

if [[ ! -f android/app/src/main/AndroidManifest.xml || ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
    # Remove only a sample test created by this invocation, never an existing test.
    new_widget_test=false
    [[ -e test/widget_test.dart ]] || new_widget_test=true
    flutter create --platforms=android,ios --org com.mozack --project-name smartbell .
    if [[ "$new_widget_test" == true ]]; then rm -f test/widget_test.dart; fi
fi
flutter pub get
dart run flutter_launcher_icons

python3 - <<'PY'
import re, pathlib

# --- Android: notification permission (Android 13+) and default channel for FCM ---
m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
if "POST_NOTIFICATIONS" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application', 1)
if "default_notification_channel_id" not in s:
    s = s.replace("</application>", '    <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="smartbell_bells"/>\n    </application>', 1)
if "com.google.firebase.messaging.default_notification_icon" not in s:
    s = s.replace("</application>", '    <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_launcher_foreground"/>\n    </application>', 1)
s = s.replace('android:label="smartbell"', 'android:label="SmartBell"')
m.write_text(s)

# --- iOS: allow remote notifications in the background and set the display name ---
p = pathlib.Path("ios/Runner/Info.plist")
t = p.read_text()
if "UIBackgroundModes" not in t:
    t = t.replace("</dict>\n</plist>", "\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>remote-notification</string>\n\t</array>\n</dict>\n</plist>")
t = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*", r"\1SmartBell", t)
p.write_text(t)

# --- Android Gradle: minSdk 23 + core library desugaring (needed by flutter_local_notifications) ---
import glob
for g in glob.glob("android/app/build.gradle*"):
    f = pathlib.Path(g); c = f.read_text(); kts = g.endswith(".kts")
    if "desugar_jdk_libs" in c:
        continue
    c = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23" if kts else "minSdkVersion 23", c)
    c = re.sub(r"(compileOptions\s*\{)", r"\1\n        " + ("isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"), c, count=1)
    dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
    c += "\ndependencies {\n    " + dep + "\n}\n"
    f.write_text(c)
    print("Patched", g)
print("Native settings applied.")
PY

cat <<'MSG'

Next (manual, see docs/FIREBASE.md and docs/BUILD.md):
  * Android: minSdk 23 and core library desugaring were applied automatically - check the diff of android/app/build.gradle(.kts).
  * iOS: open ios/Runner.xcworkspace, add the "Push Notifications" and "Background Modes > Remote notifications"
    capabilities, set your signing team, and upload an APNs key in the Firebase console.
MSG
