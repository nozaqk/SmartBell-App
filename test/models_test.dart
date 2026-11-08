import 'package:flutter_test/flutter_test.dart';
import 'package:smartbell/core/models.dart';

void main() {
  final entry = {
    'id': 'e1', 'dayOfWeek': 1, 'startMinute': 645, 'endMinute': 735, 'courseCode': 'ECE 204', 'courseName': 'Mathematics',
    'lecturerName': 'Kwame Mensah', 'lecturerTitle': 'Mr.', 'roomName': 'Laboratory 3', 'classGroupName': 'Level 200',
    'cancelled': false, 'cancelReason': null,
  };

  test('ClassEntry joins lecturer title and name', () {
    final e = ClassEntry.fromJson(entry);
    expect(e.lecturerName, 'Mr. Kwame Mensah');
    expect(e.roomName, 'Laboratory 3');
    expect(e.cancelled, false);
  });

  test('Student dashboard parses and exposes student profile', () {
    final d = Dashboard.fromJson({
      'role': 'STUDENT',
      'profile': {
        'id': 'u1', 'role': 'STUDENT', 'fullName': 'Ama Boateng', 'loginId': 'S-001', 'email': null,
        'school': {'name': 'Demo School', 'timezone': 'Africa/Accra', 'logoUrl': null},
        'student': {'level': 200, 'programme': 'BEng Electronics', 'department': 'Electronics', 'classGroups': [{'id': 'g1', 'name': 'Level 200'}]},
      },
      'nextClass': {...entry, 'date': '2026-11-09', 'dayOffset': 1, 'countdownSeconds': 3600},
      'today': [entry],
      'isHoliday': false,
      'unreadNotifications': 2,
      'latestNotifications': [
        {'id': 'n1', 'type': 'BELL', 'title': 'BREAK TIME', 'body': 'x', 'data': {'route': 'timetable'}, 'createdAt': '2026-11-09T10:15:00.000Z', 'readAt': null},
      ],
      'canPublishAnnouncements': false,
    });
    expect(d.profile.isStudent, true);
    expect(d.profile.classGroups, ['Level 200']);
    expect(d.profile.level, '200');
    expect(d.nextClass!.dayOffset, 1);
    expect(d.nextClass!.countdownSeconds, 3600);
    expect(d.nextClass!.entry.courseCode, 'ECE 204');
    expect(d.unread, 2);
    expect(d.latest.single.route, 'timetable');
    expect(d.latest.single.read, false);
    expect(d.canPublish, false);
  });

  test('Lecturer profile uses title in display name and lists courses', () {
    final p = Profile.fromJson({
      'id': 'u2', 'role': 'LECTURER', 'fullName': 'Kwame Mensah', 'loginId': 'L-001',
      'school': {'name': 'Demo School', 'timezone': 'Africa/Accra'},
      'lecturer': {'title': 'Mr.', 'department': 'Electronics', 'courses': [{'id': 'c1', 'code': 'ECE 204', 'name': 'Mathematics'}]},
    });
    expect(p.isLecturer, true);
    expect(p.displayName, 'Mr. Kwame Mensah');
    expect(p.courses, ['ECE 204 - Mathematics']);
  });

  test('A null nextClass is handled', () {
    expect(NextClass.fromJson(null), isNull);
  });

  test('WeekTimetable fills all seven days', () {
    final w = WeekTimetable.fromJson({'today': '2026-11-09', 'days': {'1': [entry]}});
    expect(w.days.keys.toList(), [1, 2, 3, 4, 5, 6, 7]);
    expect(w.days[1]!.length, 1);
    expect(w.days[2], isEmpty);
  });

  test('Notification default route is the notification list', () {
    final n = AppNotification.fromJson({'id': 'n', 'type': 'BELL', 'title': 't', 'body': 'b', 'data': {}, 'createdAt': '2026-11-09T10:15:00Z', 'readAt': '2026-11-09T10:16:00Z'});
    expect(n.route, 'notifications');
    expect(n.read, true);
  });
}
