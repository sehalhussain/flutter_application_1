// lib/providers/quran_progress_provider.dart
//
// Manages bookmarks + last-read position, persisted to shared_preferences.

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

class QuranProgress extends ChangeNotifier {
  List<QuranBookmark> _bookmarks   = [];
  LastReadPosition?   _lastRead;

  List<QuranBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  LastReadPosition?   get lastRead  => _lastRead;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final bmRaw = prefs.getStringList('quran_bookmarks') ?? [];
    _bookmarks = bmRaw
        .map((s) => QuranBookmark.fromJson(json.decode(s) as Map<String, dynamic>))
        .toList();

    final lrRaw = prefs.getString('quran_last_read');
    if (lrRaw != null) {
      _lastRead = LastReadPosition.fromJson(
          json.decode(lrRaw) as Map<String, dynamic>);
    }

    notifyListeners();
  }

  // ── Bookmarks ─────────────────────────────────────────────────────────────
  bool isBookmarked(int surah, int ayah) =>
      _bookmarks.any((b) => b.surah == surah && b.ayah == ayah);

  Future<void> toggleBookmark(int surah, int ayah, String surahName) async {
    if (isBookmarked(surah, ayah)) {
      _bookmarks.removeWhere((b) => b.surah == surah && b.ayah == ayah);
    } else {
      _bookmarks.add(
          QuranBookmark(surah: surah, ayah: ayah, surahName: surahName));
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
    prefs.setStringList(
      'quran_bookmarks',
      _bookmarks.map((b) => json.encode(b.toJson())).toList(),
    );
  }

  // ── Last read ─────────────────────────────────────────────────────────────
  bool isLastRead(int surah, int ayah) =>
      _lastRead?.surah == surah && _lastRead?.ayah == ayah;

  Future<void> setLastRead(int surah, int ayah, String surahName) async {
    _lastRead = LastReadPosition(surah: surah, ayah: ayah, surahName: surahName);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('quran_last_read', json.encode(_lastRead!.toJson()));
  }

  Future<void> clearLastRead() async {
    _lastRead = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('quran_last_read');
  }
}

// ── Provider widget ───────────────────────────────────────────────────────────
class QuranProgressProvider {
  static QuranProgress of(BuildContext context, {bool listen = true}) {
    return Provider.of<QuranProgress>(context, listen: listen);
  }
}
