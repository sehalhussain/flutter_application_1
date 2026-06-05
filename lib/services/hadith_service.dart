import 'dart:math';
import '../models/hadith_models.dart';
import 'hadith_db.dart';

class HadithService {
  HadithService._();
  static final HadithService instance = HadithService._();

  final Map<String, HadithBook> _bookCache = {};
  List<HadithBookInfo>? _books;

  /// All book entries — Riyad as-Salihin (SQL-backed) + 6 flat-table DBs.
  /// No JSON files needed.
  static final List<HadithBookInfo> _allBooks = [
    const HadithBookInfo(
      assetPath: 'assets/hadith/riyad_assalihin.db',
      title: 'Riyad as Salihin',
    ),
    for (final s in HadithDb.flatBooks)
      HadithBookInfo(assetPath: s.assetPath, title: s.name),
  ];

  Future<List<HadithBookInfo>> loadHadithBooks() async {
    _books ??= _allBooks;
    return _books!;
  }

  /// Returns the in-memory `HadithBook` for an asset path. Cached on first
  /// call. All books are now served from SQLite.
  Future<HadithBook> loadHadithBook(String assetPath) async {
    if (_bookCache.containsKey(assetPath)) return _bookCache[assetPath]!;

    HadithBook book;
    if (assetPath == HadithDb.riyadAssetPath) {
      book = await HadithDb.instance.loadRiyadBook(HadithDb.riyadAssetPath);
    } else {
      final flatSpec = HadithDb.flatSpecFor(assetPath);
      if (flatSpec != null) {
        book = await HadithDb.instance.loadFlatBook(flatSpec);
      } else {
        // Fallback: should not happen after refactor.
        book = HadithBook(
          name: '',
          arabicName: '',
          shortDesc: '',
          numBooks: '',
          numHadiths: '',
          allBooks: [],
          assetPath: assetPath,
        );
      }
    }
    _bookCache[assetPath] = book;
    return book;
  }

  List<Hadith> getHadithChunk(List<Hadith> allHadiths, int start, int count) {
    final end = (start + count).clamp(0, allHadiths.length);
    return allHadiths.sublist(start, end);
  }

  // ── Sources for "Hadith of the Day" ──
  static const List<String> _dailyHadithSources = [
    'assets/hadith/riyad_assalihin.db',
  ];

  /// Returns one random short [Hadith] from any book, or `null` if loading fails.
  /// Uses `ORDER BY RANDOM()` SQL queries for instant results.
  Future<Hadith?> getRandomHadith() async {
    final rng = Random();
    final bookPath =
        _dailyHadithSources[rng.nextInt(_dailyHadithSources.length)];

    try {
      if (bookPath == HadithDb.riyadAssetPath) {
        return await HadithDb.instance
            .getRandomShortHadith(HadithDb.riyadAssetPath);
      }
      return await HadithDb.instance.getRandomShortHadithFlat();
    } catch (_) {
      return null;
    }
  }
}
