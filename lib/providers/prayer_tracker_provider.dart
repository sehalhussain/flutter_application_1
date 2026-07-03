// lib/providers/prayer_tracker_provider.dart

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerTracker extends ChangeNotifier {
  /// Key: "YYYY-MM-DD"
  /// Value: {"Fajr": true, "Dhuhr": false, "Asr": true, "Maghrib": true, "Isha": false}
  Map<String, Map<String, bool>> _prayerLog = {};

  static const String _storageKey = 'prayer_tracker_log';
  static const List<String> _prayerNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  List<String> get prayerNames => _prayerNames;

  /// Returns today's prayer map, or empty day if nothing logged yet.
  Map<String, bool> get todayPrayers {
    final today = _dateKey(DateTime.now());
    return Map<String, bool>.from(_prayerLog[today] ?? {});
  }

  /// Returns the count of prayed prayers on a given date.
  int prayedCountForDate(String dateKey) {
    final day = _prayerLog[dateKey];
    if (day == null) return 0;
    return day.values.where((v) => v).length;
  }

  /// Returns the count of prayed prayers for today.
  int get todayPrayedCount => prayedCountForDate(_dateKey(DateTime.now()));

  /// Returns a prayer map for a specific date key.
  Map<String, bool> prayersForDate(String dateKey) {
    return Map<String, bool>.from(_prayerLog[dateKey] ?? {});
  }

  /// Toggle a specific prayer for today.
  Future<void> togglePrayer(String prayer) async {
    final today = _dateKey(DateTime.now());
    _prayerLog[today] ??= {};
    final current = _prayerLog[today]![prayer] ?? false;
    _prayerLog[today]![prayer] = !current;
    notifyListeners();
    await _persist();
  }

  /// Toggle a specific prayer for a given date.
  Future<void> togglePrayerForDate(String dateKey, String prayer) async {
    _prayerLog[dateKey] ??= {};
    final current = _prayerLog[dateKey]![prayer] ?? false;
    _prayerLog[dateKey]![prayer] = !current;
    notifyListeners();
    await _persist();
  }

  /// Grace period logic for current streak:
  /// If today is incomplete, it ignores today without breaking the streak.
  /// It checks backwards from yesterday. If yesterday is complete, streak continues.
  /// If the day ends and yesterday is incomplete, streak becomes 0.
  /// If the user backfills yesterday to 5/5, the streak resumes automatically.
  int get currentStreak {
    final totalPrayers = _prayerNames.length;
    if (totalPrayers == 0) return 0;

    var date =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int streak = 0;
    bool skippedToday = false;

    while (true) {
      final key = _dateKey(date);
      final count = prayedCountForDate(key);

      if (count == totalPrayers) {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        if (!skippedToday) {
          // If it's today and it's not 5/5, skip it.
          // The day isn't over yet, so don't break the streak.
          skippedToday = true;
          date = date.subtract(const Duration(days: 1));
          continue; // Re-evaluate the loop starting from yesterday
        }
        // We hit a day in the past that isn't 5/5. Streak breaks.
        break;
      }
    }
    return streak;
  }

  /// Best streak ever recorded.
  /// Does not break the current active run prematurely if today is unfinished.
  int get bestStreak {
    if (_prayerLog.isEmpty) return 0;
    final totalPrayers = _prayerNames.length;

    final keys = sortedDateKeys;
    final oldestDate = DateTime.parse(keys.last);
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    var start = DateTime(oldestDate.year, oldestDate.month, oldestDate.day);

    int best = 0;
    int current = 0;

    while (!start.isAfter(today)) {
      final key = _dateKey(start);
      final count = prayedCountForDate(key);
      if (count == totalPrayers) {
        current++;
        if (current > best) best = current;
      } else {
        if (start.isAtSameMomentAs(today)) {
          // Do not break current active run prematurely on unfinished today
        } else {
          // Strict reset for any past day that isn't 5/5
          current = 0;
        }
      }
      start = start.add(const Duration(days: 1));
    }
    return best;
  }

  /// Get completion percentage for a specific prayer across all logged days.
  double prayerCompletionRate(String prayer) {
    if (_prayerLog.isEmpty) return 0.0;
    int total = 0;
    int prayed = 0;
    for (final day in _prayerLog.values) {
      if (day.containsKey(prayer)) {
        total++;
        if (day[prayer] == true) prayed++;
      }
    }
    return total == 0 ? 0.0 : prayed / total;
  }

  /// Get monthly completion rate (days with 5/5 prayers / total days in month that have passed).
  double monthlyCompletionRate(int year, int month) {
    final now = DateTime.now();
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final lastDay =
        (year == now.year && month == now.month) ? now.day : daysInMonth;

    int completeDays = 0;

    for (int d = 1; d <= lastDay; d++) {
      final date = DateTime(year, month, d);
      final key = _dateKey(date);
      if (_prayerLog.containsKey(key) && prayedCountForDate(key) == 5) {
        completeDays++;
      }
    }
    return lastDay == 0 ? 0.0 : completeDays / lastDay;
  }

  /// Get completion data for the last N months.
  List<Map<String, dynamic>> getMonthlyTrend(int months) {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final rate = monthlyCompletionRate(date.year, date.month);
      result.add({
        'month': DateFormat('MMM').format(date),
        'year': date.year,
        'rate': rate,
      });
    }
    return result;
  }

  /// Get heatmap data for the last 52 weeks.
  List<Map<String, dynamic>> getWeeklyHeatmap() {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 364));

    for (int i = 0; i < 365; i++) {
      final date = start.add(Duration(days: i));
      final key = _dateKey(date);
      final count = prayedCountForDate(key);
      result.add({
        'date': key,
        'count': count,
        'weekday': date.weekday % 7,
      });
    }
    return result;
  }

  /// Get all stored date keys sorted descending (newest first).
  List<String> get sortedDateKeys {
    final keys = _prayerLog.keys.toList();
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  /// Total prayers logged lifetime.
  int get totalPrayersLogged {
    return _prayerLog.values
        .fold<int>(0, (sum, day) => sum + day.values.where((v) => v).length);
  }

  /// Total missed prayers across all days from the first log until today.
  int get totalMissed {
    if (_prayerLog.isEmpty) return 0;
    final totalPrayers = _prayerNames.length;

    final keys = sortedDateKeys;
    final oldestDate = DateTime.parse(keys.last);
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final start = DateTime(oldestDate.year, oldestDate.month, oldestDate.day);

    int totalDays = today.difference(start).inDays + 1;
    int missed = (totalDays * totalPrayers) - totalPrayersLogged;
    return missed < 0 ? 0 : missed;
  }

  /// Check if a milestone is achieved.
  bool hasMilestone(String milestone) {
    switch (milestone) {
      case 'first_prayer':
        return totalPrayersLogged >= 1;
      case 'streak_7':
        return bestStreak >= 7;
      case 'streak_30':
        return bestStreak >= 30;
      case 'perfect_week':
        return bestStreak >= 7;
      case 'centurion':
        return totalPrayersLogged >= 100;
      case 'year_of_light':
        return bestStreak >= 365;
      default:
        return false;
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _prayerLog = decoded.map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool)),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(_prayerLog));
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ── Provider widget ─────────────────────────────────────────────────────────
class PrayerTrackerProvider {
  static PrayerTracker of(BuildContext context, {bool listen = true}) {
    return Provider.of<PrayerTracker>(context, listen: listen);
  }
}
