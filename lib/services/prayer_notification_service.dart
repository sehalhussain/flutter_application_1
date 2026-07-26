// lib/services/prayer_notification_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // <-- ADDED for Int64List

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
  'Fajr': 'The dawn prayer brings blessings to your day',
  'Dhuhr': 'Take a moment for the midday prayer',
  'Asr': 'The afternoon prayer, a time of reflection',
  'Maghrib': 'As the sun sets, answer the call to prayer',
  'Isha': 'End your day with peace through prayer',
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

      await _plugin.cancelAll();

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

    // FIX 1: Added required named parameter 'channelId:'
    await androidPlugin.deleteNotificationChannel(channelId: _channelId);

    // FIX 2: Removed 'const' keyword and used Int64List.fromList for vibrationPattern
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
        // FIX 3: Explicit == true check prevents 'Object' return type error
        return result == true;
      }
      return false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final result = await androidPlugin.areNotificationsEnabled();
        // FIX 3: Explicit != false handles null (pre-Android 13) safely
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
        // FIX 3: Explicit == true check
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
      await prefs.remove(_prefsKeyLastScheduleDate);

      final scheduled = await _scheduleTodayForPrayer(prayer);
      if (!scheduled) {
        await _scheduleTomorrowForPrayer(prayer);
      }
      await _showTestNotification(prayer);
    } else {
      await _cancelTodayForPrayer(prayer);
      await _cancelTomorrowForPrayer(prayer);
    }

    return true;
  }

  // ── Reschedule All ──────────────────────────────────────────────────────

  Future<void> rescheduleToday() async {
    if (!_initialized || !_permissionsGranted) return;

    final enabledStates = await getAllEnabledStates();
    final enabledPrayers =
        enabledStates.entries.where((e) => e.value).map((e) => e.key).toList();

    if (enabledPrayers.isEmpty) return;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastScheduleDate = prefs.getString(_prefsKeyLastScheduleDate);
    final todayStr = _todayDateKey();

    if (lastScheduleDate == todayStr) return;

    final tomorrowStr = _tomorrowDateKey();
    final now = DateTime.now();
    int scheduledCount = 0;

    for (final prayer in enabledPrayers) {
      if (!_prayerDisplayNames.containsKey(prayer)) continue;

      final parsedTime = _parsePrayerTime(timings['timings'][prayer]);
      if (parsedTime == null) continue;

      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      await _cancelNotif(_notifId(todayStr, prayer));
      await _cancelNotif(_notifId(tomorrowStr, prayer));

      bool success;
      if (prayerTime.isAfter(now.add(const Duration(minutes: 1)))) {
        success = await _scheduleNotif(
          id: _notifId(todayStr, prayer),
          prayer: prayer,
          scheduledDate: prayerTime,
        );
      } else {
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowPrayerTime = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          parsedTime.hour,
          parsedTime.minute,
        );
        success = await _scheduleNotif(
          id: _notifId(tomorrowStr, prayer),
          prayer: prayer,
          scheduledDate: tomorrowPrayerTime,
        );
      }

      if (success) scheduledCount++;
    }

    if (scheduledCount > 0) {
      await prefs.setString(_prefsKeyLastScheduleDate, todayStr);
    }
  }

  Future<void> forceRescheduleToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLastScheduleDate);
    await rescheduleToday();
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

  Future<bool> _scheduleTodayForPrayer(String prayer) async {
    if (!_initialized || !_permissionsGranted) return false;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return false;

    final parsedTime = _parsePrayerTime(timings['timings'][prayer]);
    if (parsedTime == null) return false;

    final now = DateTime.now();
    final prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (prayerTime.isBefore(now.add(const Duration(minutes: 1)))) {
      return false;
    }

    final todayStr = _todayDateKey();
    await _cancelNotif(_notifId(todayStr, prayer));

    return await _scheduleNotif(
      id: _notifId(todayStr, prayer),
      prayer: prayer,
      scheduledDate: prayerTime,
    );
  }

  Future<bool> _scheduleTomorrowForPrayer(String prayer) async {
    if (!_initialized || !_permissionsGranted) return false;

    final timings = await PrayerService.instance.getTodayTimings();
    if (timings == null || timings['timings'] == null) return false;

    final parsedTime = _parsePrayerTime(timings['timings'][prayer]);
    if (parsedTime == null) return false;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final prayerTime = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    final tomorrowStr = _tomorrowDateKey();
    await _cancelNotif(_notifId(tomorrowStr, prayer));

    return await _scheduleNotif(
      id: _notifId(tomorrowStr, prayer),
      prayer: prayer,
      scheduledDate: prayerTime,
    );
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  Future<void> _cancelTodayForPrayer(String prayer) async {
    await _cancelNotif(_notifId(_todayDateKey(), prayer));
  }

  Future<void> _cancelTomorrowForPrayer(String prayer) async {
    await _cancelNotif(_notifId(_tomorrowDateKey(), prayer));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLastScheduleDate);
  }

  // ── Test Notification ────────────────────────────────────────────────────

  Future<void> _showTestNotification(String prayer) async {
    if (!_initialized || !_permissionsGranted) return;

    final displayName = _prayerDisplayNames[prayer] ?? prayer;
    final arabicName = _prayerArabicNames[prayer] ?? '';

    // FIX 2: Removed 'const', used Int64List.fromList
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

    final body = arabicName.isNotEmpty
        ? '$arabicName \u2022 You\'ll be reminded at prayer time'
        : 'You\'ll be reminded at $displayName prayer time';

    await _plugin.show(
      id: _notifId('test', prayer),
      title: '\u2705 $displayName Notifications Enabled',
      body: body,
      notificationDetails: details,
      payload: '$_payloadPrefix$prayer',
    );
  }

  // ── Scheduled Notification Details ──────────────────────────────────────

  NotificationDetails _buildScheduledNotificationDetails() {
    // FIX 2: Removed 'const', used Int64List.fromList
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
      final arabicName = _prayerArabicNames[prayer] ?? '';
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
      final body = arabicName.isNotEmpty
          ? '$arabicName \u2022 $timeStr\n$reminder'
          : '$timeStr \u2022 $reminder';

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledDate,
        notificationDetails: _buildScheduledNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '$_payloadPrefix$prayer',
      );

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

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _tomorrowDateKey() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
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
