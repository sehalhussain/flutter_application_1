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

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Immersive Premium Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 24),
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
                        widget.chapter.englishTitle,
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
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 22),
                        onPressed: _openSettings,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.chapter.hadithList.length} hadith${widget.chapter.hadithList.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body Content ──
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: HadithListView(
                  hadiths: widget.chapter.hadithList,
                  bookAsset: widget.bookAsset,
                  bookName: widget.bookName,
                  chapterTitle: widget.chapter.englishTitle,
                  initialSearchQuery: widget.initialSearchQuery,
                ),
              ),
            ),
          ),
        ],
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

  // Pre-computed fields for fast searching
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
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final progress = HadithProgressProvider.of(context, listen: true);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);

    return Column(
      children: [
        // Premium unified search field structure
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: qt.textMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    cursorColor: qt.emeraldDeep,
                    decoration: InputDecoration(
                      hintText: 'Search hadiths...',
                      hintStyle: TextStyle(color: qt.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: TextStyle(color: qt.textPrimary, fontSize: 14),
                  ),
                ),
                if (_isSearching)
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: qt.textMuted.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: qt.textPrimary, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredSearchable.length} result${_filteredSearchable.length == 1 ? '' : 's'}',
                style: TextStyle(
                    color: qt.emeraldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        Expanded(
          child: _displayedHadiths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: qt.textMuted.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.search_off_rounded,
                            size: 48, color: qt.textMuted.withOpacity(0.4)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSearching
                            ? 'No hadiths found'
                            : 'No hadiths available',
                        style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
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
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: qt.borderGlass.withOpacity(0.4)),
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
                                    Text(
                                      hadith.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: qt.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Hadith #${hadith.localNum}',
                                      style: TextStyle(
                                          color: qt.emeraldLight,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Rounded action badges matching premium toolbar logic
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildBadgedAction(
                                    qt,
                                    icon: Icons.share_outlined,
                                    color: qt.textMuted,
                                    onPressed: () => _shareHadith(hadith),
                                    tooltip: 'Share',
                                  ),
                                  const SizedBox(width: 4),
                                  _buildBadgedAction(
                                    qt,
                                    icon: progress.isFavorite(
                                            widget.bookAsset, hadith.uuid)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: progress.isFavorite(
                                            widget.bookAsset, hadith.uuid)
                                        ? Colors.redAccent
                                        : qt.textMuted,
                                    onPressed: () => _toggleFavorite(hadith),
                                    tooltip: 'Like',
                                  ),
                                  const SizedBox(width: 4),
                                  _buildBadgedAction(
                                    qt,
                                    icon: isLastRead
                                        ? Icons.bookmark_added_rounded
                                        : Icons.bookmark_add_outlined,
                                    color: isLastRead
                                        ? qt.emeraldDeep
                                        : qt.textMuted,
                                    onPressed: () => _markAsLastRead(hadith),
                                    tooltip: 'Mark as last read',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (hadith.narrator.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Narrator: ${hadith.narrator}',
                              style: TextStyle(
                                  color: qt.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                          if (hadith.grade.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
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
                            ),
                          ],
                          if (hadith.arabicText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: qt.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: qt.borderGlass.withOpacity(0.3)),
                              ),
                              child: Text(
                                hadith.arabicText,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: 'indopak',
                                    fontSize: settings.arabicFontSize,
                                    color: qt.textPrimary,
                                    height: 1.8),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // ── Correctly Formatted & Aligned English Translation ──
                          Text(
                            hadith.englishText
                                .trim()
                                .split('\n\n')
                                .map((p) =>
                                    p.replaceAll(RegExp(r'\s+'), ' ').trim())
                                .join('\n\n'),
                            style: TextStyle(
                                color: qt.textSecondary,
                                fontSize: settings.translationFontSize,
                                height: 1.6),
                            textAlign: TextAlign.start,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadgedAction(
    QuranTheme qt, {
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: qt.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: qt.borderGlass.withOpacity(0.3)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

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
