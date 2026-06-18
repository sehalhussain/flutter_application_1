// lib/services/quran_service.dart
//
// ALL JSON files share the same flat map structure:
//   { "1:1": { ...fields }, "1:2": { ... } }
//
// We cache each file after first load and never re-parse it.
//

import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/quran_models.dart';
import '../constants/juz_data.dart';
import '../constants/reciter_data.dart';
import 'translation_download_service.dart';
import 'quran_db.dart';

class QuranService {
  QuranService._();
  static final QuranService instance = QuranService._();

  // ── Asset paths ───────────────────────────────────────────────────────────
  static const _base = 'assets/data/quran';

  // ── SQLite asset paths ────────────────────────────────────────────────────
  static const _dbQpcHafs = '$_base/Scripts/qpc-hafs.db';
  static const _dbIndoPak =
      '$_base/Scripts/digital-khatt-indopak-ayah-by-ayah-script.db';
  static const _dbLiteration = '$_base/Transliteration/en-literation.db';
  static const _dbSurahInfo = '$_base/SurahInfo/surah-info-en.db';

  // ── JSON asset paths (kept as-is per user request) ────────────────────────
  static const _pathAyahAudioDefault =
      '$_base/ayah-recitation-mishari-rashid-al-afasy.json';
  static const _pathSurahMetadata = '$_base/surah-metadata.json';

  static String _translationDbPath(TranslationId id) {
    switch (id) {
      case TranslationId.enSahih:
        return '$_base/Translations/en-sahih-international-simple.db';
      case TranslationId.enMuhsin:
        return '$_base/Translations/en-muhsinkhan.db';
      case TranslationId.urMaududi:
        return '$_base/Translations/ur-roman.db';
      case TranslationId.urWahiuddin:
        return '$_base/Translations/ur-wahiduddinkhan.db';
      case TranslationId.hiUmari:
        return '$_base/Translations/hi-al-umari.db';
      case TranslationId.urJalandhari:
        return '$_base/Translations/ur-jalandhari.db';
      // No SQLite file yet — falls back to JSON
    }
  }

  // ── In-memory caches ──────────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _cacheAyahAudios = {};
  List<SurahInfo>? _cacheSurahInfo;

