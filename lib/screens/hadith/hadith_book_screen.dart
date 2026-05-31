import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import '../../services/hadith_service.dart';
import 'hadith_chapter_screen.dart';
import 'hadith_reader_screen.dart';

/// Pre-computed search index for a single Hadith.
class _HadithSearchIndex {
  final Hadith hadith;
  final String lowerTitle;
  final String lowerNarrator;
  final String lowerEnglish;
  final String lowerArabic;
  final String lowerGrade;
  final String lowerNum;

  _HadithSearchIndex(this.hadith)
      : lowerTitle = hadith.title.toLowerCase(),
        lowerNarrator = hadith.narrator.toLowerCase(),
        lowerEnglish = hadith.englishText.toLowerCase(),
        lowerArabic = hadith.arabicText.toLowerCase(),
        lowerGrade = hadith.grade.toLowerCase(),
        lowerNum = hadith.localNum.toLowerCase();

  bool matches(String query) =>
      lowerTitle.contains(query) ||
      lowerNarrator.contains(query) ||
      lowerEnglish.contains(query) ||
      lowerArabic.contains(query) ||
      lowerGrade.contains(query) ||
      lowerNum.contains(query);
}

/// Pre-computed search index for a Chapter.
class _ChapterSearchIndex {
  final HadithChapter chapter;
  final String lowerEnglishTitle;
  final String lowerArabicTitle;
  final String lowerNum;
  final List<_HadithSearchIndex> hadithIndices;

  _ChapterSearchIndex(this.chapter)
      : lowerEnglishTitle = chapter.englishTitle.toLowerCase(),
        lowerArabicTitle = chapter.arabicTitle.toLowerCase(),
        lowerNum = chapter.num.toLowerCase(),
        hadithIndices = chapter.hadithList
            .map((h) => _HadithSearchIndex(h))
            .toList(growable: false);

  bool chapterMatches(String query) =>
      lowerEnglishTitle.contains(query) ||
      lowerArabicTitle.contains(query) ||
      lowerNum.contains(query);
}

/// Represents a single search result.
sealed class _SearchResult {}

class _ChapterResult extends _SearchResult {
  final HadithChapter chapter;
  _ChapterResult(this.chapter);
}

class _HadithResult extends _SearchResult {
  final Hadith hadith;
  final HadithChapter parentChapter;
  final bool isLongArabic;
  final bool isLongEnglish;

  _HadithResult(this.hadith, this.parentChapter)
      : isLongArabic = hadith.arabicText.length > 150,
        isLongEnglish = hadith.englishText.length > 200;
}

class HadithBookScreen extends StatefulWidget {
  final HadithBookInfo book;

  const HadithBookScreen({required this.book, super.key});

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  late Future<HadithBook> _bookFuture;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<HadithChapter> _allChapters = [];
  List<_ChapterSearchIndex> _chapterIndices = [];
  List<_SearchResult> _filteredResultsAll = [];
  List<_SearchResult> _filteredResultsDisplay = [];
  Timer? _debounceTimer;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  static const int _initialSearchLimit = 50;
  bool _showingAllResults = false;
  int _totalResultCount = 0;

  bool get _isCapped =>
      _isSearching &&
      !_showingAllResults &&
      _totalResultCount > _initialSearchLimit;

