import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/reschedule_models.dart';
import '../state/session.dart';
import 'slot_widgets.dart';
import 'widgets.dart';

String _newRequestId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Form for moving one lecture. Step 1 collects the change, step 2 shows original vs proposed and any clashes
/// reported by the server, and only a clash-free change can be confirmed. Pops `true` when saved.
class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key, required this.lecture});
  final LecturerClass lecture;
  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  final _reason = TextEditingController();
  late DateTime _date;
  late TimeOfDay _start, _end;
  String? _roomId;
  List<RoomOption>? _rooms;
  String? _loadError, _formError;
  ReschedulePreview? _preview;
  bool _busy = false;
  // One id per attempt: a retry after a dropped connection can never create the change twice.
  String _requestId = _newRequestId();

  ApiClient get _api => context.read<Session>().api;
  LecturerClass get _l => widget.lecture;

  @override
  void initState() {
    super.initState();
    _date = DateTime.tryParse(_l.current.date) ?? DateTime.now();
    _start = TimeOfDay(hour: _l.current.startMinute ~/ 60, minute: _l.current.startMinute % 60);
    _end = TimeOfDay(hour: _l.current.endMinute ~/ 60 % 24, minute: _l.current.endMinute % 60);
    _roomId = _l.current.roomId;
    _loadRooms();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final j = await _api.get('/mobile/lecturer/rooms') as Map<String, dynamic>;
      if (mounted) setState(() => _rooms = [for (final r in (j['items'] as List)) RoomOption.fromJson((r as Map).cast<String, dynamic>())]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  int _min(TimeOfDay t) => t.hour * 60 + t.minute;
  String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> get _body => {
        'entryId': _l.entryId,
        'occurrenceDate': _l.occurrenceDate,
        'toDate': _key(_date),
        'toStartMinute': _min(_start),
        'toEndMinute': _min(_end),
        'toRoomId': _roomId,
        'reason': _reason.text.trim(),
      };

  /// Any edit invalidates a previous review and starts a new attempt.
  void _edited(VoidCallback f) => setState(() {
        f();
        _preview = null;
        _formError = null;
        _requestId = _newRequestId();
      });

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (d != null) _edited(() => _date = d);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (t != null) _edited(() => start ? _start = t : _end = t);
  }

  Future<void> _review() async {
    if (_roomId == null) return setState(() => _formError = 'Choose a room.');
    if (_min(_end) <= _min(_start)) return setState(() => _formError = 'The end time must be after the start time.');
    if (_reason.text.trim().length < 3) return setState(() => _formError = 'Give a short reason. Students will see it.');
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final j = await _api.post('/mobile/lecturer/reschedules/preview', body: _body) as Map<String, dynamic>;
      if (mounted) setState(() => _preview = ReschedulePreview.fromJson(j));
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await _api.post('/mobile/lecturer/reschedules', body: {..._body, 'requestId': _requestId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class rescheduled. Students have been notified.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // A clash found at save time (someone else took the slot): show it and let the lecturer adjust.
      final conflicts = e.details is Map ? Clash.listFrom((e.details as Map)['conflicts']) : const <Clash>[];
      setState(() {
        if (conflicts.isNotEmpty && _preview != null) {
          _preview = ReschedulePreview(ok: false, original: _preview!.original, current: _preview!.current, proposed: _preview!.proposed, conflicts: conflicts, courseLabel: _preview!.courseLabel, classGroup: _preview!.classGroup);
          _requestId = _newRequestId();
        } else {
          _formError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule class')),
      body: _rooms == null
          ? (_loadError != null ? ErrorView(message: _loadError!, onRetry: _loadRooms) : const LoadingView())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('${_l.courseCode} · ${_l.courseName}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(_l.classGroup, style: TextStyle(color: c.onSurfaceVariant)),
              const SizedBox(height: 12),
              SlotBox(label: 'ORIGINAL', slot: _l.original),
              const SizedBox(height: 20),
              Text('Move this lecture to', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _busy ? null : _pickDate, icon: const Icon(Icons.event_outlined), label: Align(alignment: Alignment.centerLeft, child: Text(dateLabel(_key(_date))))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pickTime(true), icon: const Icon(Icons.schedule), label: Text('Starts ${minuteLabel(_min(_start))}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pickTime(false), icon: const Icon(Icons.schedule), label: Text('Ends ${minuteLabel(_min(_end))}'))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _rooms!.any((r) => r.id == _roomId) ? _roomId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Room or laboratory'),
                items: [for (final r in _rooms!) DropdownMenuItem(value: r.id, child: Text(r.label, overflow: TextOverflow.ellipsis))],
                onChanged: _busy ? null : (v) => _edited(() => _roomId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Reason (students will see this)'),
                onChanged: (_) => _edited(() {}),
              ),
              if (_formError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_formError!, style: TextStyle(color: c.error))),
              if (p == null)
                FilledButton(onPressed: _busy ? null : _review, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Review change'))
              else ...[
                const Divider(height: 32),
                Text('Review', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SlotBox(label: 'ORIGINAL', slot: p.original),
                const SizedBox(height: 8),
                SlotBox(label: 'NEW', slot: p.proposed, highlight: p.ok),
                const SizedBox(height: 12),
                if (!p.ok)
                  Card(
                    color: c.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('This change clashes with other classes', style: TextStyle(fontWeight: FontWeight.w700, color: c.onErrorContainer)),
                        const SizedBox(height: 6),
                        for (final k in p.conflicts) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• ${k.message}', style: TextStyle(color: c.onErrorContainer))),
                        const SizedBox(height: 6),
                        Text('Change the date, time or room above and review again.', style: TextStyle(color: c.onErrorContainer, fontSize: 12)),
                      ]),
                    ),
                  )
                else
                  Text('No clashes. Students of ${p.classGroup} will be notified.', style: TextStyle(color: c.onSurfaceVariant)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy || !p.ok ? null : _confirm, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm reschedule')),
              ],
            ]),
    );
  }
}
