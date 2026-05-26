// lib/providers/prayer_tracker_provider.dart

import 'dart:convert';
import 'package:flutter/widgets.dart';
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

  /// Get all stored date keys sorted descending (newest first).
  List<String> get sortedDateKeys {
    final keys = _prayerLog.keys.toList();
    keys.sort((a, b) => b.compareTo(a));
    return keys;
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
