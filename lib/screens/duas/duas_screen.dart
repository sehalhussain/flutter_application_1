import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/dua_models.dart';
import '../../providers/dua_progress_provider.dart';
import '../../services/data_service.dart';
import '../../main.dart';
import 'dua_segment_screen.dart';
import 'dua_title_screen.dart';
import 'dua_view_screen.dart';

/// Segment colors matching the new categories
const _segmentColors = [
  Color(0xFFE8B84B), // Daily Life - gold
  Color(0xFF5B7DB1), // Prayer - blue
  Color(0xFF6B8F6B), // Remembrance - green
  Color(0xFF8B6BAE), // Life Situations - purple
  Color(0xFFD87C6E), // Faith & Hereafter - coral/reddish
  Color(0xFF4A9B9B), // Special Occasions - teal
  Color(0xFFB8860B), // All Duas - dark golden (or keep existing color)
];

/// Grid segment configurations
class _SegmentInfo {
  final String name;
  final IconData icon;
  final Color color;
  final int index;

  const _SegmentInfo(this.name, this.icon, this.color, this.index);
}

const _allSegments = [
  _SegmentInfo('Duas from Quran', Icons.menu_book_rounded,
      Color.fromARGB(255, 38, 104, 79), 6),
  _SegmentInfo('Daily Life', Icons.home_rounded, Color(0xFFE8B84B), 0),
  _SegmentInfo('Prayer', Icons.mosque_rounded, Color(0xFF5B7DB1), 1),
  _SegmentInfo('Remembrance', Icons.auto_awesome_rounded, Color(0xFF6B8F6B), 2),
  _SegmentInfo(
      'Life Situations', Icons.family_restroom_rounded, Color(0xFF8B6BAE), 3),
  _SegmentInfo(
      'Faith & Hereafter', Icons.account_balance_rounded, Color(0xFFD87C6E), 4),
  _SegmentInfo(
      'Special Occasions', Icons.celebration_rounded, Color(0xFF4A9B9B), 5),
  _SegmentInfo(
      'All Duas', Icons.collections_bookmark_rounded, Color(0xFFB8860B), -1),
];

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

class _SearchIndex {
  final List<DuaSegment> allSegments;
  final List<_SearchEntry> entries;

