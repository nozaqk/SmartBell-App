import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/session.dart';

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
  String? _error;

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
      await context.read<Session>().signIn(_id.text, _pw.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(20)),
                      child: Icon(Icons.notifications_active, color: c.onPrimary, size: 38),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('SmartBell', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Sign in with your student ID or staff ID', textAlign: TextAlign.center, style: TextStyle(color: c.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  if (notice != null && _error == null) _banner(c, notice, c.secondaryContainer, c.onSecondaryContainer),
                  if (_error != null) _banner(c, _error!, c.errorContainer, c.onErrorContainer),
                  TextFormField(
                    controller: _id,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Student ID or staff ID', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your ID' : null,
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
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  Text('Forgot your password? Ask the school administrator to reset it.', textAlign: TextAlign.center, style: TextStyle(color: c.outline, fontSize: 12)),
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
