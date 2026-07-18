import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/quran_models.dart';
import '../../services/quran_service.dart';
import '../../constants/quran_theme.dart';
import 'quran_reader_screen.dart';

class TafsirScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final String? initialAuthor;
  final List<SurahInfo> surahList;

  const TafsirScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    this.initialAuthor,
    required this.surahList,
  });

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen>
    with SingleTickerProviderStateMixin {
  late Future<TafsirResponse> _tafsirFuture;
  String? _selectedAuthor;
  bool _isDownloaded = false;

  late ScrollController _scrollController;
  late AnimationController _headerAnimController;

  static bool _authorMatches(String selected, String fromApi) {
    String normalize(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"['\-\s]"), '');
    final normalizedSelected = normalize(selected);
    final normalizedApi = normalize(fromApi);
    return normalizedSelected == normalizedApi ||
        normalizedApi.contains(normalizedSelected) ||
        normalizedSelected.contains(normalizedApi);
  }

  @override
  void initState() {
    super.initState();
    _tafsirFuture =
        QuranService.instance.getTafsir(widget.surahNumber, widget.ayahNumber);
    _selectedAuthor = widget.initialAuthor;
    _checkDownloaded();

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

  Future<void> _checkDownloaded() async {
    final offline = await QuranService.instance
        .getOfflineTafsir(widget.surahNumber, widget.ayahNumber);
    if (mounted) {
      setState(() {
        _isDownloaded = offline != null;
      });
    }
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
          FutureBuilder<TafsirResponse>(
            future: _tafsirFuture,
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
                      _tafsirFuture = QuranService.instance
                          .getTafsir(widget.surahNumber, widget.ayahNumber);
                    });
                  },
                );
              }

              if (!snapshot.hasData) {
                return _EmptyState(isDark: isDark);
              }

              final response = snapshot.data!;
              final authors = response.tafsirs.map((t) => t.author).toList();

              if (_selectedAuthor == null ||
                  !authors.any((a) => _authorMatches(_selectedAuthor!, a))) {
                _selectedAuthor = authors.isNotEmpty ? authors.first : null;
              }

              final selectedTafsir = response.tafsirs.firstWhere(
                (t) => _authorMatches(_selectedAuthor ?? '', t.author),
                orElse: () => response.tafsirs.first,
              );

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
                  // ── Hero Section ──
                  _TafsirHeroSection(
                    surahNumber: widget.surahNumber,
                    ayahNumber: widget.ayahNumber,
                    surahInfo: surahInfo,
                    response: response,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  // ── Author selector ──
                  if (authors.length > 1) ...[
                    _buildAuthorSelector(authors, qt, isDark),
                    const SizedBox(height: 12),
                  ],
                  // ── Tafsir content card ──
                  _TafsirContentCard(
                    selectedTafsir: selectedTafsir,
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
                              'Tafsir',
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
                                  '${surahInfo.nameEnglish} ${widget.ayahNumber}:${widget.surahNumber}',
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
                      // Download action
                      FutureBuilder<TafsirResponse>(
                        future: _tafsirFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(width: 40);
                          }
                          return _ActionButton(
                            icon: _isDownloaded
                                ? Icons.download_done_rounded
                                : Icons.download_rounded,
                            isDark: isDark,
                            onTap: _isDownloaded
                                ? null
                                : () async {
                                    HapticFeedback.selectionClick();
                                    await QuranService.instance
                                        .saveTafsirOffline(
                                      widget.surahNumber,
                                      widget.ayahNumber,
                                      snapshot.data!,
                                    );
                                    if (context.mounted) {
                                      setState(() => _isDownloaded = true);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                              'Tafsir saved for offline reading!'),
                                          backgroundColor: qt.emeraldDeep,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
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

  Widget _buildAuthorSelector(
      List<String> authors, QuranTheme qt, bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: authors.length,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final author = authors[index];
          final isSelected = _authorMatches(author, _selectedAuthor ?? '');

          return Padding(
            padding: EdgeInsets.only(right: index < authors.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedAuthor = author);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? qt.emeraldDeep.withValues(alpha: 0.1)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF2F2F7)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? qt.emeraldDeep.withValues(alpha: 0.2)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04)),
                  ),
                ),
                child: Text(
                  author,
                  style: TextStyle(
                    color: isSelected ? qt.emeraldDeep : qt.textMuted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
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

// ═══════════════════════════════════════════════════════════════════════════
// TAFSIR HERO SECTION — Calligraphy + ayah reference
// ═══════════════════════════════════════════════════════════════════════════

class _TafsirHeroSection extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final SurahInfo surahInfo;
  final TafsirResponse response;
  final bool isDark;

  const _TafsirHeroSection({
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahInfo,
    required this.response,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final surahCode = 'surah${surahNumber.toString().padLeft(3, '0')}';

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
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
          const SizedBox(height: 12),
          // ── Ayah reference pill ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 14, color: qt.emeraldDeep),
                const SizedBox(width: 6),
                Text(
                  '${surahInfo.nameEnglish} ${surahNumber}:${ayahNumber}',
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
          const SizedBox(height: 18),
          _DiamondDivider(color: isDark ? qt.emeraldGlow : qt.emeraldDeep),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAFSIR CONTENT CARD — Markdown in premium card
// ═══════════════════════════════════════════════════════════════════════════

class _TafsirContentCard extends StatelessWidget {
  // Using dynamic type to match whatever your TafsirResponse.tafsirs returns
  final dynamic selectedTafsir;
  final bool isDark;
  final ValueChanged<String> onLinkTap;

  const _TafsirContentCard({
    required this.selectedTafsir,
    required this.isDark,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    // Access properties dynamically to avoid type mismatch
    final author = selectedTafsir.author as String;
    final content = selectedTafsir.content as String;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: qt.emeraldDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: qt.emeraldDeep,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tafsir by',
                      style: TextStyle(
                        fontSize: 11,
                        color: qt.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: qt.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 0.5, color: qt.borderGlass),
          const SizedBox(height: 20),
          // Markdown content
          MarkdownBody(
            data: content,
            styleSheet: _buildMarkdownStyleSheet(qt, isDark),
            onTapLink: (text, href, title) {
              if (href != null) onLinkTap(href);
            },
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(QuranTheme qt, bool isDark) {
    return MarkdownStyleSheet(
      p: TextStyle(
        color: qt.textSecondary,
        fontSize: 15,
        height: 1.7,
      ),
      h1: TextStyle(
        color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: -0.3,
      ),
      h2: TextStyle(
        color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: -0.2,
      ),
      h3: TextStyle(
        color: qt.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h4: TextStyle(
        color: qt.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      listBullet: TextStyle(
        color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
        fontSize: 15,
      ),
      blockquote: TextStyle(
        color: qt.textSecondary,
        fontStyle: FontStyle.italic,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
            width: 3,
          ),
        ),
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : qt.emeraldDeep.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(12),
      code: TextStyle(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F2F7),
        fontFamily: 'monospace',
        fontSize: 13,
        color: qt.textPrimary,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      tableHead: TextStyle(
        color: qt.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
      tableBody: TextStyle(
        color: qt.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
      tableBorder: TableBorder(
        horizontalInside: BorderSide(color: qt.borderGlass),
        verticalInside: BorderSide(color: qt.borderGlass),
        top: BorderSide(color: qt.borderGlass),
        bottom: BorderSide(color: qt.borderGlass),
        left: BorderSide(color: qt.borderGlass),
        right: BorderSide(color: qt.borderGlass),
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      em: TextStyle(
        fontStyle: FontStyle.italic,
        color: qt.textMuted,
      ),
      strong: TextStyle(
        fontWeight: FontWeight.w700,
        color: qt.textPrimary,
      ),
      a: TextStyle(
        color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.none,
      ),
      img: TextStyle(color: qt.textPrimary),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: qt.borderGlass, width: 0.5),
        ),
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
              'Unable to load tafsir',
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
              'No tafsir available',
              style: TextStyle(
                color: qt.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This ayah does not have tafsir commentary yet.',
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
