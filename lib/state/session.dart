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

  /// [audience] is 'student' or 'staff' (the tab chosen on the login screen).
  Future<void> signIn(String loginId, String password, {String? audience}) async {
    await api.login(loginId.trim(), password, audience: audience);
    await _afterAuth();
  }

  /// Student self-registration: creates the account, then signs in exactly like [signIn].
  Future<void> registerStudent({
    required String studentId,
    required String fullName,
    required String phone,
    required String password,
    required String department,
    required StudyStream stream,
    String? email,
  }) async {
    await api.registerStudent(
      studentId: studentId.trim(),
      fullName: fullName.trim(),
      phone: phone.trim(),
      password: password,
      department: department.trim(),
      stream: stream,
      email: email?.trim(),
    );
    // Registration already succeeded. A profile-load error should lead to sign-in,
    // not back to a form that would try to create the same student a second time.
    try {
      await _afterAuth();
    } on ApiException {
      notice = 'Your account was created. Please sign in to continue.';
      _reset();
    }
  }

  Future<void> _afterAuth() async {
    try {
      await _loadProfile();
    } on ApiException {
      await api.logout();
      rethrow;
    }
  }

  /// A message shown once on the login screen (e.g. after a password reset).
  void setNotice(String message) {
    notice = message;
    notifyListeners();
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
