// lib/services/hadith_db.dart
//
// SQLite-backed loader for the hadith library.
//
// We support two schemas:
//
// 1. RIYAD AS-SALIHIN (3-table relational schema in `riyad_assalihin.db`):
//      - metadata: book info (id, title_en, author_en)
//      - chapters: chapter info linked to a bookId
//      - hadiths:  full hadith content linked to chapterId + bookId
//
// 2. FLAT HADITH LIBRARY (single `hadith_library` table in 6 separate .db
//    files: sahih_al_bukhari, sahih_al_muslim, jami_at_tirmidhi,
//    sunan_abi_dawud, sunan_an_nasai, sunan_ibn_majah):
//      - columns: uuid, book_num, english_title, arabic_title, local_num (TEXT),
//                 title, narrator, english_text, arabic_text, grade
//
// We use the same caching / `path_provider` pattern as `quran_db.dart` to
// keep one copy of each DB on disk and reuse open `Database` handles.
//
// The public API returns data shaped EXACTLY like the JSON-based
// `HadithBook` / `HadithChapter` / `Hadith` models so every screen
// (home, book list, chapter, reader, search) keeps working unchanged.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/hadith_models.dart';

class HadithDb {
  HadithDb._();
  static final HadithDb instance = HadithDb._();

  // ── Cached handles ─────────────────────────────────────────────────────
  final Map<String, Database> _dbs = {};
  // Cached metadata to avoid re-querying book-level info on every load.
  final Map<String, _RiyadMeta> _metaCache = {};

  // The asset key we always use for Riyad as-Salihin.
  static const String riyadAssetPath = 'assets/hadith/riyad_assalihin.db';

  /// Mark whether Riyad as-Salihin should be served from SQL vs JSON.
  /// Always `true` now that the .db is shipped in assets.
  static const bool riyadUseSql = true;

  Future<Database> getDb(String assetPath) async => _getDb(assetPath);

  Future<Database> _getDb(String assetPath) async {
    if (_dbs.containsKey(assetPath)) return _dbs[assetPath]!;

    if (kIsWeb) {
      throw UnsupportedError(
          'sqflite is not supported on web; hadith DB requires mobile');
    }

    final fileName = assetPath.split('/').last;
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/$fileName';

    // Always overwrite the local copy from the bundled asset so that
    // updated DB files ship correctly on app upgrades.
    final bytes = await rootBundle.load(assetPath);
    final file = File(localPath);
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );

