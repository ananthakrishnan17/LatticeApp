int remainingPlanMonths(DateTime? expiresAt, {DateTime? from}) {
  if (expiresAt == null) return 0;
  final now = from ?? DateTime.now();
  if (!expiresAt.isAfter(now)) return 0;

  var cursor = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
    now.microsecond,
  );
  var months = 0;
  while (true) {
    final next = DateTime(
      cursor.year,
      cursor.month + 1,
      cursor.day,
      cursor.hour,
      cursor.minute,
      cursor.second,
      cursor.millisecond,
      cursor.microsecond,
    );
    if (next.isAfter(expiresAt)) break;
    months += 1;
    cursor = next;
  }
  if (cursor.isBefore(expiresAt)) {
    months += 1;
  }
  return months;
}

String monthUnit(int months) => months == 1 ? 'month' : 'months';
