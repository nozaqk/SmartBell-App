import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../state/data_store.dart';
import '../state/nav_state.dart';
import 'announcements_screen.dart';
import 'exams_screen.dart';
import 'my_classes_screen.dart';
import 'widgets.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataStore>();
    final d = data.dashboard;
    if (d == null) {
      if (data.dashboardError != null) return ErrorView(message: data.dashboardError!, onRetry: data.loadDashboard);
      return const LoadingView();
    }
    final p = d.profile;
    final c = Theme.of(context).colorScheme;
    final lecturer = p.isLecturer;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([data.loadDashboard(), data.loadWeek()]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('${greeting(DateTime.now().hour)},', style: TextStyle(color: c.onSurfaceVariant)),
          Text(p.displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(lecturer ? [if (p.department != null) p.department!, p.schoolName].join(' · ') : [if (p.classGroups.isNotEmpty) p.classGroups.join(', '), p.schoolName].join(' · '), style: TextStyle(color: c.outline)),
          if (data.dashboardError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Showing saved data: ${data.dashboardError}', style: TextStyle(color: c.error, fontSize: 12))),
          const SizedBox(height: 16),
          if (d.isHoliday)
            _info(context, Icons.beach_access_outlined, 'Holiday', 'There are no classes today.')
          else if (d.nextClass != null)
            NextClassCard(next: d.nextClass!, fetchedAt: d.fetchedAt, forLecturer: lecturer, onElapsed: data.loadDashboard)
          else
            _info(context, Icons.event_available_outlined, 'Nothing coming up', lecturer ? 'No upcoming lectures are scheduled.' : 'No upcoming classes are scheduled.'),
          const SizedBox(height: 20),
          Text(lecturer ? "Today's lectures" : "Today's classes", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (d.today.isEmpty)
            Card.outlined(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(d.isHoliday ? 'Holiday' : 'No classes today', style: TextStyle(color: c.outline)))))
          else
            for (final e in d.today) Padding(padding: const EdgeInsets.only(bottom: 8), child: ClassTile(entry: e, forLecturer: lecturer, highlight: d.nextClass?.entry.id == e.id && d.nextClass?.dayOffset == 0)),
          if (lecturer && p.courses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('My courses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final course in p.courses) Chip(label: Text(course))]),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _action(context, Icons.campaign_outlined, 'Announcements', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen())))),
            if (lecturer) ...[
              const SizedBox(width: 12),
              Expanded(child: _action(context, Icons.edit_calendar_outlined, 'Reschedule class', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyClassesScreen())))),
            ],
            if (p.isStudent) ...[
              const SizedBox(width: 12),
              Expanded(child: _action(context, Icons.fact_check_outlined, 'Exam timetable', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamsScreen())))),
            ],
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text('Latest alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => context.read<NavState>().select(NavState.tabNotifications), child: const Text('See all')),
          ]),
          if (d.latest.isEmpty)
            Card.outlined(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No notifications yet', style: TextStyle(color: c.outline)))))
          else
            for (final n in d.latest) Padding(padding: const EdgeInsets.only(bottom: 8), child: NotificationTile(n: n, onTap: () => context.read<NavState>().select(NavState.tabNotifications))),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String title, String text) {
    final c = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Icon(icon, size: 36, color: c.primary),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), Text(text, style: TextStyle(color: c.onSurfaceVariant))])),
        ]),
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final c = Theme.of(context).colorScheme;
    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), child: Column(children: [Icon(icon, color: c.primary), const SizedBox(height: 6), Text(label, textAlign: TextAlign.center)])),
      ),
    );
  }
}

