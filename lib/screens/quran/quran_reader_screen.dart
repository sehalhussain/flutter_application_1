import 'dart:ui';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import '/models/quran_models.dart';
import '/models/downloadable_translation.dart';
import '/services/quran_service.dart';
import '/services/translation_download_service.dart';
import '/providers/quran_settings_provider.dart';
import '/providers/quran_progress_provider.dart';
import '/constants/quran_theme.dart';
import '/constants/sajdah_data.dart';
import '/constants/juz_metadata_data.dart';
import 'tafsir_screen.dart';
import 'surah_info_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Quran Reader Screen
// ─────────────────────────────────────────────────────────────────────────────
class QuranReaderScreen extends StatefulWidget {
  final int surahNumber;
  final int? initialAyah;
  final List<SurahInfo> surahList;

  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialAyah,
    required this.surahList,
  });

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  // ── Core data ───────────────────────────────────────────────────────────
  List<AyahData> _ayahs = [];
  late List<Object> _displayItems;
  bool _loading = true;

  // ── ValueNotifiers for High-Performance Localized Rebuilds ──────────────
  // Using ValueNotifier eliminates full screen UI freezes on low-end devices.
  final ValueNotifier<int?> _playingAyahNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _selectedAyahNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _openMenuAyahNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _openTafsirAyahNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isPlayingSurahNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isAyahAudioPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<double?> _downloadProgressNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isSurahDownloadedNotifier = ValueNotifier(false);

  // ── Playback state ──────────────────────────────────────────────────────
  bool _isAutoContinuing = false;
  final _ayahAudio = AudioPlayer();
  final _surahAudio = AudioPlayer();

  // ── UI state ────────────────────────────────────────────────────────────
  bool _isNavOpen = false;
  int? _highlightedAyah;

  // ── Metadata ────────────────────────────────────────────────────────────
  SurahAudio? _surahAudioData;
  Map<String, int> _juzStarts = {};
  Map<int, JuzMetadataEntry> _juzMetadataMap = {};
  Map<String, SajdahMetadata> _sajdahMetadata = {};

  // ── Scrolling ───────────────────────────────────────────────────────────
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // ── Derived ─────────────────────────────────────────────────────────────
  SurahInfo? get _surahInfo =>
      widget.surahList.firstWhere((s) => s.number == widget.surahNumber,
          orElse: () => widget.surahList.first);
  SurahInfo? get _prevSurah => widget.surahList
      .where((s) => s.number == widget.surahNumber - 1)
      .firstOrNull;
  SurahInfo? get _nextSurah => widget.surahList
      .where((s) => s.number == widget.surahNumber + 1)
      .firstOrNull;

  // ── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _configureAudioSession();
    _initConstantData();
    _loadAyahs();

    _ayahAudio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) _onAyahComplete();
    });

    // Listen to playing states and update notifiers WITHOUT calling setState
    _ayahAudio.playingStream.listen((playing) {
      _isAyahAudioPlayingNotifier.value = playing;
    });

    _surahAudio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlayingSurahNotifier.value = false;
      }
    });
  }

  @override
  void dispose() {
    _ayahAudio.dispose();
    _surahAudio.dispose();
    _playingAyahNotifier.dispose();
    _selectedAyahNotifier.dispose();
    _openMenuAyahNotifier.dispose();
    _openTafsirAyahNotifier.dispose();
    _isPlayingSurahNotifier.dispose();
    _isAyahAudioPlayingNotifier.dispose();
    _downloadProgressNotifier.dispose();
    _isSurahDownloadedNotifier.dispose();
    super.dispose();
  }

  // ── Init compile-time data once ─────────────────────────────────────────
  void _initConstantData() {
    _juzMetadataMap = kJuzMetadata;
    _sajdahMetadata = kSajdahData;
    _juzStarts = {
      for (int j = 1; j <= 30; j++)
        if (kJuzMetadata[j] != null) kJuzMetadata[j]!.firstVerseKey: j,
    };
  }

  // ── Build display list (ayah indices + juz dividers) ───────────────────
  void _rebuildDisplayItems() {
    final items = <Object>[];
    for (int i = 0; i < _ayahs.length; i++) {
      final verseKey = _ayahs[i].verseKey;
      if (_juzStarts.containsKey(verseKey)) {
        final juzNum = _juzStarts[verseKey]!;
        if (juzNum > 1) items.add(_JuzDividerData(juzNumber: juzNum));
      }
      items.add(i);
    }
    _displayItems = items;
  }

  // ── Data loading ────────────────────────────────────────────────────────
  Future<void> _loadAyahs() async {
    if (!mounted) return;
    final settings = QuranSettingsProvider.of(context, listen: false);
    List<AyahData> ayahs = [];

    try {
      if (settings.customTranslationId != null) {
        final downloaded = await TranslationDownloadService.instance
            .checkIfDownloaded(settings.customTranslationId!);
        if (!downloaded) await settings.setTranslation(TranslationId.enSahih);
      }
      ayahs = await QuranService.instance.loadAyahs(
        widget.surahNumber,
        settings.translation,
        ayahReciterId: settings.selectedAyahReciterId,
        customTranslationId: settings.customTranslationId,
      );
    } catch (_) {
      await settings.setTranslation(TranslationId.enSahih);
      ayahs = await QuranService.instance.loadAyahs(
        widget.surahNumber,
        TranslationId.enSahih,
        ayahReciterId: settings.selectedAyahReciterId,
        customTranslationId: null,
      );
    }

    if (!mounted) return;
    setState(() {
      _ayahs = ayahs;
      _rebuildDisplayItems();
      _loading = false;
    });

    _fetchSurahAudioAndCheckDownload();

    if (widget.initialAyah != null) {
      _highlightedAyah = widget.initialAyah;
      _selectedAyahNotifier.value = widget.initialAyah;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(widget.initialAyah!);
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedAyah = null);
      });
    }
  }

  Future<void> _fetchSurahAudioAndCheckDownload() async {
    try {
      final audio =
          await QuranService.instance.getSurahAudio(widget.surahNumber);
      if (mounted) setState(() => _surahAudioData = audio);
    } catch (_) {}

    final downloaded = await _checkSurahDownloaded();
    if (mounted) _isSurahDownloadedNotifier.value = downloaded;
  }

  Future<void> _reloadTranslation() async {
    final settings = QuranSettingsProvider.of(context, listen: false);
    try {
      if (settings.customTranslationId != null) {
        final downloaded = await TranslationDownloadService.instance
            .checkIfDownloaded(settings.customTranslationId!);
        if (!downloaded) await settings.setTranslation(TranslationId.enSahih);
      }
      final updated = await QuranService.instance.reloadTranslation(
        _ayahs,
        settings.translation,
        customTranslationId: settings.customTranslationId,
      );
      if (!mounted) return;
      setState(() => _ayahs = updated);
    } catch (_) {
      await settings.setTranslation(TranslationId.enSahih);
      final updated = await QuranService.instance.reloadTranslation(
        _ayahs,
        TranslationId.enSahih,
        customTranslationId: null,
      );
      if (!mounted) return;
      setState(() => _ayahs = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Translation failed to load. Fell back to English.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Audio session ───────────────────────────────────────────────────────
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: true,
      ));
      await session.setActive(true);
    } catch (_) {}
  }

  // ── Scroll helpers ──────────────────────────────────────────────────────
  int _ayahScrollIndex(int ayahNumber) {
    final target = _ayahs.indexWhere((a) => a.ayahNumber == ayahNumber);
    if (target < 0) return -1;
    int dividersBefore = 0;
    for (int i = 0; i <= target; i++) {
      final vk = _ayahs[i].verseKey;
      if (_juzStarts.containsKey(vk) && _juzStarts[vk]! > 1) dividersBefore++;
    }
    return target + dividersBefore + 1;
  }

  Future<void> _scrollToAyah(int ayahNumber) async {
    final idx = _ayahScrollIndex(ayahNumber);
    if (idx < 0 || !mounted) return;
    for (int i = 0; i < 10 && !_itemScrollController.isAttached; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
    }
    if (mounted && _itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: idx,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    }
  }

  // ── Ayah playback ──────────────────────────────────────────────────────
  Future<void> _playAyah(int ayahNumber, {bool scroll = true}) async {
    final ayah = _ayahs.firstWhere((a) => a.ayahNumber == ayahNumber,
        orElse: () => _ayahs.first);
    if (ayah.audioUrl == null) return;

    if (_playingAyahNotifier.value == ayahNumber) {
      if (_ayahAudio.playing) {
        await _ayahAudio.pause();
      } else {
        await _ayahAudio.play();
      }
      return;
    }

    await _ayahAudio.stop();
    _playingAyahNotifier.value = ayahNumber;
    _selectedAyahNotifier.value = ayahNumber;

    if (scroll) _scrollToAyah(ayahNumber);

    try {
      if (_isPlayingSurahNotifier.value) {
        await _surahAudio.stop();
        _isPlayingSurahNotifier.value = false;
      }
      final session = await AudioSession.instance;
      await session.setActive(true);
      await _ayahAudio.setUrl(ayah.audioUrl!);
      await _ayahAudio.play();
    } catch (_) {
      if (mounted) _playingAyahNotifier.value = null;
    }
    _isAutoContinuing = false;
  }

  void _onAyahComplete() {
    if (_isAutoContinuing) return;
    final current = _playingAyahNotifier.value;
    if (current == null) return;

    final settings = QuranSettingsProvider.of(context, listen: false);
    if (settings.ayahAutoContinue && _surahInfo != null) {
      int next = current + 1;
      while (next <= _surahInfo!.totalAyahs) {
        final ayah = _ayahs
            .cast<AyahData?>()
            .firstWhere((a) => a?.ayahNumber == next, orElse: () => null);
        if (ayah != null && ayah.audioUrl != null) {
          _isAutoContinuing = true;
          _playAyah(next);
          return;
        }
        next++;
      }
    }
    _ayahAudio.stop();
    if (mounted && _playingAyahNotifier.value == current) {
      _playingAyahNotifier.value = null;
    }
  }

  Future<void> _stopAyahPlay() async {
    await _ayahAudio.stop();
    if (mounted) _playingAyahNotifier.value = null;
  }

  // ── Surah playback ─────────────────────────────────────────────────────
  Future<void> _toggleSurahPlay() async {
    if (_playingAyahNotifier.value != null) await _stopAyahPlay();

    if (_isPlayingSurahNotifier.value) {
      await _surahAudio.pause();
      _isPlayingSurahNotifier.value = false;
    } else {
      _isPlayingSurahNotifier.value = true;
      final settings = QuranSettingsProvider.of(context, listen: false);
      final offlinePath = await QuranService.instance.getDownloadedSurahPath(
          widget.surahNumber, settings.selectedReciterId);
      try {
        await _surahAudio.stop();
        if (offlinePath != null) {
          await _surahAudio.setFilePath(offlinePath);
        } else {
          final url =
              _surahAudioData?.reciters[settings.selectedReciterId]?.url;
          if (url == null) {
            _isPlayingSurahNotifier.value = false;
            return;
          }
          await _surahAudio.setUrl(url);
        }
        await _surahAudio.play();
      } catch (_) {
        _isPlayingSurahNotifier.value = false;
      }
    }
  }

  Future<void> _downloadSurah() async {
    final settings = QuranSettingsProvider.of(context, listen: false);
    final reciter = _surahAudioData?.reciters[settings.selectedReciterId];
    if (reciter == null) return;

    _downloadProgressNotifier.value = 0.0;
    try {
      await QuranService.instance.downloadSurah(
        widget.surahNumber,
        settings.selectedReciterId,
        reciter.url,
        onProgress: (p) => _downloadProgressNotifier.value = p,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Downloaded Surah ${widget.surahNumber} by ${reciter.reciterName}'),
          backgroundColor: QuranTheme.of(context).emeraldDeep,
        ));
        _isSurahDownloadedNotifier.value = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) _downloadProgressNotifier.value = null;
    }
  }

  Future<bool> _checkSurahDownloaded() async {
    final settings = QuranSettingsProvider.of(context, listen: false);
    String reciterId = settings.selectedReciterId;
    if (_surahAudioData != null) {
      if (_surahAudioData!.reciters[reciterId] == null &&
          _surahAudioData!.reciters.isNotEmpty) {
        reciterId = _surahAudioData!.reciters.keys.first;
      }
    }
    return (await QuranService.instance
            .getDownloadedSurahPath(widget.surahNumber, reciterId)) !=
        null;
  }

  Future<void> _stopSurahPlay() async {
    await _surahAudio.stop();
    if (mounted) _isPlayingSurahNotifier.value = false;
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  void _copyAyah(AyahData ayah, QuranSettings settings) {
    final text = '${ayah.arabicFor(settings.script)}\n\n'
        '${settings.showTransliteration && ayah.transliteration.isNotEmpty ? "${ayah.transliteration}\n\n" : ""}'
        '${ayah.translation}\n\n'
        '— Quran ${ayah.surahNumber}:${ayah.ayahNumber}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Ayah copied'),
      backgroundColor: QuranTheme.of(context).emeraldDeep,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = QuranSettingsProvider.of(context);
    final progress = QuranProgressProvider.of(context);
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: Stack(children: [
        Positioned.fill(child: Container(color: qt.bg)),
        SafeArea(
          bottom: false,
          child: Column(children: [
            _buildHeader(qt),
            if (_isNavOpen)
              _GoToAyahPanel(
                surahList: widget.surahList,
                currentSurah: widget.surahNumber,
                onNavigate: (surah, ayah) {
                  setState(() => _isNavOpen = false);
                  if (surah == widget.surahNumber) {
                    Future.delayed(const Duration(milliseconds: 100),
                        () => _scrollToAyah(ayah));
                  } else {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => QuranReaderScreen(
                        surahNumber: surah,
                        initialAyah: ayah,
                        surahList: widget.surahList,
                      ),
                    ));
                  }
                },
                onClose: () => setState(() => _isNavOpen = false),
              ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                          strokeWidth: 2),
                    )
                  : _buildReaderList(settings, progress, qt),
            ),
          ]),
        ),
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _playingAyahNotifier,
              _selectedAyahNotifier,
              _isPlayingSurahNotifier,
              _downloadProgressNotifier,
              _isSurahDownloadedNotifier,
            ]),
            builder: (context, child) {
              return _FloatingAudioPill(
                settings: settings,
                qt: qt,
                isAnyPlaying: _isPlayingSurahNotifier.value ||
                    _playingAyahNotifier.value != null,
                playingAyah: _playingAyahNotifier.value,
                selectedAyah: _selectedAyahNotifier.value,
                isPlayingSurah: _isPlayingSurahNotifier.value,
                downloadProgress: _downloadProgressNotifier.value,
                isSurahDownloaded: _isSurahDownloadedNotifier.value,
                surahNumber: widget.surahNumber,
                surahList: widget.surahList,
                onPlayPause: (mode) {
                  if (mode == PlayMode.ayah) {
                    _playAyah(_playingAyahNotifier.value ??
                        _selectedAyahNotifier.value ??
                        1);
                  } else {
                    _toggleSurahPlay();
                  }
                },
                onStop: settings.playMode == PlayMode.ayah
                    ? _stopAyahPlay
                    : _stopSurahPlay,
                onDownloadSurah: _downloadSurah,
                onModeChanged: (m) => settings.setPlayMode(m),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(QuranTheme qt) {
    final info = _surahInfo;
    final bool isDark = qt.brightness == Brightness.dark;

    return Container(
      // Removed the manual MediaQuery top padding that caused the gap
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: qt.bg,
        border: Border(bottom: BorderSide(color: qt.borderGlass, width: 0.5)),
      ),
      child: Row(
        children: [
          _glassBtn(
            Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : qt.textPrimary, size: 18),
            qt,
            onTap: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isNavOpen = !_isNavOpen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SURAH ${info?.number ?? widget.surahNumber}',
                      style: TextStyle(
                          color: qt.textMuted,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(info?.nameEnglish ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: qt.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isNavOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: qt.textMuted, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _glassBtn(
            Icon(Icons.tune_rounded,
                color: isDark ? Colors.white : qt.textPrimary, size: 18),
            qt,
            onTap: _showSettingsSheet,
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(Widget child, QuranTheme qt, {VoidCallback? onTap}) {
    final bool isDark = qt.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          // Avoid solid black: use a slight tint in dark mode
          color: isDark ? Colors.white.withOpacity(0.1) : qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Reader list ─────────────────────────────────────────────────────────
  Widget _buildReaderList(
      QuranSettings settings, QuranProgress progress, QuranTheme qt) {
    final surahNum = widget.surahNumber;
    final itemCount = _displayItems.length + 2;

    // ── OPTIMIZED: Build lookup sets once for O(1) per-ayah checks ──
    final bookmarkedKeys =
        progress.bookmarks.map((b) => '${b.surah}:${b.ayah}').toSet();
    final recentReadKeys =
        progress.recentReads.map((r) => '${r.surah}:${r.ayah}').toSet();

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      minCacheExtent: 400,
      padding: EdgeInsets.only(
        top: 0,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: itemCount,
      itemBuilder: (ctx, index) {
        if (index == 0) return _buildBismillah(qt);
        if (index == itemCount - 1) return _buildNavFooter(qt);

        final item = _displayItems[index - 1];
        if (item is _JuzDividerData) return _buildJuzDivider(item, qt);

        final ayahIndex = item as int;
        final ayah = _ayahs[ayahIndex];
        final ayahKey = '${surahNum}:${ayah.ayahNumber}';

        return _AyahCard(
          key: ValueKey(ayah.ayahNumber),
          ayah: ayah,
          settings: settings,
          isBookmarked: bookmarkedKeys.contains(ayahKey),
          isLastRead: recentReadKeys.contains(ayahKey),
          isRecentRead: recentReadKeys.contains(ayahKey),
          isHighlighted: _highlightedAyah == ayah.ayahNumber,
          sajdah: _sajdahMetadata[ayah.verseKey],
          playingAyahNotifier: _playingAyahNotifier,
          selectedAyahNotifier: _selectedAyahNotifier,
          openMenuAyahNotifier: _openMenuAyahNotifier,
          openTafsirAyahNotifier: _openTafsirAyahNotifier,
          isAyahAudioPlayingNotifier: _isAyahAudioPlayingNotifier,
          onBookmark: () => progress.toggleBookmark(
              surahNum, ayah.ayahNumber, _surahInfo?.nameEnglish ?? ''),
          onLastRead: () {
            progress.addRecentRead(
                surahNum, ayah.ayahNumber, _surahInfo?.nameEnglish ?? '');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Saved to Recent Reads'),
              backgroundColor: qt.emeraldDeep,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ));
          },
          onCopy: () => _copyAyah(ayah, settings),
          onPlay: () => _playAyah(ayah.ayahNumber),
          onTap: () {
            _selectedAyahNotifier.value = ayah.ayahNumber;
            _openMenuAyahNotifier.value = null;
          },
          onToggleMenu: () {
            _openMenuAyahNotifier.value =
                _openMenuAyahNotifier.value == ayah.ayahNumber
                    ? null
                    : ayah.ayahNumber;
            if (_openMenuAyahNotifier.value != null)
              _openTafsirAyahNotifier.value = null;
          },
          onToggleTafsir: () async {
            final connectivity = await Connectivity().checkConnectivity();
            if (connectivity.contains(ConnectivityResult.none)) {
              final offline = await QuranService.instance
                      .getOfflineTafsir(surahNum, ayah.ayahNumber) !=
                  null;
              if (!offline) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        const Text('Tafsir requires an internet connection.'),
                    backgroundColor: qt.emeraldDeep,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
                return;
              }
            }
            _openTafsirAyahNotifier.value =
                _openTafsirAyahNotifier.value == ayah.ayahNumber
                    ? null
                    : ayah.ayahNumber;
            if (_openTafsirAyahNotifier.value != null)
              _openMenuAyahNotifier.value = null;
          },
          surahList: widget.surahList,
        );
      },
    );
  }

  // ── Bismillah ───────────────────────────────────────────────────────────
  Widget _buildBismillah(QuranTheme qt) {
    // Hide for Surah Taubah (9) and Fatihah (1) if handled elsewhere
    if (widget.surahNumber == 9 || widget.surahNumber == 1) {
      return const SizedBox(height: 16);
    }

    final bool isDark = qt.brightness == Brightness.dark;

    return Container(
      // Replaced Expanded/Flexible with Container
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        // Use a gradient or adaptive color to prevent "Black Box" look
        color: isDark ? Colors.white.withOpacity(0.03) : qt.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Text(
        'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'QPC Hafs',
          fontSize: 28,
          color: isDark ? qt.emeraldLight : qt.emeraldDeep,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Juz divider ─────────────────────────────────────────────────────────
  Widget _buildJuzDivider(_JuzDividerData data, QuranTheme qt) {
    final entry = _juzMetadataMap[data.juzNumber];
    String? surahRange;
    if (entry != null) {
      final keys = entry.verseMapping.keys.toList()..sort();
      surahRange = keys.length == 1
          ? 'Surah ${keys.first}'
          : 'Surahs ${keys.first}–${keys.last}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(children: [
        Row(children: [
          Expanded(child: Container(height: 1, color: qt.borderGlass)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.auto_stories_rounded,
                color: qt.emeraldDeep, size: 16),
          ),
          Expanded(child: Container(height: 1, color: qt.borderGlass)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: qt.emeraldDeep.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Text('JUZ ${data.juzNumber}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.5)),
        ),
        if (surahRange != null) ...[
          const SizedBox(height: 8),
          Text(surahRange,
              style: TextStyle(
                  color: qt.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
        if (entry != null) ...[
          const SizedBox(height: 4),
          Text('${entry.versesCount} verses',
              style: TextStyle(
                  color: qt.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Nav footer ──────────────────────────────────────────────────────────
  Widget _buildNavFooter(QuranTheme qt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(children: [
        if (_prevSurah != null)
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToSurah(_prevSurah!.number),
              child: _navBtn(_prevSurah!.nameEnglish, isNext: false, qt: qt),
            ),
          )
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 12),
        if (_nextSurah != null)
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToSurah(_nextSurah!.number),
              child: _navBtn(_nextSurah!.nameEnglish, isNext: true, qt: qt),
            ),
          )
        else
          const Expanded(child: SizedBox()),
      ]),
    );
  }

  void _navigateToSurah(int surah) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => QuranReaderScreen(
        surahNumber: surah,
        surahList: widget.surahList,
      ),
    ));
  }

  Widget _navBtn(String name, {required bool isNext, required QuranTheme qt}) {
    // Optimized: Removed expensive BackdropFilter.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: qt.cardBg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Row(
        mainAxisAlignment:
            isNext ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: isNext
            ? [
                Flexible(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NEXT',
                        style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700)),
                    Text(name,
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: qt.textMuted, size: 20),
              ]
            : [
                Icon(Icons.chevron_left_rounded, color: qt.textMuted, size: 20),
                const SizedBox(width: 6),
                Flexible(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PREV',
                        style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700)),
                    Text(name,
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
              ],
      ),
    );
  }

  // ── Settings ────────────────────────────────────────────────────────────
  void _showSettingsSheet() async {
    final savedAyah =
        _selectedAyahNotifier.value ?? _playingAyahNotifier.value ?? 1;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(
        onTranslationChanged: _reloadTranslation,
        onAyahReciterChanged: _loadAyahs,
        surahAudio: _surahAudioData,
      ),
    );
    final downloaded = await _checkSurahDownloaded();
    if (mounted) _isSurahDownloadedNotifier.value = downloaded;
    if (mounted) {
      Future.delayed(
          const Duration(milliseconds: 100), () => _scrollToAyah(savedAyah));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Go‑to‑Ayah Panel
// ─────────────────────────────────────────────────────────────────────────────
class _GoToAyahPanel extends StatefulWidget {
  final List<SurahInfo> surahList;
  final int currentSurah;
  final void Function(int surah, int ayah) onNavigate;
  final VoidCallback onClose;

  const _GoToAyahPanel({
    required this.surahList,
    required this.currentSurah,
    required this.onNavigate,
    required this.onClose,
  });

  @override
  State<_GoToAyahPanel> createState() => _GoToAyahPanelState();
}

class _GoToAyahPanelState extends State<_GoToAyahPanel> {
  late int _selectedSurah;
  late int _selectedAyah;

  @override
  void initState() {
    super.initState();
    _selectedSurah = widget.currentSurah;
    _selectedAyah = 1;
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final currentInfo =
        widget.surahList.firstWhere((s) => s.number == _selectedSurah);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: qt.cardBg.withOpacity(0.98),
        border: Border(bottom: BorderSide(color: qt.borderGlass)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Navigation',
            style: TextStyle(
                color: qt.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            flex: 3,
            child: _dropdownField(
              label: 'Surah',
              value: _selectedSurah,
              items: widget.surahList
                  .map((s) => DropdownMenuItem(
                      value: s.number,
                      child: Text('${s.number}. ${s.nameEnglish}')))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedSurah = v!;
                _selectedAyah = 1;
              }),
              qt: qt,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _dropdownField(
              label: 'Ayah',
              value: _selectedAyah,
              items: List.generate(
                currentInfo.totalAyahs,
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text('Ayah ${i + 1}')),
              ),
              onChanged: (v) => setState(() => _selectedAyah = v!),
              qt: qt,
            ),
          ),
        ]),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {
            widget.onNavigate(_selectedSurah, _selectedAyah);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: qt.emeraldDeep.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Center(
              child: Text('Jump to Location',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required QuranTheme qt,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: qt.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qt.borderGlass),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            dropdownColor: qt.cardBg,
            isExpanded: true,
            style: TextStyle(
                color: qt.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Audio Pill
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingAudioPill extends StatelessWidget {
  final QuranSettings settings;
  final QuranTheme qt;
  final bool isAnyPlaying;
  final int? playingAyah;
  final int? selectedAyah;
  final bool isPlayingSurah;
  final double? downloadProgress;
  final bool isSurahDownloaded;
  final int surahNumber;
  final List<SurahInfo> surahList;
  final void Function(PlayMode mode) onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onDownloadSurah;
  final ValueChanged<PlayMode> onModeChanged;

  const _FloatingAudioPill({
    required this.settings,
    required this.qt,
    required this.isAnyPlaying,
    required this.playingAyah,
    required this.selectedAyah,
    required this.isPlayingSurah,
    required this.downloadProgress,
    required this.isSurahDownloaded,
    required this.surahNumber,
    required this.surahList,
    required this.onPlayPause,
    required this.onStop,
    required this.onDownloadSurah,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final showStop =
        (settings.playMode == PlayMode.ayah && playingAyah != null) ||
            (settings.playMode == PlayMode.surah && isPlayingSurah);

    return Center(
      // Optimized: Removed heavy blur processing, replaced with highly opaque container.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isAnyPlaying
              ? qt.emeraldDeep.withOpacity(0.98)
              : qt.cardBg.withOpacity(0.95),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isAnyPlaying
                ? qt.emeraldLight.withOpacity(0.4)
                : qt.borderGlass,
          ),
          boxShadow: [
            BoxShadow(
              color: isAnyPlaying
                  ? qt.emeraldDeep.withOpacity(0.4)
                  : Colors.black26,
              blurRadius: 15,
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ModeDropdown(
            currentMode: settings.playMode,
            onChanged: onModeChanged,
            qt: qt,
            isActive: isAnyPlaying,
          ),
          const SizedBox(width: 8),
          _verticalDivider(),
          const SizedBox(width: 8),
          Tooltip(
            message: (settings.playMode == PlayMode.ayah
                    ? (playingAyah != null && isAnyPlaying)
                    : isPlayingSurah)
                ? 'Pause'
                : 'Play',
            child: GestureDetector(
              onTap: () => onPlayPause(settings.playMode),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (settings.playMode == PlayMode.ayah
                          ? (playingAyah != null && isAnyPlaying)
                          : isPlayingSurah)
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          if (showStop) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Stop',
              child: GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isAnyPlaying
                        ? Colors.white.withOpacity(0.2)
                        : Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.stop_rounded,
                      color: isAnyPlaying ? Colors.white : Colors.redAccent,
                      size: 20),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _verticalDivider(),
          const SizedBox(width: 8),
          _PillBtn(
            icon: Icons.info_outline_rounded,
            label: 'Info',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SurahInfoScreen(
                surahNumber: surahNumber,
                surahList: surahList,
              ),
            )),
            qt: qt,
            isActive: false,
            isPillActive: isAnyPlaying,
          ),
          if (settings.playMode == PlayMode.surah) ...[
            const SizedBox(width: 4),
            _verticalDivider(),
            const SizedBox(width: 4),
            if (downloadProgress != null)
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                    value: downloadProgress,
                    strokeWidth: 2,
                    color: qt.emeraldLight),
              )
            else
              _PillBtn(
                icon: isSurahDownloaded
                    ? Icons.download_done
                    : Icons.download_for_offline_rounded,
                label: isSurahDownloaded ? 'Saved' : 'Download',
                onTap: isSurahDownloaded ? () {} : onDownloadSurah,
                qt: qt,
                isActive: false,
                isPillActive: isAnyPlaying,
                iconColor: isSurahDownloaded
                    ? (isAnyPlaying ? Colors.white : qt.emeraldLight)
                    : null,
              ),
          ],
          if (settings.playMode == PlayMode.ayah &&
              (playingAyah != null || selectedAyah != null)) ...[
            const SizedBox(width: 4),
            _verticalDivider(),
            const SizedBox(width: 12),
            Text(
              '$surahNumber:${playingAyah ?? selectedAyah}',
              style: TextStyle(
                color: isAnyPlaying ? Colors.white : qt.emeraldDeep,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ]),
      ),
    );
  }

  Widget _verticalDivider() => Container(
      width: 1,
      height: 28,
      color: isAnyPlaying ? Colors.white24 : qt.borderGlass);
}

class _ModeDropdown extends StatelessWidget {
  final PlayMode currentMode;
  final ValueChanged<PlayMode> onChanged;
  final QuranTheme qt;
  final bool isActive;

  const _ModeDropdown({
    required this.currentMode,
    required this.onChanged,
    required this.qt,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: qt.cardBg,
        hoverColor: qt.emeraldLight.withOpacity(0.1),
      ),
      child: PopupMenuButton<PlayMode>(
        initialValue: currentMode,
        tooltip: 'Select Playback Mode',
        onSelected: onChanged,
        offset: const Offset(0, -110),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: PlayMode.ayah,
            child: _buildItem(Icons.format_list_numbered_rounded,
                'Play Single Ayah', currentMode == PlayMode.ayah),
          ),
          PopupMenuItem(
            value: PlayMode.surah,
            child: _buildItem(Icons.queue_music_rounded, 'Play Full Surah',
                currentMode == PlayMode.surah),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Icon(
              currentMode == PlayMode.ayah
                  ? Icons.format_list_numbered_rounded
                  : Icons.queue_music_rounded,
              size: 18,
              color: isActive ? Colors.white : qt.emeraldDeep,
            ),
            const SizedBox(width: 8),
            Text(
              currentMode == PlayMode.ayah ? 'Ayah' : 'Surah',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : qt.emeraldDeep,
              ),
            ),
            Icon(Icons.arrow_drop_up_rounded,
                color: isActive
                    ? Colors.white70
                    : qt.emeraldDeep.withOpacity(0.5)),
          ]),
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String label, bool selected) {
    return Row(children: [
      Icon(icon, size: 20, color: selected ? qt.emeraldDeep : Colors.grey),
      const SizedBox(width: 12),
      Text(label,
          style: TextStyle(
            color: selected
                ? qt.emeraldDeep
                : (qt.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
      if (selected) ...[
        const Spacer(),
        Icon(Icons.check_circle, size: 16, color: qt.emeraldDeep),
      ],
    ]);
  }
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final QuranTheme qt;
  final bool isActive;
  final bool isPillActive;
  final Color? iconColor;

  const _PillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.qt,
    required this.isActive,
    this.isPillActive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = qt.brightness == Brightness.dark;
    final effectiveIconColor = iconColor ??
        (isActive
            ? (isDark ? qt.emeraldGlow : Colors.white)
            : (isPillActive
                ? Colors.white.withOpacity(0.9)
                : (isDark ? Colors.white.withOpacity(0.8) : qt.textMuted)));
    final effectiveTextColor = isActive
        ? (isDark ? qt.emeraldGlow : Colors.white)
        : (isPillActive
            ? Colors.white.withOpacity(0.7)
            : (isDark ? Colors.white.withOpacity(0.7) : qt.textMuted));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? qt.emeraldDeep.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: effectiveIconColor, size: 18),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah Card (Optimized: Replaced Rebuilds with Localized AnimatedBuilder)
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Ayah Card (Highly Optimized: Targeted Rebuilds)
// ─────────────────────────────────────────────────────────────────────────────
class _AyahCard extends StatefulWidget {
  final AyahData ayah;
  final QuranSettings settings;
  final bool isBookmarked;
  final bool isLastRead;
  final bool isHighlighted;
  final bool isRecentRead;
  final SajdahMetadata? sajdah;
  final ValueNotifier<int?> playingAyahNotifier;
  final ValueNotifier<int?> selectedAyahNotifier;
  final ValueNotifier<int?> openMenuAyahNotifier;
  final ValueNotifier<int?> openTafsirAyahNotifier;
  final ValueNotifier<bool> isAyahAudioPlayingNotifier;
  final VoidCallback onBookmark;
  final VoidCallback onLastRead;
  final VoidCallback onCopy;
  final VoidCallback onPlay;
  final VoidCallback onTap;
  final VoidCallback onToggleMenu;
  final VoidCallback onToggleTafsir;
  final List<SurahInfo> surahList;

  const _AyahCard({
    super.key,
    required this.ayah,
    required this.settings,
    required this.isBookmarked,
    required this.isLastRead,
    required this.isHighlighted,
    required this.isRecentRead,
    this.sajdah,
    required this.playingAyahNotifier,
    required this.selectedAyahNotifier,
    required this.openMenuAyahNotifier,
    required this.openTafsirAyahNotifier,
    required this.isAyahAudioPlayingNotifier,
    required this.onBookmark,
    required this.onLastRead,
    required this.onCopy,
    required this.onPlay,
    required this.onTap,
    required this.onToggleMenu,
    required this.onToggleTafsir,
    required this.surahList,
  });

  @override
  State<_AyahCard> createState() => _AyahCardState();
}

class _AyahCardState extends State<_AyahCard> {
  bool _isPlaying = false;
  bool _isSelected = false;
  bool _isTafsirOpen = false;

  bool get _isUrdu =>
      !widget.settings.isCustomTranslation &&
      (widget.settings.translation == TranslationId.urJalandhari ||
          widget.settings.translation == TranslationId.urWahiuddin);

  @override
  void initState() {
    super.initState();
    _updateStateFlags();
    // Listen to global states
    widget.playingAyahNotifier.addListener(_onStateChanged);
    widget.selectedAyahNotifier.addListener(_onStateChanged);
    widget.openTafsirAyahNotifier.addListener(_onStateChanged);
    widget.isAyahAudioPlayingNotifier.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(_AyahCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ensure state remains synced if the parent passes new data (like bookmarks)
    _updateStateFlags();
  }

  @override
  void dispose() {
    // Prevent memory leaks when the card scrolls out of view
    widget.playingAyahNotifier.removeListener(_onStateChanged);
    widget.selectedAyahNotifier.removeListener(_onStateChanged);
    widget.openTafsirAyahNotifier.removeListener(_onStateChanged);
    widget.isAyahAudioPlayingNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _updateStateFlags() {
    _isPlaying = widget.playingAyahNotifier.value == widget.ayah.ayahNumber &&
        widget.isAyahAudioPlayingNotifier.value;
    _isSelected = widget.selectedAyahNotifier.value == widget.ayah.ayahNumber;
    _isTafsirOpen =
        widget.openTafsirAyahNotifier.value == widget.ayah.ayahNumber;
  }

  // ONLY rebuilds this specific card if ITS state changed.
  // Prevents all other 19 visible cards from rebuilding during audio transitions.
  void _onStateChanged() {
    final newIsPlaying =
        widget.playingAyahNotifier.value == widget.ayah.ayahNumber &&
            widget.isAyahAudioPlayingNotifier.value;
    final newIsSelected =
        widget.selectedAyahNotifier.value == widget.ayah.ayahNumber;
    final newIsTafsirOpen =
        widget.openTafsirAyahNotifier.value == widget.ayah.ayahNumber;

    if (_isPlaying != newIsPlaying ||
        _isSelected != newIsSelected ||
        _isTafsirOpen != newIsTafsirOpen) {
      if (mounted) {
        setState(() {
          _isPlaying = newIsPlaying;
          _isSelected = newIsSelected;
          _isTafsirOpen = newIsTafsirOpen;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final arabic = widget.ayah.arabicFor(widget.settings.script);
    final isIndoPak = widget.settings.script == ArabicScript.indoPak;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? qt.emeraldLight.withOpacity(0.12)
            : (widget.isLastRead
                ? qt.emeraldDeep.withOpacity(0.08)
                : qt.cardBg),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isHighlighted
              ? qt.emeraldGlow
              : (widget.isLastRead
                  ? qt.emeraldLight.withOpacity(0.3)
                  : qt.borderGlass),
          width: widget.isHighlighted ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: qt.emeraldLight.withOpacity(0.05),
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _numberChip(widget.ayah.ayahNumber, _isSelected, qt),
                    const Spacer(),
                    if (widget.sajdah != null) ...[
                      _sajdahBadge(qt),
                      const SizedBox(width: 8)
                    ],
                    if (widget.isLastRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('LAST READ',
                            style: TextStyle(
                                color: qt.emeraldDeep,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0)),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: isIndoPak ? 'IndoPak' : 'QPC Hafs',
                      fontFeatures: isIndoPak
                          ? const [
                              FontFeature.enable('liga'),
                              FontFeature.enable('ccmp')
                            ]
                          : null,
                      fontSize: widget.settings.arabicFontSize,
                      color: qt.textPrimary,
                      height: 2.0,
                    ),
                  ),
                  if (widget.settings.showTransliteration &&
                      widget.ayah.transliteration.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(widget.ayah.transliteration,
                        style: TextStyle(
                            color: qt.brightness == Brightness.dark
                                ? qt.emeraldGlow
                                : qt.emeraldDeep,
                            fontSize: widget.settings.translationFontSize,
                            fontStyle: FontStyle.italic,
                            height: 1.6)),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(height: 1, color: qt.borderGlass),
                  ),
                  if (widget.settings.showTranslation)
                    Text(
                      widget.ayah.translation,
                      textDirection:
                          _isUrdu ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: _isUrdu ? 'Urdu' : 'QPC Hafs',
                        fontFeatures: _isUrdu
                            ? const [
                                FontFeature.enable('liga'),
                                FontFeature.enable('ccmp')
                              ]
                            : null,
                        fontSize: _isUrdu
                            ? widget.settings.translationFontSize + 3
                            : widget.settings.translationFontSize,
                        color: qt.textSecondary,
                        height: _isUrdu ? 2.0 : 1.65,
                      ),
                    ),
                  const SizedBox(height: 14),
                  _actionRow(context, qt, _isPlaying, _isTafsirOpen),
                  if (_isTafsirOpen) ...[
                    const SizedBox(height: 16),
                    _tafsirAccordion(context, qt),
                  ],
                ]),
          ),
        ),
      ),
    );
  }

  Widget _numberChip(int n, bool selected, QuranTheme qt) {
    if (selected) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: qt.emeraldDeep.withOpacity(0.3), blurRadius: 8)
          ],
        ),
        child: Center(
            child: Text('$n',
                style: TextStyle(
                    color: qt.brightness == Brightness.dark
                        ? qt.emeraldGlow
                        : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12))),
      );
    }
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: qt.glassWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Center(
          child: Text('$n',
              style: TextStyle(
                  color: qt.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12))),
    );
  }

  Widget _sajdahBadge(QuranTheme qt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: qt.emeraldDeep.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: qt.emeraldDeep.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome_rounded, size: 10, color: qt.emeraldDeep),
          const SizedBox(width: 4),
          Text('Sajdah',
              style: TextStyle(
                  color: qt.emeraldDeep,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ]),
      );

  Widget _actionRow(
      BuildContext context, QuranTheme qt, bool isPlaying, bool isTafsirOpen) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('${widget.ayah.surahNumber}:${widget.ayah.ayahNumber}',
            style: TextStyle(
                color: qt.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        _iconBtn(
          widget.isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          widget.isBookmarked ? qt.emeraldLight : qt.textMuted,
          widget.onBookmark,
          tooltip: widget.isBookmarked ? 'Remove bookmark' : 'Bookmark',
        ),
        const SizedBox(width: 14),
        _iconBtn(
          widget.isRecentRead
              ? Icons.check_circle_rounded
              : Icons.check_circle_outline_rounded,
          widget.isRecentRead ? qt.emeraldLight : qt.textMuted,
          widget.onLastRead,
          tooltip: widget.isRecentRead
              ? 'Saved to Recent Reads'
              : 'Save to Recent Reads',
        ),
        const SizedBox(width: 14),
        _iconBtn(Icons.copy_rounded, qt.textMuted, widget.onCopy,
            tooltip: 'Copy'),
        const SizedBox(width: 14),
        _iconBtn(Icons.share_rounded, qt.textMuted, () {
          final text =
              '${widget.ayah.arabicFor(widget.settings.script)}\n\n${widget.ayah.translation}\n\n— Quran ${widget.ayah.surahNumber}:${widget.ayah.ayahNumber}';
          Share.share(text);
        }, tooltip: 'Share'),
        const SizedBox(width: 14),
        _iconBtn(
          isPlaying
              ? Icons.pause_circle_rounded
              : Icons.play_circle_outline_rounded,
          isPlaying ? qt.emeraldGlow : qt.textMuted,
          widget.onPlay,
          tooltip: isPlaying ? 'Pause' : 'Play audio',
          size: 18,
        ),
      ]),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: widget.onToggleTafsir,
        child: Text(
          isTafsirOpen ? 'Hide Tafsir' : 'Read Tafsir',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isTafsirOpen ? qt.emeraldLight : qt.emeraldDeep,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ]);
  }

  Widget _tafsirAccordion(BuildContext context, QuranTheme qt) {
    const authors = ["Ibn Kathir", "Ma'ariful Quran", "Tazkirul Quran"];
    return Container(
      decoration: BoxDecoration(
        color: qt.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text('READ TAFSIR',
              style: TextStyle(
                  color: qt.emeraldLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ),
        ...authors.map((author) {
          final isLast = author == authors.last;
          return Column(children: [
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TafsirScreen(
                  surahNumber: widget.ayah.surahNumber,
                  ayahNumber: widget.ayah.ayahNumber,
                  initialAuthor: author,
                  surahList: widget.surahList,
                ),
              )),
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(16))
                  : BorderRadius.zero,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Text(author,
                      style: TextStyle(
                          color: qt.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: qt.textMuted, size: 12),
                ]),
              ),
            ),
            if (!isLast) Divider(height: 1, color: qt.borderGlass, indent: 16),
          ]);
        }).toList(),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap,
      {double size = 18, String tooltip = ''}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  final VoidCallback onTranslationChanged;
  final VoidCallback onAyahReciterChanged;
  final SurahAudio? surahAudio;

  const _SettingsSheet({
    required this.onTranslationChanged,
    required this.onAyahReciterChanged,
    this.surahAudio,
  });

  @override
  Widget build(BuildContext context) {
    final settings = QuranSettingsProvider.of(context);
    final qt = QuranTheme.of(context);

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: qt.borderGlass)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: qt.textMuted, borderRadius: BorderRadius.circular(2)),
          )),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reading Preferences',
                  style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
              IconButton(
                  icon: Icon(Icons.close, color: qt.textMuted),
                  onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 20),
          _label('Appearance', qt),
          const SizedBox(height: 8),
          _themeToggle(settings, qt),
          const SizedBox(height: 20),
          _label('Arabic Script', qt),
          const SizedBox(height: 8),
          _scriptToggle(settings, qt),
          const SizedBox(height: 24),
          _sectionDivider(qt),
          const SizedBox(height: 20),
          _label('Translation', qt),
          const SizedBox(height: 8),
          _TranslationDropdown(
              settings: settings, onTranslationChanged: onTranslationChanged),
          const SizedBox(height: 20),
          _toggle('Show Transliteration', settings.showTransliteration,
              settings.setShowTransliteration, qt),
          const SizedBox(height: 8),
          _toggle('Show Translation', settings.showTranslation,
              settings.setShowTranslation, qt),
          const SizedBox(height: 24),
          _sectionDivider(qt),
          const SizedBox(height: 20),
          _label('Preview', qt),
          const SizedBox(height: 8),
          _buildPreviewCard(settings, qt),
          const SizedBox(height: 16),
          _label(
              'Arabic Font Size  (${settings.arabicFontSize.round()}px)', qt),
          Slider(
            value: settings.arabicFontSize,
            min: 20,
            max: 72,
            activeColor: qt.emeraldLight,
            inactiveColor: qt.emeraldDeep.withOpacity(0.4),
            onChanged: settings.setArabicFontSize,
          ),
          _label(
              'Translation Font Size  (${settings.translationFontSize.round()}px)',
              qt),
          Slider(
            value: settings.translationFontSize,
            min: 10,
            max: 28,
            activeColor: qt.emeraldLight,
            inactiveColor: qt.emeraldDeep.withOpacity(0.4),
            onChanged: settings.setTranslationFontSize,
          ),
          const SizedBox(height: 24),
          _sectionDivider(qt),
          const SizedBox(height: 20),
          _label('Audio Mode', qt),
          const SizedBox(height: 8),
          _playModeToggle(settings, qt),
          const SizedBox(height: 16),
          if (settings.playMode == PlayMode.surah && surahAudio != null) ...[
            _label('Reciter', qt),
            const SizedBox(height: 8),
            _reciterDropdown(context, settings, qt),
            const SizedBox(height: 16),
          ],
          if (settings.playMode == PlayMode.ayah) ...[
            _label('Ayah Reciter', qt),
            const SizedBox(height: 8),
            _ayahReciterDropdown(context, settings, qt),
            const SizedBox(height: 16),
            _toggle('Auto-continue Ayahs', settings.ayahAutoContinue,
                settings.setAyahAutoContinue, qt),
            const SizedBox(height: 24),
          ],
        ]),
      ),
    );
  }

  String _getBismillahTranslation(QuranSettings settings) {
    if (settings.isCustomTranslation) {
      switch (settings.customTranslationId) {
        case 'bengali':
          return 'পরম করুণাময় ও অসীম দয়ালু আল্লাহর নামে।';
        case 'tamil':
          return 'அளவற்ற அருளாளனும், நிகரற்ற அன்புடையோனுமாகிய அல்லாஹ்வின் திருப்பெயரால்...';
        case 'malyalam':
          return 'പരമ കാരുണികനും കരുണാവാരിധിയുമായ അല്ലാഹുവിന്റെ നാമത്തില്‍.';
        case 'french':
          return "Au nom d'Allah, le Tout Miséricordieux, le Très Miséricordieux.";
        default:
          return 'In the name of Allah, the Entirely Merciful, the Especially Merciful.';
      }
    }

    switch (settings.translation) {
      case TranslationId.enSahih:
        return 'In the name of Allah, the Entirely Merciful, the Especially Merciful.';
      case TranslationId.enMuhsin:
        return 'In the name of Allah, the Most Gracious, the Most Merciful.';
      case TranslationId.urMaududi:
        return 'Allah ke naam se jo bada meharban nihayat reham wala hai.';
      case TranslationId.urJalandhari:
        return 'شروع اللہ کا نام لے کر جو بڑا مہربان نہایت رحم والا ہے';
      case TranslationId.urWahiuddin:
        return 'اللہ کے نام سے جو بڑا مہربان نہایت رحم والا ہے';
      case TranslationId.hiUmari:
        return 'अल्लाह के नाम से, जो अत्यंत कृपाशील, दयावान् है।';
    }
  }

  Widget _buildPreviewCard(QuranSettings settings, QuranTheme qt) {
    final isIndoPak = settings.script == ArabicScript.indoPak;

    final customTrans = settings.customTranslationId != null
        ? kDownloadableTranslations.firstWhere(
            (t) => t.id == settings.customTranslationId,
            orElse: () => kDownloadableTranslations.first,
          )
        : null;

    final isUrdu = settings.translation == TranslationId.urJalandhari ||
        settings.translation == TranslationId.urWahiuddin ||
        (customTrans != null &&
            customTrans.language.toLowerCase().contains('urdu'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(children: [
        Text(
          'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: isIndoPak ? 'IndoPak' : 'QPC Hafs',
            fontFeatures: isIndoPak
                ? const [FontFeature.enable('liga'), FontFeature.enable('ccmp')]
                : null,
            fontSize: settings.arabicFontSize,
            color: qt.textPrimary,
            height: 1.8,
          ),
        ),
        if (settings.showTransliteration) ...[
          const SizedBox(height: 10),
          Text(
            'Bismillaahir Rahmaanir Raheem',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: qt.brightness == Brightness.dark
                  ? qt.emeraldGlow
                  : qt.emeraldDeep,
              fontSize: settings.translationFontSize,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ],
        if (settings.showTranslation) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: qt.borderGlass),
          const SizedBox(height: 12),
          if (settings.isCustomTranslation)
            FutureBuilder<Map<String, dynamic>?>(
              future: TranslationDownloadService.instance
                  .loadTranslationJson(settings.customTranslationId!),
              builder: (context, snapshot) {
                String text = _getBismillahTranslation(settings);
                if (snapshot.hasData && snapshot.data != null) {
                  final translationMap = snapshot.data!;
                  text = (translationMap['1:1']?['t'] as String?) ?? text;
                }
                return Text(
                  text,
                  textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                  textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: isUrdu ? 'Urdu' : 'QPC Hafs',
                    fontFeatures: isUrdu
                        ? const [
                            FontFeature.enable('liga'),
                            FontFeature.enable('ccmp')
                          ]
                        : null,
                    fontSize: isUrdu
                        ? settings.translationFontSize + 3
                        : settings.translationFontSize,
                    color: qt.textSecondary,
                    height: 1.5,
                  ),
                );
              },
            )
          else
            Text(
              _getBismillahTranslation(settings),
              textAlign: isUrdu ? TextAlign.right : TextAlign.left,
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: isUrdu ? 'Urdu' : 'QPC Hafs',
                fontFeatures: isUrdu
                    ? const [
                        FontFeature.enable('liga'),
                        FontFeature.enable('ccmp')
                      ]
                    : null,
                fontSize: isUrdu
                    ? settings.translationFontSize + 3
                    : settings.translationFontSize,
                color: qt.textSecondary,
                height: 1.5,
              ),
            ),
        ],
      ]),
    );
  }

  Widget _label(String text, QuranTheme qt) => Text(text,
      style: TextStyle(
          color: qt.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8));

  Widget _scriptToggle(QuranSettings settings, QuranTheme qt) {
    const scripts = [
      (ArabicScript.uthmani, 'Uthmani'),
      (ArabicScript.indoPak, 'IndoPak')
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass)),
      child: Row(
        children: scripts.map((s) {
          final active = settings.script == s.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => settings.setScript(s.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(
                            colors: [qt.emeraldDeep, qt.emeraldMid])
                        : null,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(s.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active
                            ? (qt.brightness == Brightness.dark
                                ? qt.textPrimary
                                : Colors.white)
                            : qt.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _toggle(
      String label, bool value, Function(bool) onChanged, QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass)),
      child: Row(children: [
        Text(label, style: TextStyle(color: qt.textPrimary, fontSize: 14)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: qt.emeraldLight,
          activeTrackColor: qt.emeraldDeep,
          inactiveThumbColor: qt.textMuted,
          inactiveTrackColor: qt.glassWhite,
        ),
      ]),
    );
  }

  Widget _themeToggle(QuranSettings settings, QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass)),
      child: Row(children: [
        Expanded(
            child: _modeBtn('Auto', settings.themeMode == ThemeMode.system,
                () => settings.setThemeMode(ThemeMode.system), qt)),
        Expanded(
            child: _modeBtn('Light', settings.themeMode == ThemeMode.light,
                () => settings.setThemeMode(ThemeMode.light), qt)),
        Expanded(
            child: _modeBtn('Dark', settings.themeMode == ThemeMode.dark,
                () => settings.setThemeMode(ThemeMode.dark), qt)),
      ]),
    );
  }

  Widget _playModeToggle(QuranSettings settings, QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass)),
      child: Row(children: [
        Expanded(
            child: _modeBtn(
                '▶  Full Surah',
                settings.playMode == PlayMode.surah,
                () => settings.setPlayMode(PlayMode.surah),
                qt)),
        Expanded(
            child: _modeBtn(
                '≡  Ayah by Ayah',
                settings.playMode == PlayMode.ayah,
                () => settings.setPlayMode(PlayMode.ayah),
                qt)),
      ]),
    );
  }

  Widget _modeBtn(
      String label, bool active, VoidCallback onTap, QuranTheme qt) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid])
                : null,
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: active
                    ? (qt.brightness == Brightness.dark
                        ? qt.textPrimary
                        : Colors.white)
                    : qt.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _reciterDropdown(
      BuildContext context, QuranSettings settings, QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.selectedReciterId,
          dropdownColor: qt.cardBg,
          isExpanded: true,
          style: TextStyle(color: qt.textPrimary, fontSize: 14),
          items: surahAudio!.reciters.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value.reciterName)))
              .toList(),
          onChanged: (v) {
            if (v != null) settings.setSelectedReciterId(v);
          },
        ),
      ),
    );
  }

  Widget _ayahReciterDropdown(
      BuildContext context, QuranSettings settings, QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: qt.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.selectedAyahReciterId,
          dropdownColor: qt.cardBg,
          isExpanded: true,
          style: TextStyle(color: qt.textPrimary, fontSize: 14),
          items: kAyahReciters
              .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              settings.setSelectedAyahReciterId(v);
              onAyahReciterChanged();
            }
          },
        ),
      ),
    );
  }

  Widget _sectionDivider(QuranTheme qt) => Container(
        height: 1,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
          Colors.transparent,
          qt.borderGlass.withOpacity(0.15),
          Colors.transparent
        ])),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Translation Dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _TranslationDropdown extends StatelessWidget {
  final QuranSettings settings;
  final VoidCallback onTranslationChanged;

  const _TranslationDropdown({
    required this.settings,
    required this.onTranslationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final downloadService = TranslationDownloadService.instance;
    final allOptions = _buildOptions(downloadService);
    final currentKey = settings.isCustomTranslation
        ? 'custom_${settings.customTranslationId}'
        : 'builtin_${settings.translation.index}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: QuranTheme.of(context).glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: QuranTheme.of(context).borderGlass),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentKey,
          dropdownColor: QuranTheme.of(context).cardBg,
          isExpanded: true,
          style: TextStyle(
              color: QuranTheme.of(context).textPrimary, fontSize: 14),
          items: allOptions.map((opt) {
            final isCurrent = opt.key == currentKey;
            final isDownloaded = opt.isDownloaded ?? false;
            final isDownloading = opt.isDownloading ?? false;

            return DropdownMenuItem<String>(
              value: opt.key,
              enabled: opt.isBuiltin || isDownloaded || !isDownloading,
              child: Row(children: [
                Expanded(
                    child: Text(opt.label,
                        style: TextStyle(
                            color: (!opt.isBuiltin && !isDownloaded)
                                ? QuranTheme.of(context).textMuted
                                : (isCurrent
                                    ? QuranTheme.of(context).emeraldDeep
                                    : QuranTheme.of(context).textPrimary),
                            fontWeight:
                                isCurrent ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14))),
                if (!opt.isBuiltin && !isDownloaded && !isDownloading)
                  GestureDetector(
                    onTap: () =>
                        _startDownload(context, opt.customId!, downloadService),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.download_rounded,
                          color: QuranTheme.of(context).textMuted, size: 18),
                    ),
                  ),
                if (isDownloading && opt.downloadProgress != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            value: opt.downloadProgress,
                            strokeWidth: 2,
                            color: QuranTheme.of(context).emeraldLight)),
                  ),
                if (!opt.isBuiltin && isDownloaded)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle_rounded,
                        color: QuranTheme.of(context).emeraldLight, size: 18),
                  ),
              ]),
            );
          }).toList(),
          onChanged: (key) {
            if (key == null) return;
            if (key.startsWith('builtin_')) {
              final idx = int.parse(key.split('_')[1]);
              settings.setTranslation(TranslationId.values[idx]);
              onTranslationChanged();
            } else {
              final id = key.split('_')[1];
              final downloaded = downloadService.isDownloaded(id) ?? false;
              if (downloaded) {
                settings.setCustomTranslation(id);
                onTranslationChanged();
              } else if (!(downloadService.isDownloading(id) ?? false)) {
                _startDownload(context, id, downloadService);
              }
            }
          },
        ),
      ),
    );
  }

  List<_TranslationOption> _buildOptions(TranslationDownloadService svc) {
    final displayOrder = [
      TranslationId.enSahih,
      TranslationId.enMuhsin,
      TranslationId.urMaududi,
      TranslationId.urJalandhari,
      TranslationId.urWahiuddin,
      TranslationId.hiUmari,
    ];

    final builtIn = displayOrder.map((t) => _TranslationOption(
        key: 'builtin_${t.index}',
        label: t.displayName,
        isBuiltin: true,
        builtinId: t));
    final downloadable =
        kDownloadableTranslations.map((d) => _TranslationOption(
              key: 'custom_${d.id}',
              label: d.displayName,
              isBuiltin: false,
              customId: d.id,
              isDownloaded: svc.isDownloaded(d.id) ?? false,
              isDownloading: svc.isDownloading(d.id) ?? false,
              downloadProgress: svc.progressFor(d.id),
            ));
    return [...builtIn, ...downloadable];
  }

  void _startDownload(
      BuildContext context, String id, TranslationDownloadService svc) {
    final translation = kDownloadableTranslations.firstWhere((t) => t.id == id);
    bool completed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        svc.downloadTranslation(translation).then((_) {
          if (dialogCtx.mounted && !completed) {
            completed = true;
            Navigator.of(dialogCtx, rootNavigator: true).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              settings.setCustomTranslation(translation.id);
              onTranslationChanged();
            });
          }
        }).catchError((e) {
          if (dialogCtx.mounted && !completed) {
            completed = true;
            Navigator.of(dialogCtx, rootNavigator: true).pop();
            ScaffoldMessenger.of(dialogCtx).showSnackBar(SnackBar(
                content: Text('Download failed: $e'),
                backgroundColor: Colors.redAccent));
          }
        });
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.download_for_offline_rounded,
                color: Color(0xFF26A69A)),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Downloading\n${translation.displayName}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600))),
          ]),
          content: SizedBox(
            width: double.infinity,
            child: StreamBuilder<double>(
              stream: Stream.periodic(const Duration(milliseconds: 100), (_) {
                return svc.progressFor(id) ?? 0.0;
              }).takeWhile((p) => p < 1.0),
              builder: (ctx, snap) {
                final progress = snap.data ?? 0.0;
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF26A69A),
                      minHeight: 6),
                  const SizedBox(height: 12),
                  Text('${(progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Requires one-time internet connection',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]);
              },
            ),
          ),
        );
      },
    );
  }
}

class _JuzDividerData {
  final int juzNumber;
  const _JuzDividerData({required this.juzNumber});
}

class _TranslationOption {
  final String key;
  final String label;
  final bool isBuiltin;
  final TranslationId? builtinId;
  final String? customId;
  final bool? isDownloaded;
  final bool? isDownloading;
  final double? downloadProgress;

  const _TranslationOption({
    required this.key,
    required this.label,
    required this.isBuiltin,
    this.builtinId,
    this.customId,
    this.isDownloaded,
    this.isDownloading,
    this.downloadProgress,
  });
}
