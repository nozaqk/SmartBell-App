/// Plain data classes mirroring docs/API.md of the SmartBell backend.
int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? d);
String _str(dynamic v, [String d = '']) => v == null ? d : '$v';

class ClassEntry {
  ClassEntry({
    required this.id,
    required this.dayOfWeek,
    required this.startMinute,
    required this.endMinute,
    required this.courseCode,
    required this.courseName,
    required this.lecturerName,
    required this.roomName,
    required this.classGroupName,
    required this.cancelled,
    this.cancelReason,
  });

  final String id;
  final int dayOfWeek, startMinute, endMinute;
  final String courseCode, courseName, lecturerName, roomName, classGroupName;
  final bool cancelled;
  final String? cancelReason;

  factory ClassEntry.fromJson(Map<String, dynamic> j) {
    final title = _str(j['lecturerTitle']);
    final name = _str(j['lecturerName']);
    return ClassEntry(
      id: _str(j['id']),
      dayOfWeek: _int(j['dayOfWeek']),
      startMinute: _int(j['startMinute']),
      endMinute: _int(j['endMinute']),
      courseCode: _str(j['courseCode']),
      courseName: _str(j['courseName']),
      lecturerName: title.isEmpty ? name : '$title $name',
      roomName: _str(j['roomName']),
      classGroupName: _str(j['classGroupName']),
      cancelled: j['cancelled'] == true,
      cancelReason: j['cancelReason'] as String?,
    );
  }
}

class NextClass {
  NextClass({required this.entry, required this.dateKey, required this.dayOffset, required this.countdownSeconds});
  final ClassEntry entry;
  final String dateKey;
  final int dayOffset, countdownSeconds;

  static NextClass? fromJson(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    return NextClass(
      entry: ClassEntry.fromJson(j),
      dateKey: _str(j['date']),
      dayOffset: _int(j['dayOffset']),
      countdownSeconds: _int(j['countdownSeconds']),
    );
  }
}

class Profile {
  Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.loginId,
    required this.schoolName,
    required this.timezone,
    this.email,
    this.title,
    this.level,
    this.programme,
    this.department,
    this.classGroups = const [],
    this.courses = const [],
  });

  final String id, role, fullName, loginId, schoolName, timezone;
  final String? email, title, level, programme, department;
  final List<String> classGroups; // students: groups they belong to
  final List<String> courses; // lecturers: "CODE - Name"

  bool get isLecturer => role == 'LECTURER';
  bool get isStudent => role == 'STUDENT';

  /// "Mr. Mensah"-style short name for greetings.
  String get displayName => isLecturer && (title ?? '').isNotEmpty ? '$title $fullName' : fullName;

  factory Profile.fromJson(Map<String, dynamic> j) {
    final school = (j['school'] as Map?) ?? const {};
    final s = j['student'] as Map?;
    final l = j['lecturer'] as Map?;
    return Profile(
      id: _str(j['id']),
      role: _str(j['role']),
      fullName: _str(j['fullName']),
      loginId: _str(j['loginId']),
      email: j['email'] as String?,
      schoolName: _str(school['name']),
      timezone: _str(school['timezone'], 'Africa/Accra'),
      title: l?['title'] as String?,
      level: s?['level'] == null ? null : _str(s!['level']),
      programme: s?['programme'] as String?,
      department: ((s ?? l)?['department']) as String?,
      classGroups: [for (final g in (s?['classGroups'] as List? ?? const [])) _str((g as Map)['name'])],
      courses: [for (final c in (l?['courses'] as List? ?? const [])) '${(c as Map)['code']} - ${c['name']}'],
    );
  }
}

class AppNotification {
  AppNotification({required this.id, required this.type, required this.title, required this.body, required this.data, required this.createdAt, required this.read});
  final String id, type, title, body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool read;

  String get route => _str(data['route'], 'notifications');

