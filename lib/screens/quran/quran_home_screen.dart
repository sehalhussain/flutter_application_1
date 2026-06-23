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

  // Cache for frequently accessed data
  final Map<int, SurahInfo> _surahCache = {};
  late final ScrollController _scrollController;

  // Optimized search debounce
  Timer? _debounceTimer;

  final _searchCtrl = TextEditingController();

  // Tracks which bookmark currently owns the global player.
  final ValueNotifier<QuranBookmark?> _playingBookmarkNotifier =
      ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSurahs();
    });
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

      // Build cache for O(1) lookups
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
      if (mounted) {
        setState(() => _loading = false);
      }
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
                // Early bailout for performance
                if (s.number.toString() == q) {
                  return true;
                }
                final nameEn = s.nameEnglish.toLowerCase();
                if (nameEn.contains(lq)) {
                  return true;
                }
                if (s.nameMeaning.toLowerCase().contains(lq)) {
                  return true;
                }
                return false;
              }).toList();
      });
    });
  }

  void _openReader(int surah, {int? initialAyah}) {
    // Pre-fetch next screen for smoother transition
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
    return Scaffold(
      backgroundColor: qt.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildHeader(qt),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                        strokeWidth: 2))
                : _buildBody(qt),
          ),
          _buildBottomNav(qt),
        ]),
      ),
    );
  }

  Widget _buildHeader(QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: qt.bg,
        border: Border(bottom: BorderSide(color: qt.borderGlass)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: _glassButton(
                Icon(Icons.arrow_back_ios_new_rounded,
                    color: qt.textPrimary, size: 18),
                qt),
          ),
          const Spacer(),
          Text('AL-QURAN',
              style: TextStyle(
                  fontSize: 12,
                  color: qt.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.0)),
          const Spacer(),
          _glassButton(
              Icon(Icons.search_rounded, color: qt.textPrimary, size: 20), qt,
              onTap: _showQuickNavPanel),
        ]),
        const SizedBox(height: 5),
        Text('القرآن الكريم',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'QPC Hafs',
                fontSize: 32,
                color: qt.brightness == Brightness.dark
                    ? qt.emeraldGlow
                    : qt.emeraldDeep,
                height: 1.2)),
        const SizedBox(height: 6),
        Text('The Holy Quran',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: qt.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _glassButton(Widget child, QuranTheme qt, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildBody(QuranTheme qt) {
    // Optimized item counting with caching
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
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      itemCount: itemCount,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        if (index == 0) {
          return RepaintBoundary(child: _buildRecentReadsStrip(qt));
        }
        if (index == 1) {
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _buildSearchBar(qt),
            ),
          );
        }

        final listIndex = index - 2;

        switch (_tabIndex) {
          case 0:
            if (_filtered.isEmpty) {
              return _emptyState('No surahs found', qt);
            }
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SurahTile(
                  surah: _filtered[listIndex],
                  onTap: () => _openReader(_filtered[listIndex].number),
                  surahCache: _surahCache,
                ),
              ),
            );
          case 1:
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _buildJuzTile(kJuzData[listIndex], qt),
              ),
            );
          case 2:
            final bms = QuranProgressProvider.of(context).bookmarks;
            if (bms.isEmpty) {
              return _emptyState('No bookmarks yet', qt);
            }
            final bm = bms[listIndex];
            final s = _surahCache[bm.surah] ?? _surahList.first;
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BookmarkCard(
                  bookmark: bm,
                  surah: s,
                  translation: QuranSettingsProvider.of(context).translation,
                  onOpen: () => _openReader(bm.surah, initialAyah: bm.ayah),
                  playingBookmarkNotifier: _playingBookmarkNotifier,
                ),
              ),
            );
          case 3:
            final item = kPopularSections[listIndex];
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _buildPopularTile(item, qt),
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
        padding: const EdgeInsets.only(top: 100),
        child: Text(text, style: TextStyle(color: qt.textMuted, fontSize: 16)),
      ),
    );
  }

  Widget _buildRecentReadsStrip(QuranTheme qt) {
    final progress = QuranProgressProvider.of(context);
    final sessions = progress.recentReads;

    if (sessions.isEmpty) {
      return const SizedBox(height: 16);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, color: qt.emeraldDeep, size: 14),
                  const SizedBox(width: 6),
                  Text('CONTINUE READING',
                      style: TextStyle(
                          color: qt.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ],
              ),
              const Spacer(),
              if (sessions.length > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${sessions.length}',
                      style: TextStyle(
                          color: qt.emeraldDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sessions.length,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isFirst = index == 0;
              final timeAgo = _timeAgo(session.timestamp);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: RepaintBoundary(
                  child: GestureDetector(
                    onTap: () =>
                        _openReader(session.surah, initialAyah: session.ayah),
                    onLongPress: () => _showSessionOptions(session, qt),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: isFirst
                            ? qt.emeraldDeep.withValues(alpha: 0.08)
                            : qt.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFirst
                              ? qt.emeraldDeep.withValues(alpha: 0.25)
                              : qt.borderGlass,
                          width: isFirst ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.surahName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: qt.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isFirst)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: qt.emeraldDeep,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Ayah ${session.ayah}',
                                style: TextStyle(
                                  color: qt.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: qt.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  color: qt.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
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
          border: Border(top: BorderSide(color: qt.borderGlass)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: qt.textMuted,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading:
                    Icon(Icons.bookmark_add_outlined, color: qt.emeraldDeep),
                title: Text('Save as Bookmark',
                    style: TextStyle(
                        color: qt.textPrimary, fontWeight: FontWeight.w600)),
                onTap: () {
                  final progress =
                      QuranProgressProvider.of(context, listen: false);
                  progress.toggleBookmark(
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
              Divider(height: 1, color: qt.borderGlass, indent: 16),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Remove from Recent',
                    style: TextStyle(
                        color: qt.textPrimary, fontWeight: FontWeight.w600)),
                onTap: () {
                  final progress =
                      QuranProgressProvider.of(context, listen: false);
                  progress.removeRecentRead(session.surah, session.ayah);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(QuranTheme qt) {
    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qt.borderGlass),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: qt.textPrimary, fontSize: 15),
        cursorColor: qt.emeraldLight,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search surah name, number…',
          hintStyle: TextStyle(color: qt.textMuted, fontSize: 14),
          prefixIcon:
              Icon(Icons.search_rounded, color: qt.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildJuzTile(JuzEntry j, QuranTheme qt) {
    return GestureDetector(
      onTap: () => _openReader(j.startSurah, initialAyah: j.startAyah),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Juz ${j.juzNumber}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Starts at ${j.startSurahName}',
                  style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text('Surah ${j.startSurah}, Ayah ${j.startAyah}',
                  style: TextStyle(color: qt.textMuted, fontSize: 11)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _buildPopularTile(PopularSection item, QuranTheme qt) {
    return GestureDetector(
      onTap: () => _openReader(item.surahNumber, initialAyah: item.startAyah),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                  child:
                      Icon(Icons.star_rounded, color: Colors.white, size: 22))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text(item.arabicTitle,
                  style: TextStyle(
                      fontFamily: 'QPC Hafs',
                      color: qt.textSecondary,
                      fontSize: 16)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _buildBottomNav(QuranTheme qt) {
    const tabs = [
      (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Surah'),
      (Icons.layers_outlined, Icons.layers_rounded, 'Juz'),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Bookmarks'),
      (Icons.star_border_rounded, Icons.star_rounded, 'Popular'),
    ];
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4, top: 4),
      decoration: BoxDecoration(
        color: qt.cardBg,
        border: Border(top: BorderSide(color: qt.borderGlass)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? tabs[i].$2 : tabs[i].$1,
                      color: active ? qt.emeraldDeep : qt.textMuted),
                  Text(tabs[i].$3,
                      style: TextStyle(
                          color: active ? qt.emeraldDeep : qt.textMuted,
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.normal)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Bookmark Card (Global Singleton Audio Handler)
// ─────────────────────────────────────────────────────────────────────────────
class _BookmarkCard extends StatefulWidget {
  final QuranBookmark bookmark;
  final SurahInfo surah;
  final TranslationId translation;
  final VoidCallback onOpen;
  final ValueNotifier<QuranBookmark?> playingBookmarkNotifier;

  const _BookmarkCard({
    required this.bookmark,
    required this.surah,
    required this.translation,
    required this.onOpen,
    required this.playingBookmarkNotifier,
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
      if (_isThisBookmarkActive) {
        widget.playingBookmarkNotifier.value = null;
      }
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

    final isThisActive = _isThisBookmarkActive;
    final shouldShowPlaying = isActuallyPlaying && isThisActive;

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

      // Stop any surah playback that might be active via the same singleton
      final surahAudio = QuranAudioHandler.instance.surahPlayer;
      if (surahAudio.playing) {
        await surahAudio.stop();
      }

      // Set this bookmark as the active one and load source with metadata
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                      child: Text('${bm.ayah}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.surah.nameEnglish,
                            style: TextStyle(
                                color: qt.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Ayah ${bm.ayah} • ${widget.surah.nameArabic}',
                            style: TextStyle(
                                color: qt.textSecondary, fontSize: 11)),
                      ]),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: qt.textMuted,
                ),
              ]),
            ),
          ),
        ),
        if (_expanded)
          FutureBuilder<AyahData?>(
            future: _ayahFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                          strokeWidth: 2),
                    ),
                  ),
                );
              }

              final ayah = snapshot.data;
              if (ayah == null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Unable to load ayah details.',
                      style: TextStyle(color: qt.textMuted)),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ayah.arabicFor(settings.script),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: settings.script == ArabicScript.indoPak
                            ? 'IndoPak'
                            : 'QPC Hafs',
                        fontFeatures: settings.script == ArabicScript.indoPak
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
                    if (settings.showTransliteration &&
                        ayah.transliteration.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(ayah.transliteration,
                          style: TextStyle(
                              color: qt.brightness == Brightness.dark
                                  ? qt.emeraldGlow
                                  : qt.emeraldDeep,
                              fontSize: settings.translationFontSize,
                              fontStyle: FontStyle.italic,
                              height: 1.6)),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      ayah.translation,
                      textDirection: (widget.translation ==
                                  TranslationId.urJalandhari ||
                              widget.translation == TranslationId.urWahiuddin)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: (widget.translation ==
                                    TranslationId.urJalandhari ||
                                widget.translation == TranslationId.urWahiuddin)
                            ? 'Urdu'
                            : 'QPC Hafs',
                        fontFeatures: (widget.translation ==
                                    TranslationId.urJalandhari ||
                                widget.translation == TranslationId.urWahiuddin)
                            ? const [
                                FontFeature.enable('liga'),
                                FontFeature.enable('ccmp'),
                              ]
                            : null,
                        color: qt.textSecondary,
                        height: (widget.translation ==
                                    TranslationId.urJalandhari ||
                                widget.translation == TranslationId.urWahiuddin)
                            ? 2.0
                            : 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      if (ayah.audioUrl != null) ...[
                        GestureDetector(
                          onTap: () => _togglePlayback(ayah.audioUrl),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: qt.emeraldDeep.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: qt.emeraldDeep,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isPlaying ? 'Pause' : 'Listen',
                                style: TextStyle(
                                    color: qt.emeraldDeep,
                                    fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onOpen,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: qt.glassWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: qt.borderGlass),
                            ),
                            child: Text('Open Surah',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: qt.textPrimary,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              );
            },
          ),
      ]),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahInfo surah;
  final VoidCallback onTap;
  final Map<int, SurahInfo> surahCache;

  const _SurahTile({
    required this.surah,
    required this.onTap,
    required this.surahCache,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text('${surah.number}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(surah.nameEnglish,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(surah.nameMeaning,
                    style: TextStyle(color: qt.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Row(children: [
                  _pill(
                      surah.revelationType,
                      surah.revelationType == 'Meccan'
                          ? const Color(0xFF78350F)
                          : const Color(0xFF1E3A5F),
                      qt),
                  const SizedBox(width: 6),
                  _pill('${surah.totalAyahs} Ayahs', qt.emeraldDeep, qt),
                ]),
              ],
            )),
            Text(surah.nameArabic,
                style: TextStyle(
                    fontFamily: 'IndopakN',
                    fontSize: 22,
                    color: qt.emeraldDeep)),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String label, Color bg, QuranTheme qt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style:
                TextStyle(color: bg, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}

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
    final currentSurahInfo =
        widget.surahList.firstWhere((s) => s.number == selectedSurah);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Quick Navigation',
                style: TextStyle(
                    color: qt.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.close_rounded, color: qt.textMuted),
            ),
          ]),
          const SizedBox(height: 20),
          Row(
            children: [
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dropdownLabel('Surah', qt),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: qt.glassWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: qt.borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedSurah,
                          items: widget.surahList.map((s) {
                            return DropdownMenuItem(
                              value: s.number,
                              child: Text('${s.number}. ${s.nameEnglish}',
                                  style: TextStyle(
                                      color: qt.textPrimary, fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                selectedSurah = v;
                                selectedAyah = 1;
                              });
                            }
                          },
                          icon: Icon(Icons.arrow_drop_down_rounded,
                              color: qt.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dropdownLabel('Ayah', qt),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: qt.glassWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: qt.borderGlass),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedAyah,
                          items: List.generate(
                                  currentSurahInfo.totalAyahs, (i) => i + 1)
                              .map((ayah) {
                            return DropdownMenuItem(
                              value: ayah,
                              child: Text('Ayah $ayah',
                                  style: TextStyle(
                                      color: qt.textPrimary, fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => selectedAyah = v);
                          },
                          icon: Icon(Icons.arrow_drop_down_rounded,
                              color: qt.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              widget.onNavigate(selectedSurah, selectedAyah);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text('Navigate',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownLabel(String text, QuranTheme qt) => Text(text,
      style: TextStyle(
          color: qt.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));
}
