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

  /// Get the current streak of consecutive days where all 5 prayers were prayed.
  int get currentStreak {
    var date = DateTime.now();
    int streak = 0;

    while (true) {
      final key = _dateKey(date);
      final prayed = prayedCountForDate(key);
      if (prayed < 5) break;
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Get the best streak ever recorded.
  int get bestStreak {
    if (_prayerLog.isEmpty) return 0;
    final keys = sortedDateKeys;
    int best = 0;
    int current = 0;

    // Iterate from oldest to newest
    final sortedAsc = keys.reversed.toList();
    for (final key in sortedAsc) {
      if (prayedCountForDate(key) == 5) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
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
