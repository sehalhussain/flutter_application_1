// lib/providers/quran_progress_provider.dart

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

class QuranProgress extends ChangeNotifier {
  List<QuranBookmark> _bookmarks = [];
  LastReadPosition? _lastRead;
  List<ReadingSession> _recentReads = [];

  static const int _maxRecentReads = 5;
  static const String _bookmarksKey = 'quran_bookmarks';
  static const String _lastReadKey = 'quran_last_read';
  static const String _recentReadsKey = 'quran_recent_reads_v2';

  List<QuranBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  LastReadPosition? get lastRead => _lastRead;
  List<ReadingSession> get recentReads => List.unmodifiable(_recentReads);

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Bookmarks
    final bmRaw = prefs.getStringList(_bookmarksKey) ?? [];
    _bookmarks =
        bmRaw.map((s) => QuranBookmark.fromJson(json.decode(s))).toList();

    // Legacy last read (migrate to recent reads if present)
    final lrRaw = prefs.getString(_lastReadKey);
    if (lrRaw != null) {
      _lastRead = LastReadPosition.fromJson(
          json.decode(lrRaw)); // ← FIXED: lrRaw not lr
      // Migrate to new system
      final migrated = ReadingSession(
        surah: _lastRead!.surah,
        ayah: _lastRead!.ayah,
        surahName: _lastRead!.surahName,
        timestamp: DateTime.now().subtract(const Duration(days: 30)), // old
      );
      _recentReads.add(migrated);
      prefs.remove(_lastReadKey); // clear legacy
    }

    // New recent reads
    final rrRaw = prefs.getStringList(_recentReadsKey) ?? [];
    _recentReads.addAll(
      rrRaw.map((s) => ReadingSession.fromJson(json.decode(s))),
    );
    _recentReads.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Deduplicate and cap
    _deduplicateAndCap();

    notifyListeners();
  }

  // ── Bookmarks (unchanged) ─────────────────────────────────────────────────
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

  // ── Recent Reads (NEW) ────────────────────────────────────────────────────
  bool isRecentRead(int surah, int ayah) =>
      _recentReads.any((r) => r.surah == surah && r.ayah == ayah);

  Future<void> addRecentRead(int surah, int ayah, String surahName) async {
    // Remove if exists (move to top)
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
    // Keep only newest per surah:ayah combo
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
}

// ── Provider widget ─────────────────────────────────────────────────────────
class QuranProgressProvider {
  static QuranProgress of(BuildContext context, {bool listen = true}) {
    return Provider.of<QuranProgress>(context, listen: listen);
  }
}
