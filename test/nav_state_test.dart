import 'package:flutter_test/flutter_test.dart';
import 'package:smartbell/state/nav_state.dart';

void main() {
  test('push routes map to tabs', () {
    final n = NavState();
    n.routeFromPush('timetable', ready: true);
    expect(n.tab, NavState.tabTimetable);
    n.routeFromPush('notifications', ready: true);
    expect(n.tab, NavState.tabNotifications);
    n.routeFromPush('announcements', ready: true);
    expect(n.tab, NavState.tabHome);
    expect(n.openAnnouncements, true);
    n.routeFromPush(null, ready: true);
    expect(n.tab, NavState.tabNotifications);
  });

  test('a tap before sign-in is remembered and applied afterwards', () {
    final n = NavState();
    n.routeFromPush('timetable', ready: false);
    expect(n.tab, NavState.tabHome);
    n.applyPending();
    expect(n.tab, NavState.tabTimetable);
    n.applyPending(); // only once
    n.select(0);
    n.applyPending();
    expect(n.tab, 0);
  });

  test('classes route opens the lecturer classes screen from the home tab', () {
    final n = NavState();
    n.select(2);
    n.routeFromPush('classes', ready: true);
    expect(n.tab, NavState.tabHome);
    expect(n.openClasses, true);
    n.classesOpened();
    expect(n.openClasses, false);
  });
}
