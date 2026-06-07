// lib/services/hadith_db.dart
//
// SQLite-backed loader for the hadith library.
//
// ALL books now use the same flat `hadith_library` table schema:
//   columns: uuid, book_num, english_title, arabic_title, local_num (TEXT),
//            title, narrator, english_text, arabic_text, grade, sr_no
//
// There are 7 flat DB files covering Bukhari, Muslim, Tirmidhi, Abu Dawud,
// Nasai, Ibn Majah, and Riyad as-Salihin.

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

  /// All 7 flat hadith books.
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
    HadithBookSpec(
      assetPath: 'assets/hadith/riyad_as_salihin.db',
      bookNum: 7,
      name: 'Riyad as Salihin',
      arabicName: 'رياض الصالحين',
      author: 'Imam Yahya ibn Sharaf al-Nawawi',
    ),
  ];

  static final Map<String, HadithBookSpec> _flatByAssetPath = {
    for (final spec in flatBooks) spec.assetPath: spec,
  };

  static HadithBookSpec? flatSpecFor(String assetPath) =>
      _flatByAssetPath[assetPath];

  // ── Book overview (chapter list without full hadith data) ────────────

  Future<HadithBook> loadBookOverview(String assetPath) async {
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

  Future<HadithBook> loadFlatBookOverview(HadithBookSpec spec) async {
    final db = await _getDb(spec.assetPath);

    final rows = await db.rawQuery('''
      SELECT english_title,
             arabic_title,
             COUNT(*) AS hadith_count
      FROM hadith_library
      GROUP BY english_title
      ORDER BY MIN(CAST(book_num AS INTEGER)) ASC
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

  // ── Full book load (all chapters + all hadiths) ─────────────────────

  /// Loads a full book from the flat `hadith_library` table.
  /// Chapters are sorted by `book_num` (chronological order in the book).
  Future<HadithBook> loadFlatBook(HadithBookSpec spec) async {
    final db = await _getDb(spec.assetPath);

    // Order by book_num first (chronological chapter order), then local_num within each chapter
    final hadithRows = await db.query(
      'hadith_library',
      orderBy:
          'CAST(book_num AS INTEGER) ASC, CAST(local_num AS INTEGER) ASC, local_num ASC',
    );

    final Map<String, List<Hadith>> grouped = {};
    final Map<String, String> arabicTitles = {};
    final Map<String, int> chapterBookNums = {};
    for (final row in hadithRows) {
      final hadith = _flatHadithFromRow(row, spec);
      final key = (row['english_title'] as String?) ?? '';
      grouped.putIfAbsent(key, () => <Hadith>[]).add(hadith);

      if (!arabicTitles.containsKey(key)) {
        arabicTitles[key] = (row['arabic_title'] as String?) ?? '';
      }

      // Track book_num for each chapter to sort by chronological order
      final bookNum = (row['book_num'] as int?) ?? 0;
      if (!chapterBookNums.containsKey(key)) {
        chapterBookNums[key] = bookNum;
      }
    }

    // Sort chapters by book_num (chronological order as they appear in the book)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) =>
          (chapterBookNums[a] ?? 0).compareTo(chapterBookNums[b] ?? 0));

    final chapters = <HadithChapter>[];
    int idx = 0;
    for (final key in sortedKeys) {
      idx++;
      chapters.add(HadithChapter(
        num: idx.toString(),
        englishTitle: key,
        arabicTitle: arabicTitles[key] ?? '',
        hadithList: grouped[key]!,
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

  // ── Single chapter load ────────────────────────────────────────────

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

  // ── Random short hadith for "Hadith of the Day" ────────────────────

  Future<Hadith?> getRandomShortHadithFlat(
      {String? assetPath, int maxNewlines = 12}) async {
    // Default to Riyad as-Salihin if no assetPath specified
    final targetPath = assetPath ?? 'assets/hadith/riyad_as_salihin.db';
    final spec = flatSpecFor(targetPath);
    if (spec == null) return null;

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

  // ── Row mapping helper ─────────────────────────────────────────────

  /// Safely extracts values from a flat `hadith_library` row regardless of
  /// the actual SQLite column type (TEXT / INTEGER).
  Hadith _flatHadithFromRow(Map<String, Object?> row, HadithBookSpec spec) {
    final title = (row['title'] as String?) ?? '';
    final narrator = (row['narrator'] as String?) ?? '';
    final localNum = (row['local_num'] as String?) ?? '';
    final grade = (row['grade'] as String?) ?? '';
    final chapterEnglish = (row['english_title'] as String?) ?? spec.name;

    final rawSrNo = row['sr_no'];
    final srno = rawSrNo is String
        ? rawSrNo
        : rawSrNo is int
            ? rawSrNo.toString()
            : '';

    return Hadith(
      title: title,
      narrator: narrator,
      englishText: (row['english_text'] as String?) ?? '',
      arabicText: (row['arabic_text'] as String?) ?? '',
      localNum: localNum,
      grade: grade,
      srno: srno,
      bookAsset: spec.assetPath,
      chapterTitle: chapterEnglish,
    );
  }

  Future<void> closeAll() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
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
