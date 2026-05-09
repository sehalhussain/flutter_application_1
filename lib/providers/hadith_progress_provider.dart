import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith_models.dart';

class HadithLastReadPosition {
  final String assetPath;
  final String hadithUuid;
  final String hadithTitle;
  final String chapterTitle;
  final String bookTitle;

  const HadithLastReadPosition({
    required this.assetPath,
    required this.hadithUuid,
    required this.hadithTitle,
    required this.chapterTitle,
    required this.bookTitle,
  });

  factory HadithLastReadPosition.fromJson(Map<String, dynamic> json) {
    return HadithLastReadPosition(
      assetPath: json['assetPath'] as String? ?? '',
      hadithUuid: json['hadithUuid'] as String? ?? '',
      hadithTitle: json['hadithTitle'] as String? ?? '',
      chapterTitle: json['chapterTitle'] as String? ?? '',
      bookTitle: json['bookTitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'assetPath': assetPath,
        'hadithUuid': hadithUuid,
        'hadithTitle': hadithTitle,
        'chapterTitle': chapterTitle,
        'bookTitle': bookTitle,
      };
}

class HadithProgress extends ChangeNotifier {
  final List<HadithFavorite> _favorites = [];
  HadithLastReadPosition? _lastRead;

  List<HadithFavorite> get favorites => List.unmodifiable(_favorites);
  HadithLastReadPosition? get lastRead => _lastRead;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFavorites = prefs.getStringList('hadith_favorites') ?? [];
    _favorites
      ..clear()
      ..addAll(rawFavorites.map((item) =>
          HadithFavorite.fromJson(json.decode(item) as Map<String, dynamic>)));

    final lastReadRaw = prefs.getString('hadith_last_read');
    if (lastReadRaw != null && lastReadRaw.isNotEmpty) {
      try {
        final decoded = json.decode(lastReadRaw) as Map<String, dynamic>;
        _lastRead = HadithLastReadPosition.fromJson(decoded);
      } catch (_) {
        _lastRead = null;
      }
    }
    notifyListeners();
  }

  bool isFavorite(String assetPath, String hadithUuid) {
    return _favorites.any((favorite) =>
        favorite.assetPath == assetPath && favorite.hadithUuid == hadithUuid);
  }

  bool isLastRead(String assetPath, String hadithUuid) {
    return _lastRead?.assetPath == assetPath &&
        _lastRead?.hadithUuid == hadithUuid;
  }

  Future<void> toggleFavorite(String assetPath, String hadithUuid) async {
    final existingIndex = _favorites.indexWhere((favorite) =>
        favorite.assetPath == assetPath && favorite.hadithUuid == hadithUuid);
    if (existingIndex >= 0) {
      _favorites.removeAt(existingIndex);
    } else {
      _favorites
          .add(HadithFavorite(assetPath: assetPath, hadithUuid: hadithUuid));
    }
    notifyListeners();
    await _persistFavorites();
  }

  Future<void> setLastRead({
    required String assetPath,
    required String hadithUuid,
    required String hadithTitle,
    required String chapterTitle,
    required String bookTitle,
  }) async {
    _lastRead = HadithLastReadPosition(
      assetPath: assetPath,
      hadithUuid: hadithUuid,
      hadithTitle: hadithTitle,
      chapterTitle: chapterTitle,
      bookTitle: bookTitle,
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hadith_last_read', json.encode(_lastRead!.toJson()));
  }

  Future<void> clearLastRead() async {
    _lastRead = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hadith_last_read');
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hadith_favorites',
        _favorites.map((favorite) => json.encode(favorite.toJson())).toList());
  }
}

class HadithProgressProvider {
  static HadithProgress of(BuildContext context, {bool listen = true}) {
    return Provider.of<HadithProgress>(context, listen: listen);
  }
}
