/// Indian Standard Time (IST) Date and Time Utilities
/// IST is UTC+05:30 (Asia/Kolkata).
class IstDateUtils {
  static const Duration istOffset = Duration(hours: 5, minutes: 30);
  static const int istOffsetMs = (5 * 60 + 30) * 60 * 1000;

  static DateTime Function()? _dateProviderForTesting;

  /// Configure a controlled date provider for automated tests.
  /// Pass null to restore real system time.
  static void setDateProviderForTesting(DateTime Function()? provider) {
    _dateProviderForTesting = provider;
  }

  /// Reset testing date provider
  static void resetDateProviderForTesting() {
    _dateProviderForTesting = null;
  }

  static DateTime _getNow() {
    return _dateProviderForTesting != null ? _dateProviderForTesting!() : DateTime.now();
  }

  /// Returns current DateTime in Indian Standard Time (IST)
  static DateTime nowInIST() {
    final now = _getNow();
    final utc = now.toUtc();
    final istUtc = utc.add(istOffset);
    return DateTime(
      istUtc.year,
      istUtc.month,
      istUtc.day,
      istUtc.hour,
      istUtc.minute,
      istUtc.second,
      istUtc.millisecond,
    );
  }

  /// Returns today's date formatted as `yyyy-MM-dd` in IST
  static String getTodayISTString() {
    return toISTDateString(_getNow());
  }

  /// Returns date offset by [dayOffset] days from current IST date formatted as `yyyy-MM-dd`
  static String getOffsetISTDateString(int dayOffset) {
    final ist = nowInIST().add(Duration(days: dayOffset));
    return toISTDateString(ist);
  }

  /// Converts any [DateTime] or date string into a `yyyy-MM-dd` string in IST.
  /// If input is already formatted as `yyyy-MM-dd`, returns it directly to avoid double offset shifting.
  static String toISTDateString(dynamic input) {
    if (input == null) return '';

    if (input is String) {
      final trimmed = input.trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
        return trimmed;
      }
      final parsed = DateTime.tryParse(trimmed);
      if (parsed == null) return '';
      return toISTDateString(parsed);
    }

    if (input is DateTime) {
      if (input.isUtc) {
        final ist = input.add(istOffset);
        final year = ist.year.toString().padLeft(4, '0');
        final month = ist.month.toString().padLeft(2, '0');
        final day = ist.day.toString().padLeft(2, '0');
        return '$year-$month-$day';
      } else {
        final year = input.year.toString().padLeft(4, '0');
        final month = input.month.toString().padLeft(2, '0');
        final day = input.day.toString().padLeft(2, '0');
        return '$year-$month-$day';
      }
    }

