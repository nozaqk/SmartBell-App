import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/session.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false, _hide = true;
  String _role = 'student'; // 'student' | 'staff': sent to the server, which rejects a mismatch
  String? _error;

  bool get _isStudent => _role == 'student';

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().signIn(_id.text, _pw.text, audience: _role);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ForgotPasswordScreen(initialId: _id.text.trim())));

  void _register() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final notice = context.watch<Session>().notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Image.asset(
                      'assets/branding/app-icon-rounded.png',
                      width: 72,
                      height: 72,
                      excludeFromSemantics: true, // The app name follows immediately below.
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('SmartBell', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Choose how you sign in', textAlign: TextAlign.center, style: TextStyle(color: c.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<String>(value: 'student', label: Text('Student'), icon: Icon(Icons.school_outlined)),
                      ButtonSegment<String>(value: 'staff', label: Text('Staff'), icon: Icon(Icons.badge_outlined)),
                    ],
                    selected: {_role},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() {
                              _role = s.first;
                              _error = null;
                            }),
                  ),
                  const SizedBox(height: 20),
                  if (notice != null && _error == null) _banner(c, notice, c.secondaryContainer, c.onSecondaryContainer),
                  if (_error != null) _banner(c, _error!, c.errorContainer, c.onErrorContainer),
                  TextFormField(
                    controller: _id,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(labelText: _isStudent ? 'Student ID' : 'Staff ID', prefixIcon: const Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? (_isStudent ? 'Enter your student ID' : 'Enter your staff ID') : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pw,
                    obscureText: _hide,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _busy ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide), tooltip: _hide ? 'Show password' : 'Hide password'),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Sign in'),
                  ),
                  const SizedBox(height: 18),
                  if (_isStudent) ...[
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('New here?', style: TextStyle(color: c.outline, fontSize: 12))),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: _busy ? null : _register, icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Create a student account')),
                  ] else
                    Text('Staff accounts are created by the school administrator. Ask them if you cannot sign in.', textAlign: TextAlign.center, style: TextStyle(color: c.outline, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(ColorScheme c, String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: fg)),
      );
}
