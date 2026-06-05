import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import '../../services/hadith_service.dart';
import 'hadith_chapter_screen.dart';
import 'hadith_reader_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GLOBAL HADITH SEARCH INDEX
// ═══════════════════════════════════════════════════════════════════════════

/// Pre-computed search index for a single Hadith with book/chapter context.
class _GlobalHadithSearchIndex {
  final Hadith hadith;
  final String bookTitle;
  final String chapterTitle;
  final String chapterNum;
  final String lowerTitle;
  final String lowerNarrator;
  final String lowerEnglish;
  final String lowerArabic;
  final String lowerGrade;
  final String lowerNum;
  final String lowerBookTitle;
  final String lowerChapterTitle;

  _GlobalHadithSearchIndex({
    required this.hadith,
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterNum,
  })  : lowerTitle = hadith.title.toLowerCase(),
        lowerNarrator = hadith.narrator.toLowerCase(),
        lowerEnglish = hadith.englishText.toLowerCase(),
        lowerArabic = hadith.arabicText.toLowerCase(),
        lowerGrade = hadith.grade.toLowerCase(),
        lowerNum = hadith.localNum.toLowerCase(),
        lowerBookTitle = bookTitle.toLowerCase(),
        lowerChapterTitle = chapterTitle.toLowerCase();

  /// Multi-field matching with smart scoring
  SearchMatchScore matches(String query) {
    // Exact phrase match (highest score)
    if (lowerTitle.contains(query)) return SearchMatchScore.exactTitle;
    if (lowerEnglish.contains(query)) return SearchMatchScore.exactEnglish;
    if (lowerArabic.contains(query)) return SearchMatchScore.exactArabic;
    if (lowerNarrator.contains(query)) return SearchMatchScore.exactNarrator;
    if (lowerBookTitle.contains(query)) return SearchMatchScore.exactBook;
    if (lowerChapterTitle.contains(query)) return SearchMatchScore.exactChapter;
    if (lowerGrade.contains(query)) return SearchMatchScore.exactGrade;
    if (lowerNum.contains(query)) return SearchMatchScore.exactNum;

    // Partial word match (lower score)
    final words = query.split(' ');
    for (final word in words) {
      if (word.length > 2) {
        if (lowerTitle.contains(word)) return SearchMatchScore.partialTitle;
        if (lowerEnglish.contains(word)) return SearchMatchScore.partialEnglish;
        if (lowerArabic.contains(word)) return SearchMatchScore.partialArabic;
      }
    }

    return SearchMatchScore.none;
  }
}

/// Search match scoring for ranking results
enum SearchMatchScore {
  none(0),
  partialNum(1),
  partialGrade(2),
  exactNum(3),
  exactGrade(4),
  partialChapter(5),
  exactChapter(6),
  partialBook(7),
  exactBook(8),
  partialNarrator(9),
  exactNarrator(10),
  partialArabic(11),
  exactArabic(12),
  partialEnglish(13),
  exactEnglish(14),
  partialTitle(15),
  exactTitle(16);

  final int value;
  const SearchMatchScore(this.value);

  bool get isMatch => this != SearchMatchScore.none;
}

/// Pre-computed search index for a Chapter.
class _GlobalChapterSearchIndex {
  final HadithChapter chapter;
  final String bookTitle;
  final String bookAsset;
  final String lowerEnglishTitle;
  final String lowerArabicTitle;
  final String lowerNum;
  final List<_GlobalHadithSearchIndex> hadithIndices;

  _GlobalChapterSearchIndex({
    required this.chapter,
    required this.bookTitle,
    required this.bookAsset,
  })  : lowerEnglishTitle = chapter.englishTitle.toLowerCase(),
        lowerArabicTitle = chapter.arabicTitle.toLowerCase(),
        lowerNum = chapter.num.toLowerCase(),
        hadithIndices = chapter.hadithList
            .map((h) => _GlobalHadithSearchIndex(
                  hadith: h,
                  bookTitle: bookTitle,
                  chapterTitle: chapter.englishTitle,
                  chapterNum: chapter.num,
                ))
            .toList(growable: false);

