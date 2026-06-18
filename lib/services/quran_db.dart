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

  // ── Query result cache for frequently accessed data ─────────────────────
  // Caches query results to avoid repeated database hits for the same data.
  // Key format: 'assetPath|table|surahNumber|surahColumn'
  final Map<String, Map<String, dynamic>> _queryCache = {};

  // Cache statistics for performance monitoring (debug only)
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Get cache statistics (for debugging/performance monitoring)
  Map<String, dynamic> getCacheStats() {
    final total = _cacheHits + _cacheMisses;
    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': total > 0
          ? '${(_cacheHits / total * 100).toStringAsFixed(1)}%'
          : '0%',
      'cacheSize': _queryCache.length,
      'openDatabases': _dbs.length,
    };
  }

  /// Clear all query caches (useful for testing or memory pressure).
  /// This does NOT close database connections.
  void clearCache() {
    _queryCache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Open a database by its asset or file path.
  ///
  /// If [assetPath] is an existing file on disk (e.g. a downloaded SQLite
  /// translation), it opens it directly. Otherwise it treats it as a bundled
  /// asset path, copying it from assets on first use.
  Future<Database> _getDb(String assetPath) async {
    if (_dbs.containsKey(assetPath)) return _dbs[assetPath]!;

    if (kIsWeb) {
      throw UnsupportedError('sqflite is not supported on web');
    }

    final fileOnDisk = File(assetPath);
    if (await fileOnDisk.exists()) {
      // Already a physical file – open it directly (e.g. downloaded translation)
      final db = await openDatabase(assetPath, readOnly: true);
      _dbs[assetPath] = db;
      return db;
    }

    // Bundled asset – copy from assets to local storage on first use.
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
  ///
  /// Results are cached in memory for optimal performance when the same
  /// surah is requested multiple times (e.g., switching translations).
  Future<Map<String, dynamic>> getAyahsBySurah(
    String assetPath, {
    required String table,
    required String keyColumn,
    required int surahNumber,
    String surahColumn = 'surah',
  }) async {
    if (kIsWeb) return {};

    // Generate a unique cache key for this specific query
    final cacheKey = '$assetPath|$table|$surahNumber|$surahColumn';

    // Check cache first for instant retrieval
    if (_queryCache.containsKey(cacheKey)) {
      _cacheHits++;
      return _queryCache[cacheKey]!;
    }

    _cacheMisses++;

    final db = await _getDb(assetPath);
    final rows = await db.query(
      table,
      columns: [keyColumn, 'text'],
      where: '$surahColumn = ?',
      whereArgs: [surahNumber],
    );

    // Build the exact same map shape the isolate already expects:
    // { "1:1": {"text": "..."}, "1:2": {"text": "..."} }
    final result = {
      for (final row in rows)
        row[keyColumn] as String: {'text': row['text'] as String},
    };

    // Cache the result for future requests
    _queryCache[cacheKey] = result;

    return result;
  }

  /// Query a per-ayah database for a single ayah using its verse key.
  /// Results are cached for optimal performance.
  Future<String?> getSingleAyah(
    String assetPath, {
    required String table,
    required String keyColumn,
    required String verseKey,
  }) async {
    if (kIsWeb) return null;

    // Generate a unique cache key for this specific query
    final cacheKey = '$assetPath|$table|$verseKey';

    // Check cache first for instant retrieval
    if (_queryCache.containsKey(cacheKey)) {
      _cacheHits++;
      // Stored as a single-entry map, extract the text
      final cached = _queryCache[cacheKey]!;
      return cached.values.first['text'] as String?;
    }

    _cacheMisses++;

    final db = await _getDb(assetPath);
    final rows = await db.query(
      table,
      columns: ['text'],
      where: '$keyColumn = ?',
      whereArgs: [verseKey],
      limit: 1,
    );

    final result = rows.isNotEmpty ? rows.first['text'] as String? : null;

    // Cache the result for future requests (store as single-entry map for consistency)
    if (result != null) {
      _queryCache[cacheKey] = {
        verseKey: {'text': result}
      };
    }

    return result;
  }

  // ── Surah info query ────────────────────────────────────────────────────

  /// Query the surah_infos table for all surahs.
  /// Returns a map keyed by surah number string ("1", "2", ...).
  /// Results are cached since surah info rarely changes.
  Future<Map<String, dynamic>> getSurahInfos(String assetPath) async {
    if (kIsWeb) return {};

    // Use assetPath as cache key since this queries all surahs
    if (_queryCache.containsKey(assetPath)) {
      _cacheHits++;
      return _queryCache[assetPath]!;
    }

    _cacheMisses++;

    final db = await _getDb(assetPath);
    final rows = await db.query('surah_infos');

    final result = {
      for (final row in rows)
        (row['surah_number'] as int).toString(): {
          'surah_number': row['surah_number'],
          'surah_name': row['surah_name'],
          'text': row['text'],
          'short_text': row['short_text'],
        },
    };

    // Cache the result for future requests
    _queryCache[assetPath] = result;

    return result;
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  /// Close all open database connections and clear all caches.
  /// Call this on app termination or when you need to free all resources.
  Future<void> closeAll() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
    clearCache();
  }
}
