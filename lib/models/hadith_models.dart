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

  /// Parse a hadith from the Riyad as-Salihin JSON format.
  factory Hadith.fromRiyadJson(
      Map<String, dynamic> json, String bookAsset, String chapterTitle) {
    final english = json['english'] as Map<String, dynamic>? ?? {};
    return Hadith(
      title: '',
      narrator: english['narrator'] as String? ?? '',
      englishText: english['text'] as String? ?? '',
      arabicText: json['arabic'] as String? ?? '',
      localNum: (json['idInBook'] as int?).toString(),
      grade: '',
      uuid: 'riyad_${json['id']}',
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
    // Detect format: existing (all_books) vs Riyad as-Salihin (chapters + hadiths)
    if (json.containsKey('all_books')) {
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
    } else if (json.containsKey('chapters') && json.containsKey('hadiths')) {
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      final arabicMeta = metadata['arabic'] as Map<String, dynamic>? ?? {};
      final englishMeta = metadata['english'] as Map<String, dynamic>? ?? {};

      // Build a chapter index: chapterId -> chapter info
      final chaptersRaw = json['chapters'] as List<dynamic>? ?? [];
      final hadithsRaw = json['hadiths'] as List<dynamic>? ?? [];

      // Map chapterId -> {arabic, english}
      final chapterMap = <int, Map<String, String>>{};
      for (final ch in chaptersRaw) {
        final c = ch as Map<String, dynamic>;
        chapterMap[c['id'] as int] = {
          'arabic': c['arabic'] as String? ?? '',
          'english': c['english'] as String? ?? '',
        };
      }

      // Group hadiths by chapterId
      final chapterHadiths = <int, List<Hadith>>{};
      for (final h in hadithsRaw) {
        final hadithJson = h as Map<String, dynamic>;
        final chapterId = hadithJson['chapterId'] as int? ?? 0;
        final chapterInfo = chapterMap[chapterId];
        final englishTitle = chapterInfo?['english'] ?? '';
        chapterHadiths
            .putIfAbsent(chapterId, () => [])
            .add(Hadith.fromRiyadJson(hadithJson, assetPath, englishTitle));
      }

      // Build chapters
      final chapters = <HadithChapter>[];
      for (final entry in chapterMap.entries) {
        final chapterId = entry.key;
        final info = entry.value;
        chapters.add(HadithChapter(
          num: chapterId.toString(),
          englishTitle: info['english'] ?? '',
          arabicTitle: info['arabic'] ?? '',
          hadithList: chapterHadiths[chapterId] ?? [],
        ));
      }

      // Sort by chapter ID for consistent ordering
      chapters.sort((a, b) => int.parse(a.num).compareTo(int.parse(b.num)));

      final totalHadiths =
          chapters.fold(0, (sum, ch) => sum + ch.hadithList.length);

      return HadithBook(
        name: englishMeta['title'] as String? ?? 'Riyad as-Salihin',
        arabicName: arabicMeta['title'] as String? ?? 'رياض الصالحين',
        shortDesc: '',
        numBooks: chapters.length.toString(),
        numHadiths: totalHadiths.toString(),
        allBooks: chapters,
        assetPath: assetPath,
      );
    }
    // Fallback
    return HadithBook(
      name: '',
      arabicName: '',
      shortDesc: '',
      numBooks: '',
      numHadiths: '',
      allBooks: [],
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
