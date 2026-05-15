import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import '../../services/hadith_service.dart';
import 'hadith_chapter_screen.dart';

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

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: qt.textPrimary),
        title: Text(widget.book.title, style: TextStyle(color: qt.textPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: FutureBuilder<HadithBook>(
            future: _bookFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(qt.emeraldLight)));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Text('Unable to load book',
                      style: TextStyle(color: qt.textMuted)),
                );
              }

              final book = snapshot.data!;
              if (book.allBooks.isEmpty) {
                return Center(
                  child: Text('No chapters found',
                      style: TextStyle(color: qt.textMuted)),
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
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${book.numBooks} Chapters',
                            style: TextStyle(
                                color: qt.emeraldDeep,
                                fontWeight: FontWeight.bold)),
                        Text('${book.numHadiths} Hadiths',
                            style: TextStyle(
                                color: qt.emeraldDeep,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Search chapters or hadiths...',
                      prefixIcon: Icon(Icons.search, color: qt.textMuted),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: Icon(Icons.clear, color: qt.textMuted),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: qt.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: qt.borderGlass),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: qt.borderGlass),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: qt.emeraldDeep),
                      ),
                    ),
                    style: TextStyle(color: qt.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$_totalResultCount result${_totalResultCount == 1 ? '' : 's'}${_isCapped ? ' (showing $_initialSearchLimit)' : ''}',
                          style: TextStyle(
                              color: qt.emeraldLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
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
    );
  }

  Widget _buildChapterList(QuranTheme qt, List<HadithChapter> chapters) {
    if (chapters.isEmpty) {
      return Center(
        child: Text('No chapters found', style: TextStyle(color: qt.textMuted)),
      );
    }
    return ListView.separated(
      itemCount: chapters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return _buildChapterCard(qt, chapter);
      },
    );
  }

  Widget _buildSearchResults(QuranTheme qt, HadithReaderSettings settings,
      List<_SearchResult> results) {
    if (results.isEmpty) {
      return Center(
        child: Text('No results found', style: TextStyle(color: qt.textMuted)),
      );
    }

    final int itemCount = results.length + (_isCapped ? 1 : 0);

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // "Show more" button at the end
        if (_isCapped && index == itemCount - 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: GestureDetector(
              onTap: _showAllResults,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: qt.borderGlass),
                  color: qt.cardBg.withAlpha(120),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.expand_more_rounded,
                        color: qt.emeraldLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Show all $_totalResultCount results',
                      style: TextStyle(
                          color: qt.emeraldLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withAlpha(31),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(chapter.num,
                  style: TextStyle(
                      color: qt.emeraldDeep,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.englishTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: qt.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(chapter.arabicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: qt.textMuted,
                          fontSize: 12,
                          fontFamily: 'QPC Hafs')),
                  const SizedBox(height: 6),
                  Text(
                      '${chapter.hadithList.length} hadith${chapter.hadithList.length != 1 ? 's' : ''}',
                      style: TextStyle(color: qt.emeraldLight, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted),
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
            builder: (_) => HadithChapterScreen(
                  chapter: parentChapter,
                  bookAsset: widget.book.assetPath,
                  bookName: widget.book.title,
                  initialSearchQuery: _searchController.text,
                )));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: qt.borderGlass),
          color: qt.cardBg.withAlpha(180),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withAlpha(26),
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
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Hadith #${hadith.localNum}',
                    style: TextStyle(color: qt.emeraldLight, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            if (hadith.title.isNotEmpty) ...[
              Text(hadith.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 6),
            ],
            if (hadith.arabicText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: qt.bg,
                  borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 6),
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
            const SizedBox(height: 8),
            Row(
              children: [
                if (hadith.narrator.isNotEmpty)
                  Expanded(
                    child: Text('Narrator: ${hadith.narrator}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: qt.textMuted, fontSize: 10)),
                  ),
                if (hadith.grade.isNotEmpty)
                  Text(hadith.grade,
                      style: TextStyle(color: qt.emeraldLight, fontSize: 10)),
              ],
            ),
            if (isLongArabic || isLongEnglish) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Read full hadith',
                        style: TextStyle(
                            color: qt.emeraldLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: qt.emeraldLight),
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
