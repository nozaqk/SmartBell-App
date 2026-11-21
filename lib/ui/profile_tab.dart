import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/session.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.profile;
    if (p == null) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;

    Widget row(IconData i, String label, String? v) => (v == null || v.isEmpty)
        ? const SizedBox.shrink()
        : ListTile(leading: Icon(i, color: c.primary), title: Text(label, style: TextStyle(color: c.outline, fontSize: 12)), subtitle: Text(v, style: const TextStyle(fontSize: 15)), dense: true);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: Column(children: [
          CircleAvatar(radius: 40, backgroundColor: c.primaryContainer, child: Text(p.fullName.isEmpty ? '?' : p.fullName.trim()[0].toUpperCase(), style: TextStyle(fontSize: 32, color: c.primary, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          Text(p.displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Chip(label: Text(p.isLecturer ? 'Lecturer' : 'Student'), visualDensity: VisualDensity.compact),
        ]),
      ),
      const SizedBox(height: 12),
      Card.outlined(
        child: Column(children: [
          row(Icons.badge_outlined, p.isLecturer ? 'Staff ID' : 'Student ID', p.loginId),
          row(Icons.school_outlined, 'School', p.schoolName),
          row(Icons.apartment_outlined, 'Department', p.department),
          if (p.isStudent) ...[
            row(Icons.schedule_outlined, 'Stream', p.stream?.label),
            row(Icons.menu_book_outlined, 'Programme', p.programme),
            row(Icons.event_note_outlined, 'Semester', p.semester),
          ],
          row(Icons.email_outlined, 'Email', p.email),
          row(Icons.public, 'School timezone', p.timezone),
        ]),
      ),
      const SizedBox(height: 12),
      Card.outlined(
        child: ListTile(
          leading: Icon(Icons.notifications_active_outlined, color: c.primary),
          title: const Text('Push notifications'),
          subtitle: Text(AppConfig.firebaseConfigured ? 'Bell, class and announcement alerts are sent to this device.' : 'Not configured in this build.'),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Sign out?'),
              content: const Text('You will stop receiving alerts on this device until you sign in again.'),
              actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sign out'))],
            ),
          );
          if (ok == true && context.mounted) await context.read<Session>().signOut();
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
      const SizedBox(height: 16),
      Center(child: Text('SmartBell 1.0.0', style: TextStyle(color: c.outline, fontSize: 12))),
    ]);
  }
}
