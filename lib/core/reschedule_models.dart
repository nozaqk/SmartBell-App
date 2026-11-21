/// Data classes for the lecturer rescheduling endpoints (/mobile/lecturer/*). See docs/API.md of the backend.
int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? d);
String _str(dynamic v, [String d = '']) => v == null ? d : '$v';

/// One date, time range and room: where a lecture is, or would be.
class Slot {
  Slot({required this.date, required this.startMinute, required this.endMinute, required this.roomId, required this.roomName});
  final String date; // YYYY-MM-DD in the school's timezone
  final int startMinute, endMinute;
  final String roomId, roomName;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        date: _str(j['date']),
        startMinute: _int(j['startMinute']),
        endMinute: _int(j['endMinute']),
        roomId: _str(j['roomId']),
        roomName: _str(j['roomName']),
      );
}

enum LectureState { normal, rescheduled, cancelled }

class LecturerClass {
  LecturerClass({
    required this.entryId,
    required this.occurrenceDate,
    required this.courseCode,
    required this.courseName,
    required this.classGroup,
    required this.original,
    required this.current,
    required this.state,
    required this.canReschedule,
    this.rescheduleId,
    this.reason,
  });

  final String entryId, occurrenceDate, courseCode, courseName, classGroup;
  final Slot original, current;
  final LectureState state;
  final bool canReschedule;
  final String? rescheduleId, reason;

  factory LecturerClass.fromJson(Map<String, dynamic> j) {
    final course = (j['course'] as Map?)?.cast<String, dynamic>() ?? const {};
    final group = (j['classGroup'] as Map?)?.cast<String, dynamic>() ?? const {};
    final state = switch (_str(j['state'])) {
      'RESCHEDULED' => LectureState.rescheduled,
      'CANCELLED' => LectureState.cancelled,
      _ => LectureState.normal,
    };
    return LecturerClass(
      entryId: _str(j['entryId']),
      occurrenceDate: _str(j['occurrenceDate']),
      courseCode: _str(course['code']),
      courseName: _str(course['name']),
      classGroup: _str(group['name']),
      original: Slot.fromJson((j['original'] as Map).cast<String, dynamic>()),
      current: Slot.fromJson((j['current'] as Map).cast<String, dynamic>()),
      state: state,
      canReschedule: j['canReschedule'] == true,
      rescheduleId: j['rescheduleId'] as String?,
      reason: j['reason'] as String?,
    );
  }
}

class RoomOption {
  RoomOption({required this.id, required this.name, required this.type, this.building, this.capacity});
  final String id, name, type;
  final String? building;
  final int? capacity;

  String get label => [name, if (type == 'LABORATORY') 'lab', if (building != null && building!.isNotEmpty) building!].join(' · ');

  factory RoomOption.fromJson(Map<String, dynamic> j) => RoomOption(
        id: _str(j['id']),
        name: _str(j['name']),
        type: _str(j['type']),
        building: j['building'] as String?,
        capacity: j['capacity'] is num ? (j['capacity'] as num).toInt() : null,
      );
}

class Clash {
  Clash({required this.type, required this.message});
  final String type; // LECTURER | ROOM | CLASS_GROUP | STUDENTS
  final String message;

  factory Clash.fromJson(Map<String, dynamic> j) => Clash(type: _str(j['type']), message: _str(j['message']));

  static List<Clash> listFrom(dynamic v) =>
      v is List ? [for (final c in v) if (c is Map) Clash.fromJson(c.cast<String, dynamic>())] : const [];
}

/// The server's answer to "what would happen if I made this change?". Nothing is saved.
class ReschedulePreview {
  ReschedulePreview({required this.ok, required this.original, required this.current, required this.proposed, required this.conflicts, required this.courseLabel, required this.classGroup});
  final bool ok;
  final Slot original, current, proposed;
  final List<Clash> conflicts;
  final String courseLabel, classGroup;

  factory ReschedulePreview.fromJson(Map<String, dynamic> j) {
    final course = (j['course'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReschedulePreview(
      ok: j['ok'] == true,
      original: Slot.fromJson((j['original'] as Map).cast<String, dynamic>()),
      current: Slot.fromJson((j['current'] as Map).cast<String, dynamic>()),
      proposed: Slot.fromJson((j['proposed'] as Map).cast<String, dynamic>()),
      conflicts: Clash.listFrom(j['conflicts']),
      courseLabel: '${_str(course['code'])} ${_str(course['name'])}'.trim(),
      classGroup: _str(j['classGroup']),
    );
  }
}

/// A row of the lecturer's rescheduling history.
class RescheduleRecord {
  RescheduleRecord({required this.id, required this.status, required this.from, required this.to, required this.reason, required this.courseLabel, required this.classGroup, required this.createdAt, this.revertedAt});
  final String id, status, reason, courseLabel, classGroup;
  final Slot from, to;
  final DateTime createdAt;
  final DateTime? revertedAt;

  bool get isActive => status == 'ACTIVE';
  String get statusLabel => switch (status) { 'ACTIVE' => 'In force', 'REVERTED' => 'Withdrawn', 'SUPERSEDED' => 'Replaced', _ => status };

  factory RescheduleRecord.fromJson(Map<String, dynamic> j) {
    final course = (j['course'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RescheduleRecord(
      id: _str(j['id']),
      status: _str(j['status']),
      from: Slot.fromJson((j['from'] as Map).cast<String, dynamic>()),
      to: Slot.fromJson((j['to'] as Map).cast<String, dynamic>()),
      reason: _str(j['reason']),
      courseLabel: '${_str(course['code'])} ${_str(course['name'])}'.trim(),
      classGroup: _str(j['classGroup']),
      createdAt: DateTime.tryParse(_str(j['createdAt']))?.toUtc() ?? DateTime.now().toUtc(),
      revertedAt: DateTime.tryParse(_str(j['revertedAt'])),
    );
  }
}
