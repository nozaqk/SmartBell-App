import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../state/session.dart';
import 'widgets.dart';

/// Student self-registration. Staff accounts are created by the school administrator on the web dashboard,
/// so there is deliberately no role choice here: the server only ever creates STUDENT accounts from this form.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late Future<AuthOptions> _options;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  String? _groupId;
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _options = context.read<Session>().api.authOptions();

  @override
  void dispose() {
    for (final c in [_name, _id, _phone, _email, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().registerStudent(
            studentId: _id.text,
            fullName: _name.text,
            phone: _phone.text,
            password: _pw.text,
            email: _email.text,
            classGroupId: _groupId,
          );
      // Signed in: the root widget now shows the home screen underneath this page.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create student account')),
      body: SafeArea(
        child: FutureBuilder<AuthOptions>(
          future: _options,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingView();
            if (snap.hasError) {
              final e = snap.error;
              return ErrorView(message: e is ApiException ? e.message : 'Could not load the sign-up form.', onRetry: () => setState(_load));
            }
            final o = snap.data!;
            if (!o.studentSelfRegistration) {
              return const EmptyView(
                icon: Icons.lock_outline,
                title: 'Sign-up is closed',
                subtitle: 'Ask the school administrator to create your account.',
              );
            }
            return _buildForm(context, o);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AuthOptions o) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (o.schoolName.isNotEmpty) Text(o.schoolName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('This is for students only. Staff accounts are created by the school administrator.', textAlign: TextAlign.center, style: TextStyle(color: c.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: c.onErrorContainer)),
                ),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _id,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Student ID', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Enter your student ID';
                  if (!RegExp(r'^[A-Za-z0-9._/\-]+$').hasMatch(t)) return 'Use letters, numbers and / . _ - only';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(labelText: 'Phone number', hintText: '024 123 4567', prefixIcon: Icon(Icons.phone_outlined), helperText: 'Used to reset your password and, if enabled, for SMS alerts'),
                validator: (v) => RegExp(r'\d').allMatches(v ?? '').length < 9 ? 'Enter a valid phone number' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) => (v != null && v.trim().isNotEmpty && !v.contains('@')) ? 'Enter a valid email or leave it empty' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                value: _groupId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Class', prefixIcon: Icon(Icons.groups_outlined), helperText: 'Your timetable and alerts follow your class'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Not sure yet (administrator will assign)')),
                  for (final g in o.classGroups) DropdownMenuItem<String?>(value: g.id, child: Text(g.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _groupId = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pw,
                obscureText: _hide,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
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
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Create account'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('I already have an account')),
            ]),
          ),
        ),
      ),
    );
  }
}
