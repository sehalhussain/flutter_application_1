// lib/services/prayer_notification_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'prayer_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

const String _prefsKeyEnabled = 'prayer_notif_enabled_';
const String _prefsKeyLastScheduleDate = 'prayer_notif_last_schedule_';
const String _payloadPrefix = 'prayer_notif_';

const String _channelId = 'prayer_times_channel';
const String _channelName = 'Prayer Times';
const String _channelDescription = 'Notifications for daily prayer times';
const String _groupId = 'prayer_times_group';

/// Number of days ahead to schedule prayer notifications.
/// iOS has a 64-notification limit, so we schedule fewer days.
/// Android has no hard limit, so we schedule more days for reliability.
int get _schedulingHorizonDays => Platform.isIOS ? 12 : 30;

const Map<String, String> _prayerDisplayNames = {
  'Fajr': 'Fajr',
  'Dhuhr': 'Dhuhr',
  'Asr': 'Asr',
  'Maghrib': 'Maghrib',
  'Isha': 'Isha',
};

const Map<String, String> _prayerEmojis = {
  'Fajr': '🌅',
  'Dhuhr': '☀️',
  'Asr': '🌤️',
  'Maghrib': '🌇',
  'Isha': '🌙',
};

const Map<String, String> _prayerArabicNames = {
  'Fajr': 'الفجر',
  'Dhuhr': 'الظهر',
  'Asr': 'العصر',
  'Maghrib': 'المغرب',
  'Isha': 'العشاء',
};

