// lib/models/quran_models.dart

// ─────────────────────────────────────────────────────────────────────────────
// Single ayah with all script variants + translation merged at runtime
// ─────────────────────────────────────────────────────────────────────────────
class AyahData {
  final int surahNumber;
  final int ayahNumber;
  final String verseKey; // "1:1"

  // Arabic scripts
  final String uthmani;       // qpc-hafs.json  (default)
  final String indoPak;       // indopak-nastaleek.json

  // Extras
  final String transliteration; // en.literation.json → "t"
  final String translation;     // active translation file → "t"
  final String? audioUrl;       // ayah-recitation-mishari.json → "audio_url"

  const AyahData({
    required this.surahNumber,
    required this.ayahNumber,
    required this.verseKey,
    required this.uthmani,
    required this.indoPak,
    required this.transliteration,
    required this.translation,
    this.audioUrl,
  });

  /// Returns the arabic text for the chosen script.
  String arabicFor(ArabicScript script) {
    switch (script) {
      case ArabicScript.indoPak:
        return indoPak.isNotEmpty ? indoPak : uthmani;
      case ArabicScript.uthmani:
        return uthmani;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah metadata (used in list views — no ayahs)
// ─────────────────────────────────────────────────────────────────────────────
class SurahInfo {
  final int number;
  final String nameArabic;   // Arabic name from surah-info.json
  final String nameEnglish;  // e.g. "Al-Fatihah"
  final String nameMeaning;  // e.g. "The Opening"
  final String revelationType; // "Meccan" | "Medinan"
  final int totalAyahs;
  final int juzNumber;       // starting juz

  const SurahInfo({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.nameMeaning,
    required this.revelationType,
    required this.totalAyahs,
    required this.juzNumber,
  });

  factory SurahInfo.fromJson(Map<String, dynamic> json) => SurahInfo(
        number: json['number'] as int,
        nameArabic: json['nameArabic'] as String,
        nameEnglish: json['nameEnglish'] as String,
        nameMeaning: json['nameMeaning'] as String? ?? '',
        revelationType: json['revelationType'] as String? ?? '',
        totalAyahs: json['totalAyahs'] as int,
        juzNumber: json['juzNumber'] as int? ?? 1,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah Detail (from surah-info.json)
// ─────────────────────────────────────────────────────────────────────────────
class SurahDetail {
  final int surahNumber;
  final String surahName;
  final String text;
  final String shortText;

  const SurahDetail({
    required this.surahNumber,
    required this.surahName,
    required this.text,
    required this.shortText,
  });

  factory SurahDetail.fromJson(Map<String, dynamic> json) => SurahDetail(
        surahNumber: json['surah_number'] as int,
        surahName: json['surah_name'] as String,
        text: json['text'] as String,
        shortText: json['short_text'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah Audio Metadata (from API)
// ─────────────────────────────────────────────────────────────────────────────
class SurahAudio {
  final int surahNumber;
  final Map<String, ReciterAudio> reciters;

  SurahAudio({required this.surahNumber, required this.reciters});

  factory SurahAudio.fromJson(int surahNumber, Map<String, dynamic> json) {
    final Map<String, ReciterAudio> reciters = {};
    json.forEach((key, value) {
      reciters[key] = ReciterAudio.fromJson(value as Map<String, dynamic>);
    });
    return SurahAudio(surahNumber: surahNumber, reciters: reciters);
  }
}

class ReciterAudio {
  final String reciterName;
  final String url;
  final String originalUrl;

  ReciterAudio({
    required this.reciterName,
    required this.url,
    required this.originalUrl,
  });

  factory ReciterAudio.fromJson(Map<String, dynamic> json) => ReciterAudio(
        reciterName: json['reciter'] as String,
        url: json['url'] as String,
        originalUrl: json['originalUrl'] as String,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Juz entry
// ─────────────────────────────────────────────────────────────────────────────
class JuzEntry {
  final int juzNumber;
  final String startVerseKey; // "2:142"
  final int startSurah;
  final int startAyah;
  final String startSurahName;

  const JuzEntry({
    required this.juzNumber,
    required this.startVerseKey,
    required this.startSurah,
    required this.startAyah,
    required this.startSurahName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmark
// ─────────────────────────────────────────────────────────────────────────────
class QuranBookmark {
  final int surah;
  final int ayah;
  final String surahName;

  const QuranBookmark({
    required this.surah,
    required this.ayah,
    required this.surahName,
  });

  Map<String, dynamic> toJson() =>
      {'surah': surah, 'ayah': ayah, 'surahName': surahName};

  factory QuranBookmark.fromJson(Map<String, dynamic> json) => QuranBookmark(
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
        surahName: json['surahName'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Last read position
// ─────────────────────────────────────────────────────────────────────────────
class LastReadPosition {
  final int surah;
  final int ayah;
  final String surahName;

  const LastReadPosition({
    required this.surah,
    required this.ayah,
    required this.surahName,
  });

  Map<String, dynamic> toJson() =>
      {'surah': surah, 'ayah': ayah, 'surahName': surahName};

  factory LastReadPosition.fromJson(Map<String, dynamic> json) =>
      LastReadPosition(
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
        surahName: json['surahName'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────
enum ArabicScript { uthmani, indoPak }

enum PlayMode { surah, ayah }

enum TranslationId {
  enSahih,
  urMaududi,
  urJalandhari,
  urWahiuddin,
  enMuhsin,
  hiUmari,
}

extension TranslationIdX on TranslationId {
  String get fileName {
    switch (this) {
      case TranslationId.enSahih:
        return 'en-sahih-international-simple.json';
      case TranslationId.urMaududi:
        return 'ur-roman.json';
      case TranslationId.urJalandhari:
        return 'ur-jalandhari.json';
      case TranslationId.urWahiuddin:
        return 'ur-wahiduddinkhan.json';
      case TranslationId.enMuhsin:
        return 'en-muhsinkhan.json';
      case TranslationId.hiUmari:
        return 'hi-al-umari.json';
    }
  }

  String get displayName {
    switch (this) {
      case TranslationId.enSahih:
        return 'English – Sahih International';
      case TranslationId.urMaududi:
        return 'Roman Urdu';
      case TranslationId.urJalandhari:
        return 'Urdu – Jalandhari';
      case TranslationId.urWahiuddin:
        return 'Urdu – Wahiduddin Khan';
      case TranslationId.enMuhsin:
        return 'English – Muhsin Khan';
      case TranslationId.hiUmari:
        return 'Hindi – Al-Umari';
    }
  }

  bool get isUrdu =>
      this == TranslationId.urJalandhari || this == TranslationId.urWahiuddin;
}

// ─────────────────────────────────────────────────────────────────────────────
// Popular sections (mirrors PWA's POPULAR_QURAN_SECTIONS)
// ─────────────────────────────────────────────────────────────────────────────
class PopularSection {
  final int surahNumber;
  final String title;
  final String arabicTitle;
  final int? startAyah;
  final int? endAyah;

  const PopularSection({
    required this.surahNumber,
    required this.title,
    required this.arabicTitle,
    this.startAyah,
    this.endAyah,
  });
}

const kPopularSections = [
  PopularSection(surahNumber: 67, title: 'Surah Al-Mulk', arabicTitle: 'الملك'),
  PopularSection(surahNumber: 56, title: "Surah Al-Waqi'ah", arabicTitle: 'الواقعة'),
  PopularSection(surahNumber: 2,  title: 'Ayat al-Kursi',  arabicTitle: 'آية الكرسي', startAyah: 255, endAyah: 255),
  PopularSection(surahNumber: 2,  title: 'Al-Baqarah (285–286)', arabicTitle: 'البقرة', startAyah: 285, endAyah: 286),
  PopularSection(surahNumber: 55, title: 'Surah Ar-Rahman', arabicTitle: 'الرحمن'),
  PopularSection(surahNumber: 36, title: 'Surah Yaseen',    arabicTitle: 'يس'),
  PopularSection(surahNumber: 18, title: 'Surah Al-Kahf',   arabicTitle: 'الكهف'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Tafsir Models
// ─────────────────────────────────────────────────────────────────────────────
class TafsirResponse {
  final String surahName;
  final int surahNo;
  final int ayahNo;
  final List<TafsirItem> tafsirs;

  TafsirResponse({
    required this.surahName,
    required this.surahNo,
    required this.ayahNo,
    required this.tafsirs,
  });

  factory TafsirResponse.fromJson(Map<String, dynamic> json) => TafsirResponse(
        surahName: json['surahName'] as String,
        surahNo: json['surahNo'] as int,
        ayahNo: json['ayahNo'] as int,
        tafsirs: (json['tafsirs'] as List<dynamic>)
            .map((e) => TafsirItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'surahName': surahName,
        'surahNo': surahNo,
        'ayahNo': ayahNo,
        'tafsirs': tafsirs.map((e) => e.toJson()).toList(),
      };
}

class TafsirItem {
  final String author;
  final String? groupVerse;
  final String content;

  TafsirItem({
    required this.author,
    this.groupVerse,
    required this.content,
  });

  factory TafsirItem.fromJson(Map<String, dynamic> json) => TafsirItem(
        author: json['author'] as String,
        groupVerse: json['groupVerse'] as String?,
        content: json['content'] as String,
      );

  Map<String, dynamic> toJson() => {
        'author': author,
        'groupVerse': groupVerse,
        'content': content,
      };
}
