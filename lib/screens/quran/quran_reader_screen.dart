import 'dart:ui';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import '/models/quran_models.dart';
import '/models/downloadable_translation.dart';
import '/services/quran_service.dart';
import '/services/translation_download_service.dart';
import '/services/quran_audio_handler.dart'; // 1. IMPORT GLOBAL BACKGROUND AUDIO HANDLER
import '/providers/quran_settings_provider.dart';
import '/providers/quran_progress_provider.dart';
import '/constants/quran_theme.dart';
import '/constants/sajdah_data.dart';
import '/constants/juz_metadata_data.dart';
import 'tafsir_screen.dart';
import 'surah_info_screen.dart';
import '../../widgets/quran_reader_tips.dart';
import '../../constants/reciter_data.dart';

const int kCurrentTipsVersion = 2;

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
  // ── First-time tips ─────────────────────────────────────────────────────
  final GlobalKey<QuranReaderTipsState> _tipsKey = GlobalKey();
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
  final ValueNotifier<bool> _isSurahSourceArmedNotifier = ValueNotifier(false);

  // 2. REFERENCE THE CORE HANDLER PLAYERS GLOBALLY
  late final AudioPlayer _ayahAudio;
  late final AudioPlayer _surahAudio;

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

  @override
  void initState() {
    super.initState();

    _ayahAudio = QuranAudioHandler.instance.ayahPlayer;
    _surahAudio = QuranAudioHandler.instance.surahPlayer;

    _configureAudioSession();
    _initConstantData();
    _loadAyahs();

    // 1. Sync Ayah Play State
    _ayahAudio.playingStream.listen((playing) {
      if (mounted) _isAyahAudioPlayingNotifier.value = playing;
    });

    // 2. Sync Surah Play State
    _surahAudio.playingStream.listen((playing) {
      if (mounted) _isPlayingSurahNotifier.value = playing;
    });

    // 3. Keep completion logic
    _ayahAudio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAyahComplete();
      }
    });

    _surahAudio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) _isPlayingSurahNotifier.value = false;
      }
    });
  }

  @override
  void dispose() {
    // 4. DO NOT DISPOSE SINGLETON PLAYERS (to preserve background playback)
    _playingAyahNotifier.dispose();
    _selectedAyahNotifier.dispose();
    _openMenuAyahNotifier.dispose();
    _openTafsirAyahNotifier.dispose();
    _isPlayingSurahNotifier.dispose();
    _isAyahAudioPlayingNotifier.dispose();
    _downloadProgressNotifier.dispose();
    _isSurahDownloadedNotifier.dispose();
    _isSurahSourceArmedNotifier.dispose(); // ← ADD THIS
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

    // Show tips for new users or for existing users when tip content has been updated
    if (!settings.hasSeenQuranReaderTips) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tipsKey.currentState?.startTips();
        }
      });
    } else if (settings.tipsContentVersion < kCurrentTipsVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Show the updated translation tip for users updating to a new tips version
          _tipsKey.currentState?.startTips();
        }
      });
    }

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
    // Always fetch API data so the dropdown has all reciters,
    // even when a custom reciter is currently selected.
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

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
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

      final settings = QuranSettingsProvider.of(context, listen: false);
      final surahName =
          _surahInfo?.nameEnglish ?? "Surah ${widget.surahNumber}";

      if (settings.ayahTranslationEnabled &&
          settings.playMode == PlayMode.ayah) {
        // Build concatenated source: Arabic recitation first, then translation audio
        final String translationUrl;
        if (settings.ayahTranslationLanguageId == kAyahTranslationEnglishId) {
          translationUrl =
              getAyahTranslationEnglishUrl(widget.surahNumber, ayahNumber);
        } else {
          translationUrl =
              getAyahTranslationUrduUrl(widget.surahNumber, ayahNumber);
        }

        final concatenated = ConcatenatingAudioSource(
          children: [
            AudioSource.uri(
              Uri.parse(ayah.audioUrl!),
              tag: MediaItem(
                id: 'quran_ayah_${surahName}_$ayahNumber',
                title: '$surahName — Ayah $ayahNumber',
                artist: 'Quran Recitation',
                album: 'Al-Quran',
              ),
            ),
            AudioSource.uri(
              Uri.parse(translationUrl),
              tag: MediaItem(
                id: 'quran_ayah_trans_${surahName}_$ayahNumber',
                title: '$surahName — Ayah $ayahNumber (Translation)',
                artist: 'Quran Translation',
                album: 'Al-Quran',
              ),
            ),
          ],
        );
        await _ayahAudio.setAudioSource(concatenated);
      } else {
        // Original single-source playback
        await QuranAudioHandler.instance.setAyahSource(
          ayah.audioUrl!,
          surahName: surahName,
          ayahNumber: ayahNumber,
        );
      }

      await _ayahAudio.play();
    } catch (_) {
      if (mounted) _playingAyahNotifier.value = null;
    }
    _isAutoContinuing = false;
  }

  void _onAyahComplete() {
    if (_isAutoContinuing) return;
    if (!mounted) return;
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

  Future<void> _toggleSurahPlay() async {
    // If playing, just pause. The playingStream listener will update the UI.
    if (_isPlayingSurahNotifier.value) {
      await _surahAudio.pause();
      return;
    }

    // If the surah source was previously armed (was paused, not stopped), just resume.
    if (_isSurahSourceArmedNotifier.value) {
      await _surahAudio.play();
      return;
    }

    // Otherwise, start playing logic...
    if (_playingAyahNotifier.value != null) await _stopAyahPlay();

    final settings = QuranSettingsProvider.of(context, listen: false);
    final reciterId = settings.selectedReciterId;
    final offlinePath = await QuranService.instance
        .getDownloadedSurahPath(widget.surahNumber, reciterId);

    try {
      await _surahAudio.stop();

      final surahName =
          _surahInfo?.nameEnglish ?? "Surah ${widget.surahNumber}";
      final reciterName = reciterId == kYasserUrduReciterId
          ? kYasserUrduReciterName
          : reciterId == kAbdulBasitUrduReciterId
              ? kAbdulBasitUrduReciterName
              : reciterId == kAbdulBasitEnglishReciterId
                  ? kAbdulBasitEnglishReciterName
                  : _surahAudioData?.reciters[reciterId]?.reciterName;

      if (offlinePath != null) {
        await QuranAudioHandler.instance.setSurahSource(
          offlinePath,
          surahName: surahName,
          reciterName: reciterName,
          isLocal: true,
        );
      } else {
        String? url;
        if (reciterId == kYasserUrduReciterId) {
          url = getYasserUrduSurahUrl(widget.surahNumber);
        } else if (reciterId == kAbdulBasitUrduReciterId) {
          url = getAbdulBasitUrduSurahUrl(widget.surahNumber);
        } else if (reciterId == kAbdulBasitEnglishReciterId) {
          url = getAbdulBasitEnglishSurahUrl(widget.surahNumber);
        } else {
          url = _surahAudioData?.reciters[reciterId]?.url;
        }
        if (url == null) return;
        await QuranAudioHandler.instance.setSurahSource(
          url,
          surahName: surahName,
          reciterName: reciterName,
          isLocal: false,
        );
      }
      _isSurahSourceArmedNotifier.value = true;
      await _surahAudio.play();
    } catch (_) {
      _isSurahSourceArmedNotifier.value = false;
      if (mounted) _isPlayingSurahNotifier.value = false;
    }
  }

  Future<void> _downloadSurah() async {
    final settings = QuranSettingsProvider.of(context, listen: false);
    final reciterId = settings.selectedReciterId;

    String? url;
    String? reciterName;

    if (reciterId == kYasserUrduReciterId) {
      url = getYasserUrduSurahUrl(widget.surahNumber);
      reciterName = kYasserUrduReciterName;
    } else if (reciterId == kAbdulBasitUrduReciterId) {
      url = getAbdulBasitUrduSurahUrl(widget.surahNumber);
      reciterName = kAbdulBasitUrduReciterName;
    } else if (reciterId == kAbdulBasitEnglishReciterId) {
      url = getAbdulBasitEnglishSurahUrl(widget.surahNumber);
      reciterName = kAbdulBasitEnglishReciterName;
    } else {
      final reciter = _surahAudioData?.reciters[reciterId];
      if (reciter == null) return;
      url = reciter.url;
      reciterName = reciter.reciterName;
    }

    _downloadProgressNotifier.value = 0.0;
    try {
      await QuranService.instance.downloadSurah(
        widget.surahNumber,
        reciterId,
        url!,
        onProgress: (p) => _downloadProgressNotifier.value = p,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Downloaded Surah ${widget.surahNumber} by $reciterName'),
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
    if (!mounted) return false;
    final settings = QuranSettingsProvider.of(context, listen: false);
    String reciterId = settings.selectedReciterId;
    if (reciterId != kYasserUrduReciterId &&
        reciterId != kAbdulBasitUrduReciterId &&
        reciterId != kAbdulBasitEnglishReciterId &&
        _surahAudioData != null) {
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
    _isSurahSourceArmedNotifier.value = false;
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

  @override
  Widget build(BuildContext context) {
    final settings = QuranSettingsProvider.of(context);
    final progress = QuranProgressProvider.of(context);
    final qt = QuranTheme.of(context);

    final isDark = qt.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: QuranReaderTips(
        key: _tipsKey,
        showOnlyTranslationTip: settings.hasSeenQuranReaderTips &&
            (!settings.hasSeenTranslationReciterTip ||
                settings.tipsContentVersion < kCurrentTipsVersion),
        child: Stack(children: [
          Positioned.fill(
              child: Container(
                  color: isDark
                      ? const Color(0xFF0C0C0E)
                      : const Color(0xFFF2F2F7))),
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
                _isAyahAudioPlayingNotifier,
                _downloadProgressNotifier,
                _isSurahDownloadedNotifier,
                _isSurahSourceArmedNotifier, // ← ADD THIS
              ]),
              builder: (context, child) {
                final isSurahActive = _isPlayingSurahNotifier.value ||
                    _isSurahSourceArmedNotifier.value;
                final isAyahActuallyPlaying = _isAyahAudioPlayingNotifier.value;
                return _FloatingAudioPill(
                  settings: settings,
                  qt: qt,
                  isAnyPlaying:
                      isSurahActive || _playingAyahNotifier.value != null,
                  isAyahPlaying: isAyahActuallyPlaying,
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
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(QuranTheme qt) {
    final info = _surahInfo;
    final bool isDark = qt.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
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
          color: isDark ? Colors.white.withOpacity(0.1) : qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Center(child: child),
      ),
    );
  }

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
            if (recentReadKeys.contains(ayahKey)) {
              progress.removeRecentRead(surahNum, ayah.ayahNumber);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Removed from Last Read'),
                backgroundColor: qt.emeraldDeep,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
            } else {
              progress.addRecentRead(
                  surahNum, ayah.ayahNumber, _surahInfo?.nameEnglish ?? '');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Marked as Last Read'),
                backgroundColor: qt.emeraldDeep,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
            }
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

  Widget _buildBismillah(QuranTheme qt) {
    if (widget.surahNumber == 9 || widget.surahNumber == 1) {
      return const SizedBox(height: 16);
    }

    final bool isDark = qt.brightness == Brightness.dark;
    final primaryColor = isDark ? qt.emeraldLight : qt.emeraldDeep;
    final secondaryColor = isDark
        ? qt.emeraldLight.withOpacity(0.6)
        : qt.emeraldDeep.withOpacity(0.6);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.transparent, // Relies on the page background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Bismillah Text
          Text(
            'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'QPC Hafs',
              fontSize: 28,
              color: primaryColor,
              height: 1.8,
              letterSpacing:
                  1.5, // Slight spacing helps Arabic calligraphy breathe
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: primaryColor.withOpacity(isDark ? 0.5 : 0.15),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Ornate Divider (Diamond shape)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left line
              Container(height: 1, width: 60, color: secondaryColor),
              // Center diamond
              Transform.rotate(
                angle: 3.141592653589793 / 4, // 45 degrees
                child: Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    boxShadow: [
                      BoxShadow(
                          color: primaryColor.withOpacity(0.4), blurRadius: 4),
                    ],
                  ),
                ),
              ),
              // Right line
              Container(height: 1, width: 60, color: secondaryColor),
            ],
          ),
        ],
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
// Floating Audio Pill — Enhanced v2
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingAudioPill extends StatefulWidget {
  final QuranSettings settings;
  final QuranTheme qt;
  final bool isAnyPlaying;
  final bool isAyahPlaying;
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
    required this.isAyahPlaying,
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
  State<_FloatingAudioPill> createState() => _FloatingAudioPillState();
}

class _FloatingAudioPillState extends State<_FloatingAudioPill> {
  bool _isHovering = false;

  bool get _isPlaying => widget.settings.playMode == PlayMode.ayah
      ? widget.isAyahPlaying
      : widget.isPlayingSurah;

  bool get _showStop =>
      (widget.settings.playMode == PlayMode.ayah &&
          widget.playingAyah != null) ||
      (widget.settings.playMode == PlayMode.surah && widget.isAnyPlaying);

  @override
  Widget build(BuildContext context) {
    final isDark = widget.qt.brightness == Brightness.dark;
    final isActive = widget.isAnyPlaying;

    return Center(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _isHovering ? 14 : 10,
            vertical: _isHovering ? 8 : 6,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? widget.qt.emeraldDeep.withOpacity(0.97)
                : isDark
                    ? widget.qt.cardBg.withOpacity(0.92)
                    : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isActive
                  ? widget.qt.emeraldLight.withOpacity(_isHovering ? 0.6 : 0.35)
                  : isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? widget.qt.emeraldDeep.withOpacity(0.35)
                    : Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              if (isActive)
                BoxShadow(
                  color: widget.qt.emeraldLight.withOpacity(0.2),
                  blurRadius: 35,
                  spreadRadius: 2,
                ),
              BoxShadow(
                color: Colors.white.withOpacity(isDark ? 0.03 : 0.7),
                blurRadius: 0,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Mode Selector ──
              _EnhancedModeSelector(
                currentMode: widget.settings.playMode,
                onChanged: widget.onModeChanged,
                qt: widget.qt,
                isActive: isActive,
                isDark: isDark,
              ),

              _GlowingDivider(isActive: isActive, isDark: isDark),

              // ── Play/Pause Button (no pulse) ──
              _PlayButton(
                isPlaying: _isPlaying,
                isActive: isActive,
                qt: widget.qt,
                onTap: () => widget.onPlayPause(widget.settings.playMode),
              ),

              // ── Stop Button ──
              if (_showStop)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    opacity: _showStop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _StopButton(
                      isActive: isActive,
                      isDark: isDark,
                      onTap: widget.onStop,
                    ),
                  ),
                ),

              _GlowingDivider(isActive: isActive, isDark: isDark),

              // ── Ayah Counter (uniform styling) ──
              if (widget.settings.playMode == PlayMode.ayah &&
                  (widget.playingAyah != null || widget.selectedAyah != null))
                _AyahIndicator(
                  surahNumber: widget.surahNumber,
                  ayahNumber: widget.playingAyah ?? widget.selectedAyah!,
                  isActive: isActive,
                  isDark: isDark,
                  isPlaying: _isPlaying,
                  qt: widget.qt,
                ),

              // ── Prominent Surah Info Button ──
              _SurahInfoButton(
                isActive: isActive,
                isDark: isDark,
                qt: widget.qt,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SurahInfoScreen(
                      surahNumber: widget.surahNumber,
                      surahList: widget.surahList,
                    ),
                  ),
                ),
              ),

              // ── Download Section (Surah Mode) ──
              if (widget.settings.playMode == PlayMode.surah) ...[
                _GlowingDivider(isActive: isActive, isDark: isDark),
                if (widget.downloadProgress != null)
                  _DownloadProgress(
                    progress: widget.downloadProgress!,
                    qt: widget.qt,
                    isActive: isActive,
                  )
                else
                  _CompactPillButton(
                    icon: widget.isSurahDownloaded
                        ? Icons.cloud_done_rounded
                        : Icons.download_for_offline_rounded,
                    tooltip: widget.isSurahDownloaded
                        ? 'Downloaded'
                        : 'Download Surah',
                    isActive: widget.isSurahDownloaded,
                    isPillActive: isActive,
                    isDark: isDark,
                    qt: widget.qt,
                    customIconColor: widget.isSurahDownloaded
                        ? (isActive
                            ? Colors.white.withOpacity(0.9)
                            : widget.qt.emeraldLight)
                        : null,
                    onTap: widget.isSurahDownloaded
                        ? () {}
                        : widget.onDownloadSurah,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Play Button — static size, glow shadow when playing
// ─────────────────────────────────────────────────────────────────────────────
class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isActive;
  final QuranTheme qt;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.isActive,
    required this.qt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF0F0F0),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [qt.emeraldDeep, qt.emeraldMid],
                ),
          shape: BoxShape.circle,
          boxShadow: [
            if (isPlaying)
              BoxShadow(
                color: isActive
                    ? Colors.white.withOpacity(0.35)
                    : qt.emeraldDeep.withOpacity(0.4),
                blurRadius: 18,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: qt.emeraldDeep.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            color: isActive ? qt.emeraldDeep : Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah Indicator — uniform number styling
// ─────────────────────────────────────────────────────────────────────────────
class _AyahIndicator extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final bool isActive;
  final bool isDark;
  final bool isPlaying;
  final QuranTheme qt;

  const _AyahIndicator({
    required this.surahNumber,
    required this.ayahNumber,
    required this.isActive,
    required this.isDark,
    required this.isPlaying,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isActive ? Colors.white : qt.emeraldDeep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.1)
              : isDark
                  ? Colors.white.withOpacity(0.04)
                  : qt.emeraldDeep.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.white.withOpacity(0.08)
                : qt.emeraldDeep.withOpacity(0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaying) ...[
              _PlayingDot(color: baseColor),
              const SizedBox(width: 8),
            ],
            Text(
              '$surahNumber:$ayahNumber',
              style: TextStyle(
                color: baseColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayingDot extends StatelessWidget {
  final Color color;

  const _PlayingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Surah Info Button — Minimal Label
// ─────────────────────────────────────────────────────────────────────────────
class _SurahInfoButton extends StatelessWidget {
  final bool isActive;
  final bool isDark;
  final QuranTheme qt;
  final VoidCallback onTap;

  const _SurahInfoButton({
    required this.isActive,
    required this.isDark,
    required this.qt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Colors.white.withOpacity(0.9)
        : qt.emeraldDeep.withOpacity(0.85);

    return Tooltip(
      message: 'Surah Info',
      preferBelow: false,
      child: GestureDetector(
        // Ensures the empty spaces between icon/text are tappable
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Minimal padding keeps the pill from growing too tall
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outlined,
                size: 18,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                'Surah',
                style: TextStyle(
                  color: color,
                  fontSize: 8, // Tiny size keeps it compact
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 1.2, // Tight line height
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stop Button
// ─────────────────────────────────────────────────────────────────────────────
class _StopButton extends StatelessWidget {
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _StopButton({
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.15)
                : isDark
                    ? Colors.red.withOpacity(0.1)
                    : Colors.red.withOpacity(0.06),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? Colors.white.withOpacity(0.1)
                  : Colors.red.withOpacity(0.15),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.stop_rounded,
            color: isActive ? Colors.white : Colors.redAccent,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glowing Divider
// ─────────────────────────────────────────────────────────────────────────────
class _GlowingDivider extends StatelessWidget {
  final bool isActive;
  final bool isDark;

  const _GlowingDivider({
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 1,
        height: 24,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.15)
              : isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact Pill Button (for secondary actions like download)
// ─────────────────────────────────────────────────────────────────────────────
class _CompactPillButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final QuranTheme qt;
  final bool isActive;
  final bool isPillActive;
  final bool isDark;
  final Color? customIconColor;

  const _CompactPillButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.qt,
    required this.isActive,
    required this.isPillActive,
    required this.isDark,
    this.customIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = customIconColor ??
        (isActive
            ? qt.emeraldGlow
            : (isPillActive
                ? Colors.white.withOpacity(0.85)
                : (isDark ? Colors.white.withOpacity(0.6) : qt.textMuted)));

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? qt.emeraldDeep.withOpacity(0.05)
                : (isPillActive
                    ? Colors.white.withOpacity(0.0)
                    : Colors.transparent),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Download Progress
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadProgress extends StatelessWidget {
  final double progress;
  final QuranTheme qt;
  final bool isActive;

  const _DownloadProgress({
    required this.progress,
    required this.qt,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: isActive
                  ? Colors.white.withOpacity(0.1)
                  : qt.emeraldDeep.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isActive ? Colors.white : qt.emeraldDeep,
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${(progress * 100).toInt()}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : qt.emeraldDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enhanced Mode Selector (unchanged from v1)
// ─────────────────────────────────────────────────────────────────────────────
class _EnhancedModeSelector extends StatelessWidget {
  final PlayMode currentMode;
  final ValueChanged<PlayMode> onChanged;
  final QuranTheme qt;
  final bool isActive;
  final bool isDark;

  const _EnhancedModeSelector({
    required this.currentMode,
    required this.onChanged,
    required this.qt,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        hoverColor: qt.emeraldLight.withOpacity(0.08),
      ),
      child: PopupMenuButton<PlayMode>(
        initialValue: currentMode,
        tooltip: 'Playback Mode',
        onSelected: onChanged,
        offset: const Offset(0, -120),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.15),
        itemBuilder: (ctx) => [
          _buildMenuItem(
            ctx,
            icon: Icons.format_list_numbered_rtl_rounded,
            title: 'Single Ayah',
            subtitle: 'Play selected ayah only',
            value: PlayMode.ayah,
            selected: currentMode == PlayMode.ayah,
          ),
          const PopupMenuDivider(height: 8),
          _buildMenuItem(
            ctx,
            icon: Icons.headphones_rounded,
            title: 'Full Surah',
            subtitle: 'Continuous surah playback',
            value: PlayMode.surah,
            selected: currentMode == PlayMode.surah,
          ),
        ],
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.12)
                : isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                child: Icon(
                  currentMode == PlayMode.ayah
                      ? Icons.format_list_numbered_rtl_rounded
                      : Icons.headphones_rounded,
                  key: ValueKey(currentMode),
                  size: 16,
                  color: isActive ? Colors.white : qt.emeraldDeep,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                child: Text(
                  currentMode == PlayMode.ayah ? 'Ayah' : 'Surah',
                  key: ValueKey(currentMode),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isActive ? Colors.white : qt.emeraldDeep,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.unfold_more_rounded,
                size: 14,
                color: isActive
                    ? Colors.white.withOpacity(0.5)
                    : qt.emeraldDeep.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<PlayMode> _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required PlayMode value,
    required bool selected,
  }) {
    final isDark = qt.brightness == Brightness.dark;
    return PopupMenuItem<PlayMode>(
      value: value,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected
                  ? qt.emeraldDeep.withOpacity(0.12)
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: qt.emeraldDeep.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? qt.emeraldDeep
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                    color: selected
                        ? qt.emeraldDeep
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: qt.emeraldDeep,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 12, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah Card (Enhanced: Uniform Always-On Badge, No Border)
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

class _AyahCardState extends State<_AyahCard> with TickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isSelected = false;
  bool _isTafsirOpen = false;

  late final AnimationController _highlightController;

  bool get _isUrdu =>
      !widget.settings.isCustomTranslation &&
      (widget.settings.translation == TranslationId.urJalandhari ||
          widget.settings.translation == TranslationId.urWahiuddin);

  @override
  void initState() {
    super.initState();

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _highlightController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _highlightController.repeat();
    });
    _highlightController.addListener(_onHighlightTick);

    _syncState();

    widget.playingAyahNotifier.addListener(_onNotifierChanged);
    widget.selectedAyahNotifier.addListener(_onNotifierChanged);
    widget.openTafsirAyahNotifier.addListener(_onNotifierChanged);
    widget.isAyahAudioPlayingNotifier.addListener(_onNotifierChanged);
  }

  void _onHighlightTick() {
    if (mounted && widget.isHighlighted) setState(() {});
  }

  @override
  void didUpdateWidget(_AyahCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncState();
  }

  @override
  void dispose() {
    _highlightController.removeListener(_onHighlightTick);
    _highlightController.dispose();
    widget.playingAyahNotifier.removeListener(_onNotifierChanged);
    widget.selectedAyahNotifier.removeListener(_onNotifierChanged);
    widget.openTafsirAyahNotifier.removeListener(_onNotifierChanged);
    widget.isAyahAudioPlayingNotifier.removeListener(_onNotifierChanged);
    super.dispose();
  }

  void _syncState() {
    _isPlaying = widget.playingAyahNotifier.value == widget.ayah.ayahNumber &&
        widget.isAyahAudioPlayingNotifier.value;
    _isSelected = widget.selectedAyahNotifier.value == widget.ayah.ayahNumber;
    _isTafsirOpen =
        widget.openTafsirAyahNotifier.value == widget.ayah.ayahNumber;
    _manageHighlight();
  }

  void _onNotifierChanged() {
    final newPlaying =
        widget.playingAyahNotifier.value == widget.ayah.ayahNumber &&
            widget.isAyahAudioPlayingNotifier.value;
    final newSelected =
        widget.selectedAyahNotifier.value == widget.ayah.ayahNumber;
    final newTafsir =
        widget.openTafsirAyahNotifier.value == widget.ayah.ayahNumber;

    if (_isPlaying != newPlaying ||
        _isSelected != newSelected ||
        _isTafsirOpen != newTafsir) {
      if (mounted) {
        setState(() {
          _isPlaying = newPlaying;
          _isSelected = newSelected;
          _isTafsirOpen = newTafsir;
          _manageHighlight();
        });
      }
    }
  }

  void _manageHighlight() {
    if (widget.isHighlighted && !_highlightController.isAnimating) {
      _highlightController.forward();
    } else if (!widget.isHighlighted && _highlightController.isAnimating) {
      _highlightController.stop();
      _highlightController.reset();
    }
  }

  String get _shareableText {
    final buffer = StringBuffer();
    buffer.write(widget.ayah.arabicFor(widget.settings.script));

    if (widget.settings.showTransliteration &&
        widget.ayah.transliteration.isNotEmpty) {
      buffer.write('\n\n${widget.ayah.transliteration}');
    }

    if (widget.settings.showTranslation) {
      buffer.write('\n\n${widget.ayah.translation}');
    }

    buffer.write(
        '\n\n— Quran ${widget.ayah.surahNumber}:${widget.ayah.ayahNumber}');
    return buffer.toString();
  }

  void _handleContentTap() {
    if (!_isSelected) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;
    final arabic = widget.ayah.arabicFor(widget.settings.script);
    final isIndoPak = widget.settings.script == ArabicScript.indoPak;
    final isHighlighted = widget.isHighlighted;
    final pulseVal = _highlightController.value;
    final highlightOpacity = isHighlighted ? 0.02 + (pulseVal * 0.025) : 0.0;

    final mutedColor = qt.textMuted.withOpacity(0.75);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: isHighlighted
          ? BoxDecoration(
              color: accent.withOpacity(highlightOpacity),
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(
                  color: accent.withOpacity(0.2 + pulseVal * 0.15),
                  width: 2.5,
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(qt, accent, mutedColor),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _handleContentTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RepaintBoundary(
                        child: Text(
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
                            height: 2.2,
                          ),
                        ),
                      ),
                      if (widget.settings.showTransliteration &&
                          widget.ayah.transliteration.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          widget.ayah.transliteration,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: accent.withOpacity(0.8),
                            fontSize: widget.settings.translationFontSize,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                      ],
                      if (widget.settings.showTranslation) ...[
                        const SizedBox(height: 14),
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
                            height: _isUrdu ? 2.0 : 1.7,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildBottomActions(accent, mutedColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              height: 16,
              thickness: 0.5,
              color: qt.textMuted.withOpacity(0.15),
            ),
          ),
          if (_isTafsirOpen) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _buildTafsirSection(context, qt, accent),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TOP ROW ──────────────────────────────────────────────────────────────

  Widget _buildHeader(QuranTheme qt, Color accent, Color mutedColor) {
    final ayahRef =
        '${widget.ayah.surahNumber}:${widget.ayah.ayahNumber.toString().padLeft(2, '0')}';

    return Row(
      children: [
        // Uniform Ayah Number Badge
        _buildAyahRefBadge(ayahRef, accent, mutedColor),

        const SizedBox(width: 18),

        // Heart Icon
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onBookmark();
          },
          child: Icon(
            widget.isBookmarked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: widget.isBookmarked ? accent : mutedColor,
            size: 19,
          ),
        ),
        const SizedBox(width: 16),

        // Share Icon
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Share.share(_shareableText);
          },
          child: Icon(
            Icons.share_rounded,
            color: mutedColor,
            size: 18,
          ),
        ),

        const Spacer(),

        if (widget.sajdah != null) ...[
          _buildBadge('Sajdah', Icons.auto_awesome_rounded, accent),
          const SizedBox(width: 8),
        ],
        if (widget.isLastRead) _buildBadge('LAST READ', null, accent),
      ],
    );
  }

  /// Always-on badge. Muted background by default, accent background when selected.
  Widget _buildAyahRefBadge(String ref, Color accent, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // Always show background to keep layout uniform
        color: _isSelected
            ? accent.withOpacity(0.1) // Accent tint when selected
            : mutedColor.withOpacity(0.12), // Subtle muted tint by default
        borderRadius: BorderRadius.circular(6),
        // Border removed completely
      ),
      child: Text(
        ref,
        style: TextStyle(
          color: _isSelected ? accent : mutedColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, IconData? icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: accent),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM ROW ───────────────────────────────────────────────────────────

  Widget _buildBottomActions(Color accent, Color mutedColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _textAction(
          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: _isPlaying ? 'Pause' : 'Play',
          isActive: _isPlaying,
          accent: accent,
          muted: mutedColor,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onPlay();
          },
        ),
        _buildVerticalDivider(mutedColor),
        _textAction(
          icon: widget.isRecentRead
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          label: 'Last Read',
          isActive: widget.isRecentRead,
          accent: accent,
          muted: mutedColor,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onLastRead();
          },
        ),
        _buildVerticalDivider(mutedColor),
        _textAction(
          icon: Icons.menu_book_rounded,
          label: _isTafsirOpen ? 'Hide Tafsir' : 'Tafsir',
          isActive: _isTafsirOpen,
          accent: accent,
          muted: mutedColor,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onToggleTafsir();
          },
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 1,
        height: 14,
        color: mutedColor.withOpacity(0.25),
      ),
    );
  }

  Widget _textAction({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color accent,
    required Color muted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: isActive ? accent : muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? accent : muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAFSIR SECTION ──────────────────────────────────────────────────────

  Widget _buildTafsirSection(
      BuildContext context, QuranTheme qt, Color accent) {
    const authors = ['Ibn Kathir', "Ma'ariful Quran", 'Tazkirul Quran'];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: qt.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.025)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Text(
                'TAFSIR SOURCES',
                style: TextStyle(
                  color: qt.textMuted.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...authors.map((author) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TafsirScreen(
                        surahNumber: widget.ayah.surahNumber,
                        ayahNumber: widget.ayah.ayahNumber,
                        initialAuthor: author,
                        surahList: widget.surahList,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          author,
                          style: TextStyle(
                            color: qt.textPrimary.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: qt.textMuted.withOpacity(0.5), size: 11),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final VoidCallback onTranslationChanged;
  final VoidCallback onAyahReciterChanged;
  final SurahAudio? surahAudio;

  const _SettingsSheet({
    required this.onTranslationChanged,
    required this.onAyahReciterChanged,
    this.surahAudio,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  int _activeTabIndex = 0;

  void _switchTab(int index) {
    if (index == _activeTabIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _activeTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final settings = QuranSettingsProvider.of(context);
    final qt = QuranTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final safeBottomSpacer =
        bottomInset > 0 ? bottomInset + 16.0 : systemBottomPadding + 28.0;
    final sheetHeight = MediaQuery.of(context).size.height * 0.95;

    return Container(
      height: sheetHeight,
      padding: EdgeInsets.only(bottom: safeBottomSpacer),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: qt.textMuted.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: qt.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.8,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Personalize your reading experience',
                        style: TextStyle(
                          color: qt.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  _closeButton(qt),
                ],
              ),
            ),

            // Everything below header scrolls together
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Sliding Tab Bar (now scrolls with content)
                    _SlidingTabBar(
                      tabs: const [
                        _TabItem(
                            label: 'Display', icon: Icons.text_fields_rounded),
                        _TabItem(
                            label: 'Audio', icon: Icons.headphones_rounded),
                      ],
                      activeIndex: _activeTabIndex,
                      onTap: _switchTab,
                      qt: qt,
                    ),
                    const SizedBox(height: 20),

                    // Content with fade transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                          child: child,
                        );
                      },
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: _activeTabIndex == 0
                          ? _buildDisplayTab(settings, qt)
                          : _buildAudioTab(settings, qt),
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

  Widget _closeButton(QuranTheme qt) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: qt.brightness == Brightness.dark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.close_rounded,
            color: qt.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  // ─── DISPLAY TAB ───────────────────────────────────────────────────────────

  Widget _buildDisplayTab(QuranSettings settings, QuranTheme qt) {
    return Column(
      key: const ValueKey<int>(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Appearance',
          subtitle: 'Choose your preferred theme',
          qt: qt,
        ),
        const SizedBox(height: 10),
        _Card(qt: qt, child: _themeToggle(settings, qt)),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Translation',
          subtitle: 'Select your preferred language pack',
          qt: qt,
        ),
        const SizedBox(height: 10),
        _Card(
          qt: qt,
          child: _TranslationDropdown(
            settings: settings,
            onTranslationChanged: widget.onTranslationChanged,
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Preview',
          subtitle: 'See your changes in real time',
          qt: qt,
        ),
        const SizedBox(height: 10),
        _buildPreviewCard(settings, qt),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Quran Text',
          subtitle: 'Adjust script, size & visibility',
          qt: qt,
        ),
        const SizedBox(height: 10),
        _Card(
          qt: qt,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _scriptToggle(settings, qt),
                const SizedBox(height: 26),
                _FontSlider(
                  label: 'Arabic Font Size',
                  value: settings.arabicFontSize,
                  min: 20,
                  max: 72,
                  unit: 'px',
                  onChanged: settings.setArabicFontSize,
                  qt: qt,
                ),
                const SizedBox(height: 22),
                _FontSlider(
                  label: 'Translation Size',
                  value: settings.translationFontSize,
                  min: 10,
                  max: 28,
                  unit: 'px',
                  onChanged: settings.setTranslationFontSize,
                  qt: qt,
                ),
                const SizedBox(height: 20),
                _thinDivider(qt),
                const SizedBox(height: 14),
                _ToggleRow(
                  icon: Icons.translate_rounded,
                  title: 'Transliteration',
                  subtitle: 'Show phonetic pronunciation',
                  value: settings.showTransliteration,
                  onChanged: settings.setShowTransliteration,
                  qt: qt,
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  icon: Icons.language_rounded,
                  title: 'Translation Text',
                  subtitle: 'Show meaning below Arabic',
                  value: settings.showTranslation,
                  onChanged: settings.setShowTranslation,
                  qt: qt,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── AUDIO TAB ─────────────────────────────────────────────────────────────

  Widget _buildAudioTab(QuranSettings settings, QuranTheme qt) {
    return Column(
      key: const ValueKey<int>(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Playback Mode',
          subtitle: 'How would you like to listen?',
          qt: qt,
        ),
        const SizedBox(height: 10),
        _Card(
          qt: qt,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _playModeToggle(settings, qt),
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Reciter',
          subtitle: 'Choose your preferred voice',
          qt: qt,
        ),
        const SizedBox(height: 10),
        _Card(
          qt: qt,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.playMode == PlayMode.surah &&
                    (widget.surahAudio != null ||
                        settings.selectedReciterId == kYasserUrduReciterId ||
                        settings.selectedReciterId ==
                            kAbdulBasitUrduReciterId ||
                        settings.selectedReciterId ==
                            kAbdulBasitEnglishReciterId))
                  _reciterDropdown(context, settings, qt),
                if (settings.playMode == PlayMode.ayah) ...[
                  _ayahReciterDropdown(context, settings, qt),
                  const SizedBox(height: 18),
                  _thinDivider(qt),
                  const SizedBox(height: 14),
                  _ToggleRow(
                    icon: Icons.skip_next_rounded,
                    title: 'Auto-continue Ayahs',
                    subtitle: 'Automatically play next ayah',
                    value: settings.ayahAutoContinue,
                    onChanged: settings.setAyahAutoContinue,
                    qt: qt,
                  ),
                  const SizedBox(height: 10),
                  _ToggleRow(
                    icon: Icons.record_voice_over_rounded,
                    title: 'Play With Translation',
                    subtitle: 'Read translation after each ayah',
                    value: settings.ayahTranslationEnabled,
                    onChanged: settings.setAyahTranslationEnabled,
                    qt: qt,
                  ),
                  if (settings.ayahTranslationEnabled) ...[
                    const SizedBox(height: 16),
                    _ayahTranslationLanguageDropdown(context, settings, qt),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ─── PREVIEW CARD ──────────────────────────────────────────────────────────

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

    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.04),
            isDark
                ? Colors.white.withOpacity(0.015)
                : Colors.black.withOpacity(0.015),
          ],
        ),
        border: Border.all(color: accent.withOpacity(0.15), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE PREVIEW',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '1:1',
                  style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ',
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
                fontSize: settings.arabicFontSize * 1,
                color: qt.textPrimary,
                height: 1.7,
              ),
            ),
            if (settings.showTransliteration) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Bismillaahir Rahmaanir Raheem',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: accent,
                    fontSize: settings.translationFontSize * 1,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            if (settings.showTranslation) ...[
              const SizedBox(height: 14),
              if (settings.isCustomTranslation)
                FutureBuilder<String>(
                  future: TranslationDownloadService.instance
                      .getFirstAyahTranslation(settings.customTranslationId!),
                  builder: (context, snapshot) {
                    String text = _getBismillahTranslation(settings);
                    if (snapshot.hasData && snapshot.data != null) {
                      text = snapshot.data!;
                    }
                    return _previewTranslationText(text, isUrdu, settings, qt);
                  },
                )
              else
                _previewTranslationText(
                    _getBismillahTranslation(settings), isUrdu, settings, qt),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewTranslationText(
      String text, bool isUrdu, QuranSettings settings, QuranTheme qt) {
    return Text(
      text,
      textAlign: isUrdu ? TextAlign.right : TextAlign.left,
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(
        fontFamily: isUrdu ? 'Urdu' : 'QPC Hafs',
        fontSize: isUrdu
            ? settings.translationFontSize + 2
            : settings.translationFontSize,
        color: qt.textSecondary,
        height: 1.5,
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

  // ─── SHARED HELPERS ────────────────────────────────────────────────────────

  Widget _thinDivider(QuranTheme qt) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: qt.brightness == Brightness.dark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06),
      ),
    );
  }

  Widget _themeToggle(QuranSettings settings, QuranTheme qt) {
    const modes = [
      (ThemeMode.system, 'Auto', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'Light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
    ];
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: modes.map((m) {
          final active = settings.themeMode == m.$1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  left: 3, right: modes.last == m ? 3 : 1.5, top: 3, bottom: 3),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    settings.setThemeMode(m.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? (isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active && !isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          m.$3,
                          size: 20,
                          color: active ? accent : qt.textMuted,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.$2,
                          style: TextStyle(
                            color: active ? accent : qt.textMuted,
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _scriptToggle(QuranSettings settings, QuranTheme qt) {
    const scripts = [
      (ArabicScript.uthmani, 'Uthmani'),
      (ArabicScript.indoPak, 'IndoPak'),
    ];
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: scripts.map((s) {
          final active = settings.script == s.$1;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.selectionClick();
                  settings.setScript(s.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active && !isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    s.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? accent : qt.textMuted,
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _playModeToggle(QuranSettings settings, QuranTheme qt) {
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Row(
      children: [
        Expanded(
          child: _modeCard(
            icon: Icons.play_circle_rounded,
            label: 'Full Surah',
            subtitle: 'Continuous playback',
            active: settings.playMode == PlayMode.surah,
            onTap: () {
              HapticFeedback.selectionClick();
              settings.setPlayMode(PlayMode.surah);
            },
            accent: accent,
            qt: qt,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _modeCard(
            icon: Icons.view_headline_rounded,
            label: 'Ayah by Ayah',
            subtitle: 'Step through each',
            active: settings.playMode == PlayMode.ayah,
            onTap: () {
              HapticFeedback.selectionClick();
              settings.setPlayMode(PlayMode.ayah);
            },
            accent: accent,
            qt: qt,
          ),
        ),
      ],
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool active,
    required VoidCallback onTap,
    required Color accent,
    required QuranTheme qt,
  }) {
    final isDark = qt.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? Colors.white.withOpacity(0.1) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active
                ? Border.all(color: accent.withOpacity(0.2), width: 1)
                : null,
            boxShadow: active && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: active ? accent : qt.textMuted),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? accent : qt.textPrimary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: qt.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    required QuranTheme qt,
  }) {
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: qt.textMuted.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: qt.cardBg,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: qt.textMuted,
            size: 22,
          ),
          style: TextStyle(
            color: accent,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _reciterDropdown(
      BuildContext context, QuranSettings settings, QuranTheme qt) {
    final List<MapEntry<String, String>> reciterEntries = [];
    reciterEntries.add(MapEntry(kYasserUrduReciterId, kYasserUrduReciterName));
    reciterEntries
        .add(MapEntry(kAbdulBasitUrduReciterId, kAbdulBasitUrduReciterName));
    reciterEntries.add(
        MapEntry(kAbdulBasitEnglishReciterId, kAbdulBasitEnglishReciterName));
    if (widget.surahAudio != null) {
      for (final e in widget.surahAudio!.reciters.entries) {
        reciterEntries.add(MapEntry(e.key, e.value.reciterName));
      }
    }

    final currentId =
        reciterEntries.any((e) => e.key == settings.selectedReciterId)
            ? settings.selectedReciterId
            : reciterEntries.first.key;

    return _styledDropdown(
      value: currentId,
      items: reciterEntries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          HapticFeedback.selectionClick();
          settings.setSelectedReciterId(v);
        }
      },
      qt: qt,
    );
  }

  Widget _ayahReciterDropdown(
      BuildContext context, QuranSettings settings, QuranTheme qt) {
    return _styledDropdown(
      value: settings.selectedAyahReciterId,
      items: kAyahReciters
          .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          HapticFeedback.selectionClick();
          settings.setSelectedAyahReciterId(v);
          widget.onAyahReciterChanged();
        }
      },
      qt: qt,
    );
  }

  Widget _ayahTranslationLanguageDropdown(
      BuildContext context, QuranSettings settings, QuranTheme qt) {
    return _styledDropdown(
      value: settings.ayahTranslationLanguageId,
      items: kAyahTranslationLanguages
          .map((lang) => DropdownMenuItem(
                value: lang['id'],
                child: Text(lang['name'] ?? ''),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          HapticFeedback.selectionClick();
          settings.setAyahTranslationLanguageId(v);
        }
      },
      qt: qt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXTRACTED REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── SECTION HEADER ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final QuranTheme qt;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: qt.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final QuranTheme qt;
  final Widget child;

  const _Card({required this.qt, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = qt.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _FontSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final QuranTheme qt;

  const _FontSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    required this.qt,
  });

  @override
  State<_FontSlider> createState() => _FontSliderState();
}

class _FontSliderState extends State<_FontSlider> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.qt.brightness == Brightness.dark;
    final accent = isDark ? widget.qt.emeraldLight : widget.qt.emeraldDeep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: widget.qt.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(_isDragging ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.value.round()}${widget.unit}',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accent,
            inactiveTrackColor:
                (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            thumbColor: isDark ? Colors.white : accent,
            overlayColor: accent.withOpacity(0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            onChangeStart: (_) => setState(() => _isDragging = true),
            onChangeEnd: (_) {
              HapticFeedback.selectionClick();
              setState(() => _isDragging = false);
            },
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final QuranTheme qt;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldLight : qt.emeraldDeep;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? accent.withOpacity(0.1)
                  : (isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? accent : qt.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: qt.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
              activeTrackColor: accent,
              activeColor: Colors.white,
              inactiveThumbColor:
                  isDark ? Colors.white.withOpacity(0.7) : Colors.white,
              inactiveTrackColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SLIDING TAB BAR ─────────────────────────────────────────────────────────

class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem({required this.label, required this.icon});
}

class _SlidingTabBar extends StatelessWidget {
  final List<_TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final QuranTheme qt;

  const _SlidingTabBar({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedSlide(
            offset: Offset(activeIndex.toDouble(), 0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1.0 / tabs.length,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
          Row(
            children: tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final tab = entry.value;
              final isActive = i == activeIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.icon,
                          size: 18,
                          color: isActive ? accent : qt.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.label,
                          style: TextStyle(
                            color: isActive ? accent : qt.textMuted,
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── TRANSLATION DROPDOWN ────────────────────────────────────────────────────

class _TranslationDropdown extends StatelessWidget {
  final QuranSettings settings;
  final VoidCallback onTranslationChanged;

  const _TranslationDropdown({
    required this.settings,
    required this.onTranslationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;

    final downloadService = TranslationDownloadService.instance;
    final allOptions = _buildOptions(downloadService);
    final currentKey = settings.isCustomTranslation
        ? 'custom_${settings.customTranslationId}'
        : 'builtin_${settings.translation.index}';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.textMuted.withOpacity(0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentKey,
            dropdownColor: qt.cardBg,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: qt.textMuted,
              size: 22,
            ),
            style: TextStyle(
              color: accent,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            items: allOptions.map((opt) {
              final isCurrent = opt.key == currentKey;
              final isDownloaded = opt.isDownloaded ?? false;
              final isDownloading = opt.isDownloading ?? false;

              return DropdownMenuItem<String>(
                value: opt.key,
                enabled: opt.isBuiltin || isDownloaded || !isDownloading,
                child: Row(children: [
                  Expanded(
                    child: Text(
                      opt.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: (!opt.isBuiltin && !isDownloaded)
                            ? qt.textMuted
                            : (isCurrent ? accent : qt.textPrimary),
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.normal,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (!opt.isBuiltin && !isDownloaded && !isDownloading)
                    GestureDetector(
                      onTap: () => _startDownload(
                          context, opt.customId!, downloadService),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.download_rounded,
                            color: qt.textMuted, size: 18),
                      ),
                    ),
                  if (isDownloading && opt.downloadProgress != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: opt.downloadProgress,
                          strokeWidth: 2,
                          color: qt.emeraldLight,
                        ),
                      ),
                    ),
                  if (!opt.isBuiltin && isDownloaded)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.check_circle_rounded,
                          color: qt.emeraldLight, size: 18),
                    ),
                ]),
              );
            }).toList(),
            onChanged: (key) {
              if (key == null) return;
              HapticFeedback.selectionClick();
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
                }
              }
            },
          ),
        ),
      ),
    );
  }

  // ... (keep _buildOptions and _startDownload methods exactly as they were)
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
    final qt = QuranTheme.of(context);
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
        final isDark = qt.brightness == Brightness.dark;
        final accent = isDark ? qt.emeraldGlow : qt.emeraldDeep;
        return AlertDialog(
          backgroundColor: qt.cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.download_for_offline_rounded,
                  color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Downloading',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: qt.textMuted)),
                  Text(translation.displayName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: qt.textPrimary)),
                ],
              ),
            ),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.06),
                        color: accent,
                        minHeight: 6),
                  ),
                  const SizedBox(height: 12),
                  Text('${(progress * 100).toInt()}%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: qt.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()])),
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
