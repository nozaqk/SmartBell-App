import 'package:intl/intl.dart';

const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const dayShort = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 645 -> "10:45 AM". Timetable times are minutes after local midnight in the school timezone,
/// so no timezone conversion is ever applied to them.
String minuteLabel(int minute) {
  final h = minute ~/ 60;
  final m = minute % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

String rangeLabel(int start, int end) => '${minuteLabel(start)} - ${minuteLabel(end)}';

/// 3725 -> "1h 02m 05s"; 125 -> "2m 05s"; 9 -> "9s".
String countdownLabel(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}

String greeting(int hour) => hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

/// "Today", "Tomorrow" or the weekday for a class that is [dayOffset] days away.
String dayOffsetLabel(int dayOffset, String dateKey) {
  if (dayOffset == 0) return 'Today';
  if (dayOffset == 1) return 'Tomorrow';
  final d = DateTime.tryParse(dateKey);
  return d == null ? '$dayOffset days away' : DateFormat('EEEE, d MMM').format(d);
}

String shortDateTime(DateTime utc) => DateFormat('d MMM, h:mm a').format(utc.toLocal());

String relativeTime(DateTime utc, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(utc);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(utc.toLocal());
}
