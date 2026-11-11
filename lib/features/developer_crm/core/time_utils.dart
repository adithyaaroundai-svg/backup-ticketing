import 'package:intl/intl.dart';

/// Timestamp/date helpers. The API always sends UTC (raw, per API.md's
/// "Data conventions"). The original EJS app always rendered times in IST
/// (Asia/Kolkata) since the team is based in India, regardless of viewer
/// location — we replicate that with a fixed +5:30 offset rather than
/// pulling in the full `timezone` package/tzdata, which is a reasonable
/// simplification since India does not observe DST.
const Duration kIstOffset = Duration(hours: 5, minutes: 30);

/// Parses a server timestamp string, which may be `'YYYY-MM-DD HH:MM:SS'`
/// (implicitly UTC, no marker) or full ISO-8601 (with `Z`/offset already).
DateTime? parseServerTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    var s = raw.trim();
    if (!s.contains('T')) s = s.replaceFirst(' ', 'T');
    if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d\d:\d\d$').hasMatch(s)) {
      s = '${s}Z';
    }
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return null;
  }
}

/// Parses a plain date string `'YYYY-MM-DD'`.
DateTime? parseServerDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

/// Formats an instant as an IST (`+05:30`) calendar date `'YYYY-MM-DD'`.
String formatIstDateKey(DateTime dt) {
  final ist = dt.toUtc().add(kIstOffset);
  return '${ist.year.toString().padLeft(4, '0')}-'
      '${ist.month.toString().padLeft(2, '0')}-'
      '${ist.day.toString().padLeft(2, '0')}';
}

/// Returns today's calendar date in IST (`'YYYY-MM-DD'`).
String todayIstDateKey({DateTime? now}) {
  return formatIstDateKey(now ?? DateTime.now());
}

/// Resolves the grouping date key (`'YYYY-MM-DD'` or `'No date'`) for a task.
/// Uses `displayDate` when present and falls back to `createdAt` in IST.
String resolveTaskDisplayDateKey({
  String? displayDate,
  String? createdAt,
}) {
  if (displayDate != null && displayDate.isNotEmpty) return displayDate;
  final dt = parseServerTimestamp(createdAt);
  if (dt == null) return 'No date';
  return formatIstDateKey(dt);
}

/// Returns `true` when a task's current board/task date precedes [todayIst].
bool isTaskDateBeforeToday({
  String? displayDate,
  String? taskDate,
  String? createdAt,
  required String todayIst,
}) {
  final displayKey = resolveTaskDisplayDateKey(
    displayDate: displayDate,
    createdAt: createdAt,
  );
  if (displayKey != 'No date') {
    if (displayKey.compareTo(todayIst) < 0) return true;
    // Keep legacy `task_date` synchronized when `display_date` was updated first.
    return displayKey == todayIst &&
        taskDate != null &&
        taskDate.isNotEmpty &&
        taskDate.compareTo(todayIst) < 0;
  }
  return taskDate != null &&
      taskDate.isNotEmpty &&
      taskDate.compareTo(todayIst) < 0;
}

/// Returns `true` for active Today's Tasks in `'not_started'` ("Yet to start")
/// from an earlier IST day that should automatically carry forward to today.
bool shouldAutoCarryForwardNotStarted({
  required String status,
  required bool pending,
  String? displayDate,
  String? taskDate,
  String? createdAt,
  required String todayIst,
}) {
  if (pending || status != 'not_started') return false;
  return isTaskDateBeforeToday(
    displayDate: displayDate,
    taskDate: taskDate,
    createdAt: createdAt,
    todayIst: todayIst,
  );
}

/// Formats a timestamp for display, converted to IST.
String fmtDateTimeIst(String? raw, {String pattern = 'dd MMM yyyy, hh:mm a'}) {
  final dt = parseServerTimestamp(raw);
  if (dt == null) return '-';
  final ist = dt.add(kIstOffset);
  return '${DateFormat(pattern).format(ist)} IST';
}

/// Formats a plain `'YYYY-MM-DD'` date for display (no timezone shift
/// needed — it's a calendar date, not an instant).
String fmtDate(String? raw, {String pattern = 'dd MMM yyyy'}) {
  final dt = parseServerDate(raw);
  if (dt == null) return '-';
  return DateFormat(pattern).format(dt);
}

/// Computes "live" elapsed seconds for a running timer: [base] seconds
/// already accrued, plus wall-clock elapsed since [timerStartedAt] if
/// [running] is true.
int computeLiveSeconds({
  required int base,
  required bool running,
  String? timerStartedAt,
  DateTime? now,
}) {
  if (!running || timerStartedAt == null || timerStartedAt.isEmpty) return base;
  final started = parseServerTimestamp(timerStartedAt);
  if (started == null) return base;
  final n = (now ?? DateTime.now()).toUtc();
  final elapsed = n.difference(started).inSeconds;
  if (elapsed <= 0) return base;
  return base + elapsed;
}

/// Formats a seconds count as `H:MM:SS` (or `M:SS` if under an hour).
String fmtDuration(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
  return '$m:${sec.toString().padLeft(2, '0')}';
}
