import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code, this.details});
  final int status;
  final String message;
  final String? code;

  /// The server's `details` field: validation problems or, for a 409 clash, `{conflicts: [...]}`.
  final dynamic details;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}

/// Thin REST client for /api/v1. Sends the bearer token, refreshes it once on 401 (single-flight,
/// refresh tokens rotate) and signals [onSessionExpired] when the refresh token is no longer valid.
class ApiClient {
  ApiClient({required this.baseUrl, required this.store, http.Client? client, this.schoolSlug = ''})
      : _http = client ?? http.Client();

  final String baseUrl;
  final String schoolSlug;
  final TokenStore store;
  final http.Client _http;
  String? _access;
  Future<bool>? _refreshing;
  void Function()? onSessionExpired;

  bool get hasAccessToken => _access != null;

  Uri _uri(String path, [Map<String, String>? q]) => Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: q == null || q.isEmpty ? null : q);

  /// [audience] is the role tab chosen on the login screen: 'student' or 'staff'. The server rejects a mismatch.
  Future<Map<String, dynamic>> login(String loginId, String password, {String? audience}) async {
    final res = await _send('POST', '/auth/login', body: {
      'loginId': loginId,
      'password': password,
      if (audience != null) 'audience': audience,
      if (schoolSlug.isNotEmpty) 'schoolSlug': schoolSlug,
    }, auth: false);
    return _adoptTokens(res as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _adoptTokens(Map<String, dynamic> j) async {
    _access = j['accessToken'] as String;
    await store.writeRefresh(j['refreshToken'] as String);
    return j;
  }

  /// Public department suggestions and availability of student sign-up and SMS reset.
  Future<AuthOptions> authOptions() async {
    final res = await _send('GET', '/auth/options', query: {if (schoolSlug.isNotEmpty) 'schoolSlug': schoolSlug}, auth: false);
    return AuthOptions.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Student self-registration (staff accounts are created by the administrator). Signs the new student in.
  Future<Map<String, dynamic>> registerStudent({
    required String studentId,
    required String fullName,
    required String phone,
    required String password,
    required String department,
    required StudyStream stream,
    String? email,
  }) async {
    final res = await _send('POST', '/auth/register-student', body: {
      'studentId': studentId,
      'fullName': fullName,
      'phone': phone,
      'password': password,
      'department': department,
      'stream': stream.label,
      if (email != null && email.isNotEmpty) 'email': email,
      if (schoolSlug.isNotEmpty) 'schoolSlug': schoolSlug,
    }, auth: false);
    return _adoptTokens(res as Map<String, dynamic>);
  }

  /// Asks the server to SMS a 6-digit code. The answer is the same whether or not the ID exists.
  Future<String> forgotPassword(String loginId) async {
    final res = await _send('POST', '/auth/forgot-password', body: {
      'loginId': loginId,
      if (schoolSlug.isNotEmpty) 'schoolSlug': schoolSlug,
    }, auth: false);
    return (res is Map ? res['message'] as String? : null) ?? 'If this ID has a phone number on file, a reset code has been sent by SMS.';
  }

  Future<void> resetPassword({required String loginId, required String code, required String newPassword}) async {
    await _send('POST', '/auth/reset-password', body: {
      'loginId': loginId,
      'code': code,
      'newPassword': newPassword,
      if (schoolSlug.isNotEmpty) 'schoolSlug': schoolSlug,
    }, auth: false);
  }

  /// Restores a session from the stored refresh token. Returns false when there is none or it was rejected.
  Future<bool> restore() async => _refresh();

  Future<void> logout({String? pushToken}) async {
    final refresh = await store.readRefresh();
    try {
      if (refresh != null) {
        await _send('POST', '/auth/logout', body: {'refreshToken': refresh, if (pushToken != null) 'pushToken': pushToken}, auth: false);
      }
    } on ApiException {
      // Offline or already revoked: local sign-out must still succeed.
    }
    _access = null;
    await store.clear();
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) => _send('POST', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', path, body: body);

  Future<bool> _refresh() {
    return _refreshing ??= () async {
      try {
        final token = await store.readRefresh();
        if (token == null) return false;
        final res = await _send('POST', '/auth/refresh', body: {'refreshToken': token}, auth: false);
        final j = res as Map<String, dynamic>;
        _access = j['accessToken'] as String;
        await store.writeRefresh(j['refreshToken'] as String);
        return true;
      } on ApiException catch (e) {
        // Only a definite rejection ends the session; a network error keeps the stored token for later.
        if (e.status == 401 || e.status == 403) {
          _access = null;
          await store.clear();
        } else {
          rethrow;
        }
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query, bool auth = true, bool retry = true}) async {
    final req = http.Request(method, _uri(path, query));
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    if (auth && _access != null) req.headers['Authorization'] = 'Bearer $_access';
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } on TimeoutException {
      throw ApiException(0, 'The server took too long to respond. Check your connection.');
    } on http.ClientException {
      throw ApiException(0, 'Cannot reach SmartBell. Check your internet connection.');
    } catch (_) {
      throw ApiException(0, 'Cannot reach SmartBell. Check your internet connection.');
    }
    if (res.statusCode == 401 && auth && retry) {
      final ok = await _refresh();
      if (ok) return _send(method, path, body: body, query: query, auth: auth, retry: false);
      onSessionExpired?.call();
    }
    if (res.statusCode == 204 || res.body.isEmpty) {
      if (res.statusCode >= 400) throw ApiException(res.statusCode, 'Request failed (${res.statusCode}).');
      return null;
    }
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {
      throw ApiException(res.statusCode, 'Unexpected response from the server.');
    }
    if (res.statusCode >= 400) {
      final m = data is Map ? data : const {};
      throw ApiException(res.statusCode, (m['message'] as String?) ?? 'Request failed (${res.statusCode}).', code: m['error'] as String?, details: m['details']);
    }
    return data;
  }
}
