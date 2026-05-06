import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith_models.dart';

class HadithProgress extends ChangeNotifier {
  final List<HadithFavorite> _favorites = [];

  List<HadithFavorite> get favorites => List.unmodifiable(_favorites);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('hadith_favorites') ?? [];
    _favorites
      ..clear()
      ..addAll(raw.map((item) =>
          HadithFavorite.fromJson(json.decode(item) as Map<String, dynamic>)));
    notifyListeners();
  }

  bool isFavorite(String assetPath, String hadithUuid) {
    return _favorites.any((favorite) =>
        favorite.assetPath == assetPath && favorite.hadithUuid == hadithUuid);
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
