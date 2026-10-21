/**
 * IST (Indian Standard Time, UTC+05:30) Date Utilities
 * Ensures consistent daily workout scheduling, assignment, and session locking in Alpha X Gym.
 */

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

let _dateProvider: (() => Date) | null = null;

/**
 * Configure a controlled date provider for automated tests.
 * Pass null to restore real system time.
 */
export function setDateProviderForTesting(provider: (() => Date) | null): void {
  _dateProvider = provider;
}

/**
 * Returns current Date adjusted to Indian Standard Time (IST, UTC+05:30)
 */
export function getCurrentISTDate(): Date {
  const now = _dateProvider ? _dateProvider() : new Date();
  return new Date(now.getTime() + IST_OFFSET_MS);
}

/**
 * Returns today's date formatted as `yyyy-MM-dd` in IST
 */
export function getTodayISTDateString(): string {
  const istDate = getCurrentISTDate();
  return istDate.toISOString().slice(0, 10);
}

/**
 * Returns date offset by `dayOffset` days from current IST date formatted as `yyyy-MM-dd`
 */
export function getOffsetISTDateString(dayOffset: number): string {
  const istDate = getCurrentISTDate();
  const target = new Date(istDate.getTime() + dayOffset * 24 * 60 * 60 * 1000);
  return target.toISOString().slice(0, 10);
}

/**
 * Converts any Date or date string into a `yyyy-MM-dd` string in IST.
 * If input is already formatted as `yyyy-MM-dd`, returns it directly to avoid double offset shifting.
 */
export function toISTDateString(d: Date | string | null | undefined): string | null {
  if (!d) return null;
  if (typeof d === 'string') {
    const trimmed = d.trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      return trimmed;
    }
  }
  const dateObj = typeof d === 'string' ? new Date(d) : d;
  if (isNaN(dateObj.getTime())) return null;
  const istDate = new Date(dateObj.getTime() + IST_OFFSET_MS);
  return istDate.toISOString().slice(0, 10);
}

export function isTodayInIST(d: Date | string | null | undefined): boolean {
  if (!d) return false;
  const istDateStr = toISTDateString(d);
  return istDateStr === getTodayISTDateString();
}

/**
 * Returns ISO weekday number for a given `yyyy-MM-dd` date in IST:
 * 1 = Monday, 2 = Tuesday, 3 = Wednesday, 4 = Thursday, 5 = Friday, 6 = Saturday, 7 = Sunday
 */
export function getWeekdayFromISTDateString(dateStr: string): number {
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  const dayOfWeek = date.getUTCDay(); // 0 = Sunday, 1 = Monday ... 6 = Saturday
  return dayOfWeek === 0 ? 7 : dayOfWeek;
}

/**
 * Returns today's ISO weekday in IST (1 = Monday ... 7 = Sunday)
 */
export function getTodayISTWeekday(): number {
  return getWeekdayFromISTDateString(getTodayISTDateString());
}

/**
 * Parses days of week from schedule strings like "Monday", "Monday, Thursday", "Mon, Wed, Fri", etc.
 * Returns sorted unique array of ISO weekday numbers (1 = Mon ... 7 = Sun).
 */
export function parseWeekdaysFromScheduleString(scheduleStr?: string | null): number[] {
  if (!scheduleStr) return [];
  const s = scheduleStr.toLowerCase();
  const days: number[] = [];

  if (s.includes('mon')) days.push(1);
  if (s.includes('tue')) days.push(2);
  if (s.includes('wed')) days.push(3);
  if (s.includes('thu')) days.push(4);
  if (s.includes('fri')) days.push(5);
  if (s.includes('sat')) days.push(6);
  if (s.includes('sun')) days.push(7);

  return Array.from(new Set(days)).sort((a, b) => a - b);
}

/**
 * Resolves day name (e.g. "Monday", "tue", "Day 1") to ISO weekday number (1=Mon ... 7=Sun).
 * Accepts an optional fallback index (1=Mon ... 7=Sun) if the string does not specify a weekday.
 */
export function getWeekdayFromDayName(dayName?: string | null, fallbackIndex?: number): number {
  if (!dayName && fallbackIndex !== undefined && fallbackIndex >= 1 && fallbackIndex <= 7) {
    return fallbackIndex;
  }
  if (!dayName) return fallbackIndex !== undefined && fallbackIndex >= 1 && fallbackIndex <= 7 ? fallbackIndex : 1;
  const s = dayName.toLowerCase();
  if (s.includes('mon')) return 1;
  if (s.includes('tue')) return 2;
  if (s.includes('wed')) return 3;
  if (s.includes('thu')) return 4;
  if (s.includes('fri')) return 5;
  if (s.includes('sat')) return 6;
  if (s.includes('sun')) return 7;
  const m = s.match(/day\s*(\d+)/i);
  if (m) {
    const num = parseInt(m[1], 10);
    if (num >= 1 && num <= 7) return num;
  }
  if (fallbackIndex !== undefined && fallbackIndex >= 1 && fallbackIndex <= 7) {
    return fallbackIndex;
  }
  return 1;
}

/**
 * Converts ISO weekday number (1=Mon ... 7=Sun) to canonical weekday string ("Monday" ... "Sunday").
 */
export function getWeekdayName(weekdayNum: number): string {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const idx = Math.max(1, Math.min(7, Math.floor(weekdayNum))) - 1;
  return names[idx] || 'Monday';
}


/**
 * Returns the IST date string (yyyy-MM-dd) for a given target weekday (1=Mon ... 7=Sun)
 * relative to the current IST week.
 */
export function getISTDateForWeekday(targetWeekday: number): string {
  const todayWeekday = getTodayISTWeekday();
  const diff = targetWeekday - todayWeekday;
  return getOffsetISTDateString(diff);
}

/**
 * Determines whether a workout session and assignment are scheduled for a specific date in IST.
 * Respects recurring weekdays, start dates, and specific scheduled dates.
 */
export function isSessionScheduledForDate(
  session: { recurringSchedule?: string | null; startDate?: string | Date | null; endDate?: string | Date | null },
  assignment: { scheduledDate?: string | null; assignedAt?: string | Date | null },
  targetDateIST: string
): boolean {
  const targetWeekday = getWeekdayFromISTDateString(targetDateIST);

  // 1. If session has explicit recurringSchedule (e.g. "Monday", "Monday, Thursday")
  const recurringWeekdays = parseWeekdaysFromScheduleString(session.recurringSchedule);
  if (recurringWeekdays.length > 0) {
    if (!recurringWeekdays.includes(targetWeekday)) {
      return false;
    }
    // If assignment has scheduledDate, that defines the assignment's start date
    const effectiveStartDate = assignment.scheduledDate || toISTDateString(session.startDate);
    if (effectiveStartDate && targetDateIST < effectiveStartDate) {
      return false;
    }
    const endDate = toISTDateString(session.endDate);
    if (endDate && targetDateIST > endDate) {
      return false;
    }
    return true;
  }

  // 2. If assignment has an explicit scheduledDate (e.g. "2026-10-12")
  if (assignment.scheduledDate) {
    if (targetDateIST === assignment.scheduledDate) {
      return true;
    }
    // Recurring weekly assignment on the same weekday as assigned
    const assignedWeekday = getWeekdayFromISTDateString(assignment.scheduledDate);
    if (targetWeekday === assignedWeekday && targetDateIST >= assignment.scheduledDate) {
      return true;
    }
    return false;
  }

  // 3. Fallback: if assignedAt was today in IST
  const assignedDate = toISTDateString(assignment.assignedAt);
  if (assignedDate === targetDateIST) {
    return true;
  }

  return false;
}

