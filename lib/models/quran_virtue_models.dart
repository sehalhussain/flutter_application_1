// lib/models/quran_virtue_models.dart
//
// Model for the Quran Virtues (Fadail al-Quran) database.
// The DB uses the same flat schema as hadith_library but contains
// narrations about the virtues of specific surahs and ayahs.

class QuranVirtue {
  final String srNo;
  final String bookNum;
  final String englishTitle;
  final String arabicTitle;
  final String localNum;
  final String title;
  final String englishText;
  final String arabicText;
  final String grade;

  const QuranVirtue({
    required this.srNo,
    required this.bookNum,
    required this.englishTitle,
    required this.arabicTitle,
    required this.localNum,
    required this.title,
    required this.englishText,
    required this.arabicText,
    required this.grade,
  });

  factory QuranVirtue.fromRow(Map<String, Object?> row) {
    // Helper to safely extract a String from dynamic SQLite values
    // ignore: no_leading_underscores_for_local_identifiers
    String strVal(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    return QuranVirtue(
      srNo: strVal(row['sr_no']),
      bookNum: strVal(row['book_num']),
      englishTitle: strVal(row['english_title']),
      arabicTitle: strVal(row['arabic_title']),
      localNum: strVal(row['local_num']),
      title: strVal(row['title']),
      englishText: strVal(row['english_text']),
      arabicText: strVal(row['arabic_text']),
      grade: strVal(row['grade']),
    );
  }
}

class QuranVirtueChapter {
  final String englishTitle;
  final String arabicTitle;
  final String bookNum;
  final List<QuranVirtue> virtues;
  final int virtueCount;

  const QuranVirtueChapter({
    required this.englishTitle,
    required this.arabicTitle,
    required this.bookNum,
    required this.virtues,
    this.virtueCount = 0,
  });
}
