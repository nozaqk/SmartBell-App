import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../state/nav_state.dart';

const bellChannelId = 'smartbell_bells'; // must match the channel id the backend sets on Android pushes

FirebaseOptions firebaseOptions() => FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      appId: Platform.isIOS ? AppConfig.firebaseAppIdIos : AppConfig.firebaseAppIdAndroid,
      messagingSenderId: AppConfig.firebaseSenderId,
      projectId: AppConfig.firebaseProjectId,
      iosBundleId: AppConfig.firebaseIosBundleId,
    );

/// Runs in a separate isolate when a data/notification message arrives with the app in the background.
/// Notification messages are shown by the OS; this only needs Firebase to be initialised.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!AppConfig.firebaseConfigured) return;
  await Firebase.initializeApp(options: firebaseOptions());
}

/// Firebase Cloud Messaging for Android and iOS (APNs). Does nothing when Firebase is not configured
/// (no --dart-define values), so the rest of the app still works.
class PushService {
  PushService(this.api, this.nav, {required this.isSignedIn});
  final ApiClient api;
  final NavState nav;
  final bool Function() isSignedIn;

  /// Set by the app: refresh visible data when a push arrives in the foreground.
  Future<void> Function()? onForegroundPush;

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _registeredToken;

  bool get enabled => _ready;

  Future<void> init() async {
    if (!AppConfig.firebaseConfigured) return;
    try {
      await Firebase.initializeApp(options: firebaseOptions());
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final fm = FirebaseMessaging.instance;

    await _local.initialize(
      const InitializationSettings(
        // Android small icons use the bell's alpha mask, not the full adaptive launcher tile.
        android: AndroidInitializationSettings('ic_launcher_foreground'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) => nav.routeFromPush(r.payload, ready: isSignedIn()),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          bellChannelId,
          'Bell and class alerts',
          description: 'School bell, class reminders, cancellations and announcements',
          importance: Importance.high,
        ));

    // iOS shows banners for foreground pushes itself; Android needs a local notification (below).
    await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => nav.routeFromPush(m.data['route'] as String?, ready: isSignedIn()));
    fm.onTokenRefresh.listen((t) {
      if (isSignedIn()) _register(t);
    });

    final initial = await fm.getInitialMessage(); // app launched by tapping a push
    if (initial != null) nav.routeFromPush(initial.data['route'] as String?, ready: false);
    _ready = true;
  }

  Future<void> _onForeground(RemoteMessage m) async {
    if (!kIsWeb && Platform.isAndroid) {
      final n = m.notification;
      if (n != null) {
        await _local.show(
          m.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(bellChannelId, 'Bell and class alerts', importance: Importance.high, priority: Priority.high),
          ),
          payload: m.data['route'] as String?,
        );
      }
    }
    await onForegroundPush?.call();
  }

  /// After sign-in: ask permission (iOS and Android 13+), then register this device's token with the backend.
  Future<void> onSignedIn() async {
    if (!_ready) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      final token = await fm.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
    nav.applyPending();
  }

  Future<void> _register(String token) async {
    try {
      await api.post('/mobile/push-tokens', body: {'token': token, 'platform': Platform.isIOS ? 'IOS' : 'ANDROID'});
      _registeredToken = token;
    } on ApiException catch (e) {
      debugPrint('Push token upload failed: ${e.message}');
    }
  }

  Future<String?> currentToken() async {
    if (!_ready) return null;
    try {
      return _registeredToken ?? await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// After logout the backend has already removed the token; also drop it on-device so the next
  /// account on this phone gets a fresh one.
  Future<void> onSignedOut() async {
    _registeredToken = null;
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
