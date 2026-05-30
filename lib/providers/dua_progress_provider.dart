import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuaFavorite {
  final int duaId;
  final String segmentName;
  final String categoryName;
  final String titleName;
  final String? latin;
  final String? translation;

  DuaFavorite({
    required this.duaId,
    required this.segmentName,
    required this.categoryName,
    required this.titleName,
    this.latin,
    this.translation,
  });

  factory DuaFavorite.fromJson(Map<String, dynamic> json) {
    return DuaFavorite(
      duaId: json['duaId'] as int,
      segmentName: json['segmentName'] as String? ?? '',
      categoryName: json['categoryName'] as String? ?? '',
      titleName: json['titleName'] as String? ?? '',
      latin: json['latin'] as String?,
      translation: json['translation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'duaId': duaId,
        'segmentName': segmentName,
        'categoryName': categoryName,
        'titleName': titleName,
        'latin': latin,
        'translation': translation,
      };
}

/// A pinned category shortcut for quick access from home
class PinnedCategory {
  final int categoryId;
  final String categoryName;
  final String segmentName;
  final int segmentIndex;
  final int totalDuas;

  PinnedCategory({
    required this.categoryId,
    required this.categoryName,
    required this.segmentName,
    required this.segmentIndex,
    required this.totalDuas,
  });

  factory PinnedCategory.fromJson(Map<String, dynamic> json) {
    return PinnedCategory(
      categoryId: json['categoryId'] as int,
      categoryName: json['categoryName'] as String? ?? '',
      segmentName: json['segmentName'] as String? ?? '',
      segmentIndex: json['segmentIndex'] as int? ?? 0,
      totalDuas: json['totalDuas'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'segmentName': segmentName,
        'segmentIndex': segmentIndex,
        'totalDuas': totalDuas,
      };
}

class DuaProgress extends ChangeNotifier {
  final List<DuaFavorite> _favorites = [];
  final List<PinnedCategory> _pinnedCategories = [];

  List<DuaFavorite> get favorites => List.unmodifiable(_favorites);
  List<PinnedCategory> get pinnedCategories =>
      List.unmodifiable(_pinnedCategories);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawFavorites = prefs.getStringList('dua_favorites') ?? [];
    _favorites
      ..clear()
      ..addAll(rawFavorites.map((item) =>
          DuaFavorite.fromJson(json.decode(item) as Map<String, dynamic>)));

    final rawPinned = prefs.getStringList('dua_pinned_categories') ?? [];
    _pinnedCategories
      ..clear()
      ..addAll(rawPinned.map((item) =>
          PinnedCategory.fromJson(json.decode(item) as Map<String, dynamic>)));
    notifyListeners();
  }

  bool isFavorite(int duaId) {
    return _favorites.any((f) => f.duaId == duaId);
  }

  bool isPinned(int categoryId) {
    return _pinnedCategories.any((p) => p.categoryId == categoryId);
  }

  Future<void> toggleFavorite(DuaFavorite fav) async {
    final existingIndex = _favorites.indexWhere((f) => f.duaId == fav.duaId);
    if (existingIndex >= 0) {
      _favorites.removeAt(existingIndex);
    } else {
      _favorites.add(fav);
    }
    notifyListeners();
    await _persistFavorites();
  }

  Future<void> togglePinned(PinnedCategory pin) async {
    final existingIndex =
        _pinnedCategories.indexWhere((p) => p.categoryId == pin.categoryId);
    if (existingIndex >= 0) {
      _pinnedCategories.removeAt(existingIndex);
    } else {
      _pinnedCategories.add(pin);
    }
    notifyListeners();
    await _persistPinned();
  }

  Future<void> removePinned(int categoryId) async {
    _pinnedCategories.removeWhere((p) => p.categoryId == categoryId);
    notifyListeners();
    await _persistPinned();
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dua_favorites',
        _favorites.map((f) => json.encode(f.toJson())).toList());
  }

  Future<void> _persistPinned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dua_pinned_categories',
        _pinnedCategories.map((p) => json.encode(p.toJson())).toList());
  }
}

class DuaProgressProvider {
  static DuaProgress of(BuildContext context, {bool listen = true}) {
    return Provider.of<DuaProgress>(context, listen: listen);
  }
}
