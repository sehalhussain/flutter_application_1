import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/dua_models.dart';
import '../../providers/dua_progress_provider.dart';
import '../../services/data_service.dart';
import 'dua_segment_screen.dart';
import 'dua_title_screen.dart';

/// Segment colors
const _segmentColors = [
  Color(0xFFE8B84B), // Daily - gold
  Color(0xFF5B7DB1), // Adhkar - blue
  Color(0xFF6B8F6B), // Occasional - green
  Color(0xFF8B6BAE), // All - purple
];

/// Grid segment cards
class _SegmentInfo {
  final String name;
  final IconData icon;
  final Color color;
  final int index;

  const _SegmentInfo(this.name, this.icon, this.color, this.index);
}

const _allSegments = [
  _SegmentInfo('Daily Duas', Icons.wb_sunny_rounded, Color(0xFFE8B84B), 0),
  _SegmentInfo('Adhkar', Icons.nights_stay_rounded, Color(0xFF5B7DB1), 1),
  _SegmentInfo('Occasional Duas', Icons.event_rounded, Color(0xFF6B8F6B), 2),
  _SegmentInfo(
      'All', Icons.collections_bookmark_rounded, Color(0xFF8B6BAE), -1),
];

/// Pre-computed stats so we don't recompute on every build.
class _DuaStats {
  final int totalCategories;
  final int totalDuas;
  final List<int> segCatCounts;
  final List<int> segDuaCounts;

  const _DuaStats({
    required this.totalCategories,
    required this.totalDuas,
    required this.segCatCounts,
    required this.segDuaCounts,
  });

  factory _DuaStats.fromSegments(List<DuaSegment> segments) {
    int totalCats = 0;
    int totalDuas = 0;
    final segCatCounts = <int>[];
    final segDuaCounts = <int>[];

    for (final s in segments) {
      int c = 0;
      int d = 0;
      for (final cat in s.categories) {
        c++;
        for (final t in cat.titles) {
          d += t.duas.length;
        }
      }
      totalCats += c;
      totalDuas += d;
      segCatCounts.add(c);
      segDuaCounts.add(d);
    }

    return _DuaStats(
      totalCategories: totalCats,
      totalDuas: totalDuas,
      segCatCounts: segCatCounts,
      segDuaCounts: segDuaCounts,
    );
  }
}

/// Cached search results to avoid rebuilding on every keystroke.
class _SearchIndex {
  final List<DuaSegment> allSegments;
  final List<_SearchEntry> entries;

  _SearchIndex._(this.allSegments, this.entries);

  /// Build index from all segments. Called once when segments load.
  factory _SearchIndex.build(List<DuaSegment> segments) {
    final entries = <_SearchEntry>[];
    for (final seg in segments) {
      for (final cat in seg.categories) {
        entries.add(_SearchEntry(
          segment: seg,
          category: cat,
          matchPreview: cat.categoryName,
          searchLower: cat.categoryName.toLowerCase(),
        ));
        for (final title in cat.titles) {
          // Combine title name for better search
          final titleSearch = title.titleName.toLowerCase();
          entries.add(_SearchEntry(
            segment: seg,
            category: cat,
            title: title,
            matchPreview: title.titleName,
            searchLower: titleSearch,
          ));
          for (final dua in title.duas) {
            // Pre-concatenate searchable text once, not per keystroke
            final searchable = [
              dua.latin,
              dua.translation,
              dua.source,
              dua.benefits,
            ].whereType<String>().join(' ').toLowerCase();

            entries.add(_SearchEntry(
              segment: seg,
              category: cat,
              title: title,
              dua: dua,
              matchPreview: dua.latin ?? dua.translation ?? 'Dua #${dua.id}',
              searchLower: searchable,
              hasArabic: dua.arabic != null && dua.arabic!.isNotEmpty,
              arabicText: dua.arabic ?? '',
            ));
          }
        }
      }
    }
    return _SearchIndex._(segments, entries);
  }

  List<_SearchEntry> search(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return entries
        .where((e) =>
            e.searchLower.contains(q) ||
            (e.hasArabic && e.arabicText.contains(query)))
        .toList();
  }
}