const Map<String, String> _prayerReminders = {
  'Fajr': 'Start your day with the dawn prayer',
  'Dhuhr': 'Take a moment for your midday prayer',
  'Asr': 'Pause and reflect with the afternoon prayer',
  'Maghrib': 'As the sun sets, take a moment to pray',
  'Isha': 'End your day with peace and prayer',
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
  bool _permissionsGranted = false;
  bool _useExactAlarms = true;

  void Function(String prayer)? onMarkPrayed;

  final _permissionStateController = StreamController<bool>.broadcast();
  Stream<bool> get permissionStateStream => _permissionStateController.stream;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (_initialized) return _permissionsGranted;

    try {
      tz_data.initializeTimeZones();
      await _initializeTimezone();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _createNotificationChannel();

      _permissionsGranted = await _checkPermissions();

      // NOTE: We intentionally do NOT cancel all notifications here.
      // Scheduled notifications persist across app restarts, which is
      // essential for multi-day scheduling. The rescheduleToday() method
      // will extend the schedule as needed when the app opens.

      _initialized = true;
      debugPrint(
          'PrayerNotificationService initialized. Permissions: $_permissionsGranted');
      return _permissionsGranted;
    } catch (e) {
      debugPrint('Failed to initialize PrayerNotificationService: $e');
      _initialized = true;
      return false;
    }
  }

  // ── Timezone ─────────────────────────────────────────────────────────────

  Future<void> _initializeTimezone() async {
    try {
      final String timeZoneName = DateTime.now().timeZoneName;

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        final alternatives = _getTimezoneAlternatives(timeZoneName);
        bool found = false;

        for (final alt in alternatives) {
          try {
            tz.setLocalLocation(tz.getLocation(alt));
            found = true;
            break;
          } catch (_) {}
        }

        if (!found) {
          final offset = DateTime.now().timeZoneOffset;
          final locations = tz.timeZoneDatabase.locations;

          for (final entry in locations.entries) {
            final now = tz.TZDateTime.now(entry.value);
            if (now.timeZoneOffset == offset) {
              tz.setLocalLocation(entry.value);
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Timezone initialization error: $e');
    }
  }

  List<String> _getTimezoneAlternatives(String tzName) {
    final map = <String, String>{
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'CET': 'Europe/Paris',
      'CEST': 'Europe/Paris',
      'EET': 'Europe/Bucharest',
      'EEST': 'Europe/Bucharest',
      'GST': 'Asia/Dubai',
      'PKT': 'Asia/Karachi',
      'IST': 'Asia/Kolkata',
      'WIB': 'Asia/Jakarta',
      'HKT': 'Asia/Hong_Kong',
      'JST': 'Asia/Tokyo',
      'KST': 'Asia/Seoul',
      'AEST': 'Australia/Sydney',
      'AEDT': 'Australia/Sydney',
      'NZST': 'Pacific/Auckland',
      'NZDT': 'Pacific/Auckland',
      'AST': 'America/Halifax',
      'NST': 'America/St_Johns',
    };

    final result = <String>[tzName];
    final alt = map[tzName];
    if (alt != null) {
      result.add(alt);
    }
    return result.toSet().toList();
  }

  // ── Android Channel ──────────────────────────────────────────────────────

  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.deleteNotificationChannel(channelId: _channelId);

    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFF10B981),
    );

    await androidPlugin.createNotificationChannel(channel);
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  Future<bool> _checkPermissions() async {
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final result = await iosPlugin.checkPermissions();
        return result == true;
      }
      return false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final result = await androidPlugin.areNotificationsEnabled();
        return result != false;
      }
      return true;
    }
    return false;
  }

  Future<bool> checkPermissions() async {
    if (!_initialized) return false;
    _permissionsGranted = await _checkPermissions();
    return _permissionsGranted;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final result = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionsGranted = result == true;
      } else {
        _permissionsGranted = false;
      }
    } else if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final result = await androidPlugin.requestNotificationsPermission();
        _permissionsGranted = result == true;
      } else {
        _permissionsGranted = true;
      }
    } else {
      _permissionsGranted = false;
    }

    _permissionStateController.add(_permissionsGranted);
    return _permissionsGranted;
  }

  // ── Notification Tap Handler ────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null ||
        !response.payload!.startsWith(_payloadPrefix)) {
      return;
    }

    final prayer = response.payload!.substring(_payloadPrefix.length);

    if (response.actionId == 'mark_prayed') {
      onMarkPrayed?.call(prayer);
    }
  }

  // ── Notification ID ──────────────────────────────────────────────────────

  int _notifId(String dateKey, String prayer) {
    final hash = dateKey.hashCode ^ (prayer.hashCode * 31);
    return hash.abs() % 2147483647;
  }

  // ── Enabled States ───────────────────────────────────────────────────────

  Future<bool> isEnabledForPrayer(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefsKeyEnabled$prayer') ?? false;
  }

  Future<Map<String, bool>> getAllEnabledStates() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final p in _prayerDisplayNames.keys)
        p: prefs.getBool('$_prefsKeyEnabled$p') ?? false,
    };
  }

  // ── Toggle Notification ─────────────────────────────────────────────────

  Future<bool> toggleNotification(String prayer, bool enabled) async {
    if (enabled) {
      if (!_permissionsGranted) {
        _permissionsGranted = await requestPermissions();
        if (!_permissionsGranted) {
          return false;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsKeyEnabled$prayer', enabled);

    if (enabled) {
      // Schedule for the next N days to ensure notifications fire even
      // if the user doesn't open the app for several days.
      await _schedulePrayerForNDays(prayer, _schedulingHorizonDays);
    } else {
      // Cancel all future scheduled notifications for this prayer
      await _cancelAllFutureForPrayer(prayer);
    }

    return true;
  }

  // ── Reschedule All ──────────────────────────────────────────────────────

  // ── Reschedule All ──────────────────────────────────────────────────────
  
  Future<void> rescheduleToday() async {
    if (!_initialized || !_permissionsGranted) return;

    // Refresh timezone details to handle travel/timezone shifts dynamically
    await _initializeTimezone();

    final enabledStates = await getAllEnabledStates();
    final enabledPrayers =
        enabledStates.entries.where((e) => e.value).map((e) => e.key).toList();

    if (enabledPrayers.isEmpty) {
      // Cancel the refresh reminder if no notifications are active
      await _cancelNotif(999999);
      return;
    }

    final now = DateTime.now();

    // Get timings for the next N days (shared across all prayers)
    final timings = await _getTimingsForDateRange(now, _schedulingHorizonDays);

    int scheduledCount = 0;
    for (final prayer in enabledPrayers) {
      scheduledCount += await _schedulePrayerForNDays(
        prayer,
        _schedulingHorizonDays,
        timingsCache: timings,
      );
    }

    // Schedule a keep-alive reminder notification on the 10th day for iOS
    // to prevent notifications from running out if they don't open the app.
    if (Platform.isIOS && scheduledCount > 0) {
      await _scheduleRefreshReminder(_schedulingHorizonDays);
    }

    // Update the last schedule date to the furthest scheduled date
    if (scheduledCount > 0) {
      final prefs = await SharedPreferences.getInstance();
      final targetEnd = now.add(Duration(days: _schedulingHorizonDays));
      await prefs.setString(
          _prefsKeyLastScheduleDate, _dateKeyFromDate(targetEnd));
    }
  }

  Future<void> forceRescheduleToday() async {
    // Refresh timezone details
    await _initializeTimezone();
    // Cancel all existing prayer notifications (times are now wrong)
    await _cancelAllPrayerNotifications();
    // Clear the last schedule date
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLastScheduleDate);
    // Reschedule from scratch
    await rescheduleToday();
  }

  /// Schedules a reminder notification on the (horizon - 2) day to prompt the user
  /// to open the app, ensuring their notifications don't run out.
  Future<void> _scheduleRefreshReminder(int days) async {
    final targetDay = days - 2;
    if (targetDay <= 0) return;

    final reminderTime = DateTime.now().add(Duration(days: targetDay));
    final scheduledDate = DateTime(
      reminderTime.year,
      reminderTime.month,
      reminderTime.day,
      10, // 10:00 AM local time
      0,
    );

    final id = 999999;
    await _cancelNotif(id);

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'prayer_times_reminder_channel',
      'App Reminders',
      channelDescription: 'Reminders to open the app and refresh prayer timings',
      importance: Importance.low,
      priority: Priority.low,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: '🕌 Keep your prayer notifications active',
      body: 'Open Kitably to update prayer times and keep receiving daily notifications.',
      scheduledDate: tzScheduledDate,
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'refresh_reminder',
    );
  }

  // ── Time Parsing ─────────────────────────────────────────────────────────

  _ParsedTime? _parsePrayerTime(dynamic timing) {
    if (timing == null) return null;

    String timeStr = timing.toString().trim();

    final parenIndex = timeStr.indexOf('(');
    if (parenIndex != -1) {
      timeStr = timeStr.substring(0, parenIndex).trim();
    }

    final spaceIndex = timeStr.indexOf(' ');
    if (spaceIndex != -1) {
      timeStr = timeStr.substring(0, spaceIndex).trim();
    }

    if (timeStr == '--:--' || timeStr.isEmpty) return null;

    final parts = timeStr.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return _ParsedTime(hour: hour, minute: minute);
  }

  // ── Schedule Single Prayer ──────────────────────────────────────────────

  /// Gets prayer timings for a range of dates starting from [startDate].
  /// Returns a map keyed by date key (YYYY-MM-DD) → prayer timings map.
  Future<Map<String, Map<String, String>>> _getTimingsForDateRange(
    DateTime startDate,
    int days,
  ) async {
    final result = <String, Map<String, String>>{};

    // Group dates by month to minimize calendar API calls
    final Map<int, List<DateTime>> byMonth = {};
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final monthKey = date.year * 100 + date.month;
      byMonth.putIfAbsent(monthKey, () => []).add(date);
    }

    for (final entry in byMonth.entries) {
      final year = entry.key ~/ 100;
      final month = entry.key % 100;
      final calendar =
          await PrayerService.instance.getCalendarByMonth(year, month);
      if (calendar == null) continue;

      for (final date in entry.value) {
        // Calendar uses DD-MM-YYYY format for gregorian date
        final calDateStr =
            '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

        for (final day in calendar) {
          if (day['date']['gregorian']['date'] == calDateStr) {
            final dateKey = _dateKeyFromDate(date);
            result[dateKey] = Map<String, String>.from(day['timings']);
            break;
          }
        }
      }
    }

    return result;
  }

  /// Schedules notifications for [prayer] across the next [days] days.
  /// Uses [timingsCache] if provided to avoid redundant calendar fetches.
  /// Returns the number of notifications successfully scheduled.
  Future<int> _schedulePrayerForNDays(
    String prayer,
    int days, {
    Map<String, Map<String, String>>? timingsCache,
  }) async {
    if (!_initialized || !_permissionsGranted) return 0;
    if (!_prayerDisplayNames.containsKey(prayer)) return 0;

    final now = DateTime.now();

    // Get timings for the date range
    final timings = timingsCache ?? await _getTimingsForDateRange(now, days);

    int scheduledCount = 0;

    for (int offset = 0; offset < days; offset++) {
      final date = now.add(Duration(days: offset));
      final dateKey = _dateKeyFromDate(date);

      final dayTimings = timings[dateKey];
      if (dayTimings == null) continue;

      final parsedTime = _parsePrayerTime(dayTimings[prayer]);
      if (parsedTime == null) continue;

      final prayerTime = DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      // Only schedule if the prayer time is in the future
      if (!prayerTime.isAfter(now.add(const Duration(minutes: 1)))) {
        continue;
      }

      await _cancelNotif(_notifId(dateKey, prayer));
      final success = await _scheduleNotif(
        id: _notifId(dateKey, prayer),
        prayer: prayer,
        scheduledDate: prayerTime,
      );
      if (success) scheduledCount++;
    }

    return scheduledCount;
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  /// Cancels all future scheduled notifications for a specific prayer.
  /// Iterates through the next 14 days (buffer beyond scheduling horizon).
  Future<void> _cancelAllFutureForPrayer(String prayer) async {
    final now = DateTime.now();
    for (int offset = 0; offset <= _schedulingHorizonDays + 2; offset++) {
      final date = now.add(Duration(days: offset));
      final dateKey = _dateKeyFromDate(date);
      await _cancelNotif(_notifId(dateKey, prayer));
    }
  }

  /// Cancels all scheduled prayer notifications for all prayers.
  /// Used when location/calculation method changes (forceRescheduleToday).
  Future<void> _cancelAllPrayerNotifications() async {
    final now = DateTime.now();
    for (final prayer in _prayerDisplayNames.keys) {
      for (int offset = 0; offset <= _schedulingHorizonDays + 2; offset++) {
        final date = now.add(Duration(days: offset));
        final dateKey = _dateKeyFromDate(date);
        await _cancelNotif(_notifId(dateKey, prayer));
      }
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLastScheduleDate);
  }

  // ── Scheduled Notification Details ──────────────────────────────────────

  NotificationDetails _buildScheduledNotificationDetails() {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      category: AndroidNotificationCategory.alarm,
      timeoutAfter: 300000,
      groupKey: _groupId,
      autoCancel: true,
      styleInformation: const BigTextStyleInformation(''),
      actions: const [
        AndroidNotificationAction(
          'mark_prayed',
          '\u2713 Prayed',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Dismiss',
          showsUserInterface: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'PRAYER_CATEGORY',
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  // ── Schedule Notification ────────────────────────────────────────────────

  Future<bool> _scheduleNotif({
    required int id,
    required String prayer,
    required DateTime scheduledDate,
  }) async {
    try {
      final displayName = _prayerDisplayNames[prayer] ?? prayer;
      final emoji = _prayerEmojis[prayer] ?? '\u{1F54C}';
      final reminder = _prayerReminders[prayer] ?? '';

      final hour = scheduledDate.hour;
      final minute = scheduledDate.minute;
      final period = hour < 12 ? 'AM' : 'PM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final timeStr = '$hour12:${minute.toString().padLeft(2, '0')} $period';

      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return false;
      }

      final title = '$emoji $displayName Prayer';
      final body = 'Time to pray \u2022 $timeStr\n$reminder';

      final details = _buildScheduledNotificationDetails();

      // Use exact alarms on Android for precise prayer time delivery.
      // Falls back to inexact if the OS denies exact alarm permission.
      if (!Platform.isAndroid || !_useExactAlarms) {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzScheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$_payloadPrefix$prayer',
        );
      } else {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tzScheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: '$_payloadPrefix$prayer',
          );
        } catch (e) {
          debugPrint('Exact alarm denied, falling back to inexact: $e');
          _useExactAlarms = false;
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tzScheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: '$_payloadPrefix$prayer',
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Failed to schedule $prayer: $e');
      return false;
    }
  }

  Future<void> _cancelNotif(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel notification $id: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns a date key (YYYY-MM-DD) for the given [date].
  String _dateKeyFromDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> getScheduledTime(String prayer) async {
    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return null;

    final parsedTime = _parsePrayerTime(timings['timings'][prayer]);
    if (parsedTime == null) return null;

    final now = DateTime.now();
    var prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (prayerTime.isBefore(now)) {
      final tomorrow = now.add(const Duration(days: 1));
      prayerTime = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    }

    return prayerTime;
  }

  Future<Map<String, dynamic>?> getNextPrayerNotification() async {
    final enabledStates = await getAllEnabledStates();
    final enabledPrayers =
        enabledStates.entries.where((e) => e.value).map((e) => e.key).toList();

    if (enabledPrayers.isEmpty) return null;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return null;

    final now = DateTime.now();
    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (final prayer in prayerOrder) {
      if (!enabledPrayers.contains(prayer)) continue;

      final parsedTime = _parsePrayerTime(timings['timings'][prayer]);
      if (parsedTime == null) continue;

      var prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      if (prayerTime.isAfter(now)) {
        return {
          'prayer': prayer,
          'time': prayerTime,
          'emoji': _prayerEmojis[prayer],
          'displayName': _prayerDisplayNames[prayer],
          'arabicName': _prayerArabicNames[prayer],
        };
      }
    }

    if (enabledPrayers.contains('Fajr')) {
      final parsedTime = _parsePrayerTime(timings['timings']['Fajr']);
      if (parsedTime != null) {
        final tomorrow = now.add(const Duration(days: 1));
        return {
          'prayer': 'Fajr',
          'time': DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
              parsedTime.hour, parsedTime.minute),
          'emoji': _prayerEmojis['Fajr'],
          'displayName': _prayerDisplayNames['Fajr'],
          'arabicName': _prayerArabicNames['Fajr'],
        };
      }
    }

    return null;
  }

  void dispose() {
    _permissionStateController.close();
  }
}

class _ParsedTime {
  final int hour;
  final int minute;
  const _ParsedTime({required this.hour, required this.minute});
}
