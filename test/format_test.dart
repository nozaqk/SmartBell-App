import 'package:flutter_test/flutter_test.dart';
import 'package:smartbell/core/format.dart';

void main() {
  test('minuteLabel formats minutes after midnight in 12-hour time', () {
    expect(minuteLabel(0), '12:00 AM');
    expect(minuteLabel(645), '10:45 AM');
    expect(minuteLabel(720), '12:00 PM');
    expect(minuteLabel(13 * 60 + 5), '1:05 PM');
    expect(minuteLabel(23 * 60 + 59), '11:59 PM');
  });

  test('countdownLabel', () {
    expect(countdownLabel(9), '9s');
    expect(countdownLabel(125), '2m 05s');
    expect(countdownLabel(3725), '1h 02m 05s');
    expect(countdownLabel(-5), '0s');
  });

  test('dayOffsetLabel', () {
    expect(dayOffsetLabel(0, '2026-11-09'), 'Today');
    expect(dayOffsetLabel(1, '2026-11-10'), 'Tomorrow');
    expect(dayOffsetLabel(3, '2026-11-12'), contains('Thursday'));
  });

  test('greeting', () {
    expect(greeting(8), 'Good morning');
    expect(greeting(13), 'Good afternoon');
    expect(greeting(20), 'Good evening');
  });
}