  @override
  void initState() {
    super.initState();
    _bookFuture = HadithService.instance.loadHadithBook(widget.book.assetPath);
    _searchController.addListener(_onSearchChangedDelayed);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChangedDelayed() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), _executeSearch);
  }

  void _executeSearch() {
    final raw = _searchController.text;
    final query = raw.toLowerCase().trim();

    if (query.isEmpty) {
      if (_filteredResultsAll.isNotEmpty) {
        setState(() {
          _filteredResultsAll = [];
          _filteredResultsDisplay = [];
          _totalResultCount = 0;
          _showingAllResults = false;
        });
      }
      return;
    }

    // Collect ALL results (no cap yet)
    final List<_SearchResult> allResults = [];
    for (final ci in _chapterIndices) {
      if (ci.chapterMatches(query)) {
        allResults.add(_ChapterResult(ci.chapter));
      }
      for (final hi in ci.hadithIndices) {
        if (hi.matches(query)) {
          allResults.add(_HadithResult(hi.hadith, ci.chapter));
        }
      }
    }

    _totalResultCount = allResults.length;
    final List<_SearchResult> displayResults;
    if (_showingAllResults) {
      displayResults = allResults;
    } else {
      displayResults = allResults.length > _initialSearchLimit
          ? allResults.sublist(0, _initialSearchLimit)
          : allResults;
    }

    final changed = _filteredResultsAll.length != allResults.length ||
        !_listEquals(_filteredResultsAll, allResults);
    if (changed) {
      setState(() {
        _filteredResultsAll = allResults;
        _filteredResultsDisplay = displayResults;
      });
    }
  }

  void _showAllResults() {
    setState(() {
      _showingAllResults = true;
      _filteredResultsDisplay = List.of(_filteredResultsAll);
    });
  }

  bool _listEquals(List<_SearchResult> a, List<_SearchResult> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] is _ChapterResult && b[i] is _ChapterResult) {
        if ((a[i] as _ChapterResult).chapter !=
            (b[i] as _ChapterResult).chapter) {
          return false;
        }
      } else if (a[i] is _HadithResult && b[i] is _HadithResult) {
        final ha = a[i] as _HadithResult;
        final hb = b[i] as _HadithResult;
        if (ha.hadith.uuid != hb.hadith.uuid) {
          return false;
        }
      } else {
        return false;
      }
    }
    return true;
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _showingAllResults = false;
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 24),
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
                      child: Navigator.canPop(context)
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Text(
                        widget.book.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Search Bar (Unified glassmorphic layout) ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: 'Search chapters or hadiths...',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13),
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
                                color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FutureBuilder<HadithBook>(
                future: _bookFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(qt.emeraldLight)));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Text('Unable to load book data',
                          style: TextStyle(
                              color: qt.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    );
                  }

                  final book = snapshot.data!;
                  if (book.allBooks.isEmpty) {
                    return Center(
                      child: Text('No chapters found',
                          style: TextStyle(
                              color: qt.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    );
                  }

                  // Build search indices once
                  if (_chapterIndices.isEmpty) {
                    _allChapters = book.allBooks;
                    _chapterIndices = _allChapters
                        .map((c) => _ChapterSearchIndex(c))
                        .toList(growable: false);
                  }

                  final List<_SearchResult> displayList =
                      _isSearching ? _filteredResultsDisplay : [];
                  final bool showAllChapters = !_isSearching;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: qt.emeraldDeep.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: qt.emeraldDeep.withOpacity(0.1)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${book.numBooks}',
                                      style: TextStyle(
                                          color: qt.emeraldDeep,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Chapters',
                                        style: TextStyle(
                                            color: qt.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: qt.emeraldDeep.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: qt.emeraldDeep.withOpacity(0.1)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${book.numHadiths}',
                                      style: TextStyle(
                                          color: qt.emeraldDeep,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Hadiths',
                                        style: TextStyle(
                                            color: qt.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$_totalResultCount result${_totalResultCount == 1 ? '' : 's'}${_isCapped ? ' (showing $_initialSearchLimit)' : ''}',
                              style: TextStyle(
                                  color: qt.emeraldLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Expanded(
                        child: showAllChapters
                            ? _buildChapterList(qt, _allChapters)
                            : _buildSearchResults(qt, settings, displayList),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList(QuranTheme qt, List<HadithChapter> chapters) {
    if (chapters.isEmpty) {
      return Center(
        child: Text('No chapters found',
            style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildChapterCard(qt, chapter),
        );
      },
    );
  }

  Widget _buildSearchResults(QuranTheme qt, HadithReaderSettings settings,
      List<_SearchResult> results) {
    if (results.isEmpty) {
      return Center(
        child: Text('No results found',
            style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );
    }

    final int itemCount = results.length + (_isCapped ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // "Show more" button at the end
        if (_isCapped && index == itemCount - 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: _showAllResults,
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
                    Icon(Icons.expand_more_rounded,
                        color: qt.emeraldDeep, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Show all $_totalResultCount results',
                      style: TextStyle(
                          color: qt.emeraldDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final result = results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: switch (result) {
            _ChapterResult(:final chapter) => _buildChapterCard(qt, chapter),
            _HadithResult(
              :final hadith,
              :final parentChapter,
              :final isLongArabic,
              :final isLongEnglish
            ) =>
              _buildHadithResultCard(qt, settings, hadith, parentChapter,
                  isLongArabic, isLongEnglish),
          },
        );
      },
    );
  }

  Widget _buildChapterCard(QuranTheme qt, HadithChapter chapter) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithChapterScreen(
                  chapter: chapter,
                  bookAsset: widget.book.assetPath,
                  bookName: widget.book.title,
                )));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chapter.num,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.englishTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chapter.arabicTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 12,
                        fontFamily: 'QPC Hafs'),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${chapter.hadithList.length} hadith${chapter.hadithList.length != 1 ? 's' : ''}',
                      style: TextStyle(
                          color: qt.emeraldDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHadithResultCard(
      QuranTheme qt,
      HadithReaderSettings settings,
      Hadith hadith,
      HadithChapter parentChapter,
      bool isLongArabic,
      bool isLongEnglish) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithReaderScreen(
                  hadith: hadith,
                  bookTitle: widget.book.title,
                  chapterTitle: parentChapter.englishTitle,
                )));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
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
                        Icon(Icons.folder_outlined,
                            size: 12, color: qt.emeraldDeep),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                              'Ch. ${parentChapter.num} — ${parentChapter.englishTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: qt.emeraldDeep,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Hadith #${hadith.localNum}',
                  style: TextStyle(
                      color: qt.emeraldDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hadith.title.isNotEmpty) ...[
              Text(
                hadith.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: qt.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              const SizedBox(height: 10),
            ],
            if (hadith.arabicText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: qt.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: qt.borderGlass.withOpacity(0.3)),
                ),
                child: Text(
                  isLongArabic
                      ? '${hadith.arabicText.substring(0, 150)}…'
                      : hadith.arabicText,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      fontFamily: 'QPC Hafs',
                      fontSize: settings.arabicFontSize,
                      color: qt.textPrimary,
                      height: 1.8),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              isLongEnglish
                  ? '${hadith.englishText.substring(0, 200)}…'
                  : hadith.englishText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: qt.textSecondary,
                  fontSize: settings.translationFontSize,
                  height: 1.6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hadith.narrator.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Narrator: ${hadith.narrator}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: qt.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                if (hadith.grade.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hadith.grade,
                      style: TextStyle(
                          color: qt.emeraldDeep,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (isLongArabic || isLongEnglish) ...[
              const SizedBox(height: 12),
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
                          fontWeight: FontWeight.bold),
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
