import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: c.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: c.outline))],
        ]),
      ),
    );
  }
}

/// One timetable row. Students see the lecturer; lecturers see the class group (they know who they are).
class ClassTile extends StatelessWidget {
  const ClassTile({super.key, required this.entry, required this.forLecturer, this.highlight = false});
  final ClassEntry entry;
  final bool forLecturer;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final who = forLecturer ? entry.classGroupName : entry.lecturerName;
    final strike = entry.cancelled ? TextDecoration.lineThrough : null;
    return Card.outlined(
      color: highlight ? c.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 78,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(minuteLabel(entry.startMinute), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(minuteLabel(entry.endMinute), style: TextStyle(color: c.outline, fontSize: 12)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${entry.courseCode} · ${entry.courseName}', style: TextStyle(fontWeight: FontWeight.w600, decoration: strike)),
              const SizedBox(height: 2),
              Text('${entry.roomName} · $who', style: TextStyle(color: c.onSurfaceVariant, fontSize: 13)),
              if (entry.cancelled)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Chip(
                    label: Text(entry.cancelReason == null || entry.cancelReason!.isEmpty ? 'Cancelled' : 'Cancelled: ${entry.cancelReason}'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: c.errorContainer,
                    labelStyle: TextStyle(color: c.onErrorContainer, fontSize: 12),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Counts down locally between server refreshes so the display ticks every second without polling.
class NextClassCard extends StatefulWidget {
  const NextClassCard({super.key, required this.next, required this.fetchedAt, required this.forLecturer, required this.onElapsed});
  final NextClass next;
  final DateTime fetchedAt;
  final bool forLecturer;
  final VoidCallback onElapsed;

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  Timer? _t;
  bool _fired = false;

  int get remaining => widget.next.countdownSeconds - DateTime.now().difference(widget.fetchedAt).inSeconds;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remaining <= 0 && !_fired) {
        _fired = true;
        widget.onElapsed();
      }
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant NextClassCard old) {
    super.didUpdateWidget(old);
    if (old.fetchedAt != widget.fetchedAt) _fired = false;
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final e = widget.next.entry;
    final who = widget.forLecturer ? 'Class group: ${e.classGroupName}' : 'Lecturer: ${e.lecturerName}';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, Color.lerp(c.primary, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.forLecturer ? 'NEXT LECTURE' : 'NEXT CLASS', style: TextStyle(color: c.onPrimary.withValues(alpha: 0.8), fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(e.courseName, style: TextStyle(color: c.onPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
        Text(e.courseCode, style: TextStyle(color: c.onPrimary.withValues(alpha: 0.9))),
        const SizedBox(height: 14),
        Text(countdownLabel(remaining), key: const ValueKey('countdown'), style: TextStyle(color: c.onPrimary, fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
        Text('${dayOffsetLabel(widget.next.dayOffset, widget.next.dateKey)} at ${minuteLabel(e.startMinute)}', style: TextStyle(color: c.onPrimary.withValues(alpha: 0.9))),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _meta(c, Icons.place_outlined, e.roomName),
          _meta(c, Icons.person_outline, who),
        ]),
      ]),
    );
  }

  Widget _meta(ColorScheme c, IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 16, color: c.onPrimary.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Flexible(child: Text(t, style: TextStyle(color: c.onPrimary.withValues(alpha: 0.95)))),
      ]);
}

IconData notificationIcon(String type) {
  switch (type) {
    case 'BELL':
      return Icons.notifications_active_outlined;
    case 'UPCOMING_CLASS':
      return Icons.schedule;
    case 'CLASS_CANCELLED':
      return Icons.event_busy_outlined;
    case 'ROOM_CHANGE':
      return Icons.meeting_room_outlined;
    case 'SUBSTITUTION':
      return Icons.swap_horiz;
    case 'CLASS_RESCHEDULED':
      return Icons.edit_calendar_outlined;
    case 'TIMETABLE_CHANGE':
      return Icons.edit_calendar_outlined;
    case 'ANNOUNCEMENT':
      return Icons.campaign_outlined;
    default:
      return Icons.notifications_none;
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.n, this.onTap});
  final AppNotification n;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: n.read ? c.surfaceContainerHigh : c.primaryContainer, child: Icon(notificationIcon(n.type), color: n.read ? c.outline : c.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700))),
                  if (!n.read) Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 4),
                Text(n.body, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onSurfaceVariant, height: 1.3)),
                const SizedBox(height: 6),
                Text(relativeTime(n.createdAt), style: TextStyle(color: c.outline, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
