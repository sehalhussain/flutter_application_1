// lib/providers/prayer_notification_provider.dart
/// Provider that exposes per-prayer notification toggle states to the UI.

import 'package:flutter/foundation.dart';
import '../services/prayer_notification_service.dart';

class PrayerNotificationProvider extends ChangeNotifier {
  final PrayerNotificationService _service = PrayerNotificationService.instance;

  Map<String, bool> _enabledStates = {};
  Map<String, bool> get enabledStates => Map.unmodifiable(_enabledStates);

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _permissionsGranted = false;
  bool get permissionsGranted => _permissionsGranted;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _successMessage;
  String? get successMessage => _successMessage;

  /// Load all enabled states from SharedPreferences
  Future<void> load() async {
    _enabledStates = await _service.getAllEnabledStates();
    _permissionsGranted = await _service.checkPermissions();
    _loaded = true;
    notifyListeners();
  }

  bool isEnabled(String prayer) {
    return _enabledStates[prayer] ?? false;
  }

  /// Toggle notification for a prayer
  /// Returns true if successful
  Future<bool> toggle(String prayer) async {
    final current = _enabledStates[prayer] ?? false;
    final newValue = !current;

    _errorMessage = null;
    _successMessage = null;

    // Request permissions if enabling and not granted
    if (newValue && !_permissionsGranted) {
      _permissionsGranted = await _service.requestPermissions();
      if (!_permissionsGranted) {
        _errorMessage =
            'Notification permission denied. Please enable in Settings.';
        notifyListeners();
        return false;
      }
    }

    final success = await _service.toggleNotification(prayer, newValue);

    if (!success) {
      _errorMessage = newValue
          ? 'Failed to enable notification.'
          : 'Failed to disable notification.';
      notifyListeners();
      return false;
    }

    _enabledStates[prayer] = newValue;

    final displayName = _getDisplayName(prayer);
    _successMessage = newValue
        ? '$displayName notifications enabled'
        : '$displayName notifications disabled';

    notifyListeners();
    return true;
  }

  /// Reschedule all enabled prayers for today
  Future<void> rescheduleToday() async {
    await _service.rescheduleToday();
  }

  /// Force reschedule (for location changes)
  Future<void> forceRescheduleToday() async {
    await _service.forceRescheduleToday();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  String _getDisplayName(String prayer) {
    const names = {
      'Fajr': 'Fajr',
      'Dhuhr': 'Dhuhr',
      'Asr': 'Asr',
      'Maghrib': 'Maghrib',
      'Isha': 'Isha',
    };
    return names[prayer] ?? prayer;
  }

  /// Get next scheduled prayer info
  Future<Map<String, dynamic>?> getNextPrayerNotification() async {
    return await _service.getNextPrayerNotification();
  }
}
