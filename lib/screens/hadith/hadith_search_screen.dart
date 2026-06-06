import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import '../../services/hadith_db.dart';
import '../../services/hadith_service.dart';
import 'hadith_chapter_screen.dart';
import 'hadith_reader_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SEARCH RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

sealed class SearchResult {
  final int score;
  SearchResult({required this.score});
}

class ChapterResult extends SearchResult {
  final HadithChapter chapter;
  final String bookTitle;
  final String bookAsset;
  ChapterResult({
    required this.chapter,
    required this.bookTitle,
    required this.bookAsset,
    required super.score,
  });
}

class HadithResult extends SearchResult {
  final Hadith hadith;
  final String bookTitle;
  final String bookAsset;
  final String chapterTitle;
  final bool isLongArabic;
  final bool isLongEnglish;
  final String?
      subtitleTag; // Highlight tag for smart indexing like "Position #5000"

  HadithResult({
    required this.hadith,
    required this.bookTitle,
    required this.bookAsset,
    required this.chapterTitle,
    required super.score,
    this.subtitleTag,
  })  : isLongArabic = hadith.arabicText.length > 150,
        isLongEnglish = hadith.englishText.length > 200;
}

// ═══════════════════════════════════════════════════════════════════════════
// HADITH SEARCH SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class HadithSearchScreen extends StatefulWidget {
  /// Optional: pre-select a specific book's filter on load (e.g. when coming from chapter screen)
  final String? preSelectedBookTitle;

  const HadithSearchScreen({super.key, this.preSelectedBookTitle});

  @override
  State<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends State<HadithSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Books list (loaded once, lightweight)
  List<HadithBookInfo>? _books;

  // ── Book filter state ───────────────────────────────────────────────────
  /// null = all books selected; non-null = set of selected book titles.
  Set<String>? _selectedBooks;

  // Search state
  List<SearchResult> _allResults = [];
  List<SearchResult> _displayResults = [];
  Timer? _debounceTimer;
  Timer? _searchTimer;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _showingAllResults = false;
  int _totalResultCount = 0;
  int _displayedCount = 0;

  // Per-book search status
  final Set<String> _searchedBooks = {};
  String _currentSearchingBook = '';

  bool get _isBusy => _currentSearchingBook.isNotEmpty;
  bool get _hasMoreResults => _displayedCount < _totalResultCount;

  static const int _initialLoadCount = 30;
  static const int _loadMoreCount = 50;

  // Pre-compiled RegExp patterns
  static final RegExp _smartKeywordRegex = RegExp(
    r'(bukhari|muslim|tirmidhi|dawud|nasai|majah|riyad|salihin)\s+(\w+)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.requestFocus();
    _loadBookList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookList() async {
    final books = await HadithService.instance.loadHadithBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      // If a specific book was passed (e.g. from chapter screen),
      // pre-select it as filter now that books are loaded.
      if (widget.preSelectedBookTitle != null &&
          books.any((b) => b.title == widget.preSelectedBookTitle)) {
        _selectedBooks = {widget.preSelectedBookTitle!};
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() => _isSearching = query.trim().isNotEmpty);

    // Only auto-search when user presses Space (multi-word query like "muslim 5000")
    if (query.endsWith(' ')) {
      _debounceTimer?.cancel();
      _executeSearch(query.trim());
    } else if (query.isEmpty) {
      _clearResults();
    }
    // Otherwise: search only triggers on Enter (onSubmitted) or Space
  }

  void _clearResults() {
    _searchTimer?.cancel();
    setState(() {
      _allResults = [];
      _displayResults = [];
      _totalResultCount = 0;
      _showingAllResults = false;
      _displayedCount = 0;
      _searchedBooks.clear();
      _currentSearchingBook = '';
    });
  }

  /// Returns the list of books that should be searched, respecting filters.
  List<HadithBookInfo> _getFilteredBooks() {
    if (_books == null || _books!.isEmpty) return [];
    if (_selectedBooks == null) return _books!; // all selected
    return _books!
        .where((b) => _selectedBooks!.contains(b.title))
        .toList(growable: false);
  }

  Future<void> _executeSearch(String rawQuery) async {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return;

    _searchTimer?.cancel();

    while (_books == null && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted || _books == null || _books!.isEmpty) return;

    setState(() {
      _allResults = [];
      _displayResults = [];
      _totalResultCount = 0;
      _showingAllResults = false;
      _displayedCount = 0;
      _searchedBooks.clear();
      _currentSearchingBook = '';
    });

    final booksToSearch = _getFilteredBooks();

    // High performance sequential execution yielding to frame rate
    for (var i = 0; i < booksToSearch.length; i++) {
      if (!mounted) return;
      final book = booksToSearch[i];

      setState(() => _currentSearchingBook = book.title);

      // Yield thread loop to prevent UI drop frame on old GPUs/CPUs
      await Future.delayed(const Duration(milliseconds: 16));

      if (!mounted) return;

      try {
        final newResults = await _searchBook(book, query);

        if (!mounted) return;

        _searchedBooks.add(book.title);
        _allResults.addAll(newResults);

        // Highly efficient sorting strategy
        _allResults.sort((a, b) => b.score.compareTo(a.score));

        _totalResultCount = _allResults.length;
        final displayCount =
            _showingAllResults ? _allResults.length : _initialLoadCount;
        _displayedCount = displayCount.clamp(0, _allResults.length);

        setState(() {
          _displayResults = _allResults.take(_displayedCount).toList();
          if (i == booksToSearch.length - 1) _currentSearchingBook = '';
        });
      } catch (e) {
        debugPrint('Search error for ${book.title}: $e');
        _searchedBooks.add(book.title);
        if (i == booksToSearch.length - 1 && mounted) {
          setState(() => _currentSearchingBook = '');
        }
      }
    }
  }

  /// Search a single book via SQL. Returns results with simple scoring.
  Future<List<SearchResult>> _searchBook(
      HadithBookInfo book, String query) async {
    final lowerQuery = query.toLowerCase();
    // Strip book keyword prefix (e.g. "muslim 1844a" → "1844a", "bukhari 5000" → "5000")
    // so text search matches the actual hadith content, not the prefix keyword.
    final strippedQuery = lowerQuery.replaceFirstMapped(
      _smartKeywordRegex,
      (m) => m.group(2) ?? lowerQuery,
    );
    final sqlLike = '%$strippedQuery%';

    if (book.assetPath == HadithDb.riyadAssetPath) {
      return _searchRiyadBook(book, lowerQuery, sqlLike);
    }

    final spec = HadithDb.flatSpecFor(book.assetPath);
    if (spec != null) {
      return _searchFlatBook(spec, book, lowerQuery, sqlLike);
    }

    return [];
  }

  // ═════════════════════════════════════════════════════════════════════════
  // RIYAD AS-SALIHIN SEARCH
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<SearchResult>> _searchRiyadBook(
      HadithBookInfo book, String lowerQuery, String sqlLike) async {
    final db = await HadithDb.instance.getDb(book.assetPath);
    final results = <SearchResult>[];
    final Set<String> matchedSrnos = {};

    // 1. SR_NO EXACT MATCH: If user types a number, look it up by sr_no directly
    final int? targetSrno;
    final pureInt = int.tryParse(lowerQuery);
    if (pureInt != null && pureInt > 0) {
      targetSrno = pureInt;
    } else {
      final match = _smartKeywordRegex.firstMatch(lowerQuery);
      if (match != null) {
        final keyword = match.group(1)!.toLowerCase();
        if (keyword == 'riyad' || keyword == 'salihin') {
          targetSrno = int.tryParse(match.group(2)!);
        } else {
          targetSrno = null;
        }
      } else {
        targetSrno = null;
      }
    }

    if (targetSrno != null && targetSrno > 0) {
      // Use `id` which is the true chronological row position (sequential, gapless)
      final tp = targetSrno;
      final offsetRows = await db.rawQuery('''
        SELECT h.*, c.english AS chapter_english, c.arabic AS chapter_arabic, c.id AS chapter_id
        FROM hadiths h
        LEFT JOIN chapters c ON h.chapterId = c.id
        WHERE h.id = ?
        LIMIT 1
      ''', [tp]);

      if (offsetRows.isNotEmpty) {
        final row = offsetRows.first;
        final chapterName = (row['chapter_english'] as String?) ?? '';
        final hadith = _riyadRowToHadith(row, book.assetPath, chapterName);

        matchedSrnos.add(hadith.srno);
        results.add(HadithResult(
          hadith: hadith,
          bookTitle: book.title,
          bookAsset: book.assetPath,
          chapterTitle: chapterName,
          score: 50,
          subtitleTag: 'Sr. #$targetSrno',
        ));
      }
    }

    // 2. Standard Text SQL Query
    final rows = await db.rawQuery('''
      SELECT h.*, c.english AS chapter_english, c.arabic AS chapter_arabic, c.id AS chapter_id
      FROM hadiths h
      LEFT JOIN chapters c ON h.chapterId = c.id
      WHERE h.text LIKE ?
         OR h.arabic LIKE ?
         OR h.narrator LIKE ?
      ORDER BY h.id ASC
    ''', [sqlLike, sqlLike, sqlLike]);

    final Map<int, List<Hadith>> chapterHadiths = {};
    final Map<int, String> chapterNames = {};

    for (final row in rows) {
      final chapterId = (row['chapter_id'] as int?) ?? 0;
      final chapterName = (row['chapter_english'] as String?) ?? '';
      chapterNames[chapterId] = chapterName;

      final hadith = _riyadRowToHadith(row, book.assetPath, chapterName);

      // Avoid duplicating standard results if we already added it via smart positioning
      if (!matchedSrnos.contains(hadith.srno)) {
        chapterHadiths.putIfAbsent(chapterId, () => []).add(hadith);
      }
    }

    for (final entry in chapterHadiths.entries) {
      final chapter = HadithChapter(
        num: entry.key.toString(),
        englishTitle: chapterNames[entry.key] ?? '',
        arabicTitle: '',
        hadithList: const [],
        hadithCount: entry.value.length,
        chapterKey: entry.key.toString(),
      );

      results.add(ChapterResult(
        chapter: chapter,
        bookTitle: book.title,
        bookAsset: book.assetPath,
        score: 10,
      ));

      for (final hadith in entry.value) {
        results.add(HadithResult(
          hadith: hadith,
          bookTitle: book.title,
          bookAsset: book.assetPath,
          chapterTitle: chapterNames[entry.key] ?? '',
          score: _scoreHadith(hadith, lowerQuery),
        ));
      }
    }

    return results;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FLAT BOOK SEARCH (Bukhari, Muslim, Tirmidhi, Dawud, Nasai, Ibn Majah)
  // ═════════════════════════════════════════════════════════════════════════

  Future<List<SearchResult>> _searchFlatBook(HadithBookSpec spec,
      HadithBookInfo book, String lowerQuery, String sqlLike) async {
    final db = await HadithDb.instance.getDb(spec.assetPath);
    final results = <SearchResult>[];
    final Set<String> matchedSrnos = {};

    // 1. SR_NO EXACT MATCH: Look up by sr_no directly
    int? targetSrno;

    // Check both keyword+NUMBER patterns and pure numbers
    final pureInt = int.tryParse(lowerQuery);
    if (pureInt != null && pureInt > 0) {
      targetSrno = pureInt;
    } else {
      final match = _smartKeywordRegex.firstMatch(lowerQuery);
      if (match != null) {
        final keyword = match.group(1)!.toLowerCase();
        final numberStr = match.group(2)!;
        final bookNameLower = book.title.toLowerCase();

        bool isMatchedBook = false;
        if (keyword == 'bukhari' && bookNameLower.contains('bukhari'))
          isMatchedBook = true;
        if (keyword == 'muslim' && bookNameLower.contains('muslim'))
          isMatchedBook = true;
        if (keyword == 'tirmidhi' && bookNameLower.contains('tirmidhi'))
          isMatchedBook = true;
        if (keyword == 'dawud' && bookNameLower.contains('dawud'))
          isMatchedBook = true;
        if (keyword == 'nasai' && bookNameLower.contains('nasa'))
          isMatchedBook = true;
        if (keyword == 'majah' && bookNameLower.contains('majah'))
          isMatchedBook = true;

        if (isMatchedBook) {
          targetSrno = int.tryParse(numberStr);
        }
      }
    }

    if (targetSrno != null && targetSrno > 0) {
      final offsetRows = await db.rawQuery('''
        SELECT * FROM hadith_library 
        WHERE sr_no = ?
        LIMIT 1
      ''', [targetSrno]);

      if (offsetRows.isNotEmpty) {
        final row = offsetRows.first;
        final hadith = _flatRowToHadith(row, spec);
        final chapterName = (row['english_title'] as String?) ?? '';

        matchedSrnos.add(hadith.srno);
        results.add(HadithResult(
          hadith: hadith,
          bookTitle: book.title,
          bookAsset: book.assetPath,
          chapterTitle: chapterName,
          score: 50,
          subtitleTag: 'Sr. #$targetSrno',
        ));
      }
    }

    // 2. Standard Text SQL Query
    final rows = await db.rawQuery('''
      SELECT * FROM hadith_library 
      WHERE english_text LIKE ?
         OR arabic_text LIKE ?
         OR narrator LIKE ?
         OR title LIKE ?
         OR grade LIKE ?
         OR local_num LIKE ?
         OR english_title LIKE ?
      ORDER BY CAST(local_num AS INTEGER) ASC, local_num ASC
    ''', [sqlLike, sqlLike, sqlLike, sqlLike, sqlLike, sqlLike, sqlLike]);

    final Map<String, List<Hadith>> chapterHadiths = {};
    final Map<String, String> chapterArabicNames = {};

    for (final row in rows) {
      final hadith = _flatRowToHadith(row, spec);

      // Prevent duplicates if already returned via sr_no lookup
      if (!matchedSrnos.contains(hadith.srno)) {
        final chapterName = (row['english_title'] as String?) ?? '';
        chapterHadiths.putIfAbsent(chapterName, () => []).add(hadith);

        final arabicTitle = (row['arabic_title'] as String?) ?? '';
        chapterArabicNames.putIfAbsent(chapterName, () => arabicTitle);
      }
    }

    for (final entry in chapterHadiths.entries) {
      final chapter = HadithChapter(
        num: '',
        englishTitle: entry.key,
        arabicTitle: chapterArabicNames[entry.key] ?? '',
        hadithList: const [],
        hadithCount: entry.value.length,
        chapterKey: entry.key,
      );

      results.add(ChapterResult(
        chapter: chapter,
        bookTitle: book.title,
        bookAsset: book.assetPath,
        score: 10,
      ));

      for (final hadith in entry.value) {
        results.add(HadithResult(
          hadith: hadith,
          bookTitle: book.title,
          bookAsset: book.assetPath,
          chapterTitle: entry.key,
          score: _scoreHadith(hadith, lowerQuery),
        ));
      }
    }

    return results;
  }

  /// Simple scoring based on which field matched
  int _scoreHadith(Hadith hadith, String query) {
    final lcTitle = hadith.title.toLowerCase();
    final lcNarrator = hadith.narrator.toLowerCase();
    final lcEnglish = hadith.englishText.toLowerCase();
    final lcArabic = hadith.arabicText.toLowerCase();
    final lcGrade = hadith.grade.toLowerCase();
    final lcNum = hadith.localNum.toLowerCase();

    if (lcTitle.contains(query)) return 16;
    if (lcNarrator.contains(query)) return 14;
    if (lcEnglish.contains(query)) return 13;
    if (lcArabic.contains(query)) return 12;
    if (lcGrade.contains(query)) return 8;
    if (lcNum.contains(query)) return 7;

    final words = query.split(' ');
    for (final word in words) {
      if (word.length > 2) {
        if (lcTitle.contains(word)) return 15;
        if (lcNarrator.contains(word)) return 13;
        if (lcEnglish.contains(word)) return 12;
        if (lcArabic.contains(word)) return 11;
      }
    }

    return 1;
  }

  Hadith _riyadRowToHadith(
      Map<String, Object?> row, String bookAsset, String chapterTitle) {
    return Hadith(
      title: '',
      narrator: (row['narrator'] as String?) ?? '',
      englishText: (row['text'] as String?) ?? '',
      arabicText: (row['arabic'] as String?) ?? '',
      localNum: (row['id'] as int?)?.toString() ?? '',
      grade: '',
      srno: 'riyad_${row['id']}',
      bookAsset: bookAsset,
      chapterTitle: chapterTitle,
    );
  }

  Hadith _flatRowToHadith(Map<String, Object?> row, HadithBookSpec spec) {
    return Hadith(
      title: (row['title'] as String?) ?? '',
      narrator: (row['narrator'] as String?) ?? '',
      englishText: (row['english_text'] as String?) ?? '',
      arabicText: (row['arabic_text'] as String?) ?? '',
      localNum: (row['local_num'] as String?) ?? '',
      grade: (row['grade'] as String?) ?? '',
      srno: (row['sr_no'] as int?)?.toString() ?? '',
      bookAsset: spec.assetPath,
      chapterTitle: (row['english_title'] as String?) ?? '',
    );
  }

  void _loadMoreResults() {
    if (_isLoadingMore || !_hasMoreResults) return;

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;

      final currentCount = _displayResults.length;
      final additionalCount = _loadMoreCount;
      final newResults =
          _allResults.skip(currentCount).take(additionalCount).toList();

      setState(() {
        _displayResults = [..._displayResults, ...newResults];
        _displayedCount = _displayResults.length;
        _isLoadingMore = false;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _clearResults();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FILTER PANEL
  // ═════════════════════════════════════════════════════════════════════════

  void _toggleFilterSelection(String bookTitle) {
    setState(() {
      _selectedBooks ??= _books!.map((b) => b.title).toSet();
      if (_selectedBooks!.contains(bookTitle)) {
        _selectedBooks!.remove(bookTitle);
        if (_selectedBooks!.isEmpty) {
          // If nothing selected, treat as "all selected" (null = all)
          _selectedBooks = null;
        }
      } else {
        _selectedBooks!.add(bookTitle);
        // If all books are now selected, treat as null (all)
        if (_selectedBooks!.length == _books!.length) {
          _selectedBooks = null;
        }
      }
      // Re-run search if there's an active query
      if (_isSearching && _searchController.text.trim().isNotEmpty) {
        _executeSearch(_searchController.text.trim());
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
              boxShadow: [
                BoxShadow(
                  color: qt.emeraldDeep.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Search Hadith',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (widget.preSelectedBookTitle != null)
                            Text(
                              widget.preSelectedBookTitle!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ── Filter button in top-right ──────────────────────────
                    if (_books != null)
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _selectedBooks == null
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.filter_list_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          cursorColor: Colors.white,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            _debounceTimer?.cancel();
                            _executeSearch(value.trim());
                          },
                          decoration: InputDecoration(
                            hintText: widget.preSelectedBookTitle != null
                                ? 'Search in ${widget.preSelectedBookTitle}...'
                                : 'Search by topic, narrator, hadith number...',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      if (_isSearching)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (_isBusy)
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white.withOpacity(0.7)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Searching $_currentSearchingBook...',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!_isBusy && _totalResultCount > 0)
                          Expanded(
                            child: Text(
                              '$_totalResultCount result${_totalResultCount == 1 ? '' : 's'} found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (_searchedBooks.isNotEmpty)
                          Flexible(
                            flex: 1,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _searchedBooks.map((name) {
                                  final shortName = _shortBookName(name);
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        shortName,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildResults(qt),
          ),
        ],
      ),
    );
  }

  /// Shows the book filter as a modal bottom sheet.
  void _showFilterSheet() {
    if (_books == null || _books!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final qt = QuranTheme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final allSelected = _selectedBooks == null;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
              decoration: BoxDecoration(
                color: qt.cardBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: qt.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list_rounded,
                            color: qt.emeraldDeep, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filter by Book',
                            style: TextStyle(
                              color: qt.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedBooks = null;
                              if (_isSearching &&
                                  _searchController.text.trim().isNotEmpty) {
                                _executeSearch(_searchController.text.trim());
                              }
                            });
                            setSheetState(() {});
                          },
                          child: Text(
                            'Select All',
                            style: TextStyle(
                              color: qt.emeraldDeep,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Book list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _books!.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: qt.borderGlass.withOpacity(0.1),
                      ),
                      itemBuilder: (ctx, index) {
                        final book = _books![index];
                        final isSelected =
                            allSelected || _selectedBooks!.contains(book.title);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _toggleFilterSelection(book.title);
                              // Re-run search if active
                              if (_isSearching &&
                                  _searchController.text.trim().isNotEmpty) {
                                _executeSearch(_searchController.text.trim());
                              }
                            });
                            setSheetState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? qt.emeraldDeep
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? qt.emeraldDeep
                                          : qt.textMuted.withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 16, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        style: TextStyle(
                                          color: qt.textPrimary,
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        book.assetPath
                                            .split('/')
                                            .last
                                            .replaceAll('.db', ''),
                                        style: TextStyle(
                                          color: qt.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: qt.emeraldDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Done (${allSelected ? _books!.length : _selectedBooks!.length} selected)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _shortBookName(String name) {
    if (name.startsWith('Sahih al-')) return 'S. ${name.substring(9)}';
    if (name.startsWith('Sunan ')) return name;
    if (name.startsWith('Jami` ')) return name.replaceFirst('Jami` ', 'J. ');
    if (name == 'Riyad as Salihin') return 'Riyad';
    return name;
  }

  Widget _buildResults(QuranTheme qt) {
    if (!_isSearching) {
      return _buildEmptyState(qt);
    }

    if (_displayResults.isEmpty && !_isBusy) {
      return _buildNoResultsState(qt);
    }

    if (_displayResults.isEmpty && _isBusy) {
      return _buildSearchingState(qt);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      itemCount: _displayResults.length + (_hasMoreResults ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayResults.length) {
          return _buildLoadMoreButton(qt);
        }

        final result = _displayResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: switch (result) {
            ChapterResult() => _buildChapterResultCard(qt, result),
            HadithResult() => _buildHadithResultCard(qt, result),
          },
        );
      },
    );
  }

  Widget _buildSearchingState(QuranTheme qt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(qt.emeraldDeep),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Searching $_currentSearchingBook...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Searching across ${_books?.length ?? 7} hadith collections',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(QuranTheme qt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_rounded,
                  size: 64, color: qt.emeraldDeep.withOpacity(0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              widget.preSelectedBookTitle != null
                  ? 'Search in ${widget.preSelectedBookTitle}'
                  : 'Search Across All Hadith',
              style: TextStyle(
                color: qt.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search by topic, narrator, hadith number,\nor any keyword from the text',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSearchTips(qt),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTips(QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEARCH TIPS',
            style: TextStyle(
              color: qt.emeraldDeep,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _buildTip(qt, 'Prayer', 'Search by topic'),
          _buildTip(qt, 'Abu Hurairah', 'Search by narrator'),
          _buildTip(qt, 'muslim 5000', 'Search by exact position in book'),
          _buildTip(qt, 'Charity', 'Search by keyword'),
        ],
      ),
    );
  }

  Widget _buildTip(QuranTheme qt, String example, String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 14, color: qt.emeraldDeep.withOpacity(0.6)),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, height: 1.4),
                children: [
                  TextSpan(
                    text: '"$example"',
                    style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' – $description',
                    style: TextStyle(color: qt.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(QuranTheme qt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: qt.textMuted.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 48, color: qt.textMuted.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: qt.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try different keywords or check spelling',
              style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(QuranTheme qt) {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(qt.emeraldDeep),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _loadMoreResults,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.emeraldDeep.withOpacity(0.15)),
          color: qt.emeraldDeep.withOpacity(0.06),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.expand_more_rounded, color: qt.emeraldDeep, size: 20),
            const SizedBox(width: 8),
            Text(
              'Load more results ($_totalResultCount - $_displayedCount remaining)',
              style: TextStyle(
                color: qt.emeraldDeep,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterResultCard(QuranTheme qt, ChapterResult result) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithChapterScreen(
              chapter: result.chapter,
              bookAsset: result.bookAsset,
              bookName: result.bookTitle,
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: qt.borderGlass.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: qt.emeraldDeep.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.folder_rounded, color: qt.emeraldDeep, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.chapter.englishTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            result.bookTitle,
                            style: TextStyle(
                              color: qt.emeraldDeep,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chapter ${result.chapter.num}',
                          style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHadithResultCard(QuranTheme qt, HadithResult result) {
    final settings = HadithReaderSettingsProvider.of(context, listen: true);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithReaderScreen(
              hadith: result.hadith,
              bookTitle: result.bookTitle,
              chapterTitle: result.chapterTitle,
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: qt.borderGlass.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: qt.emeraldDeep.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.book_outlined,
                              size: 12, color: qt.emeraldDeep),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              result.bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: qt.emeraldDeep,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Show custom Position Tag if returned via smart index
                  if (result.subtitleTag != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Text(
                        result.subtitleTag!,
                        style: TextStyle(
                          color: qt.emeraldLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Hadith #${result.hadith.localNum}',
                    style: TextStyle(
                      color: qt.emeraldDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'In: ${result.chapterTitle}',
                style: TextStyle(
                  color: qt.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              if (result.hadith.title.isNotEmpty) ...[
                Text(
                  result.hadith.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: qt.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (result.hadith.arabicText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: qt.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: qt.borderGlass.withOpacity(0.2)),
                  ),
                  child: Text(
                    result.isLongArabic
                        ? '${result.hadith.arabicText.substring(0, 150)}…'
                        : result.hadith.arabicText,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'QPC Hafs',
                      fontSize: settings.arabicFontSize,
                      color: qt.textPrimary,
                      height: 1.8,
                    ),
                  ),
                ),
              if (result.hadith.arabicText.isNotEmpty &&
                  result.hadith.englishText.isNotEmpty)
                const SizedBox(height: 10),
              if (result.hadith.englishText.isNotEmpty)
                Text(
                  result.isLongEnglish
                      ? '${result.hadith.englishText.substring(0, 200)}…'
                      : result.hadith.englishText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: qt.textSecondary,
                    fontSize: settings.translationFontSize,
                    height: 1.6,
                  ),
                ),
              if (result.hadith.narrator.isNotEmpty ||
                  result.hadith.grade.isNotEmpty)
                const SizedBox(height: 10),
              if (result.hadith.narrator.isNotEmpty ||
                  result.hadith.grade.isNotEmpty)
                Row(
                  children: [
                    if (result.hadith.narrator.isNotEmpty)
                      Expanded(
                        child: Text(
                          '📖 ${result.hadith.narrator}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (result.hadith.grade.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          result.hadith.grade,
                          style: TextStyle(
                            color: qt.emeraldDeep,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              if (result.isLongArabic || result.isLongEnglish) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Read full hadith',
                        style: TextStyle(
                          color: qt.emeraldDeep,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: qt.emeraldDeep),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