    return '';
  }

  /// Checks if a date or string matches today in IST
  static bool isTodayIST(dynamic input) {
    if (input == null) return false;
    final dateStr = toISTDateString(input);
    return dateStr.isNotEmpty && dateStr == getTodayISTString();
  }

  /// Checks if a given DateTime falls on today in IST
  static bool isDateTimeTodayInIST(DateTime dateTime) {
    return isTodayIST(dateTime);
  }

  /// Returns ISO weekday number for a given `yyyy-MM-dd` date in IST:
  /// 1 = Monday, 2 = Tuesday, 3 = Wednesday, 4 = Thursday, 5 = Friday, 6 = Saturday, 7 = Sunday
  static int getWeekdayFromISTDateString(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return 1;
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    final date = DateTime.utc(year, month, day);
    return date.weekday; // In Dart: DateTime.monday = 1 ... DateTime.sunday = 7
  }

  /// Returns today's ISO weekday in IST (1 = Monday ... 7 = Sunday)
  static int getTodayISTWeekday() {
    return getWeekdayFromISTDateString(getTodayISTString());
  }

  /// Returns the `yyyy-MM-dd` date in the current IST week for a given weekday (1 = Monday ... 7 = Sunday)
  static String getISTDateForWeekday(int targetWeekday) {
    final todayStr = getTodayISTString();
    final todayWeekday = getWeekdayFromISTDateString(todayStr);
    final diff = targetWeekday - todayWeekday;
    final parts = todayStr.split('-');
    if (parts.length != 3) return todayStr;
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    final baseDate = DateTime.utc(year, month, day);
    final targetDate = baseDate.add(Duration(days: diff));
    final y = targetDate.year.toString().padLeft(4, '0');
    final m = targetDate.month.toString().padLeft(2, '0');
    final d = targetDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses days of week from schedule strings like "Monday", "Monday, Thursday", "Mon, Wed, Fri", etc.
  /// Returns sorted unique list of ISO weekday numbers (1 = Mon ... 7 = Sun).
  static List<int> parseWeekdaysFromScheduleString(String? scheduleStr) {
    if (scheduleStr == null || scheduleStr.isEmpty) return [];
    final s = scheduleStr.toLowerCase();
    final days = <int>{};

    if (s.contains('mon')) days.add(1);
    if (s.contains('tue')) days.add(2);
    if (s.contains('wed')) days.add(3);
    if (s.contains('thu')) days.add(4);
    if (s.contains('fri')) days.add(5);
    if (s.contains('sat')) days.add(6);
    if (s.contains('sun')) days.add(7);

    final list = days.toList()..sort();
    return list;
  }

  /// Determines whether a workout session and assignment are scheduled for a specific date in IST.
  /// Respects recurring weekdays, start dates, and specific scheduled dates.
  static bool isSessionScheduledForDate({
    String? recurringSchedule,
    List<int>? trainingDays,
    dynamic sessionStartDate,
    dynamic sessionEndDate,
    String? assignmentScheduledDate,
    dynamic assignmentAssignedAt,
    required String targetDateIST,
  }) {
    final targetWeekday = getWeekdayFromISTDateString(targetDateIST);

    // 1. If session has explicit recurringSchedule
    if (recurringSchedule != null && recurringSchedule.isNotEmpty) {
      final recurringWeekdays = parseWeekdaysFromScheduleString(recurringSchedule);
      final combinedWeekdays = <int>{
        ...recurringWeekdays,
        ...?trainingDays,
      }.toList()..sort();

      if (combinedWeekdays.isNotEmpty) {
        if (!combinedWeekdays.contains(targetWeekday)) {
          return false;
        }
        final effectiveStartDate = (assignmentScheduledDate != null && assignmentScheduledDate.isNotEmpty)
            ? assignmentScheduledDate
            : toISTDateString(sessionStartDate);
        if (effectiveStartDate.isNotEmpty && targetDateIST.compareTo(effectiveStartDate) < 0) {
          return false;
        }
        final endDate = toISTDateString(sessionEndDate);
        if (endDate.isNotEmpty && targetDateIST.compareTo(endDate) > 0) {
          return false;
        }
        return true;
      }
    }

    // 2. If assignment has an explicit scheduledDate (e.g. "2026-10-12")
    if (assignmentScheduledDate != null && assignmentScheduledDate.isNotEmpty) {
      if (targetDateIST == assignmentScheduledDate) {
        return true;
      }
      // Recurring weekly assignment on the same weekday as assigned
      final assignedWeekday = getWeekdayFromISTDateString(assignmentScheduledDate);
      if (targetWeekday == assignedWeekday && targetDateIST.compareTo(assignmentScheduledDate) >= 0) {
        return true;
      }
      return false;
    }

    // 3. If session has trainingDays explicitly defined
    if (trainingDays != null && trainingDays.isNotEmpty) {
      if (!trainingDays.contains(targetWeekday)) {
        return false;
      }
      final effectiveStartDate = toISTDateString(sessionStartDate);
      if (effectiveStartDate.isNotEmpty && targetDateIST.compareTo(effectiveStartDate) < 0) {
        return false;
      }
      return true;
    }

    // 4. Fallback: if assignedAt was target date in IST
    final assignedDate = toISTDateString(assignmentAssignedAt);
    if (assignedDate.isNotEmpty && assignedDate == targetDateIST) {
      return true;
    }

    return false;
  }
}
