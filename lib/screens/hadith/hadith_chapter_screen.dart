import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../services/hadith_service.dart';

class HadithChapterScreen extends StatefulWidget {
  final HadithChapter chapter;
  final String bookAsset;
  final String bookName;

  const HadithChapterScreen({
    required this.chapter,
    required this.bookAsset,
    required this.bookName,
    super.key,
  });

  @override
  State<HadithChapterScreen> createState() => _HadithChapterScreenState();
}

class _HadithChapterScreenState extends State<HadithChapterScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: qt.textPrimary),
        title: Text(widget.chapter.englishTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: qt.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: qt.emeraldDeep,
          labelColor: qt.emeraldDeep,
          unselectedLabelColor: qt.textMuted,
          tabs: const [
            Tab(text: 'All Hadiths'),
            Tab(text: 'Liked'),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TabBarView(
            controller: _tabController,
            children: [
              HadithListTab(
                hadiths: widget.chapter.hadithList,
                bookAsset: widget.bookAsset,
                isFavorites: false,
              ),
              HadithListTab(
                hadiths: widget.chapter.hadithList,
                bookAsset: widget.bookAsset,
                isFavorites: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HadithListTab extends StatefulWidget {
  final List<Hadith> hadiths;
  final String bookAsset;
  final bool isFavorites;

  const HadithListTab({
    required this.hadiths,
    required this.bookAsset,
    required this.isFavorites,
    super.key,
  });

  @override
  State<HadithListTab> createState() => _HadithListTabState();
}

class _HadithListTabState extends State<HadithListTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Hadith> _filteredHadiths = [];
  List<Hadith> _displayedHadiths = [];
  int _currentChunk = 0;
  static const int _chunkSize = 15;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _initializeHadiths();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeHadiths() {
    final progress = HadithProgressProvider.of(context, listen: false);
    _filteredHadiths = widget.isFavorites
        ? widget.hadiths
            .where((h) => progress.isFavorite(widget.bookAsset, h.uuid))
            .toList()
        : widget.hadiths;
    _loadInitialChunk();
  }

  void _loadInitialChunk() {
    _displayedHadiths =
        HadithService.instance.getHadithChunk(_filteredHadiths, 0, _chunkSize);
    _currentChunk = 1;
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHadiths = widget.hadiths.where((hadith) {
        if (widget.isFavorites) {
          final progress = HadithProgressProvider.of(context, listen: false);
          if (!progress.isFavorite(widget.bookAsset, hadith.uuid)) {
            return false;
          }
        }
        return hadith.title.toLowerCase().contains(query) ||
            hadith.localNum.contains(query) ||
            hadith.arabicText.toLowerCase().contains(query) ||
            hadith.englishText.toLowerCase().contains(query) ||
            hadith.narrator.toLowerCase().contains(query) ||
            hadith.grade.toLowerCase().contains(query);
      }).toList();
      _loadInitialChunk();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _displayedHadiths.length < _filteredHadiths.length) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      final newChunk = HadithService.instance.getHadithChunk(
          _filteredHadiths, _currentChunk * _chunkSize, _chunkSize);
      setState(() {
        _displayedHadiths.addAll(newChunk);
        _currentChunk++;
        _isLoadingMore = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final progress = HadithProgressProvider.of(context, listen: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search hadiths...',
              prefixIcon: Icon(Icons.search, color: qt.textMuted),
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
        Expanded(
          child: _displayedHadiths.isEmpty
              ? Center(
                  child: Text(
                    widget.isFavorites
                        ? 'No liked hadiths in this chapter'
                        : 'No hadiths found',
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
                        child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(qt.emeraldLight)),
                      );
                    }
                    final hadith = _displayedHadiths[index];
                    final isFavorite =
                        progress.isFavorite(widget.bookAsset, hadith.uuid);

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
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(hadith.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: qt.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('Hadith #${hadith.localNum}',
                                        style: TextStyle(
                                            color: qt.emeraldLight,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () async {
                                  await progress.toggleFavorite(
                                      widget.bookAsset, hadith.uuid);
                                  if (widget.isFavorites) {
                                    _onSearchChanged(); // Refresh favorites list
                                  }
                                },
                                child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFavorite
                                        ? Colors.redAccent
                                        : qt.textMuted,
                                    size: 20),
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
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                      fontFamily: 'QPC Hafs',
                                      fontSize: 18,
                                      color: qt.textPrimary,
                                      height: 1.8),
                                  softWrap: true),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(hadith.englishText,
                              style: TextStyle(
                                  color: qt.textSecondary,
                                  fontSize: 13,
                                  height: 1.6),
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
