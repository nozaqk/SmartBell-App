import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:smartbell/core/api_client.dart';
import 'package:smartbell/core/token_store.dart';
import 'package:smartbell/push/push_service.dart';
import 'package:smartbell/state/nav_state.dart';
import 'package:smartbell/state/session.dart';
import 'package:smartbell/ui/login_screen.dart';

Future<void> _openLogin(WidgetTester tester) async {
  final client = MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/auth/options':
        return http.Response(jsonEncode({
          'school': {'name': 'Demo School'},
          'studentSelfRegistration': true,
          'passwordResetBySms': true,
          'classGroups': [],
        }), 200);
      case '/api/v1/auth/forgot-password':
        return http.Response('{"message":"Check your phone for a code."}', 200);
      case '/api/v1/auth/reset-password':
        return http.Response('', 204);
      default:
        return http.Response('{}', 404);
    }
  });
  final api = ApiClient(baseUrl: 'https://school.test', store: MemoryTokenStore(), client: client);
  await tester.pumpWidget(ChangeNotifierProvider<Session>(
    create: (_) => Session(api, PushService(api, NavState(), isSignedIn: () => false)),
    child: const MaterialApp(home: LoginScreen()),
  ));
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the student tab opens sign-up; the staff tab does not offer it', (tester) async {
    await _openLogin(tester);
    await _tap(tester, 'Staff');
    expect(find.text('Staff ID'), findsOneWidget);
    expect(find.text('Create a student account'), findsNothing);

    await _tap(tester, 'Student');
    await _tap(tester, 'Create a student account');
    expect(find.text('Demo School'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('password reset carries the login ID into the SMS flow and returns to sign-in', (tester) async {
    await _openLogin(tester);
    await tester.enterText(find.byType(TextFormField).first, 'S-001');
    await _tap(tester, 'Forgot password?');
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, 'S-001');

    await _tap(tester, 'Send code');
    expect(find.text('Check your phone for a code.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'TestPassword1');
    await tester.enterText(fields.at(2), 'TestPassword1');
    await _tap(tester, 'Change password');
    expect(find.text('Password changed. Sign in with your new password.'), findsOneWidget);
  });
}
