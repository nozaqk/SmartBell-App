import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/reschedule_models.dart';
import '../state/data_store.dart';
import '../state/session.dart';
import 'reschedule_history_screen.dart';
import 'reschedule_screen.dart';
import 'slot_widgets.dart';
import 'widgets.dart';

/// Lecturer only: upcoming lectures with a "Reschedule class" action. The server decides what may be changed.
class MyClassesScreen extends StatefulWidget {
  const MyClassesScreen({super.key});
  @override
  State<MyClassesScreen> createState() => _MyClassesScreenState();
}

class _MyClassesScreenState extends State<MyClassesScreen> {
  List<LecturerClass>? _items;
  String? _error;

  ApiClient get _api => context.read<Session>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final j = await _api.get('/mobile/lecturer/classes', query: {'days': '28'}) as Map<String, dynamic>;
      if (mounted) setState(() => _items = [for (final i in (j['items'] as List)) LecturerClass.fromJson((i as Map).cast<String, dynamic>())]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _reschedule(LecturerClass c) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RescheduleScreen(lecture: c)));
    if (done == true) {
      _load();
      if (mounted) context.read<DataStore>().onPushReceived();
    }
  }

  Future<void> _withdraw(LecturerClass c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this change?'),
        content: Text('${c.courseCode} goes back to ${rangeLabel(c.original.startMinute, c.original.endMinute)} in ${c.original.roomName} on ${dateLabel(c.original.date)}. Students are told.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep change')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true || c.rescheduleId == null) return;
    try {
      await _api.post('/mobile/lecturer/reschedules/${c.rescheduleId}/revert', body: {'reason': 'Withdrawn by lecturer'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Change withdrawn. Students have been notified.')));
      _load();
      context.read<DataStore>().onPushReceived();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My classes'),
        actions: [IconButton(tooltip: 'History', icon: const Icon(Icons.history), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RescheduleHistoryScreen())).then((_) => _load()))],
      ),
      body: items == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const LoadingView())
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: const [SizedBox(height: 260, child: EmptyView(icon: Icons.event_available_outlined, title: 'No upcoming lectures', subtitle: 'Published classes for the next four weeks appear here.'))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _tile(items[i]),
                    ),
            ),
    );
  }

  Widget _tile(LecturerClass c) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${c.courseCode} · ${c.courseName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            if (c.state == LectureState.rescheduled) const StatusChip('Rescheduled'),
            if (c.state == LectureState.cancelled) StatusChip('Cancelled', color: scheme.error),
          ]),
          const SizedBox(height: 2),
          Text(c.classGroup, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.event_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(dateLabel(c.current.date), style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(rangeLabel(c.current.startMinute, c.current.endMinute)),
            const SizedBox(width: 14),
            Icon(Icons.meeting_room_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(c.current.roomName)),
          ]),
          if (c.state == LectureState.rescheduled) ...[
            const SizedBox(height: 8),
            Text('Was ${dateLabel(c.original.date)}, ${rangeLabel(c.original.startMinute, c.original.endMinute)} · ${c.original.roomName}', style: TextStyle(color: scheme.outline, fontSize: 12)),
            if (c.reason != null) Text('Reason: ${c.reason}', style: TextStyle(color: scheme.outline, fontSize: 12)),
          ],
          if (c.state == LectureState.cancelled && c.reason != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Reason: ${c.reason}', style: TextStyle(color: scheme.outline, fontSize: 12))),
          if (c.canReschedule || c.state == LectureState.rescheduled) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (c.state == LectureState.rescheduled && c.rescheduleId != null) TextButton(onPressed: () => _withdraw(c), child: const Text('Withdraw')),
              if (c.canReschedule) FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _reschedule(c), icon: const Icon(Icons.edit_calendar_outlined, size: 18), label: const Text('Reschedule class')),
            ]),
          ],
        ]),
      ),
    );
  }
}
