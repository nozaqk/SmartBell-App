import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../state/data_store.dart';
import '../state/session.dart';
import 'widgets.dart';

class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key});
  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  int? _day; // 1..7, defaults to today (Monday-based)

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataStore>();
    final lecturer = context.select<Session, bool>((s) => s.profile?.isLecturer ?? false);
    final w = data.week;
    if (w == null) {
      if (data.weekError != null) return ErrorView(message: data.weekError!, onRetry: data.loadWeek);
      return const LoadingView();
    }
    final today = DateTime.tryParse(w.today)?.weekday ?? DateTime.now().weekday;
    final day = _day ?? today;
    final entries = w.days[day] ?? const [];
    final c = Theme.of(context).colorScheme;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(alignment: Alignment.centerLeft, child: Text(lecturer ? 'Teaching timetable' : 'Weekly timetable', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
      ),
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final d = i + 1;
            final selected = d == day;
            final count = w.days[d]?.length ?? 0;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _day = d),
              label: Text('${dayShort[d]}${count > 0 ? ' · $count' : ''}${d == today ? ' •' : ''}'),
            );
          },
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: data.loadWeek,
          child: entries.isEmpty
              ? ListView(children: [SizedBox(height: 260, child: EmptyView(icon: Icons.event_available_outlined, title: 'No classes on ${dayNames[day]}', subtitle: 'Enjoy the free time.'))])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => ClassTile(entry: entries[i], forLecturer: lecturer),
                ),
        ),
      ),
      if (data.weekError != null) Padding(padding: const EdgeInsets.all(8), child: Text('Could not refresh: ${data.weekError}', style: TextStyle(color: c.error, fontSize: 12))),
    ]);
  }
}
