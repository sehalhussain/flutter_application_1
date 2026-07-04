// lib/providers/quran_progress_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

class QuranProgress extends ChangeNotifier {
  List<QuranBookmark> _bookmarks = [];
  LastReadPosition? _lastRead;
  List<ReadingSession> _recentReads = [];

  // ── Auto-tracking fields ──────────────────────────────────────────────
  LastReadPosition? _autoTrackedPosition;
  DateTime? _autoTrackedTimestamp;
  Timer? _autoTrackDebounce;
  static const Duration _autoTrackDebounceDuration = Duration(seconds: 2);
  String? _lastTrackedAyahKey; // To avoid unnecessary updates

  static const int _maxRecentReads = 5;
  static const String _bookmarksKey = 'quran_bookmarks';
  static const String _lastReadKey = 'quran_last_read';
  static const String _recentReadsKey = 'quran_recent_reads_v2';
  static const String _autoTrackedKey = 'quran_auto_tracked_v1';

  List<QuranBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  LastReadPosition? get lastRead => _lastRead;
  List<ReadingSession> get recentReads => List.unmodifiable(_recentReads);

  /// Returns recent reads for display.
  /// Falls back to auto-tracked position if no manual reads exist.
  List<ReadingSession> get displayRecentReads {
    final list = List<ReadingSession>.from(_recentReads);
    if (_autoTrackedPosition != null) {
      final exists = _recentReads.any((r) => r.surah == _autoTrackedPosition!.surah && r.ayah == _autoTrackedPosition!.ayah);
      if (!exists) {
        list.add(
          ReadingSession(
            surah: _autoTrackedPosition!.surah,
            ayah: _autoTrackedPosition!.ayah,
            surahName: _autoTrackedPosition!.surahName,
            timestamp: _autoTrackedTimestamp ?? DateTime.now(),
            isAutoTracked: true,
          ),
        );
      }
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  /// Check if there's any reading position to show
  bool get hasAnyReadPosition =>
      _recentReads.isNotEmpty || _autoTrackedPosition != null;

  // ── Init ──────────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Bookmarks
    final bmRaw = prefs.getStringList(_bookmarksKey) ?? [];
    _bookmarks =
        bmRaw.map((s) => QuranBookmark.fromJson(json.decode(s))).toList();

    // Legacy last read (migrate to recent reads if present)
    final lrRaw = prefs.getString(_lastReadKey);
    if (lrRaw != null) {
      _lastRead = LastReadPosition.fromJson(json.decode(lrRaw));
      final migrated = ReadingSession(
        surah: _lastRead!.surah,
        ayah: _lastRead!.ayah,
        surahName: _lastRead!.surahName,
        timestamp: DateTime.now().subtract(const Duration(days: 30)),
      );
      _recentReads.add(migrated);
      prefs.remove(_lastReadKey);
    }

    // New recent reads
    final rrRaw = prefs.getStringList(_recentReadsKey) ?? [];
    _recentReads.addAll(
      rrRaw.map((s) => ReadingSession.fromJson(json.decode(s))),
    );
    _recentReads.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Load auto-tracked position
    final atRaw = prefs.getString(_autoTrackedKey);
    if (atRaw != null) {
      final decoded = json.decode(atRaw) as Map<String, dynamic>;
      _autoTrackedPosition = LastReadPosition(
        surah: decoded['surah'] as int,
        ayah: decoded['ayah'] as int,
        surahName: decoded['surahName'] as String,
      );
      _autoTrackedTimestamp =
          DateTime.tryParse(decoded['timestamp'] as String? ?? '');
      _lastTrackedAyahKey = '${decoded['surah']}:${decoded['ayah']}';
    }

    _deduplicateAndCap();
    notifyListeners();
  }

  // ── Auto-Tracking (NEW) ───────────────────────────────────────────────

  /// Call this when an ayah becomes visible during reading.
  /// Uses debouncing to avoid excessive updates.
  void trackViewingAyah(int surah, int ayah, String surahName) {
    final key = '$surah:$ayah';

    // Skip if we're already tracking this exact ayah
    if (_lastTrackedAyahKey == key) return;

    _autoTrackDebounce?.cancel();
    _autoTrackDebounce = Timer(_autoTrackDebounceDuration, () {
      _updateAutoTrackedPosition(surah, ayah, surahName);
    });
  }

  /// Immediately update the tracked position (e.g., when leaving reader)
  void finalizeTracking(int surah, int ayah, String surahName) {
    _autoTrackDebounce?.cancel();
    _updateAutoTrackedPosition(surah, ayah, surahName);
  }

  void _updateAutoTrackedPosition(int surah, int ayah, String surahName) {
    _autoTrackedPosition = LastReadPosition(
      surah: surah,
      ayah: ayah,
      surahName: surahName,
    );
    _autoTrackedTimestamp = DateTime.now();
    _lastTrackedAyahKey = '$surah:$ayah';
    _persistAutoTracked();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        notifyListeners();
      } catch (_) {}
    });
  }

  Future<void> _persistAutoTracked() async {
    if (_autoTrackedPosition == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _autoTrackedKey,
        json.encode({
          'surah': _autoTrackedPosition!.surah,
          'ayah': _autoTrackedPosition!.ayah,
          'surahName': _autoTrackedPosition!.surahName,
          'timestamp': _autoTrackedTimestamp?.toIso8601String(),
        }));
  }

  Future<void> clearAutoTracked() async {
    _autoTrackedPosition = null;
    _autoTrackedTimestamp = null;
    _lastTrackedAyahKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_autoTrackedKey);
    notifyListeners();
  }

  // ── Bookmarks (unchanged) ─────────────────────────────────────────────
  bool isBookmarked(int surah, int ayah) =>
      _bookmarks.any((b) => b.surah == surah && b.ayah == ayah);

  Future<void> toggleBookmark(int surah, int ayah, String surahName) async {
    if (isBookmarked(surah, ayah)) {
      _bookmarks.removeWhere((b) => b.surah == surah && b.ayah == ayah);
    } else {
      _bookmarks
          .add(QuranBookmark(surah: surah, ayah: ayah, surahName: surahName));
    }
    notifyListeners();
    await _persistBookmarks();
  }

  Future<void> removeBookmark(int surah, int ayah) async {
    _bookmarks.removeWhere((b) => b.surah == surah && b.ayah == ayah);
    notifyListeners();
    await _persistBookmarks();
  }

  Future<void> _persistBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _bookmarksKey,
      _bookmarks.map((b) => json.encode(b.toJson())).toList(),
    );
  }

  // ── Recent Reads ──────────────────────────────────────────────────────
  bool isRecentRead(int surah, int ayah) =>
      _recentReads.any((r) => r.surah == surah && r.ayah == ayah);

  Future<void> addRecentRead(int surah, int ayah, String surahName) async {
    _recentReads.removeWhere((r) => r.surah == surah && r.ayah == ayah);

    _recentReads.insert(
        0,
        ReadingSession(
          surah: surah,
          ayah: ayah,
          surahName: surahName,
          timestamp: DateTime.now(),
        ));

    _deduplicateAndCap();
    notifyListeners();
    await _persistRecentReads();
  }

  Future<void> removeRecentRead(int surah, int ayah) async {
    _recentReads.removeWhere((r) => r.surah == surah && r.ayah == ayah);
    notifyListeners();
    await _persistRecentReads();
  }

  Future<void> clearRecentReads() async {
    _recentReads.clear();
    notifyListeners();
    await _persistRecentReads();
  }

  // Legacy compatibility
  Future<void> setLastRead(int surah, int ayah, String surahName) async {
    _lastRead =
        LastReadPosition(surah: surah, ayah: ayah, surahName: surahName);
    await addRecentRead(surah, ayah, surahName);
  }

  Future<void> clearLastRead() async {
    _lastRead = null;
    await clearRecentReads();
  }

  void _deduplicateAndCap() {
    final seen = <String>{};
    _recentReads = _recentReads.where((r) {
      final key = '${r.surah}:${r.ayah}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    if (_recentReads.length > _maxRecentReads) {
      _recentReads = _recentReads.sublist(0, _maxRecentReads);
    }
  }

  Future<void> _persistRecentReads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentReadsKey,
      _recentReads.map((r) => json.encode(r.toJson())).toList(),
    );
  }

  @override
  void dispose() {
    _autoTrackDebounce?.cancel();
    super.dispose();
  }
}

// ── Provider widget ─────────────────────────────────────────────────────
class QuranProgressProvider {
  static QuranProgress of(BuildContext context, {bool listen = true}) {
    return Provider.of<QuranProgress>(context, listen: listen);
  }
}
