class Hadith {
  final String title;
  final String narrator;
  final String englishText;
  final String arabicText;
  final String localNum;
  final String grade;
  final String uuid;
  final String bookAsset;
  final String chapterTitle;

  const Hadith({
    required this.title,
    required this.narrator,
    required this.englishText,
    required this.arabicText,
    required this.localNum,
    required this.grade,
    required this.uuid,
    required this.bookAsset,
    required this.chapterTitle,
  });

  factory Hadith.fromJson(
      Map<String, dynamic> json, String bookAsset, String chapterTitle) {
    return Hadith(
      title: json['title'] as String? ?? '',
      narrator: json['narrator'] as String? ?? '',
      englishText: json['english_text'] as String? ?? '',
      arabicText: json['arabic_text'] as String? ?? '',
      localNum: json['local_num'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      uuid: json['uuid'] as String? ?? '',
      bookAsset: bookAsset,
      chapterTitle: chapterTitle,
    );
  }
}

class HadithChapter {
  final String num;
  final String englishTitle;
  final String arabicTitle;
  final List<Hadith> hadithList;

  const HadithChapter({
    required this.num,
    required this.englishTitle,
    required this.arabicTitle,
    required this.hadithList,
  });

  factory HadithChapter.fromJson(Map<String, dynamic> json, String bookAsset) {
    final hadithList = (json['hadith_list'] as List<dynamic>?)
            ?.map((h) => Hadith.fromJson(h as Map<String, dynamic>, bookAsset,
                json['english_title'] as String? ?? ''))
            .toList() ??
        [];
    return HadithChapter(
      num: json['num'] as String? ?? '',
      englishTitle: json['english_title'] as String? ?? '',
      arabicTitle: json['arabic_title'] as String? ?? '',
      hadithList: hadithList,
    );
  }
}

class HadithBook {
  final String name;
  final String arabicName;
  final String shortDesc;
  final String numBooks;
  final String numHadiths;
  final List<HadithChapter> allBooks;
  final String assetPath;

  const HadithBook({
    required this.name,
    required this.arabicName,
    required this.shortDesc,
    required this.numBooks,
    required this.numHadiths,
    required this.allBooks,
    required this.assetPath,
  });

  factory HadithBook.fromJson(Map<String, dynamic> json, String assetPath) {
    final allBooks = (json['all_books'] as List<dynamic>?)
            ?.map((b) =>
                HadithChapter.fromJson(b as Map<String, dynamic>, assetPath))
            .toList() ??
        [];
    return HadithBook(
      name: json['name'] as String? ?? '',
      arabicName: json['arabic_name'] as String? ?? '',
      shortDesc: json['short_desc'] as String? ?? '',
      numBooks: json['num_books'] as String? ?? '',
      numHadiths: json['num_hadiths'] as String? ?? '',
      allBooks: allBooks,
      assetPath: assetPath,
    );
  }
}

class HadithBookInfo {
  final String assetPath;
  final String title;

  const HadithBookInfo({required this.assetPath, required this.title});
}

class HadithFavorite {
  final String assetPath;
  final String hadithUuid;

  const HadithFavorite({required this.assetPath, required this.hadithUuid});

  Map<String, dynamic> toJson() => {
        'assetPath': assetPath,
        'hadithUuid': hadithUuid,
      };

  factory HadithFavorite.fromJson(Map<String, dynamic> json) => HadithFavorite(
        assetPath: json['assetPath'] as String,
        hadithUuid: json['hadithUuid'] as String,
      );
}
