import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/dua_models.dart';
import '../../providers/dua_progress_provider.dart';
import 'dua_title_screen.dart';
import 'package:flutter_islamic_icons/flutter_islamic_icons.dart';

/// Map category names to matching icons for a premium look
final Map<String, IconData> _categoryIcons = {
  // Daily Duas
  'Sleeping': Icons.bedtime_rounded,
  'Toilet': Icons.wc_rounded,
  'Wudu (Ablution)': FlutterIslamicIcons.solidWudhu,
  'Masjid': Icons.mosque_rounded,
  'Salah (Prayer)': FlutterIslamicIcons.solidPrayingPerson,
  'Home': Icons.home_rounded,
  'Clothes': Icons.checkroom_rounded,
  'Travel': Icons.flight_takeoff_rounded,
  'Food': Icons.restaurant_rounded,
  // Adhkar
  'Daily Dhikr': Icons.auto_awesome_rounded,
  'Morning & Evening Adhkar': Icons.wb_twilight_rounded,
  'After Prayers': FlutterIslamicIcons.solidPrayer,
  'Rizq (Sustenance)': FlutterIslamicIcons.solidZakat,
  'Knowledge': Icons.menu_book_rounded,
  'Faith': FlutterIslamicIcons.solidCrescentMoon,
  'Day of Judgement': Icons.gavel_rounded,
  'Forgiveness': Icons.handshake_rounded,
  'Praising Allah': FlutterIslamicIcons.solidAllah,
  'Protection': Icons.shield_rounded,
  'Family': FlutterIslamicIcons.solidFamily,
  'Health / Ilness': Icons.medical_services_rounded,
  'Loss / Failure': Icons.healing_rounded,
  'Sorrow/Joy': Icons.sentiment_satisfied_rounded,
  'Patience': Icons.hourglass_top_rounded,
  'Debt': Icons.payments_rounded,
  'During Menstruation': Icons.water_rounded,
  // Occasional
  'Deceased': Icons.emoji_people_rounded,
  'Hajj / Umrah': FlutterIslamicIcons.solidHadji,
  'Ramadan': FlutterIslamicIcons.solidLantern,
  'Nature': Icons.park_rounded,
  'Good ettiquete': Icons.emoji_emotions_rounded,
  'Decision / Guidance': Icons.explore_rounded,
};

IconData _iconForCategory(String name) =>
    _categoryIcons[name] ?? Icons.book_rounded;

/// Shows list of chapters within a segment. Tapping a chapter opens DuaTitleScreen.
class DuaSegmentScreen extends StatelessWidget {
  final DuaSegment segment;
  final Color segmentColor;
  final int segmentIndex;