  _SearchIndex._(this.allSegments, this.entries);

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
          final titleSearch = title.titleName.toLowerCase();
          entries.add(_SearchEntry(
            segment: seg,
            category: cat,
            title: title,
            titleName: title.titleName,
            matchPreview: title.titleName,
            searchLower: titleSearch,
          ));
          for (final dua in title.duas) {
            // SAFETY: Use ?.toString() ?? '' to prevent TypeErrors if JSON has nulls
            final searchable = [
              dua.latin?.toString(),
              dua.translation?.toString(),
              dua.source?.toString(),
              dua.benefits?.toString(),
              title.titleName,
            ].whereType<String>().join(' ').toLowerCase();

            entries.add(_SearchEntry(
              segment: seg,
              category: cat,
              title: title,
              dua: dua,
              titleName: title.titleName,
              matchPreview: dua.latin?.toString() ??
                  dua.translation?.toString() ??
                  'Dua #${dua.id}',
              benefitsText: dua.benefits?.toString() ?? '',
              searchLower: searchable,
              hasArabic:
                  dua.arabic != null && dua.arabic!.toString().isNotEmpty,
              arabicText: dua.arabic?.toString() ?? '',
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
  final String titleName;
  final String matchPreview;
  final String benefitsText;
  final String searchLower;
  final bool hasArabic;
  final String arabicText;

  const _SearchEntry({
    required this.segment,
    required this.category,
    this.title,
    this.dua,
    this.titleName = '',
    required this.matchPreview,
    this.benefitsText = '',
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

  _DuaStats? _stats;
  _SearchIndex? _searchIndex;
  List<DuaSegment>? _loadedSegments;

  bool _isListView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _segmentsFuture = _loadData();
  }

  Future<List<DuaSegment>> _loadData() async {
    final segments = await DataService.loadDuas(_assetPath);
    if (segments.isNotEmpty) {
      _stats = _DuaStats.fromSegments(segments);
      _searchIndex = _SearchIndex.build(segments);
      _loadedSegments = segments;
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

  DuaItem? _findDuaById(int duaId) {
    if (_loadedSegments == null) return null;
    for (final seg in _loadedSegments!) {
      for (final cat in seg.categories) {
        for (final title in cat.titles) {
          for (final dua in title.duas) {
            if (dua.id == duaId) return dua;
          }
        }
      }
    }
    return null;
  }

  void _showCustomizeModal(BuildContext context) async {
    final qt = QuranTheme.of(context);
    final segments = await _segmentsFuture;
    if (segments == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final progressCtx = DuaProgressProvider.of(ctx, listen: false);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: qt.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border:
                Border(top: BorderSide(color: qt.borderGlass.withOpacity(0.4))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: qt.borderGlass,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_rounded,
                        color: qt.emeraldDeep, size: 20),
                    const SizedBox(width: 10),
                    Text('Customize Pins',
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tap a chapter to pin or unpin it on your home screen.',
                    style: TextStyle(color: qt.textMuted, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: segments.expand((s) => s.categories).length,
                  itemBuilder: (context, index) {
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: qt.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPinned
                              ? catColor.withOpacity(0.4)
                              : qt.borderGlass.withOpacity(0.4),
                          width: isPinned ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                isPinned ? catColor.withOpacity(0.08) : qt.bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            color: isPinned ? catColor : qt.textMuted,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          cat.categoryName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: qt.textPrimary),
                        ),
                        subtitle: Text(
                          "${seg.segmentName} • $totalDuas supplications",
                          style: TextStyle(color: qt.textMuted, fontSize: 12),
                        ),
                        trailing: Checkbox(
                          value: isPinned,
                          activeColor: catColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) {
                            progressCtx.togglePinned(PinnedCategory(
                              categoryId: cat.categoryId,
                              categoryName: cat.categoryName,
                              segmentName: seg.segmentName,
                              segmentIndex: seg.segmentId,
                              totalDuas: totalDuas,
                            ));
                            (ctx as Element).markNeedsBuild();
                          },
                        ),
                        onTap: () {
                          progressCtx.togglePinned(PinnedCategory(
                            categoryId: cat.categoryId,
                            categoryName: cat.categoryName,
                            segmentName: seg.segmentName,
                            segmentIndex: seg.segmentId,
                            totalDuas: totalDuas,
                          ));
                          (ctx as Element).markNeedsBuild();
                        },
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
          // ── Immersive Premium Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 2),
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
                      child: MainNavigation.canPopShell(context)
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 22),
                              onPressed: () => MainNavigation.popShell(context),
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
                        onPressed: () => _showCustomizeModal(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"Call upon Me, I will respond to you. [Quran 40:30]"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _openSearch(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Search supplications, benefits, titles...',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13),
                          ),
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
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: qt.emeraldMid,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Browse'),
                Tab(text: 'Saved'),
              ],
            ),
          ),

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
                valueColor: AlwaysStoppedAnimation(qt.emeraldLight)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('Unable to load duas',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          );
        }
        final segments = snapshot.data!;
        final stats = _stats!;
        final progress = DuaProgressProvider.of(context, listen: true);
        final pinned = progress.pinnedCategories;
        final totalItems = _allSegments.length + pinned.length;

        return ListView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view_rounded,
                        size: 14, color: qt.emeraldLight),
                    const SizedBox(width: 6),
                    Text(
                      'BROWSE CATEGORIES',
                      style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isListView = true),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isListView
                              ? qt.emeraldDeep.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.view_list_rounded,
                          color: _isListView ? qt.emeraldDeep : qt.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _isListView = false),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: !_isListView
                              ? qt.emeraldDeep.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          color: !_isListView ? qt.emeraldDeep : qt.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isListView)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: totalItems,
                itemBuilder: (context, i) {
                  if (i < _allSegments.length) {
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
                    return _SegmentListTile(
                      seg: seg,
                      qt: qt,
                      chapters: cats,
                      duaCount: duas,
                      onTap: () => _openSegment(context, seg, segments),
                    );
                  } else {
                    final pinIndex = i - _allSegments.length;
                    final pin = pinned[pinIndex];
                    final color = pin.segmentIndex >= 0 &&
                            pin.segmentIndex < _segmentColors.length
                        ? _segmentColors[pin.segmentIndex]
                        : _segmentColors[0];
                    return _PinnedSegmentListTile(
                      pin: pin,
                      qt: qt,
                      color: color,
                      onTap: () => _openPinnedCategory(context, pin, segments),
                    );
                  }
                },
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                padding: EdgeInsets.zero,
                itemCount: totalItems,
                itemBuilder: (context, i) {
                  if (i < _allSegments.length) {
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
                  } else {
                    final pinIndex = i - _allSegments.length;
                    final pin = pinned[pinIndex];
                    final color = pin.segmentIndex >= 0 &&
                            pin.segmentIndex < _segmentColors.length
                        ? _segmentColors[pin.segmentIndex]
                        : _segmentColors[0];
                    return _PinnedSegmentCard(
                      pin: pin,
                      qt: qt,
                      color: color,
                      onTap: () => _openPinnedCategory(context, pin, segments),
                    );
                  }
                },
              ),
          ],
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: qt.textMuted.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_border_rounded,
                  size: 48, color: qt.textMuted.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text('No saved duas yet',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
      itemCount: saved.length,
      itemBuilder: (context, index) {
        final item = saved[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SavedCard(
            item: item,
            qt: qt,
            onTap: () {
              final duaItem = _findDuaById(item.duaId);
              if (duaItem != null) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DuaViewScreen(
                    dua: duaItem,
                    segmentName: item.segmentName,
                    categoryName: item.categoryName,
                    titleName: item.titleName,
                    segmentColor: _segmentColors[0],
                  ),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Could not load this dua'),
                    backgroundColor: qt.emeraldDeep,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }
}

// ── Enhanced Saved Card ──
class _SavedCard extends StatelessWidget {
  final DuaFavorite item;
  final QuranTheme qt;
  final VoidCallback? onTap;

  const _SavedCard({
    required this.item,
    required this.qt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            // Top Row: Title & Unsave Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.titleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: qt.emeraldDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Prevents tap from triggering card navigation
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {},
                  child: Tooltip(
                    message: 'Remove from saved',
                    child: IconButton(
                      icon: Icon(Icons.favorite_rounded,
                          color: Colors.redAccent.shade400, size: 18),
                      onPressed: () =>
                          DuaProgressProvider.of(context, listen: false)
                              .toggleFavorite(item),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Main Content Preview
            if (item.latin != null)
              Text(
                item.latin!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: qt.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              )
            else if (item.translation != null)
              Text(
                item.translation!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: qt.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

            const SizedBox(height: 12),

            // Path Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.segmentName} • ${item.categoryName}',
                style: TextStyle(
                  color: qt.emeraldDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: seg.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(seg.icon, color: seg.color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              seg.name,
              style: TextStyle(
                  color: qt.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$chapters chapters • $duaCount supps',
              style: TextStyle(color: qt.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentListTile extends StatelessWidget {
  final _SegmentInfo seg;
  final QuranTheme qt;
  final int chapters;
  final int duaCount;
  final VoidCallback onTap;

  const _SegmentListTile({
    required this.seg,
    required this.qt,
    required this.chapters,
    required this.duaCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: seg.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(seg.icon, color: seg.color, size: 20),
        ),
        title: Text(
          seg.name,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: qt.textPrimary),
        ),
        subtitle: Text(
          "$chapters chapters • $duaCount duas",
          style: TextStyle(color: qt.textMuted, fontSize: 12),
        ),
        trailing:
            Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}

class _PinnedSegmentListTile extends StatelessWidget {
  final PinnedCategory pin;
  final QuranTheme qt;
  final Color color;
  final VoidCallback onTap;

  const _PinnedSegmentListTile({
    required this.pin,
    required this.qt,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.push_pin_rounded, color: color, size: 20),
        ),
        title: Text(
          pin.categoryName,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: qt.textPrimary),
        ),
        subtitle: Text(
          "${pin.segmentName} • ${pin.totalDuas} supps",
          style: TextStyle(color: qt.textMuted, fontSize: 12),
        ),
        trailing:
            Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}

class _PinnedSegmentCard extends StatelessWidget {
  final PinnedCategory pin;
  final QuranTheme qt;
  final Color color;
  final VoidCallback onTap;

  const _PinnedSegmentCard({
    required this.pin,
    required this.qt,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.push_pin_rounded, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                pin.categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: qt.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${pin.segmentName} • ${pin.totalDuas} supps',
              style: TextStyle(color: qt.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Super-Powered Search Delegate ──
class _DuaSearchDelegate extends SearchDelegate<_SearchEntry?> {
  final _SearchIndex _index;

  _DuaSearchDelegate(this._index);

  @override
  String get searchFieldLabel => 'Search supplications, benefits...';

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
        hintStyle: TextStyle(color: qt.textMuted, fontSize: 14),
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
    final isDua = r.dua != null;
    // Check if the query specifically matched inside the benefits text
    final isBenefitMatch = isDua &&
        r.benefitsText.isNotEmpty &&
        r.benefitsText.toLowerCase().contains(query.toLowerCase());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBenefitMatch
                ? qt.emeraldDeep.withOpacity(0.4)
                : qt.borderGlass.withOpacity(0.4),
            width: isBenefitMatch ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDua) ...[
              // 1. Title Header
              Text(
                r.titleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              // 2. Dua Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.format_quote_rounded,
                        size: 14, color: qt.textMuted.withOpacity(0.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.matchPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              // 3. Benefit Recommendation Highlight
              if (isBenefitMatch) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 11, color: qt.emeraldDeep),
                          const SizedBox(width: 4),
                          Text('MATCHED IN BENEFITS',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: qt.emeraldDeep.withOpacity(0.7),
                                  letterSpacing: 0.8)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.benefitsText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.4),
                      ),
                    ],
                  ),
                )
              ]
            ] else ...[
              // Category/Title Match UI
              Row(
                children: [
                  if (r.title != null)
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
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // 4. Breadcrumb Path
            Text(
              '${r.segment.segmentName} › ${r.category.categoryName}${r.title != null ? ' › ${r.title!.titleName}' : ''}',
              style: TextStyle(color: qt.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Smart Navigation: Opens Dua directly if it's a Dua, otherwise opens Category
  void _navigateToEntry(BuildContext context, _SearchEntry r) {
    close(context, null);
    final color = _segmentColors[
        r.segment.segmentId < _segmentColors.length ? r.segment.segmentId : 0];

    if (r.dua != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaViewScreen(
          dua: r.dua!,
          segmentName: r.segment.segmentName,
          categoryName: r.category.categoryName,
          titleName: r.titleName,
          segmentColor: color,
        ),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaTitleScreen(
          category: r.category,
          segmentName: r.segment.segmentName,
          segmentColor: color,
        ),
      ));
    }
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
            Text('No results found',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      itemCount: results.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => _navigateToEntry(context, results[index]),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: qt.textMuted.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_rounded,
                  size: 48, color: qt.textMuted.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text('Search through chapters, titles, text & benefits',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Try: "morning", "sleep", "protection", "anxiety"',
                style: TextStyle(color: qt.textMuted, fontSize: 11)),
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
            Text('No results for "$query"',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      itemCount: suggestions.length,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => _navigateToEntry(context, suggestions[index]),
        child: _buildResultRow(suggestions[index], qt),
      ),
    );
  }
}
