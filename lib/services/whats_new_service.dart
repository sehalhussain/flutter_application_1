// lib/services/whats_new_service.dart
//
// Tracks app version changes and manages "what's new" nudge state.
//
// State machine:
// 1. App starts → check if version changed since last launch
// 2. If version changed (update): set prayer-nudge + bell-highlight flags
// 3. "What's New" dialog is shown (from _SplashWrapper)
// 4. User taps "Show Me" → navigate to Prayer tab → bell highlight shows
// 5. User taps "Maybe Later" → prayer-nudge badge stays on nav item
// 6. User taps Prayer nav item → clear prayer-nudge, keep bell-highlight
// 7. User interacts with a bell or dismisses banner → clear bell-highlight

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsNewService extends ChangeNotifier {
  WhatsNewService._();
  static final WhatsNewService instance = WhatsNewService._();

  // ── SharedPreferences keys ──────────────────────────────────────────────
  static const String _kLastVersion = 'whats_new_last_version';
  static const String _kPrayerNudge = 'whats_new_prayer_nudge';
  static const String _kBellHighlight = 'whats_new_bell_highlight';
  static const String _kDialogShown = 'whats_new_dialog_shown_version';

  // ── Current app version ────────────────────────────────────────────────
  // Update this constant when bumping the version in pubspec.yaml.
  static const String currentAppVersion = '1.2.3';

  SharedPreferences? _prefs;
  bool _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ── Update Detection ───────────────────────────────────────────────────

  /// Returns true if the app was just updated (version changed and not a
  /// fresh install). Also stores the current version and sets nudge flags.
  Future<bool> checkForUpdate() async {
    await init();
    final lastVersion = _prefs?.getString(_kLastVersion);

    // First install — no update nudge
    if (lastVersion == null) {
      await _prefs?.setString(_kLastVersion, currentAppVersion);
      return false;
    }

    // Version changed — it's an update
    if (lastVersion != currentAppVersion) {
      await _prefs?.setString(_kLastVersion, currentAppVersion);
      await _prefs?.setBool(_kPrayerNudge, true);
      await _prefs?.setBool(_kBellHighlight, true);
      await _prefs?.setString(_kDialogShown, currentAppVersion);
      debugPrint(
          '🔔 App updated from $lastVersion → $currentAppVersion. Nudge flags set.');
      notifyListeners();
      return true;
    }

    return false;
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
    notifyListeners();
  }
}