    final db = await openDatabase(localPath, readOnly: true);
    _dbs[assetPath] = db;
    return db;
  }

  // ── 1. Book-level metadata ─────────────────────────────────────────────

  Future<_RiyadMeta> _loadMeta(String assetPath) async {
    if (_metaCache.containsKey(assetPath)) return _metaCache[assetPath]!;
    final db = await _getDb(assetPath);

    // Book row (id, title_en, author_en)
    final metaRows = await db.query('metadata', limit: 1);
    String titleEn = 'Riyad as-Salihin';
    String titleAr = 'رياض الصالحين';
    String authorEn = 'Imam Yahya ibn Sharaf al-Nawawi';
    int bookId = 13;

    if (metaRows.isNotEmpty) {
      final r = metaRows.first;
      titleEn = (r['title_en'] as String?) ?? titleEn;
      authorEn = (r['author_en'] as String?) ?? authorEn;
      bookId = (r['id'] as int?) ?? bookId;
    }

    // Counts
    final chapterCountRow = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM chapters WHERE bookId = ?', [bookId]);
    final hadithCountRow = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM hadiths WHERE bookId = ?', [bookId]);

    final meta = _RiyadMeta(
      bookId: bookId,
      titleEn: titleEn,
      titleAr: titleAr,
      authorEn: authorEn,
      chapterCount: Sqflite.firstIntValue(chapterCountRow) ?? 0,
      hadithCount: Sqflite.firstIntValue(hadithCountRow) ?? 0,
    );
    _metaCache[assetPath] = meta;
    return meta;
  }

  // ── 2. Full book load (chapters + hadiths) ─────────────────────────────

  /// Loads the full Riyad as-Salihin book as a `HadithBook`
  Future<HadithBook> loadRiyadBook(String assetPath) async {
    final db = await _getDb(assetPath);
    final meta = await _loadMeta(assetPath);

    // Chapters
    final chapterRows = await db.query(
      'chapters',
      where: 'bookId = ?',
      whereArgs: [meta.bookId],
      orderBy: 'id ASC',
    );

    // Build chapterId -> {english, arabic} lookup.
    final Map<int, Map<String, String>> chapterInfo = {};
    for (final row in chapterRows) {
      final cid = row['id'] as int;
      chapterInfo[cid] = {
        'english': (row['english'] as String?) ?? '',
        'arabic': (row['arabic'] as String?) ?? '',
      };
    }

    // Hadiths (grouped locally by chapterId)
    final hadithRows = await db.query(
      'hadiths',
      where: 'bookId = ?',
      whereArgs: [meta.bookId],
      orderBy: 'id ASC',
    );

    final Map<int, List<Hadith>> grouped = {};
    for (final row in hadithRows) {
      final chapterId = row['chapterId'] as int;
      final info = chapterInfo[chapterId];
      final hadith = _hadithFromRow(row, assetPath, info?['english'] ?? '');
      grouped.putIfAbsent(chapterId, () => <Hadith>[]).add(hadith);
    }

    final chapters = <HadithChapter>[];
    for (final row in chapterRows) {
      final cid = row['id'] as int;
      chapters.add(HadithChapter(
        num: cid.toString(),
        englishTitle: (row['english'] as String?) ?? '',
        arabicTitle: (row['arabic'] as String?) ?? '',
        hadithList: grouped[cid] ?? const <Hadith>[],
      ));
    }

    return HadithBook(
      name: meta.titleEn,
      arabicName: meta.titleAr,
      shortDesc: meta.authorEn,
      numBooks: meta.chapterCount.toString(),
      numHadiths: meta.hadithCount.toString(),
      allBooks: chapters,
      assetPath: assetPath,
    );
  }

  // ── 3. Fast single-chapter load ────────────────────────────────────────

  Future<HadithBook> loadBookOverview(String assetPath) async {
    if (assetPath == riyadAssetPath) {
      return loadRiyadBookOverview(assetPath);
    }

    final spec = flatSpecFor(assetPath);
    if (spec != null) {
      return loadFlatBookOverview(spec);
    }

    return HadithBook(
      name: '',
      arabicName: '',
      shortDesc: '',
      numBooks: '0',
      numHadiths: '0',
      allBooks: const [],
      assetPath: assetPath,
    );
  }

  Future<HadithBook> loadRiyadBookOverview(String assetPath) async {
    final db = await _getDb(assetPath);
    final meta = await _loadMeta(assetPath);

    final chapterRows = await db.query(
      'chapters',
      where: 'bookId = ?',
      whereArgs: [meta.bookId],
      orderBy: 'id ASC',
    );

    final chapters = <HadithChapter>[];
    for (final row in chapterRows) {
      final chapterId = (row['id'] as int?) ?? 0;
      final hadithCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) AS c FROM hadiths WHERE bookId = ? AND chapterId = ?',
            [meta.bookId, chapterId],
          )) ??
          0;

      chapters.add(HadithChapter(
        num: chapterId.toString(),
        englishTitle: (row['english'] as String?) ?? '',
        arabicTitle: (row['arabic'] as String?) ?? '',
        hadithList: const [],
        hadithCount: hadithCount,
        chapterKey: chapterId.toString(),
      ));
    }

    return HadithBook(
      name: meta.titleEn,
      arabicName: meta.titleAr,
      shortDesc: meta.authorEn,
      numBooks: chapters.length.toString(),
      numHadiths: chapters.fold(0, (sum, c) => sum + c.hadithCount).toString(),
      allBooks: chapters,
      assetPath: assetPath,
    );
  }

  Future<HadithChapter> loadChapter(
    String assetPath, {
    required int chapterId,
  }) async {
    final db = await _getDb(assetPath);
    final chapterRows = await db.query(
      'chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
      limit: 1,
    );
    if (chapterRows.isEmpty) {
      return HadithChapter(
        num: chapterId.toString(),
        englishTitle: '',
        arabicTitle: '',
        hadithList: const [],
      );
    }
    final c = chapterRows.first;
    final englishTitle = (c['english'] as String?) ?? '';
    final hadithRows = await db.query(
      'hadiths',
      where: 'chapterId = ?',
      whereArgs: [chapterId],
      orderBy: 'id ASC',
    );
    final hadiths = hadithRows
        .map((r) => _hadithFromRow(r, assetPath, englishTitle))
        .toList(growable: false);
    return HadithChapter(
      num: (c['id'] as int).toString(),
      englishTitle: englishTitle,
      arabicTitle: (c['arabic'] as String?) ?? '',
      hadithList: hadiths,
    );
  }

  // ── 4. Random short hadith for "Hadith of the Day" (Riyad) ─────────────

  Future<Hadith?> getRandomShortHadith(String assetPath,
      {int maxNewlines = 12}) async {
    final db = await _getDb(assetPath);
    final bookIdRow = await db.query('metadata', columns: ['id'], limit: 1);
    final bookId =
        bookIdRow.isNotEmpty ? (bookIdRow.first['id'] as int? ?? 13) : 13;

    final rows = await db.rawQuery(
      '''
      SELECT * FROM hadiths
      WHERE bookId = ?
        AND (LENGTH(arabic) - LENGTH(REPLACE(arabic, char(10), ''))) <= ?
      ORDER BY RANDOM()
      LIMIT 1
      ''',
      [bookId, maxNewlines],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final chapterId = row['chapterId'] as int?;
    String chapterTitle = '';
    if (chapterId != null) {
      final cRows = await db.query('chapters',
          columns: ['english'],
          where: 'id = ?',
          whereArgs: [chapterId],
          limit: 1);
      if (cRows.isNotEmpty) {
        chapterTitle = (cRows.first['english'] as String?) ?? '';
      }
    }
    return _hadithFromRow(row, assetPath, chapterTitle);
  }

  Future<HadithBook> loadFlatBookOverview(HadithBookSpec spec) async {
    final db = await _getDb(spec.assetPath);

    final rows = await db.rawQuery('''
      SELECT english_title,
             arabic_title,
             COUNT(*) AS hadith_count
      FROM hadith_library
      GROUP BY english_title
      ORDER BY MIN(CAST(local_num AS INTEGER)) ASC, english_title ASC
    ''');

    final chapters = <HadithChapter>[];
    int index = 0;
    for (final row in rows) {
      index++;
      final englishTitle = (row['english_title'] as String?) ?? '';
      final arabicTitle = (row['arabic_title'] as String?) ?? '';
      final hadithCount = (row['hadith_count'] as int?) ?? 0;

      chapters.add(HadithChapter(
        num: index.toString(),
        englishTitle: englishTitle,
        arabicTitle: arabicTitle,
        hadithList: const [],
        hadithCount: hadithCount,
        chapterKey: englishTitle,
      ));
    }

    final totalHadiths = chapters.fold(0, (sum, ch) => sum + ch.hadithCount);

    return HadithBook(
      name: spec.name,
      arabicName: spec.arabicName,
      shortDesc: spec.author,
      numBooks: chapters.length.toString(),
      numHadiths: totalHadiths.toString(),
      allBooks: chapters,
      assetPath: spec.assetPath,
    );
  }

  Future<HadithChapter> loadFlatChapter(
    HadithBookSpec spec, {
    required String chapterKey,
  }) async {
    final db = await _getDb(spec.assetPath);
    final rows = await db.query(
      'hadith_library',
      where: 'english_title = ?',
      whereArgs: [chapterKey],
      orderBy: 'CAST(local_num AS INTEGER) ASC, local_num ASC',
    );

    final hadiths =
        rows.map((r) => _flatHadithFromRow(r, spec)).toList(growable: false);

    return HadithChapter(
      num: (hadiths.isNotEmpty ? hadiths.first.localNum : '0'),
      englishTitle: chapterKey,
      arabicTitle:
          rows.isNotEmpty ? (rows.first['arabic_title'] as String?) ?? '' : '',
      hadithList: hadiths,
      hadithCount: hadiths.length,
      chapterKey: chapterKey,
    );
  }

  // ── Helpers (Riyad schema) ──────────────────────────────────────────────

  Hadith _hadithFromRow(
      Map<String, Object?> row, String bookAsset, String chapterTitle) {
    final englishText = (row['text'] as String?) ?? '';
    final narrator = (row['narrator'] as String?) ?? '';
    final localNum = row.containsKey('idInBook') && row['idInBook'] != null
        ? (row['idInBook'] as int).toString()
        : (row['id'] as int? ?? 0).toString();

    return Hadith(
      title: '',
      narrator: narrator,
      englishText: englishText,
      arabicText: (row['arabic'] as String?) ?? '',
      localNum: localNum,
      grade: '',
      srno: 'riyad_${row['id']}',
      bookAsset: bookAsset,
      chapterTitle: chapterTitle,
    );
  }

  Future<void> closeAll() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
    _metaCache.clear();
  }

  // ─────────────────────────────────────────────────────────────────────
  // FLAT-TABLE HADITH LIBRARY (UPDATED FOR TEXT LOCAL_NUM)
  // ─────────────────────────────────────────────────────────────────────

  static const List<HadithBookSpec> flatBooks = [
    HadithBookSpec(
      assetPath: 'assets/hadith/sahih_al_bukhari.db',
      bookNum: 1,
      name: 'Sahih al-Bukhari',
      arabicName: 'صحيح البخاري',
      author: 'Imam Muhammad ibn Ismail al-Bukhari',
    ),
    HadithBookSpec(
      assetPath: 'assets/hadith/sahih_al_muslim.db',
      bookNum: 2,
      name: 'Sahih al-Muslim',
      arabicName: 'صحيح مسلم',
      author: 'Imam Muslim ibn al-Hajjaj an-Naysaburi',
    ),
    HadithBookSpec(
      assetPath: 'assets/hadith/jami_at_tirmidhi.db',
      bookNum: 3,
      name: 'Jami` at-Tirmidhi',
      arabicName: 'جامع الترمذي',
      author: 'Imam Abu `Isa Muhammad at-Tirmidhi',
    ),
    HadithBookSpec(
      assetPath: 'assets/hadith/sunan_abi_dawud.db',
      bookNum: 4,
      name: 'Sunan Abi Dawud',
      arabicName: 'سنن أبي داود',
      author: 'Imam Abu Dawud Sulayman ibn al-Ash`ath',
    ),
    HadithBookSpec(
      assetPath: 'assets/hadith/sunan_an_nasai.db',
      bookNum: 5,
      name: "Sunan an-Nasa'i",
      arabicName: 'سنن النسائي',
      author: "Imam Ahmad ibn Shu`ayb an-Nasa'i",
    ),
    HadithBookSpec(
      assetPath: 'assets/hadith/sunan_ibn_majah.db',
      bookNum: 6,
      name: 'Sunan Ibn Majah',
      arabicName: 'سنن ابن ماجه',
      author: 'Imam Muhammad ibn Yazid Ibn Majah al-Qazwini',
    ),
  ];

  static final Map<String, HadithBookSpec> _flatByAssetPath = {
    for (final spec in flatBooks) spec.assetPath: spec,
  };

  static HadithBookSpec? flatSpecFor(String assetPath) =>
      _flatByAssetPath[assetPath];

  /// Loads a full book from the flat `hadith_library` table.
  /// Modified to use natural alphanumeric sorting for the `local_num` TEXT type.
  Future<HadithBook> loadFlatBook(HadithBookSpec spec) async {
    final db = await _getDb(spec.assetPath);

    // KEY CHANGE: Since local_num is text, we must first cast it to an integer
    // to keep 2, 10, 119 sequential, and then sub-sort by raw string for alphanumeric suffixes ("119 a", "119 b")
    final hadithRows = await db.query(
      'hadith_library',
      orderBy: 'CAST(local_num AS INTEGER) ASC, local_num ASC',
    );

    final Map<String, List<Hadith>> grouped = {};
    final Map<String, String> arabicTitles = {};
    for (final row in hadithRows) {
      final hadith = _flatHadithFromRow(row, spec);
      final key = (row['english_title'] as String?) ?? '';
      grouped.putIfAbsent(key, () => <Hadith>[]).add(hadith);

      if (!arabicTitles.containsKey(key)) {
        arabicTitles[key] = (row['arabic_title'] as String?) ?? '';
      }
    }

    final chapters = <HadithChapter>[];
    int idx = 0;
    for (final entry in grouped.entries) {
      idx++;
      chapters.add(HadithChapter(
        num: idx.toString(),
        englishTitle: entry.key,
        arabicTitle: arabicTitles[entry.key] ?? '',
        hadithList: entry.value,
      ));
    }

    final totalHadiths =
        chapters.fold(0, (sum, ch) => sum + ch.hadithList.length);

    return HadithBook(
      name: spec.name,
      arabicName: spec.arabicName,
      shortDesc: spec.author,
      numBooks: chapters.length.toString(),
      numHadiths: totalHadiths.toString(),
      allBooks: chapters,
      assetPath: spec.assetPath,
    );
  }

  Future<Hadith?> getRandomShortHadithFlat({int maxNewlines = 12}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final spec = flatBooks[now % flatBooks.length];
    try {
      final db = await _getDb(spec.assetPath);
      final rows = await db.rawQuery(
        'SELECT * FROM hadith_library WHERE (LENGTH(arabic_text) - LENGTH(REPLACE(arabic_text, char(10), char(0)))) <= ? ORDER BY RANDOM() LIMIT 1',
        [maxNewlines],
      );
      if (rows.isEmpty) return null;
      return _flatHadithFromRow(rows.first, spec);
    } catch (_) {
      return null;
    }
  }

  /// Correctly extracts localNum as a safe String to protect alphanumeric tags.
  Hadith _flatHadithFromRow(Map<String, Object?> row, HadithBookSpec spec) {
    final title = (row['title'] as String?) ?? '';
    final narrator = (row['narrator'] as String?) ?? '';

    // KEY CHANGE: Keep local_num strictly as string mapping from DB
    final localNum = (row['local_num'] as String?) ?? '';

    final grade = (row['grade'] as String?) ?? '';
    final chapterEnglish = (row['english_title'] as String?) ?? spec.name;
    final bookFile = spec.assetPath.split('/').last;
    final bookNum = row['book_num']?.toString() ?? '';

    return Hadith(
      title: title,
      narrator: narrator,
      englishText: (row['english_text'] as String?) ?? '',
      arabicText: (row['arabic_text'] as String?) ?? '',
      localNum: localNum,
      grade: grade,
      srno: (row['sr_no'] as int?)?.toString() ?? '',
      bookAsset: spec.assetPath,
      chapterTitle: chapterEnglish,
    );
  }
}

class HadithBookSpec {
  final String assetPath;
  final int bookNum;
  final String name;
  final String arabicName;
  final String author;
  const HadithBookSpec({
    required this.assetPath,
    required this.bookNum,
    required this.name,
    required this.arabicName,
    required this.author,
  });
}

class _RiyadMeta {
  final int bookId;
  final String titleEn;
  final String titleAr;
  final String authorEn;
  final int chapterCount;
  final int hadithCount;
  _RiyadMeta({
    required this.bookId,
    required this.titleEn,
    required this.titleAr,
    required this.authorEn,
    required this.chapterCount,
    required this.hadithCount,
  });
}
