import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../state/session.dart';
import 'widgets.dart';

/// Student self-registration. Both steps share an in-memory draft; only the final
/// Create account action sends it to the server. Staff accounts are created by the school.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late Future<AuthOptions> _options;
  final _detailsForm = GlobalKey<FormState>();
  final _reviewForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _department = TextEditingController();
  StudyStream? _stream;
  bool _reviewing = false, _busy = false, _hide = true;
  String? _error;

  // Suggestions, not a fixed school directory. Free text is always accepted.
  static const _examples = ['Business Administration', 'Computer Science', 'Engineering', 'Nursing'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _options = context.read<Session>().api.authOptions();

  @override
  void dispose() {
    for (final c in [_name, _id, _phone, _email, _pw, _pw2, _department]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changeStep(bool review) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _reviewing = review;
      _error = null;
      _hide = true;
    });
  }

  void _continue() {
    if (!_reviewing && _detailsForm.currentState!.validate()) _changeStep(true);
  }

  Future<void> _createAccount() async {
    if (!_reviewing || _busy || !_reviewForm.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
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
            department: _department.text,
            stream: _stream!,
          );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_reviewing && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _reviewing && !_busy) _changeStep(false);
      },
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildForm(BuildContext context, AuthOptions options) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        key: ValueKey(_reviewing), // Start each step at its heading, not the previous button's scroll offset.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _reviewing ? _reviewForm : _detailsForm,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (options.schoolName.isNotEmpty) ...[
                Text(options.schoolName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
              ],
              LinearProgressIndicator(value: _reviewing ? 1 : 0.5),
              const SizedBox(height: 12),
              Text(_reviewing ? 'Step 2 of 2' : 'Step 1 of 2', style: theme.textTheme.labelLarge?.copyWith(color: c.primary)),
              Text(_reviewing ? 'Review your details' : 'Account details', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                _reviewing
                    ? 'Check your name, student ID and email. You can edit them here before choosing your department and stream.'
                    : 'For students only. Staff accounts are created by the school administrator.',
                style: TextStyle(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              for (final field in _fields(options)) ...[field, const SizedBox(height: 14)],
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: TextStyle(color: c.onErrorContainer)),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : (_reviewing ? _createAccount : _continue),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_reviewing ? 'Create account' : 'Continue to review'),
              ),
              const SizedBox(height: 8),
              if (_reviewing)
                TextButton(onPressed: _busy ? null : () => _changeStep(false), child: const Text('Back to account details'))
              else
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('I already have an account')),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(AuthOptions options) => [
        TextFormField(
          controller: _name,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
        ),
        TextFormField(
          controller: _id,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Student ID', prefixIcon: Icon(Icons.badge_outlined)),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Enter your student ID';
            return RegExp(r'^[A-Za-z0-9._/\-]+$').hasMatch(t) ? null : 'Use letters, numbers and / . _ - only';
          },
        ),
        if (!_reviewing)
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(labelText: 'Phone number', hintText: '024 123 4567', prefixIcon: Icon(Icons.phone_outlined), helperText: 'For password resets and SMS alerts', helperMaxLines: 2),
            validator: (v) => RegExp(r'\d').allMatches(v ?? '').length < 9 ? 'Enter a valid phone number' : null,
          ),
        TextFormField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline)),
          validator: (v) {
            final email = (v ?? '').trim();
            return email.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(email) ? null : 'Enter a valid email or leave it empty';
          },
        ),
        if (!_reviewing) ...[
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
            validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
          ),
          TextFormField(
            controller: _pw2,
            obscureText: _hide,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _continue(),
            decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
          ),
        ] else ...[
          _departmentField(options.departments),
          DropdownButtonFormField<StudyStream>(
            value: _stream,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Stream', prefixIcon: Icon(Icons.schedule_outlined)),
            hint: const Text('Choose a stream'),
            items: [for (final stream in StudyStream.values) DropdownMenuItem(value: stream, child: Text(stream.label))],
            onChanged: _busy ? null : (v) => setState(() => _stream = v),
            validator: (v) => v == null ? 'Select your stream' : null,
          ),
        ],
      ];

  Widget _departmentField(List<String> departments) => TextFormField(
        controller: _department,
        enabled: !_busy,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Department',
          helperText: 'Type a name or use the arrow to choose a suggestion.',
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.apartment_outlined),
          suffixIcon: PopupMenuButton<String>(
            tooltip: 'Choose a department',
            enabled: !_busy,
            icon: const Icon(Icons.arrow_drop_down),
            itemBuilder: (_) => [
              for (final name in departments.isEmpty ? _examples : departments) PopupMenuItem(value: name, child: Text(name)),
            ],
            onSelected: (name) => _department.value = TextEditingValue(text: name, selection: TextSelection.collapsed(offset: name.length)),
          ),
        ),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter or choose your department' : null,
      );
}
