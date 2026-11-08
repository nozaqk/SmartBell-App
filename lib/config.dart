/// Build-time configuration, injected with --dart-define (see README). Nothing secret lives here:
/// Firebase client keys identify the project but do not grant admin access.
class AppConfig {
  /// Backend base URL without trailing slash. 10.0.2.2 reaches the host machine from the Android emulator.
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

  /// Optional: pins login to one school when several share the backend.
  static const schoolSlug = String.fromEnvironment('SCHOOL_SLUG', defaultValue: '');

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const firebaseAppIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseIosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.mozack.smartbell');

  static bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseSenderId.isNotEmpty && firebaseProjectId.isNotEmpty;
}
