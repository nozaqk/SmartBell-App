import 'dart:async';
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

Future<Session> _openLogin(
  WidgetTester tester, {
  Map<String, dynamic> options = const {},
  Future<http.Response> Function(http.Request)? onRegister,
  bool profileAvailable = true,
}) async {
  final client = MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/auth/options':
        return http.Response(jsonEncode({
          'school': {'name': 'Demo School'},
          'studentSelfRegistration': true,
          'passwordResetBySms': true,
          ...options,
        }), 200);
      case '/api/v1/auth/register-student':
        if (onRegister == null) throw StateError('Unexpected registration');
        return onRegister(request);
      case '/api/v1/mobile/me':
        return profileAvailable
            ? http.Response('{"id":"u1","role":"STUDENT","student":{"department":"Statistics","stream":"Weekend"}}', 200)
            : http.Response('{"message":"Profile unavailable"}', 503);
      case '/api/v1/auth/logout':
        return http.Response('', 204);
      case '/api/v1/auth/forgot-password':
        return http.Response('{"message":"Check your phone for a code."}', 200);
      case '/api/v1/auth/reset-password':
        return http.Response('', 204);
      default:
        return http.Response('{}', 404);
    }
  });
  final api = ApiClient(baseUrl: 'https://school.test', store: MemoryTokenStore(), client: client);
  final session = Session(api, PushService(api, NavState(), isSignedIn: () => false));
  await session.start();
  await tester.pumpWidget(ChangeNotifierProvider<Session>(create: (_) => session, child: const MaterialApp(home: LoginScreen())));
  return session;
}

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) => _tapFinder(tester, find.text(label));
Finder _field(String label) => find.widgetWithText(TextFormField, label);
String _value(WidgetTester tester, String label) => tester.widget<TextFormField>(_field(label)).controller!.text;

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = _field(label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _fillAccountDetails(WidgetTester tester, {String email = ''}) async {
  await _enter(tester, 'Full name', 'Ama Doe');
  await _enter(tester, 'Student ID', 'S-001');
  await _enter(tester, 'Phone number', '024 123 4567');
  if (email.isNotEmpty) await _enter(tester, 'Email (optional)', email);
  await _enter(tester, 'Password', 'TestPassword1');
  await _enter(tester, 'Confirm password', 'TestPassword1');
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
    expect(find.text('Continue to review'), findsOneWidget);
    expect(find.text('Class'), findsNothing);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('closed registration does not expose either step', (tester) async {
    await _openLogin(tester, options: {'studentSelfRegistration': false});
    await _tap(tester, 'Create a student account');
    expect(find.text('Sign-up is closed'), findsOneWidget);
    expect(find.text('Continue to review'), findsNothing);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('keyboard advances to review; only a valid final form posts the corrected details, once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final posts = <Map<String, dynamic>>[];
    final reply = Completer<http.Response>();
    final session = await _openLogin(tester, options: {
      'departments': ['Statistics', 'Physics'],
    }, onRegister: (r) {
      posts.add(jsonDecode(r.body) as Map<String, dynamic>);
      return reply.future;
    });
    await _tap(tester, 'Create a student account');
    await _tap(tester, 'Continue to review');
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsNothing);
    await _fillAccountDetails(tester, email: 'draft@example.org');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Review your details'), findsOneWidget);
    expect(find.text('Class'), findsNothing);
    expect(_field('Password'), findsNothing);
    expect(_value(tester, 'Full name'), 'Ama Doe');
    expect(_value(tester, 'Student ID'), 'S-001');
    expect(_value(tester, 'Email (optional)'), 'draft@example.org');
    expect(posts, isEmpty);
    expect(session.status, SessionStatus.signedOut);

    await _enter(tester, 'Email (optional)', 'not-an-email');
    await _enter(tester, 'Department', '   ');
    await _tap(tester, 'Create account');
    expect(find.text('Enter a valid email or leave it empty'), findsOneWidget);
    expect(find.text('Enter or choose your department'), findsOneWidget);
    expect(find.text('Select your stream'), findsOneWidget);
    expect(posts, isEmpty);

    await _enter(tester, 'Full name', ' Ama Boateng ');
    await _enter(tester, 'Student ID', ' S-002 ');
    await _enter(tester, 'Email (optional)', ' ama@example.org ');
    await _tapFinder(tester, find.byTooltip('Choose a department'));
    await _tap(tester, 'Statistics');
    expect(_value(tester, 'Department'), 'Statistics');
    await _tap(tester, 'Choose a stream');
    for (final label in ['Regular', 'Weekend', 'Evening']) {
      expect(find.text(label), findsWidgets);
    }
    await _tapFinder(tester, find.text('Weekend').last);

    final create = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.tap(create); // Before the next frame disables the button.
    await tester.pump();
    expect(posts, [
      {
        'studentId': 'S-002', 'fullName': 'Ama Boateng', 'phone': '024 123 4567', 'password': 'TestPassword1',
        'email': 'ama@example.org', 'department': 'Statistics', 'stream': 'Weekend',
      },
    ]);
    reply.complete(http.Response('{"accessToken":"A1","refreshToken":"R1"}', 201));
    await tester.pumpAndSettle();
    expect(session.status, SessionStatus.signedIn);
    expect(session.profile?.stream?.label, 'Weekend');
    expect(find.text('Review your details'), findsNothing);
  });

  testWidgets('custom department and draft survive back and a failed submission', (tester) async {
    final posts = <Map<String, dynamic>>[];
    final session = await _openLogin(tester, profileAvailable: false, onRegister: (r) async {
      posts.add(jsonDecode(r.body) as Map<String, dynamic>);
      return posts.length == 1
          ? http.Response('{"message":"Student ID already in use"}', 409)
          : http.Response('{"accessToken":"A1","refreshToken":"R1"}', 201);
    });
    await _tap(tester, 'Create a student account');
    await _fillAccountDetails(tester);
    await _tap(tester, 'Continue to review');
    // Even without school-supplied options, a suggestion can be selected or replaced with free text.
    await _tapFinder(tester, find.byTooltip('Choose a department'));
    await _tap(tester, 'Engineering');
    await _enter(tester, 'Department', ' Textile Design ');
    await _tap(tester, 'Choose a stream');
    await _tapFinder(tester, find.text('Evening').last);
    await _enter(tester, 'Full name', 'Ama Mensah');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(_value(tester, 'Full name'), 'Ama Mensah');
    expect(_value(tester, 'Phone number'), '024 123 4567');
    expect(_value(tester, 'Confirm password'), 'TestPassword1');
    await _tap(tester, 'Continue to review');
    expect(_value(tester, 'Department'), ' Textile Design ');
    expect(find.text('Evening'), findsOneWidget);
    expect(posts, isEmpty);

    await _tap(tester, 'Create account');
    expect(find.text('Student ID already in use'), findsOneWidget);
    expect(session.status, SessionStatus.signedOut);
    expect(_value(tester, 'Department'), ' Textile Design ');
    await _enter(tester, 'Student ID', 'S-003');
    await _tap(tester, 'Create account');
    expect(posts, hasLength(2));
    expect(posts.last['department'], 'Textile Design');
    expect(posts.last['stream'], 'Evening');
    expect(posts.last['studentId'], 'S-003');
    expect(posts.last, isNot(contains('email')));
    // The POST succeeded but /mobile/me failed. Offer sign-in, not another account creation.
    expect(find.text('Your account was created. Please sign in to continue.'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('password reset carries the ID through the SMS flow on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
