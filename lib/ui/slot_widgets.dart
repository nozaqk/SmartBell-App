import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/reschedule_models.dart';

/// "Mon, 24 Nov" for a YYYY-MM-DD key.
String dateLabel(String key) {
  final d = DateTime.tryParse(key);
  return d == null ? key : DateFormat('EEE, d MMM yyyy').format(d);
}

String slotLine(Slot s) => '${dateLabel(s.date)}\n${rangeLabel(s.startMinute, s.endMinute)} · ${s.roomName}';

/// A labelled block showing one slot (used for "Original" and "New").
class SlotBox extends StatelessWidget {
  const SlotBox({super.key, required this.label, required this.slot, this.highlight = false});
  final String label;
  final Slot slot;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? c.primaryContainer : c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(slotLine(slot), style: const TextStyle(height: 1.35)),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
