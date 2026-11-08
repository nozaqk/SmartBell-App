import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../state/session.dart';
import 'widgets.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<ExamItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final j = await context.read<Session>().api.get('/mobile/exams') as List;
      if (mounted) setState(() => _items = [for (final e in j) ExamItem.fromJson((e as Map).cast<String, dynamic>())]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('EEE, d MMM yyyy');
    Widget body;
    if (_items == null && _error == null) {
      body = const LoadingView();
    } else if (_error != null) {
      body = ErrorView(message: _error!, onRetry: _load);
    } else if (_items!.isEmpty) {
      body = const EmptyView(icon: Icons.fact_check_outlined, title: 'No examinations scheduled', subtitle: 'Exam dates published by your school appear here.');
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = _items![i];
          final same = e.start.year == e.end.year && e.start.month == e.end.month && e.start.day == e.end.day;
          return Card.outlined(child: ListTile(leading: const Icon(Icons.fact_check_outlined), title: Text(e.title), subtitle: Text(same ? f.format(e.start) : '${f.format(e.start)} to ${f.format(e.end)}')));
        },
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Exam timetable')), body: RefreshIndicator(onRefresh: _load, child: body));
  }
}
