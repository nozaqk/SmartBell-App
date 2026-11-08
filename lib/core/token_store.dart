import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction so tests can use an in-memory store.
abstract class TokenStore {
  Future<String?> readRefresh();
  Future<void> writeRefresh(String token);
  Future<void> clear();
}

/// Keychain (iOS) / EncryptedSharedPreferences (Android). The short-lived access token is kept in memory only.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final FlutterSecureStorage _s;
  static const _key = 'smartbell.refresh';

  @override
  Future<String?> readRefresh() => _s.read(key: _key);
  @override
  Future<void> writeRefresh(String token) => _s.write(key: _key, value: token);
  @override
  Future<void> clear() => _s.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? _v;
  @override
  Future<String?> readRefresh() async => _v;
  @override
  Future<void> writeRefresh(String token) async => _v = token;
  @override
  Future<void> clear() async => _v = null;
}
