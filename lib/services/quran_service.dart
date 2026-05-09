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

class QuranService {
  QuranService._();
  static final QuranService instance = QuranService._();

  // ── Asset paths ───────────────────────────────────────────────────────────
  static const _base = 'assets/data/quran';

  static const _pathQpcHafs = '$_base/qpc-hafs.json';
  static const _pathIndoPak = '$_base/indopak-nastaleeq.json';
  static const _pathLiteration = '$_base/en.literation.json';
  static const _pathAyahAudio =
      '$_base/ayah-recitation-mishari-rashid-al-afasy.json';
  static const _pathSurahInfo = '$_base/surah-info.json';
  static const _pathSurahMetadata = '$_base/surah-metadata.json';

  static String _translationPath(TranslationId id) => '$_base/${id.fileName}';

  // ── In-memory caches ──────────────────────────────────────────────────────
  Map<String, dynamic>? _cacheQpcHafs;
  Map<String, dynamic>? _cacheIndoPak;
  Map<String, dynamic>? _cacheLiteration;
  Map<String, dynamic>? _cacheAyahAudio;
  List<SurahInfo>? _cacheSurahInfo;
  Map<String, dynamic>? _cacheSurahInfoDetail;
  final Map<String, Map<String, dynamic>> _cacheTranslations = {};

  // ── Generic loader ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _load(String path) async {
    final String s = await rootBundle.loadString(path);
    // Offload heavy JSON decoding to a background isolate to keep UI snappy
    return compute(_decodeJson, s);
  }

  static Map<String, dynamic> _decodeJson(String s) {
    return json.decode(s) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _getQpcHafs() async =>
      _cacheQpcHafs ??= await _load(_pathQpcHafs);

  Future<Map<String, dynamic>> _getIndoPak() async =>
      _cacheIndoPak ??= await _load(_pathIndoPak);

  Future<Map<String, dynamic>> _getLiteration() async =>
      _cacheLiteration ??= await _load(_pathLiteration);

  Future<Map<String, dynamic>> _getAyahAudio() async =>
      _cacheAyahAudio ??= await _load(_pathAyahAudio);

  Future<Map<String, dynamic>> _getTranslation(TranslationId id) async {
    final key = id.fileName;
    if (!_cacheTranslations.containsKey(key)) {
      _cacheTranslations[key] = await _load(_translationPath(id));
    }
    return _cacheTranslations[key]!;
  }

  Future<Map<String, dynamic>> _getSurahInfoDetail() async =>
      _cacheSurahInfoDetail ??= await _load(_pathSurahInfo);

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
  /// Runs all 5 JSON lookups in parallel for speed.
  Future<List<AyahData>> loadAyahs(
    int surahNumber,
    TranslationId translation,
  ) async {
    // Fire all loads in parallel
    final results = await Future.wait([
      _getQpcHafs(),
      _getIndoPak(),
      _getLiteration(),
      _getAyahAudio(),
      _getTranslation(translation),
    ]);

    // Offload the mapping loop to a background isolate. 
    // This is especially beneficial for large surahs like Al-Baqarah.
    return compute(_parseAyahsIsolate, {
      'surahNumber': surahNumber,
      'qpcMap': results[0],
      'ipMap': results[1],
      'litMap': results[2],
      'audioMap': results[3],
      'transMap': results[4],
    });
  }

  static List<AyahData> _parseAyahsIsolate(Map<String, dynamic> params) {
    final int surahNumber = params['surahNumber'];
    final Map<String, dynamic> qpcMap = params['qpcMap'];
    final Map<String, dynamic> ipMap = params['ipMap'];
    final Map<String, dynamic> litMap = params['litMap'];
    final Map<String, dynamic> audioMap = params['audioMap'];
    final Map<String, dynamic> transMap = params['transMap'];

    // Determine ayah count from QPC-Hafs keys
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
        transliteration: (litMap[key]?['t'] as String?) ?? '',
        translation: (transMap[key]?['t'] as String?) ?? '',
        audioUrl: (audioMap[key]?['audio_url'] as String?),
      ));
    }
    return ayahs;
  }

  Future<AyahData?> loadAyah(
    int surahNumber,
    int ayahNumber,
    TranslationId translation,
  ) async {
    final results = await Future.wait([
      _getQpcHafs(),
      _getIndoPak(),
      _getLiteration(),
      _getAyahAudio(),
      _getTranslation(translation),
    ]);

    final qpcMap = results[0];
    final ipMap = results[1];
    final litMap = results[2];
    final audioMap = results[3];
    final transMap = results[4];

    final key = '$surahNumber:$ayahNumber';
    if (!qpcMap.containsKey(key)) return null;

    final uthmani = (qpcMap[key]?['text'] as String?) ?? '';
    final indoPak = (ipMap[key]?['text'] as String?) ?? '';
    final literation = (litMap[key]?['t'] as String?) ?? '';
    final trans = (transMap[key]?['t'] as String?) ?? '';
    final audioUrl = (audioMap[key]?['audio_url'] as String?);

    return AyahData(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      verseKey: key,
      uthmani: uthmani,
      indoPak: indoPak,
      transliteration: literation,
      translation: trans,
      audioUrl: audioUrl,
    );
  }

  /// Reload translation only (re-uses cached arabic/audio data).
  Future<List<AyahData>> reloadTranslation(
    List<AyahData> existing,
    TranslationId newTranslation,
  ) async {
    if (existing.isEmpty) return existing;
    final transMap = await _getTranslation(newTranslation);

    return existing.map((a) {
      final trans = (transMap[a.verseKey]?['t'] as String?) ?? '';
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
    final qpcMap = await _getQpcHafs();
    final transMap = await _getTranslation(TranslationId.enSahih);

    final uthmani = (qpcMap[verseKey]?['text'] as String?) ?? '';
    final trans = (transMap[verseKey]?['t'] as String?) ?? '';

    return AyahData(
      surahNumber: surah.number,
      ayahNumber: ayahNum,
      verseKey: verseKey,
      uthmani: uthmani,
      indoPak: '',
      transliteration: '',
      translation: trans,
      audioUrl: null,
    );
  }

  void clearCache() {
    _cacheQpcHafs = null;
    _cacheIndoPak = null;
    _cacheLiteration = null;
    _cacheAyahAudio = null;
    _cacheSurahInfo = null;
    _cacheSurahInfoDetail = null;
    _cacheTranslations.clear();
  }

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
