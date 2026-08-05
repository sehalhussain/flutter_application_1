// lib/services/whats_new_service.dart
//
// Handles both "what's new" update nudges AND first-time user discovery.
//
// ── UPDATE FLOW (existing users) ─────────────────────────────────────────
// 1. App starts → version changed since last launch → nudge flags set
// 2. "What's New" dialog is shown (update only – not for new users)
// 3. User taps "Show Me" → navigate to Prayer tab → banner shows
// 4. User taps "Maybe Later" → badge stays on nav item
//
// ── NEW USER FLOW (first install) ───────────────────────────────────────
// 1. App starts → no version stored → nudge flags set
// 2. NO "What's New" dialog — just the pulsing dot on Prayer nav item
// 3. When user taps Prayer → info banner shows at top of prayer screen
// 4. Nudge + banner persist for 5 app opens, then auto-clear permanently
//    (or until user interacts with the bell / dismisses the banner)

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsNewService extends ChangeNotifier {
  WhatsNewService._();
  static final WhatsNewService instance = WhatsNewService._();

  // ── SharedPreferences keys ──────────────────────────────────────────────
  static const String _kLastVersion = 'whats_new_last_version';
  static const String _kPrayerNudge = 'whats_new_prayer_nudge';
  static const String _kBellHighlight = 'whats_new_bell_highlight';
  static const String _kDialogShown = 'whats_new_dialog_shown_version';
  static const String _kAppOpenCount = 'whats_new_app_open_count';

  // ── Number of app opens the nudge persists for ─────────────────────────
  // Set to 4 so that: launch 1 (count=4, shown) → launches 2-4 (shown)
  // → launch 5 (count=0, cleared). Total: 5 app opens with the nudge visible.
  // If nudgeAppOpenLimit is changed, delete the app's SharedPreferences
  // (or call debugReset()) to re-trigger.
  static const int _kAppOpenLimit = 4;

  SharedPreferences? _prefs;
  bool _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Reads the current app version from the build (pubspec.yaml version).
  Future<String> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version; // e.g. "1.2.3"
    } catch (e) {
      debugPrint('Failed to read package info: $e');
      return 'unknown';
    }
  }

  // ── Update + New-User Detection ────────────────────────────────────────

  /// Called on every app launch.
  /// Returns true if the "What's New" dialog should be shown (update only).
  /// For new users, sets nudge flags but returns false (no dialog).
  Future<bool> checkForUpdate() async {
    await init();
    final currentVersion = await _getCurrentVersion();
    final lastVersion = _prefs?.getString(_kLastVersion);

    // First install — set nudge flags, no dialog
    if (lastVersion == null) {
      await _prefs?.setString(_kLastVersion, currentVersion);
      await _prefs?.setBool(_kPrayerNudge, true);
      await _prefs?.setBool(_kBellHighlight, true);
      await _prefs?.setInt(_kAppOpenCount, _kAppOpenLimit);
      debugPrint(
          '🆕 First install. Prayer nudge + bell highlight set for 5 opens.');
      notifyListeners();
      return false;
    }

    // Version changed — it's an update
    if (lastVersion != currentVersion) {
      await _prefs?.setString(_kLastVersion, currentVersion);
      await _prefs?.setBool(_kPrayerNudge, true);
      await _prefs?.setBool(_kBellHighlight, true);
      await _prefs?.setInt(_kAppOpenCount, _kAppOpenLimit);
      await _prefs?.setString(_kDialogShown, currentVersion);
      debugPrint(
          '🔔 App updated from $lastVersion → $currentVersion. Nudge flags set.');
      notifyListeners();
      return true;
    }

    // Same version — decrement app-open counter
    await _decrementAppOpenCount();
    return false;
  }

  /// Decrements the app-open counter. When it reaches 0, clears all nudge flags.
  Future<void> _decrementAppOpenCount() async {
    final count = _prefs?.getInt(_kAppOpenCount) ?? 0;
    if (count <= 0) return;

    final newCount = count - 1;
    await _prefs?.setInt(_kAppOpenCount, newCount);

    if (newCount <= 0) {
      // Nudge period over — clear all flags permanently
      await _prefs?.setBool(_kPrayerNudge, false);
      await _prefs?.setBool(_kBellHighlight, false);
      debugPrint('⏰ Nudge period over. Cleared prayer nudge + bell highlight.');
      notifyListeners();
    }
  }

  // ── Prayer Tab Nudge (badge on nav item) ───────────────────────────────

  bool get shouldShowPrayerNudge {
    return _prefs?.getBool(_kPrayerNudge) ?? false;
  }

  /// Clear the prayer tab nudge (called when user taps the Prayer nav item).
  Future<void> clearPrayerNudge() async {
    await init();
    await _prefs?.setBool(_kPrayerNudge, false);
    notifyListeners();
  }

  // ── Bell Highlight (coachmark on prayer screen) ────────────────────────

  bool get shouldShowBellHighlight {
    return _prefs?.getBool(_kBellHighlight) ?? false;
  }

  /// Clear the bell highlight (called when user interacts with a bell or
  /// dismisses the info banner).
  Future<void> clearBellHighlight() async {
    await init();
    await _prefs?.setBool(_kBellHighlight, false);
    notifyListeners();
  }

  // ── Debug / Testing Helpers ─────────────────────────────────────────────

  /// Force-trigger the nudge for testing purposes.
  Future<void> debugTriggerNudge() async {
    await init();
    await _prefs?.setBool(_kPrayerNudge, true);
    await _prefs?.setBool(_kBellHighlight, true);
    await _prefs?.setInt(_kAppOpenCount, _kAppOpenLimit);
    notifyListeners();
  }

  /// Reset all nudge state (useful for testing).
  Future<void> debugReset() async {
    await init();
    await _prefs?.remove(_kLastVersion);
    await _prefs?.remove(_kPrayerNudge);
    await _prefs?.remove(_kBellHighlight);
    await _prefs?.remove(_kAppOpenCount);
    await _prefs?.remove(_kDialogShown);
    notifyListeners();
  }
}
