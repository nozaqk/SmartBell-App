import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartbell/config.dart';
import 'package:smartbell/core/api_client.dart';
import 'package:smartbell/core/token_store.dart';

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('API calls use the configured backend with the /api/v1 prefix', () async {
    const override = String.fromEnvironment('API_URL');
    final origin = override.isEmpty ? 'https://smartbell-backend.onrender.com' : override;
    late Uri requested;
    final client = MockClient((req) async {
      requested = req.url;
      return json({});
    });
    final api = ApiClient(baseUrl: AppConfig.apiUrl, store: MemoryTokenStore(), client: client);
    await api.get('/mobile/me');
    expect(requested.toString(), '$origin/api/v1/mobile/me');
  });

  test('login stores the refresh token and sends the bearer token afterwards', () async {
    final seen = <String?>[];
    final client = MockClient((req) async {
      if (req.url.path == '/api/v1/auth/login') {
        expect(jsonDecode(req.body), {'loginId': 'S-001', 'password': 'pw'});
        return json({'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 900, 'user': {}});
      }
      seen.add(req.headers['Authorization']);
      return json({'ok': true});
    });
    final store = MemoryTokenStore();
    final api = ApiClient(baseUrl: 'http://x', store: store, client: client);
    await api.login('S-001', 'pw');
    await api.get('/mobile/me');
    expect(await store.readRefresh(), 'R1');
    expect(seen.single, 'Bearer A1');
  });

  test('an expired access token is refreshed once and the request retried', () async {
    var refreshes = 0;
    var first = true;
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/auth/refresh')) {
        refreshes++;
        expect(jsonDecode(req.body), {'refreshToken': 'R1'});
        return json({'accessToken': 'A9', 'refreshToken': 'R9'});
      }
      if (first) {
        first = false;
        return json({'error': 'unauthorized', 'message': 'expired'}, 401);
      }
      return req.headers['Authorization'] == 'Bearer A9' ? json({'ok': 1}) : json({'message': 'bad'}, 401);
    });
    final store = MemoryTokenStore();
    await store.writeRefresh('R1');
    final api = ApiClient(baseUrl: 'http://x', store: store, client: client);
    expect(await api.get('/mobile/dashboard'), {'ok': 1});
    expect(await store.readRefresh(), 'R9'); // rotated
    expect(refreshes, 1);
  });

  test('a rejected refresh token clears the session and notifies the app', () async {
    final client = MockClient((req) async => json({'error': 'unauthorized', 'message': 'Refresh token has already been used'}, 401));
    final store = MemoryTokenStore();
    await store.writeRefresh('OLD');
    final api = ApiClient(baseUrl: 'http://x', store: store, client: client);
    expect(await api.restore(), false);
    expect(await store.readRefresh(), isNull);
  });

  test('server errors surface the backend message', () async {
    final client = MockClient((req) async => json({'error': 'unauthorized', 'message': 'Invalid ID or password'}, 401));
    final api = ApiClient(baseUrl: 'http://x', store: MemoryTokenStore(), client: client);
    await expectLater(api.login('S-001', 'bad'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid ID or password').having((e) => e.status, 'status', 401)));
  });

  test('network failures become a friendly offline error', () async {
    final client = MockClient((req) async => throw http.ClientException('down'));
    final api = ApiClient(baseUrl: 'http://x', store: MemoryTokenStore(), client: client);
    await expectLater(api.login('a', 'b'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
  });

  test('logout sends the push token and clears local tokens even when offline', () async {
    String? sent;
    final client = MockClient((req) async {
      sent = req.body;
      throw http.ClientException('offline');
    });
    final store = MemoryTokenStore();
    await store.writeRefresh('R1');
    final api = ApiClient(baseUrl: 'http://x', store: store, client: client);
    await api.logout(pushToken: 'FCM_TOKEN');
    expect(jsonDecode(sent!), {'refreshToken': 'R1', 'pushToken': 'FCM_TOKEN'});
    expect(await store.readRefresh(), isNull);
  });
}
