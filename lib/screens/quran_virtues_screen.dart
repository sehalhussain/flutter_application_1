// lib/screens/quran_virtues_screen.dart
//
// Premium screen for Quran Virtues (Fadāʾil al-Qurʾān).
// Apple-inspired card hierarchy, emerald calligraphy, glassmorphic headers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/quran_theme.dart';
import '../models/quran_virtue_models.dart';
import '../services/quran_virtues_db.dart';
import '../main.dart';
import '../providers/hadith_reader_settings_provider.dart';
import 'hadith/hadith_chapter_screen.dart';
import '../models/quran_models.dart';
import '../services/quran_service.dart';
import 'quran/quran_reader_screen.dart';
import 'quran/surah_info_screen.dart';

// ── Mapping from the virtues DB "book_num" to the real Quran surah number(s) ──
const Map<int, List<int>> _bookNumToSurah = {
  1: [1],
  2: [2],
  3: [3],
  4: [4],
  5: [6],
  6: [17],
  7: [18],
  8: [20],
  9: [32],
  10: [36],
  11: [39],
  12: [48],
  13: [50],
  14: [54],
  15: [55],
  16: [62, 63],
  17: [67],
  18: [76],
  19: [81, 82, 84],
  20: [87],
  21: [88],
  22: [99],
  23: [103],
  24: [109],
  25: [112],
  26: [113, 114],
};

