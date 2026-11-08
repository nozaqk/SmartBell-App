import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../state/session.dart';
import 'widgets.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<AppNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final j = await context.read<Session>().api.get('/mobile/announcements', query: {'pageSize': '50'}) as Map<String, dynamic>;
      if (mounted) setState(() => _items = [for (final n in (j['items'] as List)) AppNotification.fromJson((n as Map).cast<String, dynamic>())]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lecturer = context.select<Session, bool>((s) => s.profile?.isLecturer ?? false);
    Widget body;
    if (_items == null && _error == null) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(message: _error!, onRetry: _load);
    } else if (_items!.isEmpty) {
      body = const EmptyView(icon: Icons.campaign_outlined, title: 'No announcements', subtitle: 'School and class announcements appear here.');
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => NotificationTile(n: _items![i]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: RefreshIndicator(onRefresh: _load, child: body),
      floatingActionButton: lecturer
          ? FloatingActionButton.extended(
              onPressed: () async {
                final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ComposeAnnouncementScreen()));
                if (sent == true) _load();
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New'),
            )
          : null,
    );
  }
}

/// Lecturers can publish to a class group they teach. The backend rejects any other group with 403.
class ComposeAnnouncementScreen extends StatefulWidget {
  const ComposeAnnouncementScreen({super.key});
  @override
  State<ComposeAnnouncementScreen> createState() => _ComposeAnnouncementScreenState();
}

class _ComposeAnnouncementScreenState extends State<ComposeAnnouncementScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<ClassGroupRef>? _groups;
  String? _groupId, _error, _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final j = await context.read<Session>().api.get('/mobile/lecturer/class-groups') as List;
      if (!mounted) return;
      setState(() {
        _groups = [for (final g in j) ClassGroupRef.fromJson((g as Map).cast<String, dynamic>())];
        if (_groups!.length == 1) _groupId = _groups!.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api.post('/mobile/announcements', body: {'title': _title.text.trim(), 'body': _body.text.trim(), 'classGroupId': _groupId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement sent')));
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loadError != null) {
      body = ErrorView(message: _loadError!, onRetry: () {
        setState(() => _loadError = null);
        _loadGroups();
      });
    } else if (_groups == null) {
      body = const LoadingView();
    } else if (_groups!.isEmpty) {
      body = const EmptyView(icon: Icons.groups_outlined, title: 'No class groups yet', subtitle: 'You can announce to groups you teach once a timetable is published.');
    } else {
      body = Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(
            value: _groupId,
            decoration: const InputDecoration(labelText: 'Class group'),
            items: [for (final g in _groups!) DropdownMenuItem(value: g.id, child: Text(g.name))],
            onChanged: (v) => setState(() => _groupId = v),
            validator: (v) => v == null ? 'Choose a class group' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null),
          const SizedBox(height: 6),
          TextFormField(controller: _body, maxLines: 6, maxLength: 2000, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a message' : null),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _busy ? null : _send, icon: const Icon(Icons.send), label: Text(_busy ? 'Sending...' : 'Send to class group')),
        ]),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('New announcement')), body: body);
  }
}
