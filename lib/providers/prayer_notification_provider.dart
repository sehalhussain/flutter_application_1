// lib/providers/prayer_notification_provider.dart
/// Provider that exposes per-prayer notification toggle states to the UI.
/// Wraps PrayerNotificationService so screens can use Provider/Consumer.

import 'package:flutter/foundation.dart';
import '../services/prayer_notification_service.dart';

class PrayerNotificationProvider extends ChangeNotifier {
  final PrayerNotificationService _service = PrayerNotificationService.instance;

  /// Cached enabled states: prayerName -> bool
  Map<String, bool> _enabledStates = {};
  Map<String, bool> get enabledStates => Map.unmodifiable(_enabledStates);

  /// Whether the initial load has completed
  bool _loaded = false;
  bool get loaded => _loaded;

  /// Load all enabled states from SharedPreferences
  Future<void> load() async {
    _enabledStates = await _service.getAllEnabledStates();
    _loaded = true;
    notifyListeners();
  }

  /// Check if a specific prayer notification is enabled
  bool isEnabled(String prayer) {
    return _enabledStates[prayer] ?? false;
  }

  /// Toggle notification for a prayer
  Future<void> toggle(String prayer) async {
    final current = _enabledStates[prayer] ?? false;
    final newValue = !current;

    // Update local cache immediately for responsive UI
    _enabledStates[prayer] = newValue;
    notifyListeners();

    // Persist and schedule/cancel via the service
    await _service.toggleNotification(prayer, newValue);
  }

  /// Reschedule all enabled prayers for today
  Future<void> rescheduleToday() async {
    await _service.rescheduleToday();
  }
}
