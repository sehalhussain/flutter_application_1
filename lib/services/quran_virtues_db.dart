// lib/services/quran_virtues_db.dart
//
// SQLite-backed loader for the Quran Virtues (Fadail al-Quran) database.
// Uses the same flat schema as hadith_library:
//   columns: sr_no, book_num, english_title, arabic_title, local_num,
//            title, english_text, arabic_text, grade

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/quran_virtue_models.dart';

class QuranVirtuesDb {
  QuranVirtuesDb._();
  static final QuranVirtuesDb instance = QuranVirtuesDb._();

  static const String assetPath = 'assets/hadith/quran_virtues.db';
  static const String tableName = 'hadith_library';

  // ── Cached handles ──────────────────────────────────────────────────────
  final Map<String, Database> _dbs = {};

  Future<Database> _getDb() async {
    if (_dbs.containsKey(assetPath)) return _dbs[assetPath]!;

    if (kIsWeb) {
      throw UnsupportedError(
          'sqflite is not supported on web; requires mobile');
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

  // ── Load all virtues ────────────────────────────────────────────────────

  /// Loads all chapters (grouped by english_title) and their virtues.
  /// Chapters are sorted by book_num (chronological order in the book).
  Future<List<QuranVirtueChapter>> loadAllChapters() async {
    final db = await _getDb();

    final rows = await db.query(
      tableName,
      orderBy:
          'CAST(book_num AS INTEGER) ASC, CAST(sr_no AS INTEGER) ASC, sr_no ASC',
    );

    // Move the grouping/sorting/parsing work to a background isolate so the
    // UI thread stays free for fast first-frame rendering.
    return compute(_groupChapters, rows);
  }

  /// Loads a single chapter by its english_title
  Future<QuranVirtueChapter?> loadChapter(String englishTitle) async {
    final db = await _getDb();

    final rows = await db.query(
      tableName,
      where: 'english_title = ?',
      whereArgs: [englishTitle],
      orderBy: 'CAST(sr_no AS INTEGER) ASC, sr_no ASC',
    );

    if (rows.isEmpty) return null;

    final virtues = rows.map((r) => QuranVirtue.fromRow(r)).toList();
    return QuranVirtueChapter(
      englishTitle: englishTitle,
      arabicTitle: virtues.first.arabicTitle,
      bookNum: virtues.first.bookNum,
      virtues: virtues,
      virtueCount: virtues.length,
    );
  }

  // ── Random virtue for "Virtue of the Day" ───────────────────────────────

  Future<QuranVirtue?> getRandomVirtue() async {
    try {
      final db = await _getDb();
      final rows = await db.rawQuery(
        'SELECT * FROM $tableName ORDER BY RANDOM() LIMIT 1',
      );
      if (rows.isEmpty) return null;
      return QuranVirtue.fromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<void> closeAll() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
  }
}

// ── Isolate entry point (runs off the UI thread) ──────────────────────────

List<QuranVirtueChapter> _groupChapters(List<Map<String, Object?>> rows) {
  final Map<String, List<QuranVirtue>> grouped = {};
  final Map<String, String> arabicTitles = {};
  final Map<String, String> bookNums = {};

  for (final row in rows) {
    final virtue = QuranVirtue.fromRow(row);
    final key = virtue.englishTitle;
    grouped.putIfAbsent(key, () => []).add(virtue);

    if (!arabicTitles.containsKey(key)) {
      arabicTitles[key] = virtue.arabicTitle;
    }
    if (!bookNums.containsKey(key)) {
      bookNums[key] = virtue.bookNum;
    }
  }

  // Sort chapters by book_num
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) {
      final aNum = int.tryParse(bookNums[a] ?? '0') ?? 0;
      final bNum = int.tryParse(bookNums[b] ?? '0') ?? 0;
      return aNum.compareTo(bNum);
    });

  final chapters = <QuranVirtueChapter>[];
  for (final key in sortedKeys) {
    final virtues = grouped[key]!;
    chapters.add(QuranVirtueChapter(
      englishTitle: key,
      arabicTitle: arabicTitles[key] ?? '',
      bookNum: bookNums[key] ?? '',
      virtues: virtues,
      virtueCount: virtues.length,
    ));
  }

  return chapters;
}