  const DuaSegmentScreen({
    super.key,
    required this.segment,
    required this.segmentColor,
    this.segmentIndex = -1,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final categories = segment.categories;
    final totalCategories = categories.length;
    final totalDuas = categories.fold<int>(
        0,
        (sum, cat) =>
            sum + cat.titles.fold<int>(0, (s, t) => s + t.duas.length));
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Immersive Premium Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
              boxShadow: [
                BoxShadow(
                  color: qt.emeraldDeep.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top row: Back | Title | info
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
                        segment.segmentName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44), // balance for back button
                  ],
                ),
                const SizedBox(height: 4),
                // Subtitle — category & dua counts
                Text(
                  '$totalCategories chapters  •  $totalDuas duas',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),
                // ── Premium Search Bar ──
                GestureDetector(
                  onTap: () {
                    showSearch(
                      context: context,
                      delegate: _SegmentSearchDelegate(segment),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 10),
                          Text('Search in ${segment.segmentName}...',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$totalDuas Duas',
                                style: const TextStyle(
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

          // ── Content ──
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: qt.textMuted.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.folder_off_rounded,
                              size: 48,
                              color: qt.textMuted.withValues(alpha: 0.4)),
                        ),
                        const SizedBox(height: 16),
                        Text('No chapters found in this segment',
                            style: TextStyle(
                                color: qt.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        20, 16, 20, 32 + MediaQuery.of(context).padding.bottom),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final duaCount = cat.titles
                          .fold<int>(0, (sum, t) => sum + t.duas.length);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChapterCard(
                          category: cat,
                          segmentName: segment.segmentName,
                          segmentColor: segmentColor,
                          segmentIndex: segmentIndex,
                          totalDuas: duaCount,
                          qt: qt,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Extracted to a separate widget so only this card rebuilds when pin state changes,
/// not the entire ListView.
class _ChapterCard extends StatelessWidget {
  final DuaCategory category;
  final String segmentName;
  final Color segmentColor;
  final int segmentIndex;
  final int totalDuas;
  final QuranTheme qt;

  const _ChapterCard({
    required this.category,
    required this.segmentName,
    required this.segmentColor,
    required this.segmentIndex,
    required this.totalDuas,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    final progress = DuaProgressProvider.of(context, listen: true);
    final isPinned = progress.isPinned(category.categoryId);
    final icon = _iconForCategory(category.categoryName);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DuaTitleScreen(
          category: category,
          segmentName: segmentName,
          segmentColor: segmentColor,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: segmentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: segmentColor, size: 20),
            ),
            const SizedBox(width: 14),
            // Name + dua count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: qt.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('$totalDuas duas',
                      style: TextStyle(color: qt.textMuted, fontSize: 13)),
                ],
              ),
            ),
            // Pin button
            Tooltip(
              message: isPinned ? 'Unpin from home' : 'Pin to home',
              child: GestureDetector(
                onTap: () {
                  progress.togglePinned(PinnedCategory(
                    categoryId: category.categoryId,
                    categoryName: category.categoryName,
                    segmentName: segmentName,
                    segmentIndex: segmentIndex,
                    totalDuas: totalDuas,
                  ));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPinned
                        ? segmentColor.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: isPinned ? segmentColor : qt.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 24),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SEARCH DELEGATE — filters within a single segment
// ═══════════════════════════════════════════════════════════════════════════

class _SegmentSearchDelegate extends SearchDelegate<String?> {
  final DuaSegment segment;

  _SegmentSearchDelegate(this.segment);

  // Flatten all titles and duas from this segment
  List<_SearchHit> _buildIndex() {
    final hits = <_SearchHit>[];
    for (final cat in segment.categories) {
      hits.add(_SearchHit(
        categoryName: cat.categoryName,
        matchPreview: cat.categoryName,
        searchLower: cat.categoryName.toLowerCase(),
        category: cat,
      ));
      for (final title in cat.titles) {
        hits.add(_SearchHit(
          categoryName: cat.categoryName,
          matchPreview: title.titleName,
          searchLower: title.titleName.toLowerCase(),
          category: cat,
        ));
        for (final dua in title.duas) {
          final searchable = [
            dua.latin,
            dua.translation,
            dua.source,
            dua.benefits,
          ].whereType<String>().join(' ').toLowerCase();

          hits.add(_SearchHit(
            categoryName: cat.categoryName,
            matchPreview: dua.latin ?? dua.translation ?? 'Dua #${dua.id}',
            searchLower: searchable,
            category: cat,
          ));
        }
      }
    }
    return hits;
  }

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

  Widget _buildResultRow(_SearchHit hit, QuranTheme qt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hit.matchPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: qt.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              hit.categoryName,
              style: TextStyle(color: qt.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCategory(BuildContext context, _SearchHit hit) {
    close(context, null);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DuaTitleScreen(
        category: hit.category,
        segmentName: segment.segmentName,
        segmentColor: const Color(0xFF5B7DB1), // default blue
      ),
    ));
  }

  Widget _buildEmptyState(QuranTheme qt, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: qt.textMuted.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 48, color: qt.textMuted.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  color: qt.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final qt = QuranTheme.of(context);
    final index = _buildIndex();
    final q = query.toLowerCase();
    final results = index.where((h) => h.searchLower.contains(q)).toList();
    if (results.isEmpty) {
      return _buildEmptyState(qt, 'No results found');
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: qt.textMuted.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_rounded,
                  size: 48, color: qt.textMuted.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text('Search chapters, titles, and duas in ${segment.segmentName}',
                style: TextStyle(color: qt.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Try: "morning", "sleep", "protection"',
                style: TextStyle(color: qt.textMuted, fontSize: 11)),
          ],
        ),
      );
    }
    final index = _buildIndex();
    final q = query.toLowerCase();
    final suggestions = index.where((h) => h.searchLower.contains(q)).toList();
    if (suggestions.isEmpty) {
      return _buildEmptyState(qt, 'No results for "$query"');
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

class _SearchHit {
  final String categoryName;
  final String matchPreview;
  final String searchLower;
  final DuaCategory category;

  const _SearchHit({
    required this.categoryName,
    required this.matchPreview,
    required this.searchLower,
    required this.category,
  });
}
