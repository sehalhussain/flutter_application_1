// lib/providers/daily_ayah_notification_provider.dart
/// Exposes the Daily Ayah Reminder state (on/off + time) to the Settings UI.

import 'package:flutter/material.dart';

import '../services/daily_ayah_notification_service.dart';

class DailyAyahNotificationProvider extends ChangeNotifier {
  final DailyAyahNotificationService _service =
      DailyAyahNotificationService.instance;

  bool _enabled = false;
  bool get enabled => _enabled;

  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay get time => _time;

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _permissionsGranted = false;
  bool get permissionsGranted => _permissionsGranted;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _enabled = await _service.isEnabled();
    _time = await _service.getTime();
    _permissionsGranted = await _service.checkPermissions();
    _loaded = true;
    notifyListeners();
  }

  /// Toggle the reminder. Returns true on success.
  Future<bool> toggle() async {
    _errorMessage = null;
    final newValue = !_enabled;
    final success = await _service.setEnabled(newValue);
    if (!success) {
      _errorMessage =
          'Notification permission denied. Please enable in Settings.';
      notifyListeners();
      return false;
    }
    _enabled = newValue;
    notifyListeners();
    return true;
  }

  /// Change the daily notification time. Returns true on success.
  Future<bool> setTime(TimeOfDay time) async {
    _errorMessage = null;
    await _service.setTime(time);
    _time = time;
    notifyListeners();
    return true;
  }
}
