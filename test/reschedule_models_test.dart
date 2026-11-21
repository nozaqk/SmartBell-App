import 'package:flutter_test/flutter_test.dart';
import 'package:smartbell/core/api_client.dart';
import 'package:smartbell/core/reschedule_models.dart';

void main() {
  final slot = {'date': '2026-11-23', 'startMinute': 645, 'endMinute': 735, 'roomId': 'r1', 'roomName': 'Laboratory 3'};

  test('lecturer class parses state and slots', () {
    final c = LecturerClass.fromJson({
      'entryId': 'e1', 'occurrenceDate': '2026-11-23',
      'course': {'code': 'ECE 204', 'name': 'Mathematics'}, 'classGroup': {'id': 'g', 'name': 'Level 200'},
      'original': slot, 'current': {...slot, 'date': '2026-11-25'}, 'state': 'RESCHEDULED', 'rescheduleId': 'x', 'reason': 'Meeting', 'canReschedule': true,
    });
    expect(c.state, LectureState.rescheduled);
    expect(c.current.date, '2026-11-25');
    expect(c.original.roomName, 'Laboratory 3');
    expect(c.canReschedule, true);
  });

  test('preview exposes conflicts and blocks confirmation', () {
    final p = ReschedulePreview.fromJson({
      'ok': false, 'course': {'code': 'ECE 204', 'name': 'Mathematics'}, 'classGroup': 'Level 200',
      'original': slot, 'current': slot, 'proposed': {...slot, 'startMinute': 540},
      'conflicts': [{'type': 'ROOM', 'message': 'Laboratory 3 is in use'}],
    });
    expect(p.ok, false);
    expect(p.conflicts.single.type, 'ROOM');
    expect(p.proposed.startMinute, 540);
  });

  test('history record labels', () {
    final r = RescheduleRecord.fromJson({
      'id': 'a', 'status': 'REVERTED', 'from': slot, 'to': slot, 'reason': 'x', 'course': {'code': 'C', 'name': 'N'},
      'classGroup': 'G', 'createdAt': '2026-11-20T10:00:00.000Z', 'revertedAt': null,
    });
    expect(r.statusLabel, 'Withdrawn');
    expect(r.isActive, false);
  });

  test('ApiException keeps the server details', () {
    final e = ApiException(409, 'clash', details: {'conflicts': []});
    expect((e.details as Map)['conflicts'], isEmpty);
  });
}
