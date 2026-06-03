import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/hadith_models.dart';

class HadithService {
  HadithService._();
  static final HadithService instance = HadithService._();

  static const _basePath = 'assets/hadith';
  final Map<String, HadithBook> _bookCache = {};
  List<HadithBookInfo>? _books;

  Future<List<HadithBookInfo>> loadHadithBooks() async {
    if (_books != null) return _books!;

    final assets = <String>[];
    try {
      final manifest = await rootBundle.loadString('AssetManifest.json');
      final decoded = json.decode(manifest) as Map<String, dynamic>;
      assets.addAll(decoded.keys
          .where(
              (key) => key.startsWith('$_basePath/') && key.endsWith('.json'))
          .toList());
    } catch (_) {
      // Fall back to a manual index when the JSON manifest is unavailable.
    }

    if (assets.isEmpty) {
      try {
        final indexJson =
            await rootBundle.loadString('assets/hadith/books.json');
        final indexData = json.decode(indexJson);
        if (indexData is List) {
          assets.addAll(indexData.whereType<String>());
        }
      } catch (_) {
        // If the index is missing or invalid, continue with an empty list.
      }
    }

    assets.sort();
    _books = assets
        .map((asset) => HadithBookInfo(
              assetPath: asset,
              title: _titleFromAsset(asset),
            ))
        .toList();
    return _books!;
  }

  Future<HadithBook> loadHadithBook(String assetPath) async {
    if (_bookCache.containsKey(assetPath)) return _bookCache[assetPath]!;
    final String raw = await rootBundle.loadString(assetPath);
    final book = await compute(_parseHadithBook, [raw, assetPath]);
    _bookCache[assetPath] = book;
    return book;
  }

  static HadithBook _parseHadithBook(List<String> args) {
    final raw = args[0];
    final assetPath = args[1];
    final data = json.decode(raw);
    if (data is Map<String, dynamic>) {
      return HadithBook.fromJson(data, assetPath);
    }
    return HadithBook(
      name: '',
      arabicName: '',
      shortDesc: '',
      numBooks: '',
      numHadiths: '',
      allBooks: [],
      assetPath: assetPath,
    );
  }

  List<Hadith> getHadithChunk(List<Hadith> allHadiths, int start, int count) {
    final end = (start + count).clamp(0, allHadiths.length);
    return allHadiths.sublist(start, end);
  }

  // ── Sources for "Hadith of the Day" ──
  static const List<String> _dailyHadithSources = [
    'assets/hadith/riyad_assalihin.json',
  ];

  /// Rough heuristic: a "short" hadith has no more than ~6 Arabic lines.
  /// We count newlines in the Arabic text as a proxy for visual length.
  static bool _isShortHadith(Hadith h) {
    final lines = h.arabicText.split('\n').length;
    return lines <= 12; // ~5-6 visible Arabic lines
  }

  /// Returns one random short [Hadith] from Sahih al-Bukhari, Sahih al-Muslim,
  /// or Riyad as-Salihin, or `null` if loading fails.
  Future<Hadith?> getRandomHadith() async {
    // Pick a random source book.
    final rng = Random();
    final bookPath =
        _dailyHadithSources[rng.nextInt(_dailyHadithSources.length)];

    try {
      final book = await loadHadithBook(bookPath);
      if (book.allBooks.isEmpty) return null;

      // Collect short hadiths only.
      final shortHadiths = <Hadith>[];
      for (final chapter in book.allBooks) {
        for (final h in chapter.hadithList) {
          if (_isShortHadith(h)) {
            shortHadiths.add(h);
          }
        }
      }

      if (shortHadiths.isEmpty) return null;
      return shortHadiths[rng.nextInt(shortHadiths.length)];
    } catch (_) {
      return null;
    }
  }

  String _titleFromAsset(String assetPath) {
    final fileName = assetPath.split('/').last;
    final baseName = fileName.replaceAll('.json', '');
    return baseName
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
