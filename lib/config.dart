/// Build-time configuration, injected with --dart-define (see README). Nothing secret lives here:
/// Firebase client keys identify the project but do not grant admin access.
class AppConfig {
  static const _apiUrlOverride = String.fromEnvironment('API_URL');

  /// Backend origin only; ApiClient adds /api/v1. An unset or empty override uses the hosted backend.
  static const apiUrl = _apiUrlOverride == ''
      ? 'https://smartbell-backend.onrender.com'
      : _apiUrlOverride;

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
