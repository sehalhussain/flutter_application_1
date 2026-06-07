import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import '../../providers/quran_settings_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/hadith_service.dart';
import 'hadith_search_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<_SearchableHadith> _searchableHadiths = [];
  List<_SearchableHadith> _filteredSearchable = [];
  List<Hadith> _displayedHadiths = [];

  int _currentChunk = 0;
  static const int _chunkSize = 15;
  bool _isLoadingMore = false;
  bool _isLoadingChapter = false;
  bool _initialSearchApplied = false;
  Timer? _debounceTimer;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChangedDelayed);

    _bootstrapChapter();

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

  Future<void> _bootstrapChapter() async {
    if (widget.chapter.hadithList.isNotEmpty) {
      _hydrateFromChapter(widget.chapter);
      return;
    }

    setState(() => _isLoadingChapter = true);

    try {
      final chapter = await HadithService.instance.loadChapter(
        widget.bookAsset,
        chapterId: int.tryParse(widget.chapter.num) ?? 0,
        chapterKey: widget.chapter.chapterKey ?? widget.chapter.englishTitle,
      );

      if (!mounted) return;
      _hydrateFromChapter(chapter);
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  void _hydrateFromChapter(HadithChapter chapter) {
    setState(() {
      _searchableHadiths = chapter.hadithList
          .map((h) => _SearchableHadith(h))
          .toList(growable: false);
      _filteredSearchable = List.of(_searchableHadiths);
      _loadInitialChunk();
    });
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
      if (a[i].hadith.srno != b[i].hadith.srno) return false;
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
    final isLastRead = progress.isLastRead(widget.bookAsset, hadith.srno);

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
        hadithSrno: hadith.srno,
        hadithTitle: hadith.title,
        chapterTitle: widget.chapter.englishTitle,
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
    await progress.toggleFavorite(widget.bookAsset, hadith.srno);
  }

  void _shareHadith(Hadith hadith) {
    final text = '${hadith.title}\n\n'
        '${hadith.arabicText}\n\n'
        '${hadith.englishText}\n\n'
        '— ${widget.bookName}, ${widget.chapter.englishTitle}';
    Share.share(text);
  }

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
    final progress = HadithProgressProvider.of(context, listen: true);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Immersive Premium Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 20),
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

                // ── Glassmorphic Top Search Bar (In Header) ──
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
                        child: GestureDetector(
                          onTap: () {
                            // Navigate to unified search with this book pre-filtered
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HadithSearchScreen(
                                  preSelectedBookTitle: widget.bookName,
                                ),
                              ),
                            );
                          },
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              cursorColor: Colors.white,
                              decoration: InputDecoration(
                                hintText: 'Search hadiths in this chapter...',
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
                const SizedBox(height: 4),
              ],
            ),
          ),

          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _isLoadingChapter
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                        ),
                      )
                    : _displayedHadiths.isEmpty
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
                                      size: 48,
                                      color: qt.textMuted.withOpacity(0.4)),
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
                            padding: const EdgeInsets.only(
                                bottom: 32, left: 4, right: 4),
                            itemCount: _displayedHadiths.length +
                                (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Divider(
                                color: qt.borderGlass.withOpacity(0.08),
                                height: 1,
                                thickness: 1,
                              ),
                            ),
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
                                          valueColor: AlwaysStoppedAnimation(
                                              qt.emeraldLight)),
                                    ),
                                  ),
                                );
                              }
                              final hadith = _displayedHadiths[index];
                              final isLastRead = progress.isLastRead(
                                  widget.bookAsset, hadith.srno);

                              // Determine if title should be shown (first occurrence or changed)
                              final showTitle = index == 0 ||
                                  hadith.title !=
                                      _displayedHadiths[index - 1].title;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Metadata Header block
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              qt.emeraldDeep.withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          'HADITH #${hadith.localNum}',
                                          style: TextStyle(
                                            color: qt.emeraldDeep,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isLastRead)
                                        Row(
                                          children: [
                                            Icon(Icons.bookmark_added_rounded,
                                                color: qt.emeraldDeep,
                                                size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                              'LAST READ',
                                              style: TextStyle(
                                                color: qt.emeraldDeep,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Hadith Title Text — only shown when title differs from previous hadith
                                  if (showTitle) ...[
                                    Text(
                                      hadith.title,
                                      style: TextStyle(
                                        color: qt.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.5,
                                        height: 1.35,
                                        letterSpacing: -0.2,
                                      ),
                                    ),

                                    // Narrator sub-labeling
                                    if (hadith.narrator.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${hadith.narrator}',
                                        style: TextStyle(
                                          color: qt.emeraldMid,
                                          fontSize: 12.5,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ],

                                  if (settings.showArabic &&
                                      hadith.arabicText.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: qt.brightness == Brightness.dark
                                            ? Colors.white.withOpacity(
                                                0.03) // Subtle whitish in dark mode
                                            : Colors.white.withOpacity(
                                                0.70), // Subtle whitish in light mode
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              qt.borderGlass.withOpacity(0.06),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        hadith.arabicText,
                                        textAlign: TextAlign.right,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          fontFamily: 'indopak',
                                          fontSize: settings.arabicFontSize,
                                          color: qt.textPrimary,
                                          height: 1.85,
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),

                                  // English Translation Paragraphs
                                  if (settings.showEnglish &&
                                      hadith.englishText.trim().isNotEmpty)
                                    Text(
                                      hadith.englishText
                                          .trim()
                                          .split('\n\n')
                                          .map((p) => p
                                              .replaceAll(RegExp(r'\s+'), ' ')
                                              .trim())
                                          .join('\n\n'),
                                      style: TextStyle(
                                        color: qt.textSecondary,
                                        fontSize: settings.translationFontSize,
                                        height: 1.6,
                                        letterSpacing: 0.1,
                                      ),
                                      textAlign: TextAlign.start,
                                    ),

                                  if (settings.showEnglish &&
                                      hadith.englishText.trim().isNotEmpty)
                                    const SizedBox(height: 20),

                                  Row(
                                    children: [
                                      if (hadith.grade.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: qt.emeraldDeep
                                                .withOpacity(0.04),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: qt.emeraldDeep
                                                  .withOpacity(0.08),
                                            ),
                                          ),
                                          child: Text(
                                            hadith.grade,
                                            style: TextStyle(
                                                color: qt.emeraldDeep,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.2),
                                          ),
                                        ),
                                      const Spacer(),

                                      // Reading interactions bar
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildBadgedAction(
                                            qt,
                                            icon: Icons.share_outlined,
                                            color: qt.textMuted,
                                            onPressed: () =>
                                                _shareHadith(hadith),
                                            tooltip: 'Share Hadith',
                                          ),
                                          const SizedBox(width: 8),
                                          _buildBadgedAction(
                                            qt,
                                            icon: progress.isFavorite(
                                                    widget.bookAsset,
                                                    hadith.srno)
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: progress.isFavorite(
                                                    widget.bookAsset,
                                                    hadith.srno)
                                                ? Colors.redAccent
                                                : qt.textMuted,
                                            onPressed: () =>
                                                _toggleFavorite(hadith),
                                            tooltip: 'Like Hadith',
                                          ),
                                          const SizedBox(width: 8),
                                          _buildBadgedAction(
                                            qt,
                                            icon: isLastRead
                                                ? Icons.bookmark_added_rounded
                                                : Icons.bookmark_add_outlined,
                                            color: isLastRead
                                                ? qt.emeraldDeep
                                                : qt.textMuted,
                                            onPressed: () =>
                                                _markAsLastRead(hadith),
                                            tooltip: 'Mark as last read',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ),
          ),
        ],
      ),
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: qt.borderGlass.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

class HadithReaderSettingsSheet extends StatelessWidget {
  const HadithReaderSettingsSheet({super.key});

  Widget _modeChip(
      String label, bool selected, VoidCallback onTap, QuranTheme qt) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? qt.emeraldDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : qt.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
    final appSettings = QuranSettingsProvider.of(context, listen: true);
    final qt = QuranTheme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: qt.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: qt.borderGlass.withOpacity(0.4))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: qt.borderGlass,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Reader Settings',
            style: TextStyle(
              color: qt.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Theme',
            style: TextStyle(
              color: qt.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: qt.borderGlass.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _modeChip(
                        'Auto',
                        appSettings.themeMode == ThemeMode.system,
                        () => appSettings.setThemeMode(ThemeMode.system),
                        qt)),
                Expanded(
                    child: _modeChip(
                        'Light',
                        appSettings.themeMode == ThemeMode.light,
                        () => appSettings.setThemeMode(ThemeMode.light),
                        qt)),
                Expanded(
                    child: _modeChip(
                        'Dark',
                        appSettings.themeMode == ThemeMode.dark,
                        () => appSettings.setThemeMode(ThemeMode.dark),
                        qt)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Display',
            style: TextStyle(
              color: qt.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Arabic'),
            subtitle: const Text('Toggle the Arabic narration text.'),
            value: settings.showArabic,
            onChanged: settings.setShowArabic,
          ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show English'),
            subtitle: const Text('Toggle the translation text.'),
            value: settings.showEnglish,
            onChanged: settings.setShowEnglish,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arabic Font Size',
                style: TextStyle(
                  color: qt.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${settings.arabicFontSize.round()} px',
                style: TextStyle(
                  color: qt.emeraldDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: settings.arabicFontSize,
            min: 18,
            max: 42,
            divisions: 12,
            activeColor: qt.emeraldDeep,
            inactiveColor: qt.emeraldDeep.withOpacity(0.12),
            onChanged: settings.setArabicFontSize,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Translation Font Size',
                style: TextStyle(
                  color: qt.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${settings.translationFontSize.round()} px',
                style: TextStyle(
                  color: qt.emeraldDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: settings.translationFontSize,
            min: 14,
            max: 28,
            divisions: 14,
            activeColor: qt.emeraldDeep,
            inactiveColor: qt.emeraldDeep.withOpacity(0.12),
            onChanged: settings.setTranslationFontSize,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Live Preview',
                  style: TextStyle(
                    color: qt.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'مثال الحديث الشريف',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'indopak',
                    fontSize: settings.arabicFontSize,
                    height: 1.8,
                    color: qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The translation font size will scale smoothly across all Hadith reader views.',
                  style: TextStyle(
                    color: qt.textSecondary,
                    fontSize: settings.translationFontSize,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
        ],
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
