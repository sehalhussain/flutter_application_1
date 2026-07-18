import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../models/quran_models.dart';
import '../../services/quran_service.dart';
import '../../constants/quran_theme.dart';
import 'quran_reader_screen.dart';

class SurahInfoScreen extends StatefulWidget {
  final int surahNumber;
  final List<SurahInfo> surahList;

  const SurahInfoScreen({
    super.key,
    required this.surahNumber,
    required this.surahList,
  });

  @override
  State<SurahInfoScreen> createState() => _SurahInfoScreenState();
}

class _SurahInfoScreenState extends State<SurahInfoScreen>
    with SingleTickerProviderStateMixin {
  late Future<SurahDetail> _detailFuture;
  late ScrollController _scrollController;
  late AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _detailFuture = QuranService.instance.getSurahDetail(widget.surahNumber);
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

    final surahInfo = widget.surahList.firstWhere(
      (s) => s.number == widget.surahNumber,
      orElse: () => widget.surahList.first,
    );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // ── Scrollable content ──
          FutureBuilder<SurahDetail>(
            future: _detailFuture,
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

              if (snapshot.hasError) {
                return _ErrorState(
                  error: snapshot.error,
                  isDark: isDark,
                  onRetry: () {
                    setState(() {
                      _detailFuture = QuranService.instance
                          .getSurahDetail(widget.surahNumber);
                    });
                  },
                );
              }

              if (!snapshot.hasData) {
                return _EmptyState(isDark: isDark);
              }

              final detail = snapshot.data!;

              return ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  22,
                  statusBarHeight + appBarHeight + 8,
                  22,
                  40,
                ),
                children: [
                  // ── Hero Section with calligraphy only ──
                  _SurahHeroSection(
                    surahNumber: widget.surahNumber,
                    surahInfo: surahInfo,
                    detail: detail,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  // ── Info content card ──
                  _InfoContentCard(
                    detail: detail,
                    isDark: isDark,
                    onLinkTap: _handleLink,
                  ),
                ],
              );
            },
          ),

          // ── Frosted Glass Header with dynamic surah name ──
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
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              surahInfo.nameEnglish,
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
                            if (t > 0.3)
                              Opacity(
                                opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0),
                                child: Text(
                                  'Surah ${widget.surahNumber}',
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
                      const SizedBox(width: 40), // Balance the back button
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

  void _handleLink(String url) {
    final parts = url.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final surahNum = int.tryParse(parts[0]);
      final ayahPart = parts[1];
      int? ayahNum;
      if (ayahPart.contains('-')) {
        ayahNum = int.tryParse(ayahPart.split('-')[0]);
      } else {
        ayahNum = int.tryParse(ayahPart);
      }

      if (surahNum != null && ayahNum != null) {
        HapticFeedback.selectionClick();
        if (surahNum == widget.surahNumber) {
          Navigator.of(context).pop({'ayah': ayahNum});
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QuranReaderScreen(
                surahNumber: surahNum,
                initialAyah: ayahNum,
                surahList: widget.surahList,
              ),
            ),
          );
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SURAH HERO SECTION — Calligraphy + metadata only (no English title)
// ═══════════════════════════════════════════════════════════════════════════

class _SurahHeroSection extends StatelessWidget {
  final int surahNumber;
  final SurahInfo surahInfo;
  final SurahDetail detail;
  final bool isDark;

  const _SurahHeroSection({
    required this.surahNumber,
    required this.surahInfo,
    required this.detail,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final surahCode = 'surah${surahNumber.toString().padLeft(3, '0')}';

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Column(
        children: [
          // ── surahName calligraphy ──
          Text(
            surahCode,
            style: TextStyle(
              fontFamily: 'surahName',
              fontSize: 56,
              color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          // ── Metadata pills ──
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetadataPill(
                icon: Icons.location_on_outlined,
                label: surahInfo.revelationType,
                isDark: isDark,
              ),
              _MetadataPill(
                icon: Icons.format_list_numbered_rounded,
                label: '${surahInfo.totalAyahs} Ayahs',
                isDark: isDark,
              ),
              _MetadataPill(
                icon: Icons.menu_book_outlined,
                label: 'Juz ${((surahNumber - 1) ~/ 2) + 1}',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DiamondDivider(color: isDark ? qt.emeraldGlow : qt.emeraldDeep),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INFO CONTENT CARD — HTML rendered in premium card
// ═══════════════════════════════════════════════════════════════════════════

class _InfoContentCard extends StatelessWidget {
  final SurahDetail detail;
  final bool isDark;
  final ValueChanged<String> onLinkTap;

  const _InfoContentCard({
    required this.detail,
    required this.isDark,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Container(
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
      child: HtmlWidget(
        detail.text,
        textStyle: TextStyle(
          color: qt.textPrimary.withValues(alpha: 0.9),
          fontSize: 15,
          height: 1.7,
        ),
        onTapUrl: (url) {
          onLinkTap(url);
          return true;
        },
        customStylesBuilder: (element) {
          if (element.localName == 'h2') {
            return {
              'color': _colorToHex(isDark ? qt.emeraldGlow : qt.emeraldDeep),
              'font-weight': '700',
              'font-size': '20px',
              'margin-top': '28px',
              'margin-bottom': '12px',
              'letter-spacing': '-0.3px',
            };
          }
          if (element.localName == 'h3') {
            return {
              'color': _colorToHex(qt.textPrimary),
              'font-weight': '600',
              'font-size': '17px',
              'margin-top': '20px',
              'margin-bottom': '8px',
            };
          }
          if (element.localName == 'p') {
            return {
              'margin-bottom': '14px',
              'color': _colorToHex(qt.textSecondary),
            };
          }
          if (element.localName == 'a') {
            return {
              'color': _colorToHex(isDark ? qt.emeraldGlow : qt.emeraldDeep),
              'text-decoration': 'none',
              'font-weight': '600',
            };
          }
          if (element.localName == 'em' || element.localName == 'i') {
            return {
              'font-style': 'italic',
              'color': _colorToHex(qt.textMuted),
            };
          }
          if (element.localName == 'strong' || element.localName == 'b') {
            return {
              'font-weight': '700',
              'color': _colorToHex(qt.textPrimary),
            };
          }
          if (element.localName == 'ul' || element.localName == 'ol') {
            return {
              'padding-left': '20px',
              'margin-bottom': '14px',
            };
          }
          if (element.localName == 'li') {
            return {
              'margin-bottom': '6px',
              'color': _colorToHex(qt.textSecondary),
            };
          }
          return null;
        },
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2)}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// METADATA PILL
// ═══════════════════════════════════════════════════════════════════════════

class _MetadataPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _MetadataPill({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: qt.emeraldDeep.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: qt.emeraldDeep),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: qt.emeraldDeep,
              letterSpacing: 0.2,
            ),
          ),
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
        Container(
          height: 0.5,
          width: 36,
          color: color.withValues(alpha: 0.3),
        ),
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
        Container(
          height: 0.5,
          width: 36,
          color: color.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ERROR STATE
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final Object? error;
  final bool isDark;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: qt.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load surah information',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textMuted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: qt.emeraldDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 16, color: qt.emeraldDeep),
                    const SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: qt.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No information available',
              style: TextStyle(
                color: qt.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This surah does not have detailed information yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED ACTION BUTTON
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
