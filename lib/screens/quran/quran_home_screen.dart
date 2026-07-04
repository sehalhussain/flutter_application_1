import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '/models/quran_models.dart';
import '/providers/quran_progress_provider.dart';
import '/providers/quran_settings_provider.dart';
import '/services/quran_service.dart';
import '/services/quran_audio_handler.dart';
import '/constants/juz_data.dart';
import '/constants/quran_theme.dart';
import 'quran_reader_screen.dart';

class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen>
    with SingleTickerProviderStateMixin {
  List<SurahInfo> _surahList = [];
  List<SurahInfo> _filtered = [];
  int _tabIndex = 0;
  bool _loading = true;

  final Map<int, SurahInfo> _surahCache = {};
  late final ScrollController _scrollController;
  Timer? _debounceTimer;
  final _searchCtrl = TextEditingController();
  final ValueNotifier<QuranBookmark?> _playingBookmarkNotifier =
      ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSurahs());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    _playingBookmarkNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      final list = await QuranService.instance.loadSurahList();
      if (!mounted) return;
      for (var surah in list) {
        _surahCache[surah.number] = surah;
      }
      setState(() {
        _surahList = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading surahs: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final lq = q.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _surahList
            : _surahList.where((s) {
                if (s.number.toString() == q) return true;
                if (s.nameEnglish.toLowerCase().contains(lq)) return true;
                if (s.nameMeaning.toLowerCase().contains(lq)) return true;
                return false;
              }).toList();
      });
    });
  }

  void _openReader(int surah, {int? initialAyah}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuranReaderScreen(
        surahNumber: surah,
        initialAyah: initialAyah,
        surahList: _surahList,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildHeader(qt, isDark),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                        strokeWidth: 1.5))
                : _buildBody(qt, isDark),
          ),
          _buildBottomNav(qt, isDark),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(QuranTheme qt, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(13),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: Center(
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: qt.textPrimary, size: 16),
              ),
            ),
          ),
          const Spacer(),
          Text('AL-QURAN',
              style: TextStyle(
                  fontSize: 11,
                  color: qt.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4)),
          const Spacer(),
          GestureDetector(
            onTap: _showQuickNavPanel,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(13),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: Center(
                child: Icon(Icons.search, color: qt.textPrimary, size: 18),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Text('القرآن الكريم',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'QPC Hafs',
                fontSize: 36,
                color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
                height: 1.2)),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────

  Widget _buildBody(QuranTheme qt, bool isDark) {
    int itemCount;
    switch (_tabIndex) {
      case 0:
        itemCount = _filtered.length + 2;
        break;
      case 1:
        itemCount = kJuzData.length + 2;
        break;
      case 2:
        itemCount = QuranProgressProvider.of(context).bookmarks.length + 2;
        break;
      case 3:
        itemCount = kPopularSections.length + 2;
        break;
      default:
        itemCount = 2;
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
      itemCount: itemCount,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        if (index == 0) {
          return RepaintBoundary(child: _buildRecentReadsStrip(qt, isDark));
        }
        if (index == 1) {
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
              child: _buildSearchBar(qt, isDark),
            ),
          );
        }

        final listIndex = index - 2;

        switch (_tabIndex) {
          case 0:
            if (_filtered.isEmpty) return _emptyState('No surahs found', qt);
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _SurahTile(
                  surah: _filtered[listIndex],
                  onTap: () => _openReader(_filtered[listIndex].number),
                  surahCache: _surahCache,
                  isDark: isDark,
                ),
              ),
            );
          case 1:
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _buildJuzTile(kJuzData[listIndex], qt, isDark),
              ),
            );
          case 2:
            final bms = QuranProgressProvider.of(context).bookmarks;
            if (bms.isEmpty) return _emptyState('No bookmarks yet', qt);
            final bm = bms[listIndex];
            final s = _surahCache[bm.surah] ?? _surahList.first;
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _BookmarkCard(
                  bookmark: bm,
                  surah: s,
                  translation: QuranSettingsProvider.of(context).translation,
                  onOpen: () => _openReader(bm.surah, initialAyah: bm.ayah),
                  playingBookmarkNotifier: _playingBookmarkNotifier,
                  isDark: isDark,
                ),
              ),
            );
          case 3:
            final item = kPopularSections[listIndex];
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: _buildPopularTile(item, qt, isDark),
              ),
            );
          default:
            return const SizedBox();
        }
      },
    );
  }

  Widget _emptyState(String text, QuranTheme qt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 120),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                color: qt.textMuted.withValues(alpha: 0.4), size: 48),
            const SizedBox(height: 16),
            Text(text,
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  // ── Continue Reading ──────────────────────────────────────────────────

  Widget _buildRecentReadsStrip(QuranTheme qt, bool isDark) {
    final progress = QuranProgressProvider.of(context);
    final sessions = progress.displayRecentReads;
    if (sessions.isEmpty) return const SizedBox(height: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Text('Continue Reading',
              style: TextStyle(
                  color: qt.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2)),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: sessions.length,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isFirst = index == 0;
              final timeAgo = _timeAgo(session.timestamp);

              return Padding(
                padding: EdgeInsets.only(
                    right: index < sessions.length - 1 ? 12 : 22),
                child: GestureDetector(
                  onTap: () =>
                      _openReader(session.surah, initialAyah: session.ayah),
                  onLongPress: () => _showSessionOptions(session, qt),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: isFirst
                          ? (isDark
                              ? qt.emeraldDeep.withValues(alpha: 0.1)
                              : qt.emeraldDeep.withValues(alpha: 0.08))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(18),
                      border: isFirst
                          ? Border.all(
                              color: qt.emeraldDeep.withValues(alpha: 0.2),
                              width: 1)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(session.surahName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: qt.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                            if (session.isAutoTracked) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Auto',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (isFirst)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: qt.emeraldDeep,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (isFirst) const SizedBox(width: 8),
                            Text('Ayah ${session.ayah}  ·  $timeAgo',
                                style: TextStyle(
                                  color: qt.textMuted,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  void _showSessionOptions(ReadingSession session, QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: qt.textMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading:
                    Icon(Icons.bookmark_add_outlined, color: qt.emeraldDeep),
                title: Text('Save as Bookmark',
                    style: TextStyle(
                        color: qt.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () {
                  QuranProgressProvider.of(context, listen: false)
                      .toggleBookmark(
                          session.surah, session.ayah, session.surahName);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Added to bookmarks'),
                    backgroundColor: Color(0xFF26A69A),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ));
                },
              ),
              Divider(height: 0.5, color: qt.borderGlass, indent: 20),
              if (session.isAutoTracked) ...[
                ListTile(
                  leading: const Icon(Icons.pin_rounded, color: Color(0xFF10B981)),
                  title: Text('Pin to Recent Reads',
                      style: TextStyle(
                          color: qt.textPrimary, fontWeight: FontWeight.w500)),
                  subtitle: Text('Save this position permanently',
                      style: TextStyle(color: qt.textMuted, fontSize: 12)),
                  onTap: () {
                    QuranProgressProvider.of(context, listen: false)
                        .addRecentRead(session.surah, session.ayah, session.surahName);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Pinned to recent reads'),
                      backgroundColor: qt.emeraldDeep,
                      behavior: SnackBarBehavior.floating,
                    ));
                  },
                ),
                Divider(height: 0.5, color: qt.borderGlass, indent: 20),
              ],
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(
                    session.isAutoTracked ? 'Clear Reading Position' : 'Remove from Recent',
                    style: TextStyle(
                        color: qt.textPrimary, fontWeight: FontWeight.w500)),
                onTap: () {
                  if (session.isAutoTracked) {
                    QuranProgressProvider.of(context, listen: false)
                        .clearAutoTracked();
                  } else {
                    QuranProgressProvider.of(context, listen: false)
                        .removeRecentRead(session.surah, session.ayah);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(QuranTheme qt, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: qt.textPrimary, fontSize: 16),
        cursorColor: qt.emeraldLight,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search surah…',
          hintStyle: TextStyle(
              color: qt.textMuted, fontSize: 15, fontWeight: FontWeight.w400),
          prefixIcon: Icon(Icons.search, color: qt.textMuted, size: 19),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ── Juz Tile ──────────────────────────────────────────────────────────

  Widget _buildJuzTile(JuzEntry j, QuranTheme qt, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openReader(j.startSurah, initialAyah: j.startAyah),
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
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text('${j.juzNumber}',
                    style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Juz ${j.juzNumber}',
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(j.startSurahName,
                    style: TextStyle(
                        color: qt.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)),
              ],
            )),
            Icon(Icons.chevron_right_rounded,
                color: qt.textMuted.withValues(alpha: 0.4), size: 20),
          ]),
        ),
      ),
    );
  }

  // ── Popular Tile ──────────────────────────────────────────────────────

  Widget _buildPopularTile(PopularSection item, QuranTheme qt, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openReader(item.surahNumber, initialAyah: item.startAyah),
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
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(Icons.auto_awesome_rounded,
                    color: qt.emeraldDeep, size: 22),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(item.arabicTitle,
                    style: TextStyle(
                        fontFamily: 'QPC Hafs',
                        color: qt.textSecondary,
                        fontSize: 18)),
              ],
            )),
            Icon(Icons.chevron_right_rounded,
                color: qt.textMuted.withValues(alpha: 0.4), size: 20),
          ]),
        ),
      ),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────

  Widget _buildBottomNav(QuranTheme qt, bool isDark) {
    const tabs = [
      (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Surah'),
      (Icons.layers_outlined, Icons.layers_rounded, 'Juz'),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved'),
      (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Popular'),
    ];

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8, top: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: isDark ? 0 : 20,
            offset: Offset(0, isDark ? 0 : -4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Icon(active ? tabs[i].$2 : tabs[i].$1,
                        color: active ? qt.emeraldDeep : qt.textMuted,
                        size: active ? 23 : 21),
                  ),
                  const SizedBox(height: 4),
                  Text(tabs[i].$3,
                      style: TextStyle(
                          color: active ? qt.emeraldDeep : qt.textMuted,
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showQuickNavPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QuickNavPanel(
        surahList: _surahList,
        onNavigate: (surah, ayah) => _openReader(surah, initialAyah: ayah),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Surah Tile — Proper card with shadow, Arabic name prominent
// ═══════════════════════════════════════════════════════════════════════════

class _SurahTile extends StatelessWidget {
  final SurahInfo surah;
  final VoidCallback onTap;
  final Map<int, SurahInfo> surahCache;
  final bool isDark;

  const _SurahTile({
    required this.surah,
    required this.onTap,
    required this.surahCache,
    required this.isDark,
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
              // De-emphasized number — just small muted text
              SizedBox(
                width: 28,
                child: Text(
                  '${surah.number}',
                  style: TextStyle(
                    color: qt.emeraldDeep.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Name + metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary
                    Text(
                      surah.nameEnglish,
                      style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.15,
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Secondary
                    Text(
                      surah.nameMeaning,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: qt.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Tertiary
                    Text(
                      '${surah.totalAyahs} Ayahs • ${surah.revelationType}',
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
              // Hero: Arabic name — large and prominent
              Text(
                'surah${surah.number.toString().padLeft(3, '0')}',
                style: TextStyle(
                  fontFamily: 'surahName',
                  fontSize: 44,
                  color: isDark ? qt.emeraldGlow : qt.emeraldDeep,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Bookmark Card — Spacious, elevated, no number badge
// ═══════════════════════════════════════════════════════════════════════════

class _BookmarkCard extends StatefulWidget {
  final QuranBookmark bookmark;
  final SurahInfo surah;
  final TranslationId translation;
  final VoidCallback onOpen;
  final ValueNotifier<QuranBookmark?> playingBookmarkNotifier;
  final bool isDark;

  const _BookmarkCard({
    required this.bookmark,
    required this.surah,
    required this.translation,
    required this.onOpen,
    required this.playingBookmarkNotifier,
    required this.isDark,
  });

  @override
  State<_BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends State<_BookmarkCard>
    with AutomaticKeepAliveClientMixin {
  bool _expanded = false;
  Future<AyahData?>? _ayahFuture;
  late final AudioPlayer _ayahAudio;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ayahAudio = QuranAudioHandler.instance.ayahPlayer;
    _playerStateSub =
        _ayahAudio.playerStateStream.listen(_onPlayerStateChanged);
    widget.playingBookmarkNotifier.addListener(_onNotifierChanged);
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    widget.playingBookmarkNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (!mounted) return;
    if (state.processingState == ProcessingState.completed ||
        state.processingState == ProcessingState.idle) {
      if (_isThisBookmarkActive) widget.playingBookmarkNotifier.value = null;
    }
    _syncPlayingState();
  }

  void _onNotifierChanged() {
    if (!mounted) return;
    _syncPlayingState();
  }

  void _syncPlayingState() {
    final state = _ayahAudio.playerState;
    final isActuallyPlaying = state.playing &&
        (state.processingState == ProcessingState.ready ||
            state.processingState == ProcessingState.buffering);
    final shouldShowPlaying = isActuallyPlaying && _isThisBookmarkActive;
    if (_isPlaying != shouldShowPlaying) {
      setState(() => _isPlaying = shouldShowPlaying);
    }
  }

  bool get _isThisBookmarkActive {
    final active = widget.playingBookmarkNotifier.value;
    if (active == null) return false;
    return active.surah == widget.bookmark.surah &&
        active.ayah == widget.bookmark.ayah;
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded && _ayahFuture == null) {
      final settings = QuranSettingsProvider.of(context, listen: false);
      _ayahFuture = QuranService.instance.loadAyah(
        widget.bookmark.surah,
        widget.bookmark.ayah,
        widget.translation,
        ayahReciterId: settings.selectedAyahReciterId,
      );
    }
  }

  Future<void> _togglePlayback(String? url) async {
    if (url == null) return;
    try {
      if (_isPlaying) {
        await _ayahAudio.pause();
        _syncPlayingState();
        return;
      }
      final surahAudio = QuranAudioHandler.instance.surahPlayer;
      if (surahAudio.playing) await surahAudio.stop();
      widget.playingBookmarkNotifier.value = widget.bookmark;
      await QuranAudioHandler.instance.setAyahSource(
        url,
        surahName: widget.surah.nameEnglish,
        ayahNumber: widget.bookmark.ayah,
      );
      await _ayahAudio.play();
      _syncPlayingState();
    } catch (e) {
      debugPrint('Bookmark audio error: $e');
      if (mounted) {
        widget.playingBookmarkNotifier.value = null;
        setState(() => _isPlaying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final qt = QuranTheme.of(context);
    final settings = QuranSettingsProvider.of(context);
    final bm = widget.bookmark;
    final isDark = widget.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggleExpanded,
            child: Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.surah.nameEnglish,
                              style: TextStyle(
                                  color: qt.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                          const SizedBox(height: 5),
                          Text('Ayah ${bm.ayah}  ·  ${widget.surah.nameArabic}',
                              style:
                                  TextStyle(color: qt.textMuted, fontSize: 13)),
                        ]),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: qt.textMuted.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ]),
              ),
              if (_expanded)
                FutureBuilder<AyahData?>(
                  future: _ayahFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation(qt.emeraldLight),
                                strokeWidth: 1.5),
                          ),
                        ),
                      );
                    }

                    final ayah = snapshot.data;
                    if (ayah == null) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Unable to load ayah details.',
                            style: TextStyle(color: qt.textMuted)),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Arabic
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : qt.emeraldDeep.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              ayah.arabicFor(settings.script),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily:
                                    settings.script == ArabicScript.indoPak
                                        ? 'IndoPak'
                                        : 'QPC Hafs',
                                fontFeatures:
                                    settings.script == ArabicScript.indoPak
                                        ? const [
                                            FontFeature.enable('liga'),
                                            FontFeature.enable('ccmp'),
                                          ]
                                        : null,
                                fontSize: settings.arabicFontSize,
                                color: qt.textPrimary,
                                height: 2.0,
                              ),
                            ),
                          ),
                          // Transliteration
                          if (settings.showTransliteration &&
                              ayah.transliteration.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(ayah.transliteration,
                                style: TextStyle(
                                    color: isDark
                                        ? qt.emeraldGlow
                                        : qt.emeraldDeep,
                                    fontSize: settings.translationFontSize,
                                    fontStyle: FontStyle.italic,
                                    height: 1.7)),
                          ],
                          const SizedBox(height: 14),
                          // Translation
                          Text(
                            ayah.translation,
                            textDirection: (widget.translation ==
                                        TranslationId.urJalandhari ||
                                    widget.translation ==
                                        TranslationId.urWahiuddin)
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: (widget.translation ==
                                          TranslationId.urJalandhari ||
                                      widget.translation ==
                                          TranslationId.urWahiuddin)
                                  ? 'Urdu'
                                  : 'QPC Hafs',
                              fontFeatures: (widget.translation ==
                                          TranslationId.urJalandhari ||
                                      widget.translation ==
                                          TranslationId.urWahiuddin)
                                  ? const [
                                      FontFeature.enable('liga'),
                                      FontFeature.enable('ccmp'),
                                    ]
                                  : null,
                              color: qt.textSecondary,
                              height: (widget.translation ==
                                          TranslationId.urJalandhari ||
                                      widget.translation ==
                                          TranslationId.urWahiuddin)
                                  ? 2.0
                                  : 1.7,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Action buttons
                          Row(children: [
                            if (ayah.audioUrl != null) ...[
                              _actionChip(
                                icon: _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                label: _isPlaying ? 'Pause' : 'Listen',
                                color: qt.emeraldDeep,
                                onTap: () => _togglePlayback(ayah.audioUrl),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: _actionChip(
                                icon: Icons.arrow_forward_rounded,
                                label: 'Open Surah',
                                color: qt.textPrimary,
                                onTap: widget.onOpen,
                                isDark: isDark,
                                isSubtle: true,
                              ),
                            ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isSubtle = false,
  }) {
    final qt = QuranTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isSubtle
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F2F7))
              : qt.emeraldDeep.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Quick Nav Panel
// ═══════════════════════════════════════════════════════════════════════════

class _QuickNavPanel extends StatefulWidget {
  final List<SurahInfo> surahList;
  final Function(int surah, int ayah) onNavigate;

  const _QuickNavPanel({required this.surahList, required this.onNavigate});

  @override
  State<_QuickNavPanel> createState() => _QuickNavPanelState();
}

class _QuickNavPanelState extends State<_QuickNavPanel> {
  int selectedSurah = 1;
  int selectedAyah = 1;

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final currentSurahInfo =
        widget.surahList.firstWhere((s) => s.number == selectedSurah);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: qt.textMuted.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            Text('Quick Navigation',
                style: TextStyle(
                    color: qt.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.close_rounded, color: qt.textMuted, size: 22),
            ),
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Surah', qt),
                    const SizedBox(height: 10),
                    _dropdown<int>(
                      value: selectedSurah,
                      items: widget.surahList
                          .map((s) => MapEntry(
                              s.number, '${s.number}. ${s.nameEnglish}'))
                          .toList(),
                      qt: qt,
                      isDark: isDark,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            selectedSurah = v;
                            selectedAyah = 1;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Ayah', qt),
                    const SizedBox(height: 10),
                    _dropdown<int>(
                      value: selectedAyah,
                      items: List.generate(
                              currentSurahInfo.totalAyahs, (i) => i + 1)
                          .map((a) => MapEntry(a, 'Ayah $a'))
                          .toList(),
                      qt: qt,
                      isDark: isDark,
                      onChanged: (v) {
                        if (v != null) setState(() => selectedAyah = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              widget.onNavigate(selectedSurah, selectedAyah);
            },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: qt.emeraldDeep,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: qt.emeraldDeep.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text('Navigate',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, QuranTheme qt) => Text(text,
      style: TextStyle(
          color: qt.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3));

  Widget _dropdown<T>({
    required T value,
    required List<MapEntry<T, String>> items,
    required QuranTheme qt,
    required bool isDark,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items
              .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      style: TextStyle(color: qt.textPrimary, fontSize: 14))))
              .toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: qt.textMuted, size: 20),
        ),
      ),
    );
  }
}