List<int> _relatedSurahNums(String bookNum) {
  final n = int.tryParse(bookNum) ?? 0;
  return _bookNumToSurah[n] ?? const [];
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARE HELPER
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _shareHadith(QuranVirtue virtue, String chapterTitle) async {
  try {
    final b = StringBuffer();
    if (virtue.arabicText.isNotEmpty) {
      b.write(virtue.arabicText);
      b.write('\n\n');
    }
    if (virtue.englishText.isNotEmpty) {
      b.write(virtue.englishText.trim());
      b.write('\n\n');
    }
    if (virtue.grade.isNotEmpty) b.writeln('Grade: ${virtue.grade}');
    if (virtue.localNum.isNotEmpty) b.writeln('Hadith #${virtue.localNum}');
    b.write('— $chapterTitle');
    await Share.share(b.toString().trim());
  } catch (_) {}
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class QuranVirtuesScreen extends StatefulWidget {
  const QuranVirtuesScreen({super.key});

  @override
  State<QuranVirtuesScreen> createState() => _QuranVirtuesScreenState();
}

class _QuranVirtuesScreenState extends State<QuranVirtuesScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<QuranVirtueChapter>> _chaptersFuture;
  late ScrollController _scrollController;
  late AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = QuranVirtuesDb.instance.loadAllChapters();
    _scrollController = ScrollController();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final t = (offset / 80.0).clamp(0.0, 1.0);
    _headerAnimController.value = t;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const HadithReaderSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const double appBarHeight = 56.0;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // ── Scrollable content ──
          FutureBuilder<List<QuranVirtueChapter>>(
            future: _chaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                      strokeWidth: 1.5,
                    ),
                  ),
                );
              }

              final chapters = snapshot.data ?? [];

              return ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  22,
                  statusBarHeight + appBarHeight + 8,
                  22,
                  40,
                ),
                itemCount: chapters.isEmpty ? 1 : chapters.length + 2,
                addRepaintBoundaries: true,
                cacheExtent: 500,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return RepaintBoundary(
                      child: _MainHeroSection(isDark: isDark),
                    );
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 18),
                      child: Text(
                        'Chapters',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: qt.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ErrorCard(error: snapshot.error, qt: qt);
                  }
                  if (chapters.isEmpty) {
                    return _EmptyCard(qt: qt);
                  }

                  final chapterIndex = index - 2;
                  final chapter = chapters[chapterIndex];

                  return RepaintBoundary(
                    child: _ChapterCard(
                      chapter: chapter,
                      index: chapterIndex,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VirtueDetailScreen(chapter: chapter),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),

          // ── Frosted Glass Header ──
          AnimatedBuilder(
            animation: _headerAnimController,
            builder: (context, child) {
              final t = _headerAnimController.value;
              final titleSize = 24.0 - (8.0 * t);
              final glassOpacity = t * 0.88;

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, statusBarHeight, 20, 0),
                  height: statusBarHeight + appBarHeight,
                  decoration: BoxDecoration(
                    color: (isDark
                            ? const Color(0xFF0C0C0E)
                            : const Color(0xFFF2F2F7))
                        .withValues(alpha: glassOpacity),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFFFFFFFF)
                                .withValues(alpha: t * 0.08)
                            : const Color(0xFF000000)
                                .withValues(alpha: t * 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ActionButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        isDark: isDark,
                        onTap: () {
                          if (!MainNavigation.popShell(context)) {
                            Navigator.maybePop(context);
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Virtues of the Qurʾān',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: qt.textPrimary,
                            letterSpacing: -0.5 + (0.3 * t),
                          ),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.tune_rounded,
                        isDark: isDark,
                        onTap: _openSettings,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN HERO SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _MainHeroSection extends StatelessWidget {
  final bool isDark;

  const _MainHeroSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Column(
        children: [
          Text(
            'فَضَائِلُ الْقُرْآنِ',
            style: TextStyle(
              fontFamily: 'QPC Hafs',
              fontSize: 32,
              color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
              height: 1.6,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _DiamondDivider(color: isDark ? qt.emeraldGlow : qt.emeraldDeep),
          const SizedBox(height: 16),
          Text(
            'An authenticated collection of Prophet ﷺ hadith highlighting the unique virtues, rewards, and protections of various sūrahs and āyāt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: qt.textMuted,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHAPTER CARD — EXACTLY matches QuranHomeScreen _SurahTile sizing
// ═══════════════════════════════════════════════════════════════════════════

class _ChapterCard extends StatelessWidget {
  final QuranVirtueChapter chapter;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapter,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // De-emphasized number — just small muted text, 28 width
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: qt.emeraldDeep.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Name + metadata column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary: English title — matches surah.nameEnglish style
                    Text(
                      chapter.englishTitle,
                      style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 7),
                    // Secondary: Arabic title — matches meaning style
                    if (chapter.arabicTitle.isNotEmpty)
                      Text(
                        chapter.arabicTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'QPC Hafs',
                          color: qt.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 5),
                    // Tertiary: virtue count — matches ayahs style
                    Text(
                      '${chapter.virtueCount} narrations',
                      style: TextStyle(
                        color: qt.textMuted.withValues(alpha: 0.8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.15,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Trailing: count pill + chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${chapter.virtueCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: qt.emeraldDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: qt.textMuted.withValues(alpha: 0.4),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL SCREEN — Full screen push, NOT modal
// ═══════════════════════════════════════════════════════════════════════════

class VirtueDetailScreen extends StatefulWidget {
  final QuranVirtueChapter chapter;

  const VirtueDetailScreen({super.key, required this.chapter});

  @override
  State<VirtueDetailScreen> createState() => _VirtueDetailScreenState();
}

class _VirtueDetailScreenState extends State<VirtueDetailScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final t = (offset / 80.0).clamp(0.0, 1.0);
    _headerAnimController.value = t;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const double appBarHeight = 56.0;
    final chapter = widget.chapter;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // ── Scrollable content ──
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              22,
              statusBarHeight + appBarHeight + 8,
              22,
              40,
            ),
            itemCount: chapter.virtues.length + 2,
            addRepaintBoundaries: true,
            cacheExtent: 500,
            itemBuilder: (context, index) {
              if (index == 0) {
                return RepaintBoundary(
                  child: _DetailHeroSection(chapter: chapter, isDark: isDark),
                );
              }
              if (index == 1) {
                return const SizedBox(height: 8);
              }
              final virtueIndex = index - 2;
              return RepaintBoundary(
                child: _VirtueCard(
                  virtue: chapter.virtues[virtueIndex],
                  index: virtueIndex,
                  total: chapter.virtues.length,
                  chapterTitle: chapter.englishTitle,
                  isDark: isDark,
                ),
              );
            },
          ),

          // ── Frosted Glass Header ──
          AnimatedBuilder(
            animation: _headerAnimController,
            builder: (context, child) {
              final t = _headerAnimController.value;
              final titleSize = 22.0 - (6.0 * t);
              final glassOpacity = t * 0.88;

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, statusBarHeight, 20, 0),
                  height: statusBarHeight + appBarHeight,
                  decoration: BoxDecoration(
                    color: (isDark
                            ? const Color(0xFF0C0C0E)
                            : const Color(0xFFF2F2F7))
                        .withValues(alpha: glassOpacity),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFFFFFFFF)
                                .withValues(alpha: t * 0.08)
                            : const Color(0xFF000000)
                                .withValues(alpha: t * 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ActionButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        isDark: isDark,
                        onTap: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              chapter.englishTitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: qt.textPrimary,
                                letterSpacing: -0.4 + (0.2 * t),
                              ),
                            ),
                            if (t > 0.3 && chapter.arabicTitle.isNotEmpty)
                              Opacity(
                                opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
                                child: Text(
                                  chapter.arabicTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: qt.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.tune_rounded,
                        isDark: isDark,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => const HadithReaderSettingsSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL HERO SECTION — With surahName calligraphy font
// ═══════════════════════════════════════════════════════════════════════════

class _DetailHeroSection extends StatelessWidget {
  final QuranVirtueChapter chapter;
  final bool isDark;

  const _DetailHeroSection({
    required this.chapter,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final surahNums = _relatedSurahNums(chapter.bookNum);
    final hasSurahs = surahNums.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          // ── Surah calligraphy names ──
          if (hasSurahs) ...[
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: surahNums.map((s) {
                final surahCode =
                    'surah${s.toString().padLeft(3, '0')}surah-icon';
                return Text(
                  surahCode,
                  style: TextStyle(
                    fontFamily: 'surahName',
                    fontSize: 44,
                    color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
                    height: 1.2,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],
          // ── Narration count pill ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories_rounded,
                    size: 14, color: qt.emeraldDeep),
                const SizedBox(width: 6),
                Text(
                  '${chapter.virtueCount} Narrations',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: qt.emeraldDeep,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DiamondDivider(color: isDark ? qt.emeraldGlow : qt.emeraldDeep),
          // ── Related Surah section (Read/Info chips) ──
          if (hasSurahs) ...[
            const SizedBox(height: 18),
            _RelatedSurahSection(
              surahNums: surahNums,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VIRTUE CARD — Multi-line reference support, premium redesign
// ═══════════════════════════════════════════════════════════════════════════

class _VirtueCard extends StatelessWidget {
  final QuranVirtue virtue;
  final int index;
  final int total;
  final String chapterTitle;
  final bool isDark;

  const _VirtueCard({
    required this.virtue,
    required this.index,
    required this.total,
    required this.chapterTitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1} of $total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: qt.emeraldDeep,
                    ),
                  ),
                ),
                const Spacer(),
                // Share
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _shareHadith(virtue, chapterTitle);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.share_rounded,
                      size: 15,
                      color: qt.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (virtue.grade.isNotEmpty)
                  _GradeBadge(grade: virtue.grade, isDark: isDark),
              ],
            ),
            // Title
            if (virtue.title.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                virtue.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: qt.textPrimary,
                  height: 1.35,
                  letterSpacing: -0.3,
                ),
              ),
            ],
            // Arabic
            if (settings.showArabic && virtue.arabicText.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ArabicBlock(
                text: virtue.arabicText,
                arabicFontSize: settings.arabicFontSize,
                isDark: isDark,
              ),
            ],
            // English
            if (settings.showEnglish && virtue.englishText.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                virtue.englishText
                    .trim()
                    .split('\n\n')
                    .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
                    .join('\n\n'),
                style: TextStyle(
                  fontSize: settings.translationFontSize,
                  color: qt.textSecondary,
                  height: 1.65,
                  letterSpacing: -0.1,
                ),
              ),
            ],
            // Reference footer — multi-line support with Column instead of Row
            if (virtue.localNum.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(height: 0.5, color: qt.borderGlass),
              const SizedBox(height: 12),
              // Using Column + Wrap instead of Row to allow wrapping
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 12,
                        color: qt.textMuted.withValues(alpha: 0.6),
                      ),
                      Text(
                        'Hadith #${virtue.localNum}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: qt.textMuted,
                          letterSpacing: 0.2,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ARABIC TEXT BLOCK
// ═══════════════════════════════════════════════════════════════════════════

class _ArabicBlock extends StatelessWidget {
  final String text;
  final double arabicFontSize;
  final bool isDark;

  const _ArabicBlock({
    required this.text,
    required this.arabicFontSize,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : qt.emeraldDeep.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : qt.emeraldDeep.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'IndoPak',
              fontSize: arabicFontSize,
              height: 1.8,
              color: qt.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _DiamondDivider(color: isDark ? qt.emeraldGlow : qt.emeraldDeep),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIAMOND DIVIDER
// ═══════════════════════════════════════════════════════════════════════════

class _DiamondDivider extends StatelessWidget {
  final Color color;

  const _DiamondDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 0.5, width: 36, color: color.withValues(alpha: 0.3)),
        Transform.rotate(
          angle: 0.7854,
          child: Container(
            height: 5,
            width: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(height: 0.5, width: 36, color: color.withValues(alpha: 0.3)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GRADE BADGE
// ═══════════════════════════════════════════════════════════════════════════

class _GradeBadge extends StatelessWidget {
  final String grade;
  final bool isDark;

  const _GradeBadge({required this.grade, required this.isDark});

  Color get _color {
    final lower = grade.toLowerCase();
    if (lower.contains('sahih') || lower.contains('authentic')) {
      return const Color(0xFF10B981);
    } else if (lower.contains('hasan') || lower.contains('good')) {
      return const Color(0xFFF59E0B);
    } else if (lower.contains('daif') || lower.contains('weak')) {
      return const Color(0xFFEF4444);
    }
    return Colors.grey.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RELATED SURAH SECTION — Redesigned as compact action chips
// ═══════════════════════════════════════════════════════════════════════════

class _RelatedSurahSection extends StatelessWidget {
  final List<int> surahNums;
  final bool isDark;

  const _RelatedSurahSection({required this.surahNums, required this.isDark});

  SurahInfo? _safeInfo(int s) {
    try {
      return QuranService.instance.surahInfoSync(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(BuildContext context, int surah, bool info) async {
    final list = await QuranService.instance.loadSurahList();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => info
            ? SurahInfoScreen(surahNumber: surah, surahList: list)
            : QuranReaderScreen(surahNumber: surah, surahList: list),
      ),
    );
  }

  Widget _actionChip(
    BuildContext context,
    int surah,
    bool info,
    IconData icon,
    String label,
    QuranTheme qt,
  ) {
    return GestureDetector(
      onTap: () => _open(context, surah, info),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: qt.emeraldDeep.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: qt.emeraldDeep),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: qt.emeraldDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Surah',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: qt.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...surahNums.map((s) {
          final info = _safeInfo(s);
          final name = info?.nameEnglish.isNotEmpty == true
              ? info!.nameEnglish
              : 'سورة $s';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: !isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: qt.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Surah $s',
                          style: TextStyle(
                            fontSize: 12,
                            color: qt.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _actionChip(
                    context,
                    s,
                    false,
                    Icons.book_rounded,
                    'Read',
                    qt,
                  ),
                  const SizedBox(width: 8),
                  _actionChip(
                    context,
                    s,
                    true,
                    Icons.info_outline_rounded,
                    'Info',
                    qt,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR / EMPTY CARDS
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorCard extends StatelessWidget {
  final Object? error;
  final QuranTheme qt;

  const _ErrorCard({this.error, required this.qt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 36, color: qt.textMuted),
          const SizedBox(height: 12),
          Text(
            'Unable to load virtues',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: qt.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error?.toString() ?? 'Unknown error',
            style: TextStyle(
              fontSize: 12,
              color: qt.textMuted,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final QuranTheme qt;

  const _EmptyCard({required this.qt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 36, color: qt.textMuted),
          const SizedBox(height: 12),
          Text(
            'No virtues found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: qt.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white : const Color(0xFF3A3A3C),
          ),
        ),
      ),
    );
  }
}
