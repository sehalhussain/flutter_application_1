// lib/screens/quran_virtues_screen.dart
//
// Premium screen for Quran Virtues (Fadāʾil al-Qurʾān).
// Scroll-linked frosted-glass header, clean emerald calligraphy,
// Apple-inspired card hierarchy, per-hadith share via share_plus.

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
// PRE-COMPUTED COLOUR & DECORATION CACHE
// ═══════════════════════════════════════════════════════════════════════════

class _Pal {
  _Pal(QuranTheme qt) {
    final d = qt.brightness == Brightness.dark;
    isDark = d;

    // ── Backgrounds ──
    appBg = d ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7);
    cardBg = d ? const Color(0xFF1A1A1C) : const Color(0xFFFFFFFF);
    cardBorder = d ? const Color(0x14FFFFFF) : const Color(0x0C000000);
    cardShadowColor = d ? Colors.transparent : const Color(0x08000000);
    divider = d ? const Color(0x12FFFFFF) : const Color(0x10000000);
    btnBg = d ? const Color(0x1AFFFFFF) : const Color(0x0A000000);

    // ── Text ──
    textPrimary = qt.textPrimary;
    textSecondary = qt.textSecondary;
    textMuted = qt.textMuted;
    iconColor = d ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C);

    // ── Emerald accent ──
    emerald = d ? qt.emeraldLight : qt.emeraldDeep;
    emeraldTint = emerald.withOpacity(d ? 0.12 : 0.07);
    emeraldBorder = emerald.withOpacity(d ? 0.10 : 0.06);
    emeraldBlockBg = emerald.withOpacity(d ? 0.05 : 0.025);
    emeraldDiamond = emerald.withOpacity(d ? 0.25 : 0.20);

    // ── Pre-built decorations ──
    final bdr = Border.all(color: cardBorder);
    final shadow = d
        ? null
        : [
            BoxShadow(
              color: cardShadowColor,
              blurRadius: 14,
              offset: const Offset(0, 2),
            )
          ];

    cardDec = BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      border: bdr,
      boxShadow: shadow,
    );

    virtueCardDec = BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      border: bdr,
      boxShadow: shadow,
    );

    emeraldBlockDec = BoxDecoration(
      color: emeraldBlockBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: emeraldBorder),
    );

    numBadgeDec = BoxDecoration(
      color: emeraldTint,
      borderRadius: BorderRadius.circular(10),
    );

    pillDec = BoxDecoration(
      color: emeraldTint,
      borderRadius: BorderRadius.circular(100),
    );

    btnDec = BoxDecoration(
      color: btnBg,
      borderRadius: BorderRadius.circular(12),
    );

    shareBtnDec = BoxDecoration(
      color: btnBg,
      shape: BoxShape.circle,
    );

    relatedCardDec = BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      border: bdr,
    );
  }

  late final bool isDark;
  late final Color appBg, cardBg, cardBorder, cardShadowColor;
  late final Color divider, btnBg;
  late final Color textPrimary, textSecondary, textMuted, iconColor;
  late final Color emerald, emeraldTint, emeraldBorder, emeraldBlockBg;
  late final Color emeraldDiamond;

  late final BoxDecoration cardDec, virtueCardDec, emeraldBlockDec;
  late final BoxDecoration numBadgeDec, pillDec, btnDec, shareBtnDec;
  late final BoxDecoration relatedCardDec;
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

class _QuranVirtuesScreenState extends State<QuranVirtuesScreen> {
  late Future<List<QuranVirtueChapter>> _chaptersFuture;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = QuranVirtuesDb.instance.loadAllChapters();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    final p = _Pal(qt);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const double appBarHeight = 56.0;

    return Scaffold(
      backgroundColor: p.appBg,
      body: Stack(
        children: [
          // ── Scrollable content (NO extra top gap so it slides under header) ──
          FutureBuilder<List<QuranVirtueChapter>>(
            future: _chaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(p.emerald),
                      strokeWidth: 1.5,
                    ),
                  ),
                );
              }

              final chapters = snapshot.data ?? [];

