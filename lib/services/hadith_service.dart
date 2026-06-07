import '../models/hadith_models.dart';
import 'hadith_db.dart';

class HadithService {
  HadithService._();
  static final HadithService instance = HadithService._();

  final Map<String, HadithBook> _bookCache = {};
  List<HadithBookInfo>? _books;

  /// All book entries — all 7 books use the same flat `hadith_library` schema.
  static final List<HadithBookInfo> _allBooks = [
    for (final s in HadithDb.flatBooks)
      HadithBookInfo(assetPath: s.assetPath, title: s.name),
  ];

  Future<List<HadithBookInfo>> loadHadithBooks() async {
    _books ??= _allBooks;
    return _books!;
  }

  /// Returns the in-memory `HadithBook` for an asset path. Cached on first call.
  Future<HadithBook> loadHadithBook(String assetPath,
      {bool preloadAll = true}) async {
    final cacheKey = '$assetPath::${preloadAll ? 'full' : 'summary'}';
    if (_bookCache.containsKey(cacheKey)) return _bookCache[cacheKey]!;

    final flatSpec = HadithDb.flatSpecFor(assetPath);
    if (flatSpec == null) {
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

    final book = preloadAll
        ? await HadithDb.instance.loadFlatBook(flatSpec)
        : await HadithDb.instance.loadBookOverview(assetPath);

    _bookCache[cacheKey] = book;
    return book;
  }

  Future<HadithChapter> loadChapter(String assetPath,
      {required int chapterId, String? chapterKey}) async {
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

  /// Returns one random short [Hadith] from any book, or `null` if loading fails.
  Future<Hadith?> getRandomHadith() async {
    try {
      return await HadithDb.instance.getRandomShortHadithFlat();
    } catch (_) {
      return null;
    }
  }
}
