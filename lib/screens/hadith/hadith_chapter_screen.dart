import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/hadith_service.dart';
import 'hadith_reader_screen.dart';

class HadithChapterScreen extends StatefulWidget {
  final HadithChapter chapter;
  final String bookAsset;
  final String bookName;
  final String? initialSearchQuery;

  const HadithChapterScreen({
    required this.chapter,
    required this.bookAsset,
    required this.bookName,
    this.initialSearchQuery,
    super.key,
  });

  @override
  State<HadithChapterScreen> createState() => _HadithChapterScreenState();
}

class _HadithChapterScreenState extends State<HadithChapterScreen> {
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const HadithReaderSettingsSheet(),
    );
  }

  Widget _glassBtn(Widget child, QuranTheme qt) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qt.glassWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: qt.borderGlass),
            ),
            child: Center(child: child),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: qt.textPrimary),
        title: Text(
          widget.chapter.englishTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: qt.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: GestureDetector(
              onTap: _openSettings,
              child: Center(
                child: _glassBtn(
                    Icon(Icons.tune_rounded, color: qt.textPrimary, size: 18),
                    qt),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '${widget.chapter.hadithList.length} hadiths',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: qt.emeraldLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: HadithListView(
                  hadiths: widget.chapter.hadithList,
                  bookAsset: widget.bookAsset,
                  bookName: widget.bookName,
                  chapterTitle: widget.chapter.englishTitle,
                  initialSearchQuery: widget.initialSearchQuery,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HadithListView extends StatefulWidget {
  final List<Hadith> hadiths;
  final String bookAsset;
  final String bookName;
  final String chapterTitle;
  final String? initialSearchQuery;

  const HadithListView({
    required this.hadiths,
    required this.bookAsset,
    required this.bookName,
    required this.chapterTitle,
    this.initialSearchQuery,
    super.key,
  });

  @override
  State<HadithListView> createState() => _HadithListViewState();
}

class _HadithListViewState extends State<HadithListView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Pre-computed lower-case fields for fast searching
  List<_SearchableHadith> _searchableHadiths = [];
  List<_SearchableHadith> _filteredSearchable = [];
  List<Hadith> _displayedHadiths = [];

  int _currentChunk = 0;
  static const int _chunkSize = 15;
  bool _isLoadingMore = false;
  bool _initialSearchApplied = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchableHadiths =
        widget.hadiths.map((h) => _SearchableHadith(h)).toList(growable: false);
    _filteredSearchable = List.of(_searchableHadiths);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChangedDelayed);

    // Initialize the first chunk of hadiths immediately so it's ready for the first build.
    _loadInitialChunk();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.isNotEmpty &&
          !_initialSearchApplied) {
        _initialSearchApplied = true;
        _searchController.text = widget.initialSearchQuery!;
      } else if (!_initialSearchApplied) {
        _initialSearchApplied = true;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadInitialChunk() {
    if (_filteredSearchable.isEmpty) {
      _displayedHadiths = [];
      return;
    }
    final hadiths =
        _filteredSearchable.map((s) => s.hadith).toList(growable: false);
    _displayedHadiths =
        HadithService.instance.getHadithChunk(hadiths, 0, _chunkSize);
    _currentChunk = 1;
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  void _onSearchChangedDelayed() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 120), _executeSearch);
  }

  void _executeSearch() {
    final query = _searchController.text.toLowerCase().trim();

    List<_SearchableHadith> newFiltered;
    if (query.isEmpty) {
      newFiltered = List.of(_searchableHadiths);
    } else {
      newFiltered = _searchableHadiths.where((s) => s.matches(query)).toList();
    }

    // Avoid rebuild if no changes
    if (_listsEqual(newFiltered, _filteredSearchable)) return;

    setState(() {
      _filteredSearchable = newFiltered;
      _loadInitialChunk();
    });
  }

  bool _listsEqual(List<_SearchableHadith> a, List<_SearchableHadith> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hadith.uuid != b[i].hadith.uuid) return false;
    }
    return true;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _displayedHadiths.length < _filteredSearchable.length) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final hadiths =
          _filteredSearchable.map((s) => s.hadith).toList(growable: false);
      final newChunk = HadithService.instance
          .getHadithChunk(hadiths, _currentChunk * _chunkSize, _chunkSize);
      setState(() {
        _displayedHadiths.addAll(newChunk);
        _currentChunk++;
        _isLoadingMore = false;
      });
    });
  }

  Future<void> _markAsLastRead(Hadith hadith) async {
    final progress = HadithProgressProvider.of(context, listen: false);
    final isLastRead = progress.isLastRead(widget.bookAsset, hadith.uuid);

    if (isLastRead) {
      await progress.clearLastRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${hadith.title}" from last read.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } else {
      await progress.setLastRead(
        assetPath: widget.bookAsset,
        hadithUuid: hadith.uuid,
        hadithTitle: hadith.title,
        chapterTitle: widget.chapterTitle,
        bookTitle: widget.bookName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked "${hadith.title}" as last read.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Hadith hadith) async {
    final progress = HadithProgressProvider.of(context, listen: false);
    await progress.toggleFavorite(widget.bookAsset, hadith.uuid);
  }

  void _shareHadith(Hadith hadith) {
    final text = '${hadith.title}\n\n'
        '${hadith.arabicText}\n\n'
        '${hadith.englishText}\n\n'
        '— ${widget.bookName}, ${widget.chapterTitle}';
    // ignore: deprecated_member_use
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final progress = HadithProgressProvider.of(context, listen: true);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search hadiths...',
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
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredSearchable.length} result${_filteredSearchable.length == 1 ? '' : 's'}',
                style: TextStyle(
                    color: qt.emeraldLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        Expanded(
          child: _displayedHadiths.isEmpty
              ? Center(
                  child: Text(
                    _isSearching ? 'No hadiths found' : 'No hadiths',
                    style: TextStyle(color: qt.textMuted),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount:
                      _displayedHadiths.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == _displayedHadiths.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(qt.emeraldLight)),
                          ),
                        ),
                      );
                    }
                    final hadith = _displayedHadiths[index];
                    final isLastRead =
                        progress.isLastRead(widget.bookAsset, hadith.uuid);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: qt.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: qt.borderGlass),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(hadith.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: qt.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text('Hadith #${hadith.localNum}',
                                        style: TextStyle(
                                            color: qt.emeraldLight,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    icon: Icon(Icons.share_outlined,
                                        color: qt.textMuted, size: 20),
                                    onPressed: () => _shareHadith(hadith),
                                    tooltip: 'Share',
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    icon: Icon(
                                      progress.isFavorite(
                                              widget.bookAsset, hadith.uuid)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: progress.isFavorite(
                                              widget.bookAsset, hadith.uuid)
                                          ? Colors.redAccent
                                          : qt.textMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleFavorite(hadith),
                                    tooltip: 'Like',
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    icon: Icon(
                                      isLastRead
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                      color: isLastRead
                                          ? qt.emeraldDeep
                                          : qt.textMuted,
                                      size: 22,
                                    ),
                                    onPressed: () => _markAsLastRead(hadith),
                                    tooltip: 'Mark as last read',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (hadith.narrator.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text('Narrator: ${hadith.narrator}',
                                style: TextStyle(
                                    color: qt.textMuted, fontSize: 11),
                                softWrap: true),
                          ],
                          if (hadith.grade.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Grade: ${hadith.grade}',
                                style: TextStyle(
                                    color: qt.emeraldLight, fontSize: 10),
                                softWrap: true),
                          ],
                          if (hadith.arabicText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: qt.bg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(hadith.arabicText,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                      fontFamily: 'indopak',
                                      fontSize: settings.arabicFontSize,
                                      color: qt.textPrimary,
                                      height: 1.8),
                                  softWrap: true),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                              hadith.englishText
                                  .split('\n\n')
                                  .map((p) => p.replaceAll('\n', ' '))
                                  .join('\n\n'),
                              style: TextStyle(
                                  color: qt.textSecondary,
                                  fontSize: settings.translationFontSize,
                                  height: 1.6),
                              textAlign: TextAlign.justify,
                              softWrap: true),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Pre-computed lower-case fields for fast filtering.
class _SearchableHadith {
  final Hadith hadith;
  final String lowerTitle;
  final String lowerNarrator;
  final String lowerEnglish;
  final String lowerArabic;
  final String lowerGrade;
  final String lowerNum;

  _SearchableHadith(this.hadith)
      : lowerTitle = hadith.title.toLowerCase(),
        lowerNarrator = hadith.narrator.toLowerCase(),
        lowerEnglish = hadith.englishText.toLowerCase(),
        lowerArabic = hadith.arabicText.toLowerCase(),
        lowerGrade = hadith.grade.toLowerCase(),
        lowerNum = hadith.localNum.toLowerCase();

  bool matches(String query) =>
      lowerTitle.contains(query) ||
      lowerNum.contains(query) ||
      lowerArabic.contains(query) ||
      lowerEnglish.contains(query) ||
      lowerNarrator.contains(query) ||
      lowerGrade.contains(query);
}