  // ── Generic loader ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _load(String path) async {
    final String s = await rootBundle.loadString(path);
    return compute(_decodeJson, s);
  }

  static Map<String, dynamic> _decodeJson(String s) {
    return json.decode(s) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _getAyahAudio(String reciterId) async {
    if (_cacheAyahAudios.containsKey(reciterId)) {
      return _cacheAyahAudios[reciterId]!;
    }

    final reciter = kAyahReciters.firstWhere((r) => r.id == reciterId,
        orElse: () => kAyahReciters.first);
    final path = '$_base/${reciter.fileName}';
    final data = await _load(path);
    _cacheAyahAudios[reciterId] = data;
    return data;
  }

  Future<Map<String, dynamic>> _getSurahInfoDetail() async =>
      QuranDb.instance.getSurahInfos(_dbSurahInfo);

  Future<SurahDetail> getSurahDetail(int surahNumber) async {
    final data = await _getSurahInfoDetail();
    final surahData = data[surahNumber.toString()];
    if (surahData == null) {
      throw Exception('Surah info not found for surah $surahNumber');
    }
    return SurahDetail.fromJson(surahData as Map<String, dynamic>);
  }

  // ── Surah list ────────────────────────────────────────────────────────────
  Future<List<SurahInfo>> loadSurahList() async {
    if (_cacheSurahInfo != null) return _cacheSurahInfo!;
    final ByteData data = await rootBundle.load(_pathSurahMetadata);

    final String s = utf8.decode(data.buffer.asUint8List());
    final dynamic decoded = await compute(_decodeJson, s);

    final List<SurahInfo> surahs = [];
    if (decoded is Map) {
      // JSON is a Map of surah numbers "1", "2", ...
      decoded.forEach((key, value) {
        final data = value as Map<String, dynamic>;
        final surahNum = data['id'] as int;

        // Find juz number from kJuzData
        int juzNum = 1;
        for (var j in kJuzData) {
          if (j.startSurah <= surahNum) {
            juzNum = j.juzNumber;
          } else {
            break;
          }
        }

        surahs.add(SurahInfo(
          number: surahNum,
          nameArabic: data['name_arabic'] as String? ?? '',
          nameEnglish: data['name_simple'] as String? ?? '',
          nameMeaning: '', // Not in metadata
          revelationType: data['revelation_place'] as String? ?? '',
          totalAyahs: data['verses_count'] as int? ?? 0,
          juzNumber: juzNum,
        ));
      });

      // Sort by surah number just in case
      surahs.sort((a, b) => a.number.compareTo(b.number));
    }

    _cacheSurahInfo = surahs;
    return _cacheSurahInfo!;
  }

  SurahInfo? surahInfoSync(int number) {
    return _cacheSurahInfo?.firstWhere(
      (s) => s.number == number,
      orElse: () => throw StateError('Surah not found'),
    );
  }

  // ── Load ayahs for a surah ────────────────────────────────────────────────
  /// Returns a list of [AyahData] for [surahNumber] using [translation].
  /// Script + transliteration + translation come from SQLite; audio stays JSON.
  Future<List<AyahData>> loadAyahs(
    int surahNumber,
    TranslationId translation, {
    String? ayahReciterId,
    String? customTranslationId,
  }) async {
    // ── Fire all data loads in parallel ──────────────────────────────────
    final qpcFuture = QuranDb.instance.getAyahsBySurah(
      _dbQpcHafs,
      table: 'verses',
      keyColumn: 'verse_key',
      surahNumber: surahNumber,
    );

    final ipFuture = QuranDb.instance.getAyahsBySurah(
      _dbIndoPak,
      table: 'verses',
      keyColumn: 'verse_key',
      surahNumber: surahNumber,
    );

    final litFuture = QuranDb.instance.getAyahsBySurah(
      _dbLiteration,
      table: 'translation',
      keyColumn: 'ayah_key',
      surahNumber: surahNumber,
      surahColumn: 'sura',
    );

    final audioFuture = _getAyahAudio(ayahReciterId ?? 'mishary');

    // Translation: custom = JSON or SQLite download; built-in = SQLite
    Future<Map<String, dynamic>> transFuture;
    if (customTranslationId != null) {
      final filePath = await TranslationDownloadService.instance
          .getDownloadedFilePath(customTranslationId);
      if (filePath == null) {
        throw Exception(
            'Translation "$customTranslationId" not downloaded. Requires one-time internet connection.');
      }
      if (filePath.endsWith('.db')) {
        // Custom translation is SQLite
        transFuture = QuranDb.instance.getAyahsBySurah(
          filePath,
          table: 'translation',
          keyColumn: 'ayah_key',
          surahNumber: surahNumber,
          surahColumn: 'sura',
        );
      } else {
        // Custom translation is JSON
        transFuture = TranslationDownloadService.instance
            .loadTranslationJson(customTranslationId)
            .then((json) => json ?? {});
      }
    } else {
      final dbPath = _translationDbPath(translation);
      if (dbPath.isNotEmpty) {
        transFuture = QuranDb.instance.getAyahsBySurah(
          dbPath,
          table: 'translation',
          keyColumn: 'ayah_key',
          surahNumber: surahNumber,
          surahColumn: 'sura',
        );
      } else {
        // JSON fallback (ur-jalandhari)
        transFuture = _loadTranslationJson(translation, surahNumber);
      }
    }

    final results = await Future.wait([
      qpcFuture,
      ipFuture,
      litFuture,
      audioFuture,
      transFuture,
    ]);

    return compute(_parseAyahsIsolate, {
      'surahNumber': surahNumber,
      'qpcMap': results[0],
      'ipMap': results[1],
      'litMap': results[2],
      'audioMap': results[3],
      'transMap': results[4],
    });
  }

  /// Load a JSON translation file and filter to a single surah.
  Future<Map<String, dynamic>> _loadTranslationJson(
      TranslationId id, int surahNumber) async {
    final all = await _load('$_base/${id.fileName}');
    final prefix = '$surahNumber:';
    return {
      for (final e in all.entries)
        if (e.key.startsWith(prefix)) e.key: e.value,
    };
  }

  static List<AyahData> _parseAyahsIsolate(Map<String, dynamic> params) {
    final int surahNumber = params['surahNumber'];
    final Map<String, dynamic> qpcMap = params['qpcMap'];
    final Map<String, dynamic> ipMap = params['ipMap'];
    final Map<String, dynamic> litMap = params['litMap'];
    final Map<String, dynamic> audioMap = params['audioMap'];
    final Map<String, dynamic> transMap = params['transMap'];

    final ayahCount =
        qpcMap.keys.where((k) => k.startsWith('$surahNumber:')).length;
    if (ayahCount == 0) return [];

    final List<AyahData> ayahs = [];
    for (int i = 1; i <= ayahCount; i++) {
      final key = '$surahNumber:$i';
      ayahs.add(AyahData(
        surahNumber: surahNumber,
        ayahNumber: i,
        verseKey: key,
        uthmani: (qpcMap[key]?['text'] as String?) ?? '',
        indoPak: (ipMap[key]?['text'] as String?) ?? '',
        transliteration: (litMap[key]?['text'] as String?) ?? '',
        translation: (transMap[key]?['text'] as String?) ??
            (transMap[key]?['t'] as String?) ??
            '',
        audioUrl: (audioMap[key]?['audio_url'] as String?),
      ));
    }
    return ayahs;
  }

  Future<AyahData?> loadAyah(
    int surahNumber,
    int ayahNumber,
    TranslationId translation, {
    String? ayahReciterId,
  }) async {
    final db = QuranDb.instance;

    final verseKey = '$surahNumber:$ayahNumber';

    final uthmaniF = db.getSingleAyah(_dbQpcHafs,
        table: 'verses', keyColumn: 'verse_key', verseKey: verseKey);
    final indoPakF = db.getSingleAyah(_dbIndoPak,
        table: 'verses', keyColumn: 'verse_key', verseKey: verseKey);
    final litF = db.getSingleAyah(_dbLiteration,
        table: 'translation', keyColumn: 'ayah_key', verseKey: verseKey);
    final audioF = _getAyahAudio(ayahReciterId ?? 'mishary');

    final uthmani = await uthmaniF ?? '';
    final indoPak = await indoPakF ?? '';
    final literation = await litF ?? '';
    final audioMap = await audioF;

    // Translation
    String trans = '';
    final dbPath = _translationDbPath(translation);
    if (dbPath.isNotEmpty) {
      trans = await db.getSingleAyah(dbPath,
              table: 'translation',
              keyColumn: 'ayah_key',
              verseKey: verseKey) ??
          '';
    } else {
      final transMap = await _load(translation.fileName);
      trans = (transMap[verseKey]?['t'] as String?) ?? '';
    }

    final audioUrl = (audioMap[verseKey]?['audio_url'] as String?);
    return AyahData(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      verseKey: verseKey,
      uthmani: uthmani,
      indoPak: indoPak,
      transliteration: literation,
      translation: trans,
      audioUrl: audioUrl,
    );
  }

  /// Reload translation only (re-uses cached arabic/audio data).
  /// Supports both built-in (SQLite) and downloadable (JSON) translations.
  Future<List<AyahData>> reloadTranslation(
    List<AyahData> existing,
    TranslationId newTranslation, {
    String? customTranslationId,
  }) async {
    if (existing.isEmpty) return existing;

    // Determine the surah number from the first ayah
    final surahNumber = existing.first.surahNumber;

    if (customTranslationId != null) {
      final filePath = await TranslationDownloadService.instance
          .getDownloadedFilePath(customTranslationId);
      if (filePath == null) {
        throw Exception(
            'Translation "$customTranslationId" not downloaded. Requires one-time internet connection.');
      }

      if (filePath.endsWith('.db')) {
        // Custom translation is SQLite
        final transMap = await QuranDb.instance.getAyahsBySurah(
          filePath,
          table: 'translation',
          keyColumn: 'ayah_key',
          surahNumber: surahNumber,
          surahColumn: 'sura',
        );
        return existing.map((a) {
          final trans = (transMap[a.verseKey]?['text'] as String?) ?? '';
          return AyahData(
            surahNumber: a.surahNumber,
            ayahNumber: a.ayahNumber,
            verseKey: a.verseKey,
            uthmani: a.uthmani,
            indoPak: a.indoPak,
            transliteration: a.transliteration,
            translation: trans,
            audioUrl: a.audioUrl,
          );
        }).toList();
      } else {
        // Custom translation is JSON
        final json = await TranslationDownloadService.instance
            .loadTranslationJson(customTranslationId);
        if (json == null) {
          throw Exception(
              'Translation "$customTranslationId" could not be loaded.');
        }
        return existing.map((a) {
          final trans = (json[a.verseKey]?['t'] as String?) ?? '';
          return AyahData(
            surahNumber: a.surahNumber,
            ayahNumber: a.ayahNumber,
            verseKey: a.verseKey,
            uthmani: a.uthmani,
            indoPak: a.indoPak,
            transliteration: a.transliteration,
            translation: trans,
            audioUrl: a.audioUrl,
          );
        }).toList();
      }
    }

    // Built-in translation — SQLite
    final dbPath = _translationDbPath(newTranslation);
    if (dbPath.isNotEmpty) {
      final transMap = await QuranDb.instance.getAyahsBySurah(
        dbPath,
        table: 'translation',
        keyColumn: 'ayah_key',
        surahNumber: surahNumber,
        surahColumn: 'sura',
      );
      return existing.map((a) {
        final trans = (transMap[a.verseKey]?['text'] as String?) ?? '';
        return AyahData(
          surahNumber: a.surahNumber,
          ayahNumber: a.ayahNumber,
          verseKey: a.verseKey,
          uthmani: a.uthmani,
          indoPak: a.indoPak,
          transliteration: a.transliteration,
          translation: trans,
          audioUrl: a.audioUrl,
        );
      }).toList();
    }

    // JSON fallback (ur-jalandhari)
    final all = await _load('$_base/${newTranslation.fileName}');
    return existing.map((a) {
      final trans = (all[a.verseKey]?['t'] as String?) ?? '';
      return AyahData(
        surahNumber: a.surahNumber,
        ayahNumber: a.ayahNumber,
        verseKey: a.verseKey,
        uthmani: a.uthmani,
        indoPak: a.indoPak,
        transliteration: a.transliteration,
        translation: trans,
        audioUrl: a.audioUrl,
      );
    }).toList();
  }

  /// Fetches a random ayah natively and offline without APIs.
  Future<AyahData> getRandomAyah() async {
    final surahs = await loadSurahList();
    final random = Random();
    final surah = surahs[random.nextInt(surahs.length)];

    // Handle edge case if surah has no ayahs
    if (surah.totalAyahs == 0) return getRandomAyah();

    final ayahNum = random.nextInt(surah.totalAyahs) + 1;
    final verseKey = '${surah.number}:$ayahNum';

    // Load ONLY the specific dictionaries needed for the display to save massive memory parsing
    final db = QuranDb.instance;
    final uthmani = await db.getSingleAyah(
      _dbQpcHafs,
      table: 'verses',
      keyColumn: 'verse_key',
      verseKey: verseKey,
    );
    final trans = await db.getSingleAyah(
      _translationDbPath(TranslationId.enSahih),
      table: 'translation',
      keyColumn: 'ayah_key',
      verseKey: verseKey,
    );

    return AyahData(
      surahNumber: surah.number,
      ayahNumber: ayahNum,
      verseKey: verseKey,
      uthmani: uthmani ?? '',
      indoPak: '',
      transliteration: '',
      translation: trans ?? '',
      audioUrl: null,
    );
  }

  void clearCache() {
    _cacheAyahAudios.clear();
    _cacheSurahInfo = null;
  }

  // ── Juz metadata (removed — now a compile-time constant in juz_metadata_data.dart) ──
  // ── Surah Audio API ───────────────────────────────────────────────────────
  final Map<int, SurahAudio> _cacheSurahAudio = {};

  Future<SurahAudio> getSurahAudio(int surahNumber) async {
    if (_cacheSurahAudio.containsKey(surahNumber)) {
      return _cacheSurahAudio[surahNumber]!;
    }

    final url = 'https://quranapi.pages.dev/api/audio/$surahNumber.json';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final surahAudio = SurahAudio.fromJson(surahNumber, data);
      _cacheSurahAudio[surahNumber] = surahAudio;
      return surahAudio;
    } else {
      throw Exception('Failed to load surah audio metadata');
    }
  }

  /// Returns the direct audio URL for a surah based on reciter.
  /// For the Yasser Urdu reciter, constructs URL from the archive pattern.
  /// Otherwise fetches from the API.
  Future<String?> getSurahAudioUrl(int surahNumber, String reciterId) async {
    if (reciterId == 'yasser_urdu') {
      return getYasserUrduSurahUrl(surahNumber);
    }
    try {
      final audio = await getSurahAudio(surahNumber);
      return audio.reciters[reciterId]?.url;
    } catch (_) {
      return null;
    }
  }

  // ── Downloading ───────────────────────────────────────────────────────────
  Future<String?> getDownloadedSurahPath(
      int surahNumber, String reciterId) async {
    if (kIsWeb) return null;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/audio/surah_${surahNumber}_$reciterId.mp3');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<List<File>> getDownloadedAudioFiles() async {
    if (kIsWeb) return [];
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) return [];
    return audioDir.listSync().whereType<File>().toList();
  }

  Future<void> deleteAudioFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> downloadSurah(
    int surahNumber,
    String reciterId,
    String url, {
    Function(double)? onProgress,
  }) async {
    if (kIsWeb) {
      throw Exception('Downloading is not supported on Web');
    }

    // Check/request permissions on Android
    if (!kIsWeb && Platform.isAndroid) {
      await Permission.storage.request();
    }

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final savePath = '${audioDir.path}/surah_${surahNumber}_$reciterId.mp3';

    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (count, total) {
        if (total != -1) {
          onProgress?.call(count / total);
        }
      },
    );
  }

  // ── Tafsir API ────────────────────────────────────────────────────────────
  Future<TafsirResponse> getTafsir(int surahNumber, int ayahNumber) async {
    // Check offline cache first
    final offlineTafsir = await getOfflineTafsir(surahNumber, ayahNumber);
    if (offlineTafsir != null) {
      return offlineTafsir;
    }

    final url =
        'https://quranapi.pages.dev/api/tafsir/${surahNumber}_$ayahNumber.json';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return TafsirResponse.fromJson(data);
    } else {
      throw Exception('Failed to load tafsir');
    }
  }

  Future<void> saveTafsirOffline(
      int surahNumber, int ayahNumber, TafsirResponse response) async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    final tafsirDir = Directory('${dir.path}/tafsirs');
    if (!await tafsirDir.exists()) await tafsirDir.create();

    final file =
        File('${tafsirDir.path}/tafsir_${surahNumber}_$ayahNumber.json');
    final jsonStr = json.encode(response.toJson());
    await file.writeAsString(jsonStr);
  }

  Future<TafsirResponse?> getOfflineTafsir(
      int surahNumber, int ayahNumber) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file =
        File('${dir.path}/tafsirs/tafsir_${surahNumber}_$ayahNumber.json');
    if (await file.exists()) {
      final jsonStr = await file.readAsString();
      return TafsirResponse.fromJson(json.decode(jsonStr));
    }
    return null;
  }

  Future<List<File>> getDownloadedTafsirs() async {
    if (kIsWeb) return [];
    final dir = await getApplicationDocumentsDirectory();
    final tafsirDir = Directory('${dir.path}/tafsirs');
    if (!await tafsirDir.exists()) return [];
    return tafsirDir.listSync().whereType<File>().toList();
  }

  Future<void> deleteTafsirFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
