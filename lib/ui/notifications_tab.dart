import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../state/data_store.dart';
import '../state/nav_state.dart';
import 'announcements_screen.dart';
import 'my_classes_screen.dart';
import 'widgets.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataStore>();
    final list = data.notifications;

    Widget body;
    if (list.isEmpty && data.notifLoading) {
      body = const LoadingView();
    } else if (list.isEmpty && data.notifError != null) {
      body = ErrorView(message: data.notifError!, onRetry: () => data.loadNotifications(refresh: true));
    } else if (list.isEmpty) {
      body = ListView(children: const [SizedBox(height: 320, child: EmptyView(icon: Icons.notifications_none, title: 'No notifications yet', subtitle: 'Bell, class and announcement alerts will appear here.'))]);
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) data.loadNotifications();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: list.length + (data.notifHasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i >= list.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            final n = list[i];
            return NotificationTile(
              n: n,
              onTap: () {
                data.markRead(n);
                if (n.route == 'timetable') {
                  context.read<NavState>().select(NavState.tabTimetable);
                } else if (n.route == 'classes') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyClassesScreen()));
                } else if (n.route == 'announcements') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
                }
              },
            );
          },
        ),
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(children: [
          Expanded(child: Text('Notifications', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          TextButton.icon(
            onPressed: data.unread == 0
                ? null
                : () async {
                    try {
                      await data.markAllRead();
                    } on ApiException catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Mark all read'),
          ),
        ]),
      ),
      Expanded(child: RefreshIndicator(onRefresh: () => data.loadNotifications(refresh: true), child: body)),
    ]);
  }
}