              return ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                // Flush against the header bottom so it scrolls behind it
                padding: EdgeInsets.fromLTRB(
                  20,
                  statusBarHeight + appBarHeight,
                  20,
                  40,
                ),
                children: [
                  // Hero section (NO fading logic, just scrolls up naturally)
                  _MainHeroSection(p: p),
                  const SizedBox(height: 28),

                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Chapters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (snapshot.hasError)
                    _ErrorCard(error: snapshot.error, p: p)
                  else if (chapters.isEmpty)
                    _EmptyCard(p: p)
                  else
                    ...chapters.asMap().entries.map((e) => _ChapterCard(
                          chapter: e.value,
                          index: e.key,
                          p: p,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VirtueDetailScreen(chapter: e.value),
                              ),
                            );
                          },
                        )),
                ],
              );
            },
          ),

          // ── Frosted Glass Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                final offset = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;
                final t = (offset / 80.0).clamp(0.0, 1.0);
                final titleSize = 24.0 - (8.0 * t);

                // Simulated Glass Effect: 0% opaque at top -> 88% opaque when scrolled
                // Avoids BackdropFilter to maintain 60fps on older devices
                final glassOpacity = t * 0.88;

                return Container(
                  padding: EdgeInsets.fromLTRB(20, statusBarHeight, 20, 0),
                  height: statusBarHeight + appBarHeight,
                  decoration: BoxDecoration(
                    color: p.appBg.withOpacity(glassOpacity),
                    border: Border(
                      bottom: BorderSide(
                        color: p.isDark
                            ? const Color(0xFFFFFFFF).withOpacity(t * 0.08)
                            : const Color(0xFF000000).withOpacity(t * 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _actionBtn(
                        Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: p.iconColor),
                        p: p,
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
                            color: p.textPrimary,
                            letterSpacing: -0.5 + (0.3 * t),
                          ),
                        ),
                      ),
                      _actionBtn(
                        Icon(Icons.tune_rounded, size: 18, color: p.iconColor),
                        p: p,
                        onTap: _openSettings,
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// MAIN HERO SECTION — No fading, scrolls natively behind header
// ═══════════════════════════════════════════════════════════════════════════

class _MainHeroSection extends StatelessWidget {
  final _Pal p;

  const _MainHeroSection({required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4, right: 4),
      child: Column(
        children: [
          Text(
            'فَضَائِلُ الْقُرْآنِ',
            style: TextStyle(
              fontFamily: 'QPC Hafs',
              fontSize: 26,
              color: p.emerald,
              height: 1.6,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _DiamondDivider(p: p),
          const SizedBox(height: 16),
          Text(
            'An authenticated collection of Prophet ﷺ hadith highlighting the unique virtues, rewards, and protections of various sūrahs and āyāt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: p.textMuted,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHAPTER CARD
// ═══════════════════════════════════════════════════════════════════════════

class _ChapterCard extends StatelessWidget {
  final QuranVirtueChapter chapter;
  final int index;
  final _Pal p;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapter,
    required this.index,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: p.cardDec,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: p.numBadgeDec,
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: p.emerald,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.englishTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (chapter.arabicTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        chapter.arabicTitle,
                        style: TextStyle(fontSize: 13, color: p.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: p.pillDec,
                child: Text(
                  '${chapter.virtueCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.emerald,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: p.textMuted.withOpacity(0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class VirtueDetailScreen extends StatefulWidget {
  final QuranVirtueChapter chapter;

  const VirtueDetailScreen({super.key, required this.chapter});

  @override
  State<VirtueDetailScreen> createState() => _VirtueDetailScreenState();
}

class _VirtueDetailScreenState extends State<VirtueDetailScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final p = _Pal(qt);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const double appBarHeight = 56.0;
    final chapter = widget.chapter;

    return Scaffold(
      backgroundColor: p.appBg,
      body: Stack(
        children: [
          // ── Scrollable content ──
          // Flat ListView(children:) — the proven structure that avoids any
          // ParentDataWidget issues while scrolling. Heavy model parsing is
          // already off the UI thread (compute isolate in the DB layer) and
          // the palette is reused, so first-frame cost stays minimal.
          ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            // Flush against the header bottom so it scrolls behind it
            padding: EdgeInsets.fromLTRB(
              20,
              statusBarHeight + appBarHeight,
              20,
              40,
            ),
            children: [
              // Hero — scrolls natively up behind glass header
              _DetailHeroSection(chapter: chapter, p: p),
              const SizedBox(height: 8),
              ...chapter.virtues.asMap().entries.map((e) => _VirtueCard(
                    virtue: e.value,
                    index: e.key,
                    total: chapter.virtues.length,
                    p: p,
                    chapterTitle: chapter.englishTitle,
                  )),
            ],
          ),

          // ── Frosted Glass Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                final offset = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;
                final t = (offset / 80.0).clamp(0.0, 1.0);
                final titleSize = 22.0 - (6.0 * t);

                final glassOpacity = t * 0.88;

                return Container(
                  padding: EdgeInsets.fromLTRB(20, statusBarHeight, 20, 0),
                  height: statusBarHeight + appBarHeight,
                  decoration: BoxDecoration(
                    color: p.appBg.withOpacity(glassOpacity),
                    border: Border(
                      bottom: BorderSide(
                        color: p.isDark
                            ? const Color(0xFFFFFFFF).withOpacity(t * 0.08)
                            : const Color(0xFF000000).withOpacity(t * 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _actionBtn(
                        Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: p.iconColor),
                        p: p,
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
                                color: p.textPrimary,
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
                                      fontSize: 11, color: p.textMuted),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _actionBtn(
                        Icon(Icons.tune_rounded, size: 18, color: p.iconColor),
                        p: p,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DETAIL HERO SECTION — No fading, scrolls natively behind header
// ═══════════════════════════════════════════════════════════════════════════

class _DetailHeroSection extends StatelessWidget {
  final QuranVirtueChapter chapter;
  final _Pal p;

  const _DetailHeroSection({
    required this.chapter,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4, left: 4, right: 4),
      child: Column(
        children: [
          if (chapter.arabicTitle.isNotEmpty) ...[
            Text(
              chapter.arabicTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'QPC Hafs',
                fontSize: 28,
                color: p.emerald,
                height: 1.8,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: p.pillDec,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories_rounded, size: 14, color: p.emerald),
                const SizedBox(width: 6),
                Text(
                  '${chapter.virtueCount} Narrations',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.emerald,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DiamondDivider(p: p),
          if (_relatedSurahNums(chapter.bookNum).isNotEmpty) ...[
            const SizedBox(height: 18),
            _RelatedSurahSection(
              surahNums: _relatedSurahNums(chapter.bookNum),
              p: p,
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VIRTUE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _VirtueCard extends StatelessWidget {
  final QuranVirtue virtue;
  final int index;
  final int total;
  final _Pal p;
  final String chapterTitle;

  const _VirtueCard({
    required this.virtue,
    required this.index,
    required this.total,
    required this.p,
    required this.chapterTitle,
  });

  @override
  Widget build(BuildContext context) {
    final settings = HadithReaderSettingsProvider.of(context, listen: true);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: p.virtueCardDec,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.emerald,
                  ),
                ),
                Text(
                  ' of $total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.textMuted,
                  ),
                ),
                const Spacer(),

                // Share Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _shareHadith(virtue, chapterTitle);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: p.shareBtnDec,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.share_rounded,
                      size: 14,
                      color: p.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                if (virtue.grade.isNotEmpty)
                  _GradeBadge(grade: virtue.grade, isDark: p.isDark),
              ],
            ),
            if (virtue.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                virtue.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                  height: 1.35,
                  letterSpacing: -0.3,
                ),
              ),
            ],
            if (settings.showArabic && virtue.arabicText.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ArabicBlock(text: virtue.arabicText, p: p),
            ],
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
                  color: p.textSecondary,
                  height: 1.65,
                  letterSpacing: -0.1,
                ),
              ),
            ],
            if (virtue.localNum.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(height: 0.5, color: p.divider),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                runSpacing: 2, // Adds a tiny bit of space between wrapped lines
                children: [
                  Icon(Icons.tag_rounded,
                      size: 12, color: p.textMuted.withOpacity(0.6)),
                  // NOTE: Do NOT wrap the Text in Flexible/Expanded here — a
                  // Wrap only accepts WrapParentData, and Flexible requires a
                  // Flex ancestor, which throws ParentDataWidget at layout time.
                  Text(
                    'Hadith #${virtue.localNum}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.textMuted,
                      letterSpacing: 0.2,
                      height: 1.4, // Ensures nice line spacing if it wraps
                    ),
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
  final _Pal p;

  const _ArabicBlock({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: p.emeraldBlockDec,
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'QPC Hafs',
              fontSize: 20,
              height: 1.8,
              color: p.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _DiamondDivider(p: p),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIAMOND DIVIDER
// ═══════════════════════════════════════════════════════════════════════════

class _DiamondDivider extends StatelessWidget {
  final _Pal p;

  const _DiamondDivider({required this.p});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(height: 0.5, width: 36, color: p.emeraldDiamond),
        Transform.rotate(
          angle: 0.7854,
          child: Container(
            height: 4,
            width: 4,
            decoration: BoxDecoration(
              color: p.emerald,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(height: 0.5, width: 36, color: p.emeraldDiamond),
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
      return Colors.green.shade600;
    } else if (lower.contains('hasan') || lower.contains('good')) {
      return Colors.orange.shade600;
    } else if (lower.contains('daif') || lower.contains('weak')) {
      return Colors.red.shade400;
    }
    return Colors.grey.shade500;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RELATED SURAH SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _RelatedSurahSection extends StatelessWidget {
  final List<int> surahNums;
  final _Pal p;

  const _RelatedSurahSection({required this.surahNums, required this.p});

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

  Widget _chip(
    BuildContext context,
    int surah,
    bool info,
    IconData icon,
    String label,
  ) {
    return GestureDetector(
      onTap: () => _open(context, surah, info),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: p.emeraldTint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: p.emerald),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.emerald,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Surah',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        ...surahNums.map((s) {
          final info = _safeInfo(s);
          final name = info?.nameEnglish.isNotEmpty == true
              ? info!.nameEnglish
              : 'سورة $s';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: p.relatedCardDec,
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
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Surah $s',
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _chip(context, s, false, Icons.book_rounded, 'Read'),
                  const SizedBox(width: 8),
                  _chip(context, s, true, Icons.info_outline_rounded, 'Info'),
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
  final _Pal p;

  const _ErrorCard({this.error, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: p.cardDec,
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 36, color: p.textMuted),
          const SizedBox(height: 12),
          Text(
            'Unable to load virtues',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error?.toString() ?? 'Unknown error',
            style: TextStyle(
              fontSize: 12,
              color: p.textMuted,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final _Pal p;

  const _EmptyCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: p.cardDec,
      child: Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 36, color: p.textMuted),
          const SizedBox(height: 12),
          Text(
            'No virtues found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
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

Widget _actionBtn(Widget child, {required _Pal p, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: p.btnDec,
      child: Center(child: child),
    ),
  );
}