  AppNotification copyWith({bool? read}) => AppNotification(id: id, type: type, title: title, body: body, data: data, createdAt: createdAt, read: read ?? this.read);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _str(j['id']),
        type: _str(j['type']),
        title: _str(j['title']),
        body: _str(j['body']),
        data: (j['data'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse(_str(j['createdAt']))?.toUtc() ?? DateTime.now().toUtc(),
        read: j['readAt'] != null,
      );
}

class Dashboard {
  Dashboard({
    required this.profile,
    required this.nextClass,
    required this.today,
    required this.isHoliday,
    required this.unread,
    required this.latest,
    required this.canPublish,
    required this.fetchedAt,
  });

  final Profile profile;
  final NextClass? nextClass;
  final List<ClassEntry> today;
  final bool isHoliday, canPublish;
  final int unread;
  final List<AppNotification> latest;
  final DateTime fetchedAt;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        profile: Profile.fromJson((j['profile'] as Map).cast<String, dynamic>()),
        nextClass: NextClass.fromJson(j['nextClass']),
        today: [for (final e in (j['today'] as List? ?? const [])) ClassEntry.fromJson((e as Map).cast<String, dynamic>())],
        isHoliday: j['isHoliday'] == true,
        unread: _int(j['unreadNotifications']),
        latest: [for (final n in (j['latestNotifications'] as List? ?? const [])) AppNotification.fromJson((n as Map).cast<String, dynamic>())],
        canPublish: j['canPublishAnnouncements'] == true,
        fetchedAt: DateTime.now(),
      );
}

class WeekTimetable {
  WeekTimetable(this.days, this.today);
  final Map<int, List<ClassEntry>> days; // 1 = Monday ... 7 = Sunday
  final String today;

  factory WeekTimetable.fromJson(Map<String, dynamic> j) {
    final raw = (j['days'] as Map?) ?? const {};
    final out = <int, List<ClassEntry>>{};
    for (var d = 1; d <= 7; d++) {
      out[d] = [for (final e in (raw['$d'] as List? ?? const [])) ClassEntry.fromJson((e as Map).cast<String, dynamic>())];
    }
    return WeekTimetable(out, _str(j['today']));
  }
}

class ExamItem {
  ExamItem({required this.title, required this.start, required this.end, this.description});
  final String title;
  final DateTime start, end;
  final String? description;

  factory ExamItem.fromJson(Map<String, dynamic> j) => ExamItem(
        title: _str(j['title'], 'Examination'),
        start: DateTime.tryParse(_str(j['startDate'])) ?? DateTime.now(),
        end: DateTime.tryParse(_str(j['endDate'])) ?? DateTime.now(),
        description: j['description'] as String?,
      );
}

class ClassGroupRef {
  ClassGroupRef(this.id, this.name);
  final String id, name;
  factory ClassGroupRef.fromJson(Map<String, dynamic> j) => ClassGroupRef(_str(j['id']), _str(j['name']));
}

class ClassGroupOption {
  ClassGroupOption({required this.id, required this.name, this.level, this.programme});
  final String id, name;
  final int? level;
  final String? programme;

  String get label => programme == null || programme!.isEmpty ? name : '$name · $programme';

  factory ClassGroupOption.fromJson(Map<String, dynamic> j) =>
      ClassGroupOption(id: _str(j['id']), name: _str(j['name']), level: j['level'] == null ? null : _int(j['level']), programme: j['programme'] as String?);
}

/// GET /auth/options: what the sign-up and forgot-password screens need before anyone is signed in.
class AuthOptions {
  AuthOptions({required this.schoolName, required this.studentSelfRegistration, required this.passwordResetBySms, required this.classGroups});
  final String schoolName;
  final bool studentSelfRegistration, passwordResetBySms;
  final List<ClassGroupOption> classGroups;

  factory AuthOptions.fromJson(Map<String, dynamic> j) => AuthOptions(
        schoolName: _str((j['school'] as Map?)?['name']),
        studentSelfRegistration: j['studentSelfRegistration'] == true,
        passwordResetBySms: j['passwordResetBySms'] == true,
        classGroups: [for (final g in (j['classGroups'] as List? ?? const [])) ClassGroupOption.fromJson((g as Map).cast<String, dynamic>())],
      );
}
