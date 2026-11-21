import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/reschedule_models.dart';
import '../state/session.dart';
import 'slot_widgets.dart';
import 'widgets.dart';

/// Every change the lecturer has made, newest first. Withdrawn and replaced versions are kept for the record.
class RescheduleHistoryScreen extends StatefulWidget {
  const RescheduleHistoryScreen({super.key});
  @override
  State<RescheduleHistoryScreen> createState() => _RescheduleHistoryScreenState();
}

class _RescheduleHistoryScreenState extends State<RescheduleHistoryScreen> {
  List<RescheduleRecord>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final j = await context.read<Session>().api.get('/mobile/lecturer/reschedules', query: {'pageSize': '50'}) as Map<String, dynamic>;
      if (mounted) setState(() => _items = [for (final i in (j['items'] as List)) RescheduleRecord.fromJson((i as Map).cast<String, dynamic>())]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule history')),
      body: items == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const LoadingView())
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: const [SizedBox(height: 260, child: EmptyView(icon: Icons.history, title: 'No changes yet', subtitle: 'Lectures you reschedule are listed here.'))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = items[i];
                        final c = Theme.of(context).colorScheme;
                        return Card.outlined(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(r.courseLabel, style: const TextStyle(fontWeight: FontWeight.w700))),
                                StatusChip(r.statusLabel, color: r.isActive ? c.primary : c.outline),
                              ]),
                              Text('${r.classGroup} · ${shortDateTime(r.createdAt)}', style: TextStyle(color: c.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 10),
                              SlotBox(label: 'PREVIOUS', slot: r.from),
                              const SizedBox(height: 6),
                              SlotBox(label: 'NEW', slot: r.to, highlight: r.isActive),
                              const SizedBox(height: 8),
                              Text('Reason: ${r.reason}', style: TextStyle(color: c.onSurfaceVariant)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
