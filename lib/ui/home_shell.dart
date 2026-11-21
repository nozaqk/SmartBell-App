import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/data_store.dart';
import '../state/nav_state.dart';
import '../state/session.dart';
import 'announcements_screen.dart';
import 'home_tab.dart';
import 'my_classes_screen.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';
import 'timetable_tab.dart';

/// Bottom-navigation shell shared by students and lecturers. Role-specific content lives inside the tabs.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final data = context.read<DataStore>();
    data.loadDashboard();
    data.loadWeek();
    data.loadNotifications(refresh: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NavState>().applyPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final data = context.read<DataStore>();
      data.loadDashboard();
      data.loadNotifications(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavState>();
    final unread = context.select<DataStore, int>((d) => d.unread);
    final isLecturer = context.select<Session, bool>((s) => s.profile?.isLecturer ?? false);

    if (nav.openAnnouncements) {
      nav.announcementsOpened();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
      });
    }

    if (nav.openClasses) {
      nav.classesOpened();
      if (isLecturer) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyClassesScreen()));
        });
      }
    }

    const pages = [HomeTab(), TimetableTab(), NotificationsTab(), ProfileTab()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: nav.tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.tab,
        onDestinationSelected: nav.select,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: isLecturer ? 'Teaching' : 'Timetable'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications)),
            label: 'Alerts',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
