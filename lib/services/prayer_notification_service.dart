// lib/services/prayer_notification_service.dart
/// Handles scheduling and canceling local prayer time notifications.
/// Automatically reschedules every day when the app is foregrounded.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'prayer_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

/// SharedPreferences keys
const String _prefsKeyEnabled = 'prayer_notif_enabled_'; // + prayerName

/// Notification payload
const String _payloadPrefix = 'prayer_notif_';

/// Prayer display names used in the notification body
const Map<String, String> _prayerDisplayNames = {
  'Fajr': 'Fajr',
  'Dhuhr': 'Dhuhr',
  'Asr': 'Asr',
  'Maghrib': 'Maghrib',
  'Isha': 'Isha',
};

/// Adhan-like icons per prayer
const Map<String, String> _prayerEmojis = {
  'Fajr': '🌅',
  'Dhuhr': '☀️',
  'Asr': '🌤',
  'Maghrib': '🌇',
  'Isha': '🌙',
};

// ═══════════════════════════════════════════════════════════════════════════
//  NOTIFICATION SERVICE  —  Singleton
// ═══════════════════════════════════════════════════════════════════════════

class PrayerNotificationService {
  PrayerNotificationService._();
  static final PrayerNotificationService instance =
      PrayerNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Must be called once at app startup (in main).
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Android initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permission on Android 13+ (API 33+)
    // This is required at runtime even though we declared it in the manifest
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Called when user taps a notification
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Prayer notification tapped: ${response.payload}');
  }

  // ── Notification ID generation ───────────────────────────────────────────

  /// Generate a stable unique ID for a prayer on a given date.
  int _notifId(String dateKey, String prayer) {
    return (prayer.hashCode * 31 + dateKey.hashCode).abs() % 2147483647;
  }

  // ── Check if user enabled notifications for a prayer ─────────────────────

  Future<bool> isEnabledForPrayer(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefsKeyEnabled$prayer') ?? false;
  }

  /// Get all prayer enabled states at once
  Future<Map<String, bool>> getAllEnabledStates() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final p in _prayerDisplayNames.keys)
        p: prefs.getBool('$_prefsKeyEnabled$p') ?? false,
    };
  }

  // ── Toggle notification for a prayer ──────────────────────────────────────

  /// Toggle notification on/off for a specific prayer.
  Future<void> toggleNotification(
    String prayer,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsKeyEnabled$prayer', enabled);

    if (enabled) {
      // Try scheduling for today; if all times passed, schedule for tomorrow
      final scheduled = await _scheduleTodayForPrayer(prayer);
      if (!scheduled) {
        await _scheduleTomorrowForPrayer(prayer);
      }
      // Show an immediate test notification so user can verify it works
      await _showTestNotification(prayer);
    } else {
      await _cancelTodayForPrayer(prayer);
      await _cancelTomorrowForPrayer(prayer);
    }
  }

  // ── Schedule all enabled prayers for today ────────────────────────────────

  /// Called every time the app resumes or when location changes.
  Future<void> rescheduleToday() async {
    if (!_initialized) return;

    final enabledStates = await getAllEnabledStates();
    final enabledPrayers =
        enabledStates.entries.where((e) => e.value).map((e) => e.key).toList();

    if (enabledPrayers.isEmpty) return;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return;

    final todayStr = _todayDateKey();

    for (final prayer in enabledPrayers) {
      if (!_prayerDisplayNames.containsKey(prayer)) continue;

      final timeStr = timings['timings'][prayer]?.toString().split(' ')[0];
      if (timeStr == null || timeStr == '--:--') continue;

      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      final now = DateTime.now();
      final prayerTime = DateTime(now.year, now.month, now.day, hour, minute);

      if (prayerTime.isBefore(now)) continue;

      await _cancelNotif(_notifId(todayStr, prayer));
      await _scheduleNotif(
        id: _notifId(todayStr, prayer),
        prayer: prayer,
        scheduledDate: prayerTime,
      );
    }
  }

  // ── Schedule a single prayer for today ────────────────────────────────────

  /// Returns true if the notification was scheduled, false if time already passed.
  Future<bool> _scheduleTodayForPrayer(String prayer) async {
    if (!_initialized) return false;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return false;

    final todayStr = _todayDateKey();
    final timeStr = timings['timings'][prayer]?.toString().split(' ')[0];
    if (timeStr == null || timeStr == '--:--') return false;

    final parts = timeStr.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();
    final prayerTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (prayerTime.isBefore(now)) return false;

    await _cancelNotif(_notifId(todayStr, prayer));
    await _scheduleNotif(
      id: _notifId(todayStr, prayer),
      prayer: prayer,
      scheduledDate: prayerTime,
    );
    return true;
  }

  // ── Schedule a single prayer for tomorrow ─────────────────────────────────

  Future<void> _scheduleTomorrowForPrayer(String prayer) async {
    if (!_initialized) return;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = _tomorrowDateKey();
    final timeStr = timings['timings'][prayer]?.toString().split(' ')[0];
    if (timeStr == null || timeStr == '--:--') return;

    final parts = timeStr.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final prayerTime =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);

    await _cancelNotif(_notifId(tomorrowStr, prayer));
    await _scheduleNotif(
      id: _notifId(tomorrowStr, prayer),
      prayer: prayer,
      scheduledDate: prayerTime,
    );
  }

  // ── Cancel today's notification for a prayer ─────────────────────────────

  Future<void> _cancelTodayForPrayer(String prayer) async {
    final todayStr = _todayDateKey();
    await _cancelNotif(_notifId(todayStr, prayer));
  }

  // ── Cancel tomorrow's notification for a prayer ──────────────────────────

  Future<void> _cancelTomorrowForPrayer(String prayer) async {
    final tomorrowStr = _tomorrowDateKey();
    await _cancelNotif(_notifId(tomorrowStr, prayer));
  }

  // ── Cancel ALL notifications ──────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Show an immediate test notification ───────────────────────────────────

  /// Shows a notification immediately to confirm the system works.
  Future<void> _showTestNotification(String prayer) async {
    if (!_initialized) return;

    final displayName = _prayerDisplayNames[prayer] ?? prayer;
    final emoji = _prayerEmojis[prayer] ?? '🕌';

    final androidDetails = AndroidNotificationDetails(
      'prayer_times_channel',
      'Prayer Times',
      channelDescription: 'Notifications for daily prayer times',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: _notifId('test', prayer),
      title: '✅ $displayName Notifications Enabled',
      body: 'You will now be notified at $displayName prayer time. 🕌',
      notificationDetails: details,
    );
  }

  // ── Internal scheduling ───────────────────────────────────────────────────

  Future<void> _scheduleNotif({
    required int id,
    required String prayer,
    required DateTime scheduledDate,
  }) async {
    final displayName = _prayerDisplayNames[prayer] ?? prayer;
    final emoji = _prayerEmojis[prayer] ?? '🕌';

    final androidDetails = AndroidNotificationDetails(
      'prayer_times_channel',
      'Prayer Times',
      channelDescription: 'Notifications for daily prayer times',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      timeoutAfter: 300000,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      id: id,
      title: '$emoji $displayName Time',
      body: 'It is time for $displayName prayer. 🕌',
      scheduledDate: tzScheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$_payloadPrefix$prayer',
    );
  }

  Future<void> _cancelNotif(int id) async {
    await _plugin.cancel(id: id);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _tomorrowDateKey() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
  }
}
