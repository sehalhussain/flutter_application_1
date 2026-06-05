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
  Future<HadithBook> loadHadithBook(String assetPath,
      {bool preloadAll = true}) async {
    final cacheKey = '$assetPath::${preloadAll ? 'full' : 'summary'}';
    if (_bookCache.containsKey(cacheKey)) return _bookCache[cacheKey]!;

    final book = preloadAll
        ? await _loadFullBook(assetPath)
        : await HadithDb.instance.loadBookOverview(assetPath);

    _bookCache[cacheKey] = book;
    return book;
  }

  Future<HadithBook> _loadFullBook(String assetPath) async {
    if (assetPath == HadithDb.riyadAssetPath) {
      return HadithDb.instance.loadRiyadBook(HadithDb.riyadAssetPath);
    }

    final flatSpec = HadithDb.flatSpecFor(assetPath);
    if (flatSpec != null) {
      return HadithDb.instance.loadFlatBook(flatSpec);
    }

    return const HadithBook(
      name: '',
      arabicName: '',
      shortDesc: '',
      numBooks: '',
      numHadiths: '',
      allBooks: [],
      assetPath: '',
    );
  }

  Future<HadithChapter> loadChapter(String assetPath,
      {required int chapterId, String? chapterKey}) async {
    if (assetPath == HadithDb.riyadAssetPath) {
      return HadithDb.instance.loadChapter(assetPath, chapterId: chapterId);
    }

    final flatSpec = HadithDb.flatSpecFor(assetPath);
    if (flatSpec != null) {
      return HadithDb.instance
          .loadFlatChapter(flatSpec, chapterKey: chapterKey ?? '');
    }

    return const HadithChapter(
      num: '',
      englishTitle: '',
      arabicTitle: '',
      hadithList: [],
    );
  }

  List<Hadith> getHadithChunk(List<Hadith> allHadiths, int start, int count) {
    final end = (start + count).clamp(0, allHadiths.length);
    return allHadiths.sublist(start, end);
  }

  // ── Sources for "Hadith of the Day" ──
  // KEY CHANGE: Included flat book paths so daily quotes aren't locked to Riyad
  static final List<String> _dailyHadithSources = [
    'assets/hadith/riyad_assalihin.db',
    for (final s in HadithDb.flatBooks) s.assetPath,
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

      // Pass maxNewlines argument to match interface signature if needed,
      // or rely on its internal default.
      return await HadithDb.instance.getRandomShortHadithFlat();
    } catch (_) {
      return null;
    }
  }
}
