// lib/services/quran_db.dart
//
// Generic service for reading Quran data from SQLite databases.
// Handles per-ayah databases (scripts, translations, transliteration)
// and per-surah databases (surah info).
//
// All per-ayah DBs share the same core schema:
//   - scripts: table "verses" with columns verse_key, surah, ayah, text
//   - translations/transliteration: table "translation" with columns sura, ayah, ayah_key, text
//
// Returns data in the same Map<String, dynamic> format the isolate expects,
// so quran_service.dart needs zero changes to _parseAyahsIsolate.
//

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class QuranDb {
  QuranDb._();
  static final QuranDb instance = QuranDb._();

  // ── In-memory cache of open DB handles ──────────────────────────────────
  final Map<String, Database> _dbs = {};

  /// Open a database by its asset path, copying it from assets on first use.
  Future<Database> _getDb(String assetPath) async {
    if (_dbs.containsKey(assetPath)) return _dbs[assetPath]!;

    if (kIsWeb) {
      throw UnsupportedError('sqflite is not supported on web');
    }

    final fileName = assetPath.split('/').last;
    final dir = await getApplicationDocumentsDirectory();
    final localPath = '${dir.path}/$fileName';

    final file = File(localPath);
    if (!await file.exists()) {
      final bytes = await rootBundle.load(assetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }

    final db = await openDatabase(localPath, readOnly: true);
    _dbs[assetPath] = db;
    return db;
  }

  // ── Generic per-ayah query ──────────────────────────────────────────────

  /// Query a per-ayah database for all ayahs in a surah.
  ///
  /// [table] is "verses" for script DBs or "translation" for translation/TL DBs.
  /// [keyColumn] is "verse_key" for scripts or "ayah_key" for translations.
  /// [surahColumn] is "surah" for script DBs or "sura" for translation DBs.
  Future<Map<String, dynamic>> getAyahsBySurah(
    String assetPath, {
    required String table,
    required String keyColumn,
    required int surahNumber,
    String surahColumn = 'surah',
  }) async {
    if (kIsWeb) return {};

    final db = await _getDb(assetPath);
    final rows = await db.query(
      table,
      columns: [keyColumn, 'text'],
      where: '$surahColumn = ?',
      whereArgs: [surahNumber],
    );

    // Build the exact same map shape the isolate already expects:
    // { "1:1": {"text": "..."}, "1:2": {"text": "..."} }
    return {
      for (final row in rows)
        row[keyColumn] as String: {'text': row['text'] as String},
    };
  }

  /// Query a per-ayah database for a single ayah using its verse key.
  Future<String?> getSingleAyah(
    String assetPath, {
    required String table,
    required String keyColumn,
    required String verseKey,
  }) async {
    if (kIsWeb) return null;

    final db = await _getDb(assetPath);
    final rows = await db.query(
      table,
      columns: ['text'],
      where: '$keyColumn = ?',
      whereArgs: [verseKey],
      limit: 1,
    );

    return rows.isNotEmpty ? rows.first['text'] as String : null;
  }

  // ── Surah info query ────────────────────────────────────────────────────

  /// Query the surah_infos table for all surahs.
  /// Returns a map keyed by surah number string ("1", "2", ...).
  Future<Map<String, dynamic>> getSurahInfos(String assetPath) async {
    if (kIsWeb) return {};

    final db = await _getDb(assetPath);
    final rows = await db.query('surah_infos');

    return {
      for (final row in rows)
        (row['surah_number'] as int).toString(): {
          'surah_number': row['surah_number'],
          'surah_name': row['surah_name'],
          'text': row['text'],
          'short_text': row['short_text'],
        },
    };
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  Future<void> closeAll() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
  }
}
