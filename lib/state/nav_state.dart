import 'package:flutter/foundation.dart';

/// Which tab / screen to open, driven by notification taps. A tap that arrives before sign-in is remembered
/// and applied once the home shell exists.
class NavState extends ChangeNotifier {
  int tab = 0;
  bool openAnnouncements = false;
  bool openClasses = false;
  String? _pendingRoute;

  static const tabHome = 0, tabTimetable = 1, tabNotifications = 2, tabProfile = 3;

  void routeFromPush(String? route, {required bool ready}) {
    if (!ready) {
      _pendingRoute = route ?? 'notifications';
      return;
    }
    _apply(route);
  }

  void applyPending() {
    final r = _pendingRoute;
    if (r == null) return;
    _pendingRoute = null;
    _apply(r);
  }

  void _apply(String? route) {
    switch (route) {
      case 'timetable':
        tab = tabTimetable;
        break;
      case 'classes':
        tab = tabHome;
        openClasses = true;
        break;
      case 'announcements':
        tab = tabHome;
        openAnnouncements = true;
        break;
      default:
        tab = tabNotifications;
    }
    notifyListeners();
  }

  void select(int i) {
    tab = i;
    notifyListeners();
  }

  void announcementsOpened() => openAnnouncements = false;
  void classesOpened() => openClasses = false;

  void reset() {
    tab = 0;
    openAnnouncements = false;
    openClasses = false;
    _pendingRoute = null;
  }
}
