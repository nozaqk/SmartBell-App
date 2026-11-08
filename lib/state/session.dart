import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../push/push_service.dart';

enum SessionStatus { starting, signedOut, signedIn }

/// Owns authentication. The role comes from the backend (/mobile/dashboard) after sign-in, and the UI picks
/// the student or lecturer experience from it. The server enforces permissions regardless of what the UI shows.
class Session extends ChangeNotifier {
  Session(this.api, this.push) {
    api.onSessionExpired = _expired;
  }
  final ApiClient api;
  final PushService push;

  SessionStatus status = SessionStatus.starting;
  Profile? profile;
  String? notice;

  Future<void> start() async {
    try {
      if (await api.restore()) {
        await _loadProfile();
        return;
      }
    } on ApiException {
      // Offline at launch with a stored token: stay signed out of memory but keep the token for the next try.
      notice = 'You are offline. Connect to the internet to continue.';
    }
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> signIn(String loginId, String password) async {
    await api.login(loginId.trim(), password);
    try {
      await _loadProfile();
    } on ApiException {
      await api.logout();
      rethrow;
    }
  }

  Future<void> _loadProfile() async {
    final j = await api.get('/mobile/me') as Map<String, dynamic>;
    profile = Profile.fromJson(j);
    status = SessionStatus.signedIn;
    notice = null;
    notifyListeners();
    await push.onSignedIn();
  }

  Future<void> signOut() async {
    final token = await push.currentToken();
    await api.logout(pushToken: token);
    await push.onSignedOut();
    _reset();
  }

  void _expired() {
    if (status == SessionStatus.signedOut) return;
    notice = 'Your session has ended. Please sign in again.';
    _reset();
  }

  void _reset() {
    profile = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }
}