  SearchMatchScore chapterMatches(String query) {
    if (lowerEnglishTitle.contains(query)) return SearchMatchScore.exactChapter;
    if (lowerArabicTitle.contains(query)) return SearchMatchScore.exactChapter;
    if (lowerNum.contains(query)) return SearchMatchScore.exactNum;
    return SearchMatchScore.none;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SEARCH RESULT TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a single search result with score for ranking.
sealed class GlobalSearchResult {
  final SearchMatchScore score;
  GlobalSearchResult(this.score);
}

class GlobalChapterResult extends GlobalSearchResult {
  final HadithChapter chapter;
  final String bookTitle;
  final String bookAsset;

  GlobalChapterResult({
    required this.chapter,
    required this.bookTitle,
    required this.bookAsset,
    required SearchMatchScore score,
  }) : super(score);
}

class GlobalHadithResult extends GlobalSearchResult {
  final Hadith hadith;
  final String bookTitle;
  final String bookAsset;
  final HadithChapter parentChapter;
  final bool isLongArabic;
  final bool isLongEnglish;

  GlobalHadithResult({
    required this.hadith,
    required this.bookTitle,
    required this.bookAsset,
    required this.parentChapter,
    required SearchMatchScore score,
  })  : isLongArabic = hadith.arabicText.length > 150,
        isLongEnglish = hadith.englishText.length > 200,
        super(score);
}

// ═══════════════════════════════════════════════════════════════════════════
// HADITH SEARCH SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class HadithSearchScreen extends StatefulWidget {
  const HadithSearchScreen({super.key});

  @override
  State<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends State<HadithSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Search state
  List<_GlobalChapterSearchIndex> _chapterIndices = [];
  List<GlobalSearchResult> _filteredResults = [];
  List<GlobalSearchResult> _displayResults = [];
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _showingAllResults = false;
  bool _isInitialized = false;
  int _totalResultCount = 0;
  int _displayedCount = 0;

  static const int _initialLoadCount = 30;
  static const int _loadMoreCount = 50;

  bool get _hasMoreResults => _displayedCount < _totalResultCount;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() => _isSearching = query.isNotEmpty);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (query.isEmpty) {
        setState(() {
          _filteredResults = [];
          _displayResults = [];
          _totalResultCount = 0;
          _showingAllResults = false;
          _displayedCount = 0;
        });
      } else {
        _executeSearch(query);
      }
    });
  }

  Future<void> _executeSearch(String rawQuery) async {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return;

    // Load and index all books if not done yet
    if (!_isInitialized) {
      setState(() => _isLoading = true);
      try {
        await _initializeSearchIndex();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    if (_chapterIndices.isEmpty) return;

    // Perform search with scoring
    final List<GlobalSearchResult> results = [];

    for (final ci in _chapterIndices) {
      // Check chapter match
      final chapterScore = ci.chapterMatches(query);
      if (chapterScore.isMatch) {
        results.add(GlobalChapterResult(
          chapter: ci.chapter,
          bookTitle: ci.bookTitle,
          bookAsset: ci.bookAsset,
          score: chapterScore,
        ));
      }

      // Check hadith matches
      for (final hi in ci.hadithIndices) {
        final score = hi.matches(query);
        if (score.isMatch) {
          results.add(GlobalHadithResult(
            hadith: hi.hadith,
            bookTitle: ci.bookTitle,
            bookAsset: ci.bookAsset,
            parentChapter: ci.chapter,
            score: score,
          ));
        }
      }
    }

    // Sort by score (highest first)
    results.sort((a, b) => b.score.value.compareTo(a.score.value));

    _totalResultCount = results.length;
    final displayCount =
        _showingAllResults ? results.length : _initialLoadCount;
    _displayedCount = displayCount.clamp(0, results.length);

    if (mounted) {
      setState(() {
        _filteredResults = results;
        _displayResults = results.take(_displayedCount).toList();
      });
    }
  }

  Future<void> _initializeSearchIndex() async {
    final books = await HadithService.instance.loadHadithBooks();

    for (final book in books) {
      try {
        final fullBook = await HadithService.instance.loadHadithBook(
          book.assetPath,
          preloadAll: true,
        );

        for (final chapter in fullBook.allBooks) {
          _chapterIndices.add(_GlobalChapterSearchIndex(
            chapter: chapter,
            bookTitle: book.title,
            bookAsset: book.assetPath,
          ));
        }
      } catch (e) {
        // Skip books that fail to load
        debugPrint('Failed to index book: ${book.title} - $e');
      }
    }

    _isInitialized = true;
  }

  void _loadMoreResults() {
    if (_isLoadingMore || !_hasMoreResults) return;

    setState(() => _isLoadingMore = true);

    // Simulate async for smooth UX
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      final currentCount = _displayResults.length;
      final additionalCount = _loadMoreCount;
      final newResults =
          _filteredResults.skip(currentCount).take(additionalCount).toList();

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
    setState(() {
      _isSearching = false;
      _filteredResults = [];
      _displayResults = [];
      _totalResultCount = 0;
      _showingAllResults = false;
      _displayedCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Header with Search Bar ──
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
                    const Expanded(
                      child: Text(
                        'Search Hadith',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Search Input ──
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
                            hintText:
                                'Search by topic, narrator, hadith number...',
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
                if (_isSearching && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$_totalResultCount result${_totalResultCount == 1 ? '' : 's'} found',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Results ──
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(qt.emeraldLight)),
                  )
                : _buildResults(qt),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(QuranTheme qt) {
    if (!_isSearching) {
      return _buildEmptyState(qt);
    }

    if (_displayResults.isEmpty) {
      return _buildNoResultsState(qt);
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
            GlobalChapterResult() => _buildChapterResultCard(qt, result),
            GlobalHadithResult() => _buildHadithResultCard(qt, result),
          },
        );
      },
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
              'Search Across All Hadith',
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
          _buildTip(qt, 'Bukhari 1', 'Search by book & number'),
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
                style: TextStyle(fontSize: 12, height: 1.4),
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

  Widget _buildChapterResultCard(QuranTheme qt, GlobalChapterResult result) {
    return GestureDetector(
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
    );
  }

  Widget _buildHadithResultCard(QuranTheme qt, GlobalHadithResult result) {
    final settings = HadithReaderSettingsProvider.of(context, listen: true);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HadithReaderScreen(
            hadith: result.hadith,
            bookTitle: result.bookTitle,
            chapterTitle: result.parentChapter.englishTitle,
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
            // Book & Chapter badge
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

            // Chapter info
            Text(
              'In: ${result.parentChapter.englishTitle}',
              style: TextStyle(
                color: qt.textMuted,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),

            // Title (if available)
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

            // Arabic text
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

            // English translation
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

            // Metadata row
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

            // "Read full" indicator for truncated content
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
    );
  }
}
