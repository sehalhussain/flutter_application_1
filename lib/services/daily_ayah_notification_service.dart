// lib/services/daily_ayah_notification_service.dart
/// Schedules a daily "Ayah of the Day" local notification at a user-chosen
/// fixed time. Each scheduled day gets a different random ayah (fetched
/// offline via QuranService at schedule time), mirroring the multi-day
/// scheduling approach used by PrayerNotificationService.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_notification_service.dart';
import 'quran_service.dart';

const String _kPrefsEnabled = 'daily_ayah_notif_enabled';
const String _kPrefsHour = 'daily_ayah_notif_hour';
const String _kPrefsMinute = 'daily_ayah_notif_minute';

const String _channelId = 'daily_ayah_channel';
const String _channelName = 'Daily Ayah Reminder';
const String _channelDescription = 'A random ayah from the Quran every day';

class DailyAyahNotificationService {
  DailyAyahNotificationService._();
  static final DailyAyahNotificationService instance =
      DailyAyahNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsGranted = false;

  /// Called when the user taps an ayah notification.
  /// Provides the surah and ayah numbers so the app can open the reader.
  void Function(int surah, int ayah)? onOpenAyah;

  void _onNotificationTap(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handlePayload(String? payload) {
    if (payload == null) return;
    // Payload format: 'daily_ayah:<surahNumber>:<ayahNumber>'
    final parts = payload.split(':');
    if (parts.length != 3 || parts[0] != 'daily_ayah') return;
    final surah = int.tryParse(parts[1]);
    final ayah = int.tryParse(parts[2]);
    if (surah == null || ayah == null) return;
    onOpenAyah?.call(surah, ayah);
  }

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

      // Handle a cold start caused by tapping a notification: the tap
      // callback above only fires while the app is already running.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _handlePayload(launchDetails!.notificationResponse?.payload);
      }

      _permissionsGranted = await _checkPermissions();
      _initialized = true;
      debugPrint(
          'DailyAyahNotificationService initialized. Permissions: $_permissionsGranted');
      return _permissionsGranted;
    } catch (e) {
      debugPrint('Failed to initialize DailyAyahNotificationService: $e');
      _initialized = true;
      return false;
    }
  }

  Future<void> _initializeTimezone() async {
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
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
    } catch (e) {
      debugPrint('DailyAyah timezone initialization error: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      ledColor: const Color(0xFF10B981),
    );
    await androidPlugin.createNotificationChannel(channel);
  }

  // ── Permissions ───────────────────────────────────────────────────────────

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

  /// Requests notification permission (delegates to the prayer service so the
  /// user isn't shown the system dialog twice).
  Future<bool> requestPermissions() async {
    if (!_initialized) return false;
    _permissionsGranted = await _checkPermissions();
    if (_permissionsGranted) return true;
    _permissionsGranted =
        await PrayerNotificationService.instance.requestPermissions();
    return _permissionsGranted;
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPrefsEnabled) ?? false;
  }

  Future<TimeOfDay> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_kPrefsHour) ?? 8,
      minute: prefs.getInt(_kPrefsMinute) ?? 0,
    );
  }

  Future<void> setTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsHour, time.hour);
    await prefs.setInt(_kPrefsMinute, time.minute);
    if (await isEnabled()) {
      await reschedule();
    }
  }

  /// Enables/disables the daily ayah notification.
  /// Returns false if enabling failed (e.g. permission denied).
  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      if (!_permissionsGranted) {
        _permissionsGranted = await requestPermissions();
        if (!_permissionsGranted) return false;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefsEnabled, enabled);

    if (enabled) {
      await _scheduleForNDays(_schedulingHorizon());
    } else {
      await cancelAll();
    }
    return true;
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Schedules one notification per day for the horizon, each with a fresh
  /// random ayah. Extends the schedule as the app is opened.
  Future<int> reschedule() async {
    if (!_initialized || !_permissionsGranted) return 0;
    if (!(await isEnabled())) return 0;
    return _scheduleForNDays(_schedulingHorizon());
  }

  int _schedulingHorizon() => Platform.isIOS ? 12 : 30;

  Future<int> _scheduleForNDays(int days) async {
    final time = await getTime();
    final now = DateTime.now();
    int scheduledCount = 0;

    for (int offset = 0; offset < days; offset++) {
      final date = now.add(Duration(days: offset));
      final scheduledDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);

      // Only schedule if it's in the future
      if (!scheduledDate.isAfter(now.add(const Duration(minutes: 1)))) {
        continue;
      }

      try {
        // Fetch a different random ayah for each day (offline, local DB).
        final ayah = await QuranService.instance.getRandomAyah();
        final success = await _scheduleNotif(
          id: _notifId(date),
          scheduledDate: scheduledDate,
          uthmani: ayah.uthmani,
          translation: ayah.translation,
          reference: 'Surah ${ayah.surahNumber} : Ayah ${ayah.ayahNumber}',
          payload:
              'daily_ayah:${ayah.surahNumber}:${ayah.ayahNumber}',
        );
        if (success) scheduledCount++;
      } catch (e) {
        debugPrint('Failed to schedule daily ayah for day +$offset: $e');
      }
    }

    return scheduledCount;
  }

  Future<bool> _scheduleNotif({
    required int id,
    required DateTime scheduledDate,
    required String uthmani,
    required String translation,
    required String reference,
    required String payload,
  }) async {
    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return false;
      }

      // Keep the body readable: arabic on its own line, then translation.
      final body = '$uthmani\n$translation\n— $reference';

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.zonedSchedule(
        id: id,
        title: '📖 Ayah of the Day',
        body: body,
        scheduledDate: tzScheduledDate,
        notificationDetails:
            NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to schedule daily ayah notification: $e');
      return false;
    }
  }

  Future<void> cancelAll() async {
    try {
      // Notifications are id'd from date hashes, so cancel by date range.
      final now = DateTime.now();
      for (int offset = 0; offset <= _schedulingHorizon() + 2; offset++) {
        await _cancelNotif(_notifId(now.add(Duration(days: offset))));
      }
    } catch (e) {
      debugPrint('Failed to cancel daily ayah notifications: $e');
    }
  }

  /// Deterministic notification id derived from the date, offset into a
  /// dedicated high range so it never collides with prayer notification ids.
  int _notifId(DateTime date) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final hash = (dateKey.hashCode ^ ('daily_ayah'.hashCode * 31)).abs();
    return 1000000000 + (hash % 1000000000);
  }

  Future<void> _cancelNotif(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel daily ayah notification $id: $e');
    }
  }
}
