import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/models.dart';

/// Loads and caches everything the screens show. Each section keeps its own error so one failure
/// does not blank the whole app.
class DataStore extends ChangeNotifier {
  DataStore(this.api);
  final ApiClient api;

  Dashboard? dashboard;
  String? dashboardError;
  bool dashboardLoading = false;

  WeekTimetable? week;
  String? weekError;
  bool weekLoading = false;

  final List<AppNotification> notifications = [];
  int unread = 0;
  int _notifPage = 0;
  bool notifHasMore = true;
  bool notifLoading = false;
  String? notifError;

  Future<void> loadDashboard() async {
    dashboardLoading = true;
    notifyListeners();
    try {
      dashboard = Dashboard.fromJson(await api.get('/mobile/dashboard') as Map<String, dynamic>);
      unread = dashboard!.unread;
      dashboardError = null;
    } on ApiException catch (e) {
      dashboardError = e.message;
    } finally {
      dashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWeek() async {
    weekLoading = true;
    notifyListeners();
    try {
      week = WeekTimetable.fromJson(await api.get('/mobile/timetable/week') as Map<String, dynamic>);
      weekError = null;
    } on ApiException catch (e) {
      weekError = e.message;
    } finally {
      weekLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotifications({bool refresh = false}) async {
    if (notifLoading) return;
    if (refresh) {
      _notifPage = 0;
      notifHasMore = true;
    }
    if (!notifHasMore) return;
    notifLoading = true;
    notifError = null;
    notifyListeners();
    try {
      final j = await api.get('/mobile/notifications', query: {'page': '${_notifPage + 1}', 'pageSize': '25'}) as Map<String, dynamic>;
      final items = [for (final n in (j['items'] as List)) AppNotification.fromJson((n as Map).cast<String, dynamic>())];
      if (refresh) notifications.clear();
      notifications.addAll(items);
      _notifPage = (j['page'] as num).toInt();
      notifHasMore = _notifPage < (j['totalPages'] as num).toInt();
      unread = (j['unread'] as num).toInt();
    } on ApiException catch (e) {
      notifError = e.message;
    } finally {
      notifLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    final i = notifications.indexWhere((x) => x.id == n.id);
    if (i >= 0) notifications[i] = n.copyWith(read: true);
    unread = unread > 0 ? unread - 1 : 0;
    notifyListeners();
    try {
      await api.post('/mobile/notifications/read', body: {'ids': [n.id]});
    } on ApiException {
      // Best effort; the next refresh restores the true state.
    }
  }

  Future<void> markAllRead() async {
    try {
      await api.post('/mobile/notifications/read', body: {'all': true});
      for (var i = 0; i < notifications.length; i++) {
        notifications[i] = notifications[i].copyWith(read: true);
      }
      unread = 0;
      notifyListeners();
    } on ApiException {
      rethrow;
    }
  }

  /// Called when a push arrives while the app is open.
  Future<void> onPushReceived() async {
    await Future.wait([loadDashboard(), loadNotifications(refresh: true), loadWeek()]);
  }

  void clear() {
    dashboard = null;
    week = null;
    notifications.clear();
    unread = 0;
    _notifPage = 0;
    notifHasMore = true;
    dashboardError = weekError = notifError = null;
    notifyListeners();
  }
}