class _SearchEntry {
  final DuaSegment segment;
  final DuaCategory category;
  final DuaTitle? title;
  final DuaItem? dua;
  final String matchPreview;
  final String searchLower;
  final bool hasArabic;
  final String arabicText;

  const _SearchEntry({
    required this.segment,
    required this.category,
    this.title,
    this.dua,
    required this.matchPreview,
    required this.searchLower,
    this.hasArabic = false,
    this.arabicText = '',
  });
}

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<DuaSegment>>? _segmentsFuture;
  static const String _assetPath = 'assets/data/duas/duas.json';

  // Cached when data loads — avoids recomputing every build
  _DuaStats? _stats;
  _SearchIndex? _searchIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _segmentsFuture = _loadData();
  }

  Future<List<DuaSegment>> _loadData() async {
    final segments = await DataService.loadDuas(_assetPath);
    // Pre-compute stats and search index once
    if (segments.isNotEmpty) {
      _stats = _DuaStats.fromSegments(segments);
      _searchIndex = _SearchIndex.build(segments);
    }
    return segments;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSegment(
      BuildContext context, _SegmentInfo seg, List<DuaSegment> allSegments) {
    if (seg.index >= 0 && seg.index < allSegments.length) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaSegmentScreen(
          segment: allSegments[seg.index],
          segmentIndex: seg.index,
          segmentColor: seg.color,
        ),
      ));
    } else {
      final allCategories = <DuaCategory>[];
      for (final s in allSegments) {
        allCategories.addAll(s.categories);
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaTitleScreen(
          allCategories: allCategories,
          segmentName: 'All Duas',
          segmentColor: seg.color,
        ),
      ));
    }
  }

  void _openPinnedCategory(
      BuildContext context, PinnedCategory pin, List<DuaSegment> allSegments) {
    DuaCategory? foundCat;
    for (final seg in allSegments) {
      for (final cat in seg.categories) {
        if (cat.categoryId == pin.categoryId) {
          foundCat = cat;
          break;
        }
      }
      if (foundCat != null) break;
    }
    if (foundCat != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaTitleScreen(
          category: foundCat,
          segmentName: pin.segmentName,
          segmentColor: _segmentColors[
              pin.segmentIndex >= 0 && pin.segmentIndex < _segmentColors.length
                  ? pin.segmentIndex
                  : 0],
        ),
      ));
    }
  }

  void _openSearch(BuildContext context) {
    if (_searchIndex == null) return;
    showSearch(
      context: context,
      delegate: _DuaSearchDelegate(_searchIndex!),
    );
  }

  void _showCustomizeModal(BuildContext context) async {
    final qt = QuranTheme.of(context);
    final segments = await _segmentsFuture;
    if (segments == null || !mounted) return;
    if (!context.mounted) return;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final progressCtx = DuaProgressProvider.of(ctx, listen: false);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: qt.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: qt.emeraldDeep, size: 20),
                    const SizedBox(width: 10),
                    Text('Customize',
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Tap a chapter to pin it to your dua home screen.',
                  style: TextStyle(color: qt.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: segments.expand((s) => s.categories).length,
                  itemBuilder: (context, index) {
                    // Flatten all categories across segments
                    final allCats = segments
                        .expand(
                            (s) => s.categories.map((c) => (cat: c, seg: s)))
                        .toList();
                    final entry = allCats[index];
                    final cat = entry.cat;
                    final seg = entry.seg;
                    final isPinned = progressCtx.isPinned(cat.categoryId);
                    final catColor = _segmentColors[
                        seg.segmentId < _segmentColors.length
                            ? seg.segmentId
                            : 0];
                    final totalDuas = cat.titles
                        .fold<int>(0, (sum, t) => sum + t.duas.length);

                    return GestureDetector(
                      onTap: () {
                        progressCtx.togglePinned(PinnedCategory(
                          categoryId: cat.categoryId,
                          categoryName: cat.categoryName,
                          segmentName: seg.segmentName,
                          segmentIndex: seg.segmentId,
                          totalDuas: totalDuas,
                        ));
                        // Force rebuild of the modal
                        (ctx as Element).markNeedsBuild();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isPinned ? catColor.withOpacity(0.08) : qt.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPinned
                                ? catColor.withOpacity(0.3)
                                : qt.borderGlass,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isPinned
                                    ? Icons.push_pin_rounded
                                    : Icons.add_rounded,
                                color: catColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat.categoryName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: qt.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${seg.segmentName}  •  $totalDuas duas',
                                      style: TextStyle(
                                          color: qt.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (isPinned)
                              Icon(Icons.check_circle_rounded,
                                  color: catColor, size: 20)
                            else
                              Icon(Icons.add_circle_outline_rounded,
                                  color: qt.textMuted.withOpacity(0.4),
                                  size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
          // ── Immersive Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
            ),
            child: Column(
              children: [
                // Top row: Back | Title (center) | Search (right)
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
                    const Expanded(
                      child: Text(
                        'Authentic Duas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Customize / Sort button
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.sort_outlined,
                            color: Colors.white, size: 22),
                        onPressed: () => _showCustomizeModal(context),
                      ),
                    ),
                  ],
                ),
                // Quran ayah — Arabic
                // Quran ayah — English
                Text(
                  '"Call upon Me, I will respond to you."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quran 40:60',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 34),
                // ── Search Bar (inside header) ──
                GestureDetector(
                  onTap: () => _openSearch(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 10),
                        Text('Search duas...',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 14)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Search All',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Bar (on gradient) ──
          Container(
            color: qt.emeraldMid,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: const [
                Tab(text: 'Duas'),
                Tab(text: 'Saved'),
              ],
            ),
          ),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDuasTab(qt),
                _buildSavedTab(qt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuasTab(QuranTheme qt) {
    return FutureBuilder<List<DuaSegment>>(
      future: _segmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(qt.emeraldDeep)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('Unable to load duas',
                style: TextStyle(color: qt.textMuted)),
          );
        }
        final segments = snapshot.data!;
        // Use cached stats — no recomputation per build
        final stats = _stats!;
        final progress = DuaProgressProvider.of(context, listen: true);
        final pinned = progress.pinnedCategories;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 30, 20, 32 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title — centered
              Center(
                child: Text('Browse Duas',
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              // Grid — segments + pinned merged into one grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
                padding: EdgeInsets.zero, // 👈 ensures no extra top space

                children: [
                  // Main segment cards
                  ...List.generate(_allSegments.length, (i) {
                    final seg = _allSegments[i];
                    final isAll = seg.index == -1;
                    final cats = isAll
                        ? stats.totalCategories
                        : (seg.index >= 0 &&
                                seg.index < stats.segCatCounts.length
                            ? stats.segCatCounts[seg.index]
                            : 0);
                    final duas = isAll
                        ? stats.totalDuas
                        : (seg.index >= 0 &&
                                seg.index < stats.segDuaCounts.length
                            ? stats.segDuaCounts[seg.index]
                            : 0);
                    return _SegmentCard(
                      seg: seg,
                      qt: qt,
                      chapters: cats,
                      duaCount: duas,
                      onTap: () => _openSegment(context, seg, segments),
                    );
                  }),
                  // Pinned category cards
                  ...pinned.map((pin) {
                    final color = pin.segmentIndex >= 0 &&
                            pin.segmentIndex < _segmentColors.length
                        ? _segmentColors[pin.segmentIndex]
                        : _segmentColors[0];
                    return _PinnedCategoryCard(
                      pin: pin,
                      qt: qt,
                      color: color,
                      onTap: () => _openPinnedCategory(context, pin, segments),
                      onRemove: () => progress.removePinned(pin.categoryId),
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedTab(QuranTheme qt) {
    final progress = DuaProgressProvider.of(context, listen: true);
    final saved = progress.favorites;
    if (saved.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline_rounded,
                size: 64, color: qt.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No saved duas yet',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Tap the heart icon to save duas',
                style: TextStyle(color: qt.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 24 + MediaQuery.of(context).padding.bottom),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: saved.length,
      itemBuilder: (context, index) {
        final item = saved[index];
        return _SavedCard(item: item, qt: qt);
      },
    );
  }
}

/// Extracted to avoid rebuilds of the entire ListView when one favorite changes
class _SavedCard extends StatelessWidget {
  final DuaFavorite item;
  final QuranTheme qt;

  const _SavedCard({required this.item, required this.qt});

  @override
  Widget build(BuildContext context) {
    final progress = DuaProgressProvider.of(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.latin != null)
                  Text(item.latin!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: qt.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                const SizedBox(height: 4),
                Text('${item.segmentName} \u00B7 ${item.categoryName}',
                    style: TextStyle(color: qt.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => progress.toggleFavorite(item),
            child:
                const Icon(Icons.favorite, color: Colors.redAccent, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Pinned category — grid card matching _SegmentCard visuals exactly
class _PinnedCategoryCard extends StatelessWidget {
  final PinnedCategory pin;
  final QuranTheme qt;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PinnedCategoryCard({
    required this.pin,
    required this.qt,
    required this.color,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.push_pin_rounded, color: color, size: 26),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    pin.categoryName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pin.totalDuas} duas',
                    style: TextStyle(color: qt.textMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Unpin button (top-right)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: qt.bg.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.close_rounded, size: 14, color: qt.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segment card for grid
class _SegmentCard extends StatelessWidget {
  final _SegmentInfo seg;
  final QuranTheme qt;
  final int chapters;
  final int duaCount;
  final VoidCallback onTap;

  const _SegmentCard({
    required this.seg,
    required this.qt,
    required this.chapters,
    required this.duaCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: seg.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(seg.icon, color: seg.color, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                seg.name,
                style: TextStyle(
                    color: qt.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '$chapters chapters \u00B7 $duaCount duas',
                style: TextStyle(color: qt.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SEARCH DELEGATE — uses pre-built index for O(1) keystroke filtering
// ═══════════════════════════════════════════════════════════════════════════

class _DuaSearchDelegate extends SearchDelegate<_SearchEntry?> {
  final _SearchIndex _index;

  _DuaSearchDelegate(this._index);

  @override
  String get searchFieldLabel => 'Search chapters, titles, duas...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: qt.cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: qt.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: qt.textMuted),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  Widget _buildResultRow(_SearchEntry r, QuranTheme qt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (r.dua != null)
                  Icon(Icons.format_quote_rounded,
                      size: 14, color: qt.emeraldDeep)
                else if (r.title != null)
                  Icon(Icons.title_rounded, size: 14, color: qt.emeraldDeep)
                else
                  Icon(Icons.folder_rounded,
                      size: 14, color: const Color(0xFFE8B84B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.matchPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${r.segment.segmentName} \u203A ${r.category.categoryName}${r.title != null ? ' \u203A ${r.title!.titleName}' : ''}',
              style: TextStyle(color: qt.textMuted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCategory(BuildContext context, _SearchEntry r) {
    close(context, null);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DuaTitleScreen(
        category: r.category,
        segmentName: r.segment.segmentName,
        segmentColor: _segmentColors[r.segment.segmentId < _segmentColors.length
            ? r.segment.segmentId
            : 0],
      ),
    ));
  }

  @override
  Widget buildResults(BuildContext context) {
    final qt = QuranTheme.of(context);
    final results = _index.search(query);
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: qt.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No results found',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      itemCount: results.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => _navigateToCategory(context, results[index]),
        child: _buildResultRow(results[index], qt),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final qt = QuranTheme.of(context);
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 64, color: qt.textMuted.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Search through all chapters, titles, and duas',
                style: TextStyle(color: qt.textMuted, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Try: "morning", "sleep", "protection", "bismillah"',
                style: TextStyle(color: qt.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    final suggestions = _index.search(query);
    if (suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 64, color: qt.textMuted.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No results for "$query"',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      itemCount: suggestions.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => _navigateToCategory(context, suggestions[index]),
        child: _buildResultRow(suggestions[index], qt),
      ),
    );
  }
}
