import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/session.dart';

/// Two steps: ask for an SMS code with the student/staff ID, then enter the code with a new password.
/// The server answers the first step identically for every ID, so this screen never confirms that an ID exists.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialId = ''});
  final String initialId;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _id = TextEditingController(text: widget.initialId);
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _idForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  bool _codeSent = false, _busy = false, _hide = true;
  bool? _smsAvailable; // null while unknown (or the options request failed): do not block the user
  String? _info, _error;

  @override
  void initState() {
    super.initState();
    context.read<Session>().api.authOptions().then((o) {
      if (mounted) setState(() => _smsAvailable = o.passwordResetBySms);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_id, _code, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    // "Send a new code" is also used from step 2, where the ID form is not on screen.
    if (!(_idForm.currentState?.validate() ?? true)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await context.read<Session>().api.forgotPassword(_id.text.trim());
      if (mounted) {
        setState(() {
          _codeSent = true;
          _info = msg;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      await session.api.resetPassword(loginId: _id.text.trim(), code: _code.text.trim(), newPassword: _pw.text);
      session.setNotice('Password changed. Sign in with your new password.');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final smsOff = _smsAvailable == false;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.lock_reset, size: 48, color: c.primary),
                const SizedBox(height: 12),
                Text(
                  _codeSent ? 'Enter the code we sent you' : 'We will text you a 6-digit code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _codeSent ? (_info ?? '') : 'Enter your student ID or staff ID. The code goes to the phone number saved on your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                if (smsOff && !_codeSent) _banner(c, 'Password reset by SMS is not set up for your school yet. Please ask the school administrator to reset your password.', c.secondaryContainer, c.onSecondaryContainer),
                if (_error != null) _banner(c, _error!, c.errorContainer, c.onErrorContainer),
                if (!_codeSent) _askForm(c, smsOff) else _resetFormWidget(c),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _askForm(ColorScheme c, bool smsOff) => Form(
        key: _idForm,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _id,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onFieldSubmitted: (_) => (_busy || smsOff) ? null : _sendCode(),
            decoration: const InputDecoration(labelText: 'Student ID or staff ID', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your ID' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_busy || smsOff) ? null : _sendCode,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Send code'),
          ),
          const SizedBox(height: 12),
          Text('No phone number on your account? Ask the school administrator to reset your password.', textAlign: TextAlign.center, style: TextStyle(color: c.outline, fontSize: 12)),
        ]),
      );

  Widget _resetFormWidget(ColorScheme c) => Form(
        key: _resetForm,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: '6-digit code', prefixIcon: Icon(Icons.sms_outlined), counterText: ''),
            validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 6-digit code',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pw,
            obscureText: _hide,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              helperText: 'At least 8 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide), tooltip: _hide ? 'Show password' : 'Hide password'),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pw2,
            obscureText: _hide,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _busy ? null : _reset(),
            decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _reset,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Change password'),
          ),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, children: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _codeSent = false;
                        _error = null;
                      }),
              child: const Text('Use a different ID'),
            ),
            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Send a new code')),
          ]),
        ]),
      );

  Widget _banner(ColorScheme c, String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: fg)),
      );
}
