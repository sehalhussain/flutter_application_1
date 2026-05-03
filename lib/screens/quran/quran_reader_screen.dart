import 'dart:ui';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '/models/quran_models.dart';
import '/services/quran_service.dart';
import '/providers/quran_settings_provider.dart';
import '/providers/quran_progress_provider.dart';
import '/constants/quran_theme.dart';
import 'surah_info_screen.dart';
import 'tafsir_screen.dart';

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
  // ── State ─────────────────────────────────────────────────────────────────
  List<AyahData> _ayahs = [];
  bool _loading = true;
  int? _playingAyah;
  int? _selectedAyah; // newly selected or playing ayah
  bool _isPlaying = false; // full-surah player
  int? _openMenuAyah; // which ayah card has its action panel open
  int? _openTafsirAyah; // which ayah card has its tafsir menu open
  bool _isNavOpen = false; // go-to-ayah header dropdown
  int? _highlightedAyah; // temporary highlight for jump-to-ayah
  SurahAudio? _surahAudioData;
  double? _downloadProgress;
  bool _isSurahDownloaded = false;
  bool _isAutoContinuing = false;

  bool get _isAnyPlaying => _isPlaying || _playingAyah != null;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final _ayahAudio = AudioPlayer();
  final _surahAudio = AudioPlayer();

  // ── Derived ───────────────────────────────────────────────────────────────
  SurahInfo? get _surahInfo =>
      widget.surahList.firstWhere((s) => s.number == widget.surahNumber,
          orElse: () => widget.surahList.first);

  SurahInfo? get _prevSurah => widget.surahList
      .where((s) => s.number == widget.surahNumber - 1)
      .firstOrNull;

  SurahInfo? get _nextSurah => widget.surahList
      .where((s) => s.number == widget.surahNumber + 1)
      .firstOrNull;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _configureAudioSession();
    _loadAyahs();
    _ayahAudio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onAyahComplete();
      }
    });
    // Listen to playing state for immediate UI updates
    _ayahAudio.playingStream.listen((_) {
      if (mounted) setState(() {});
    });
    _surahAudio.playingStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ayahAudio.dispose();
    _surahAudio.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadAyahs() async {
    final settings = QuranSettingsProvider.of(context, listen: false);
    final ayahs = await QuranService.instance
        .loadAyahs(widget.surahNumber, settings.translation);
    if (!mounted) return;
    setState(() {
      _ayahs = ayahs;
      _loading = false;
    });

    // Fetch surah audio metadata
    try {
      final audioData =
          await QuranService.instance.getSurahAudio(widget.surahNumber);
      if (mounted) setState(() => _surahAudioData = audioData);
      // Check if surah is downloaded
      final downloaded = await _checkSurahDownloaded();
      if (mounted) setState(() => _isSurahDownloaded = downloaded);
    } catch (e) {
      debugPrint("Error fetching surah audio: $e");
    }

    // Scroll to initial ayah after frame
    if (widget.initialAyah != null) {
      _highlightedAyah = widget.initialAyah;
      _selectedAyah = widget.initialAyah;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToAyah(widget.initialAyah!);
      });

      // Remove highlight after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedAyah = null);
      });
    }
  }

  Future<void> _reloadTranslation() async {
    final settings = QuranSettingsProvider.of(context, listen: false);
    final updated = await QuranService.instance
        .reloadTranslation(_ayahs, settings.translation);
    if (!mounted) return;
    setState(() => _ayahs = updated);
  }

  // ── Audio Session Configuration ────────────────────────────────────────────
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      // Configure audio session for background playback
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );
      debugPrint('Audio session configured for background playback');
    } catch (e) {
      debugPrint('Error configuring audio session: $e');
    }
  }

  // ── Scroll to ayah ────────────────────────────────────────────────────────
  Future<void> _scrollToAyah(int ayahNumber) async {
    if (!mounted) return;
    final targetIndex = _ayahs.indexWhere((a) => a.ayahNumber == ayahNumber);
    if (targetIndex < 0) return;

    final listIndex = targetIndex + 1; // +1 for the Bismillah header
    for (var attempt = 0; attempt < 10 && mounted; attempt++) {
      if (_itemScrollController.isAttached) break;
      await Future.delayed(const Duration(milliseconds: 40));
    }
    if (!mounted || !_itemScrollController.isAttached) return;

    await _itemScrollController.scrollTo(
      index: listIndex,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  // ── Audio: per-ayah ───────────────────────────────────────────────────────
  Future<void> _playAyah(int ayahNumber, {bool scroll = true}) async {
    final ayah = _ayahs.firstWhere((a) => a.ayahNumber == ayahNumber,
        orElse: () => _ayahs.first);
    if (ayah.audioUrl == null) return;

    // If same ayah is playing — toggle pause/resume
    if (_playingAyah == ayahNumber) {
      if (_ayahAudio.playing) {
        await _ayahAudio.pause();
        setState(() {}); // refresh UI for pause icon
      } else {
        await _ayahAudio.play();
        setState(() => _playingAyah = ayahNumber);
      }
      return;
    }

    // Update state immediately for instant UI feedback
    setState(() {
      _playingAyah = ayahNumber;
      _selectedAyah = ayahNumber;
    });

    // Scroll to ayah being played
    if (scroll) _scrollToAyah(ayahNumber);

    try {
      // Stop surah audio
      if (_isPlaying) {
        await _surahAudio.stop();
        setState(() => _isPlaying = false);
      }

      await _ayahAudio.stop();
      // Use headers to avoid 403 Forbidden from some audio providers
      await _ayahAudio.setUrl(ayah.audioUrl!,
          headers: kIsWeb
              ? null
              : {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                });
      await _ayahAudio.play();
    } catch (e) {
      debugPrint("Audio playback error: $e");
    }

    _isAutoContinuing = false;
  }

  void _onAyahComplete() {
    if (_isAutoContinuing) return; // Prevent multiple auto-continues

    final settings = QuranSettingsProvider.of(context, listen: false);
    final current = _playingAyah;

    if (settings.ayahAutoContinue && current != null) {
      final surahInfo = _surahInfo;
      if (surahInfo != null) {
        int nextAyah = current + 1;
        while (nextAyah <= surahInfo.totalAyahs) {
          final candidates = _ayahs.where((a) => a.ayahNumber == nextAyah);
          final ayah = candidates.isNotEmpty ? candidates.first : null;
          if (ayah != null && ayah.audioUrl != null) {
            _isAutoContinuing = true;
            if (mounted) _playAyah(nextAyah);
            return;
          }
          nextAyah++;
        }
      }
    }

    // If not continuing or reached end
    if (mounted) setState(() => _playingAyah = null);
  }

  Future<void> _stopAyahPlay() async {
    await _ayahAudio.stop();
    if (mounted) setState(() => _playingAyah = null);
  }

  // ── Audio: full surah ─────────────────────────────────────────────────────
  Future<void> _toggleSurahPlay() async {
    if (_playingAyah != null) {
      if (_ayahAudio.playing) await _ayahAudio.stop();
      setState(() => _playingAyah = null);
    }

    if (_isPlaying) {
      await _surahAudio.pause();
      setState(() => _isPlaying = false);
    } else {
      if (!mounted) return;
      setState(() => _isPlaying = true); // Set immediately for UI feedback

      final settings = QuranSettingsProvider.of(context, listen: false);
      final reciterId = settings.selectedReciterId;

      final offlinePath = await QuranService.instance
          .getDownloadedSurahPath(widget.surahNumber, reciterId);

      try {
        if (offlinePath != null) {
          await _surahAudio.setFilePath(offlinePath);
        } else {
          final audioUrl = _surahAudioData?.reciters[reciterId]?.url;
          if (audioUrl == null) {
            setState(() => _isPlaying = false);
            return;
          }

          await _surahAudio.setUrl(audioUrl,
              headers: kIsWeb
                  ? null
                  : {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                    });
        }

        await _surahAudio.play();

        _surahAudio.playerStateStream
            .where((s) => s.processingState == ProcessingState.completed)
            .first
            .then((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      } catch (e) {
        debugPrint("Playback error: $e");
        if (mounted) setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _downloadSurah() async {
    if (!mounted) return;
    final settings = QuranSettingsProvider.of(context, listen: false);
    final reciterId = settings.selectedReciterId;
    final reciterAudio = _surahAudioData?.reciters[reciterId];

    if (reciterAudio == null) return;

    setState(() => _downloadProgress = 0.0);

    try {
      await QuranService.instance.downloadSurah(
        widget.surahNumber,
        reciterId,
        reciterAudio.url,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );

      if (mounted) {
        final qt = QuranTheme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Downloaded Surah ${widget.surahNumber} by ${reciterAudio.reciterName}'),
          backgroundColor: qt.emeraldDeep,
        ));
        setState(() => _isSurahDownloaded = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloadProgress = null);
    }
  }

  Future<bool> _checkSurahDownloaded() async {
    if (_surahAudioData == null) return false;
    final settings = QuranSettingsProvider.of(context, listen: false);
    String reciterId = settings.selectedReciterId;
    ReciterAudio? reciterAudio = _surahAudioData!.reciters[reciterId];
    if (reciterAudio == null) {
      reciterId = _surahAudioData!.reciters.keys.first;
      reciterAudio = _surahAudioData!.reciters[reciterId];
    }
    if (reciterAudio == null) return false;
    final path = await QuranService.instance
        .getDownloadedSurahPath(widget.surahNumber, reciterId);
    return path != null;
  }

  Future<void> _stopSurahPlay() async {
    await _surahAudio.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _copyAyah(AyahData ayah, QuranSettings settings) {
    final text = '${ayah.arabicFor(settings.script)}\n\n'
        '${settings.showTransliteration && ayah.transliteration.isNotEmpty ? "${ayah.transliteration}\n\n" : ""}'
        '${ayah.translation}\n\n'
        '— Quran ${ayah.surahNumber}:${ayah.ayahNumber}';
    Clipboard.setData(ClipboardData(text: text));
    final qt = QuranTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Ayah copied'),
      backgroundColor: qt.emeraldDeep,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = QuranSettingsProvider.of(context);
    final progress = QuranProgressProvider.of(context);
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: Stack(children: [
        _buildBg(qt),
        SafeArea(
          bottom: false,
          child: Column(children: [
            _buildHeader(qt),
            if (_isNavOpen) _buildGoToAyahPanel(qt),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                          strokeWidth: 2))
                  : _buildReaderList(settings, progress, qt),
            ),
          ]),
        ),
        // Floating audio pill
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 0,
          right: 0,
          child: _buildFloatingPill(settings, qt),
        ),
      ]),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────
  Widget _buildBg(QuranTheme qt) =>
      Positioned.fill(child: Container(color: qt.bg));

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(QuranTheme qt) {
    final surahInfo = _surahInfo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: qt.bg,
        border: Border(bottom: BorderSide(color: qt.borderGlass)),
      ),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: _glassBtn(
              Icon(Icons.arrow_back_ios_new_rounded,
                  color: qt.textPrimary, size: 18),
              qt),
        ),
        // Title — tap to open go-to-ayah
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isNavOpen = !_isNavOpen),
            child: Column(children: [
              Text('SURAH ${surahInfo?.number ?? widget.surahNumber}',
                  style: TextStyle(
                      color: qt.textMuted,
                      fontSize: 10,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(surahInfo?.nameEnglish ?? '',
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _isNavOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: qt.textMuted, size: 20),
                ),
              ]),
            ]),
          ),
        ),
        // Settings
        GestureDetector(
          onTap: () => _showSettingsSheet(),
          child: _glassBtn(
              Icon(Icons.tune_rounded, color: qt.textPrimary, size: 18), qt),
        ),
      ]),
    );
  }

  Widget _glassBtn(Widget child, QuranTheme qt) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qt.glassWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: qt.borderGlass),
            ),
            child: Center(child: child),
          ),
        ),
      );

  Widget _buildGoToAyahPanel(QuranTheme qt) {
    int selectedSurah = widget.surahNumber;
    int selectedAyah = 1;

    return StatefulBuilder(builder: (ctx, setLocal) {
      final currentSurahInfo =
          widget.surahList.firstWhere((s) => s.number == selectedSurah);

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
            // Surah Dropdown
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownLabel('Surah', qt),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: qt.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: qt.borderGlass),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedSurah,
                        dropdownColor: qt.cardBg,
                        isExpanded: true,
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        items: widget.surahList
                            .map((s) => DropdownMenuItem(
                                  value: s.number,
                                  child: Text('${s.number}. ${s.nameEnglish}'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setLocal(() {
                              selectedSurah = v;
                              selectedAyah = 1; // reset ayah when surah changes
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Ayah Dropdown
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownLabel('Ayah', qt),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: qt.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: qt.borderGlass),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedAyah,
                        dropdownColor: qt.cardBg,
                        isExpanded: true,
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        items: List.generate(
                          currentSurahInfo.totalAyahs,
                          (i) => DropdownMenuItem(
                              value: i + 1, child: Text('Ayah ${i + 1}')),
                        ),
                        onChanged: (v) => setLocal(() => selectedAyah = v ?? 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() => _isNavOpen = false);
              if (selectedSurah == widget.surahNumber) {
                // Same surah, just scroll
                Future.delayed(const Duration(milliseconds: 100),
                    () => _scrollToAyah(selectedAyah));
              } else {
                // Different surah, navigate
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => QuranReaderScreen(
                      surahNumber: selectedSurah,
                      initialAyah: selectedAyah,
                      surahList: widget.surahList,
                    ),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: qt.emeraldDeep.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Center(
                child: Text('Jump to Location',
                    style: TextStyle(
                        color: qt.brightness == Brightness.dark
                            ? qt.textPrimary
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _dropdownLabel(String text, QuranTheme qt) => Text(text,
      style: TextStyle(
          color: qt.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));

  // ── Reader list ───────────────────────────────────────────────────────────
  Widget _buildReaderList(
      QuranSettings settings, QuranProgress progress, QuranTheme qt) {
    final surahNum = widget.surahNumber;
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: EdgeInsets.only(
        top: 0,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: _ayahs.length + 2, // +1 bismillah header, +1 nav footer
      itemBuilder: (ctx, index) {
        // Header: Bismillah
        if (index == 0) return _buildBismillah(qt);

        // Footer: Prev/Next navigation
        if (index == _ayahs.length + 1) return _buildNavFooter(qt);

        final ayah = _ayahs[index - 1];
        final isBookmarked = progress.isBookmarked(surahNum, ayah.ayahNumber);
        final isLastRead = progress.isLastRead(surahNum, ayah.ayahNumber);
        final isMenuOpen = _openMenuAyah == ayah.ayahNumber;
        final isPlaying = _playingAyah == ayah.ayahNumber && _ayahAudio.playing;
        final isHighlighted = _highlightedAyah == ayah.ayahNumber;
        final isSelected = _selectedAyah == ayah.ayahNumber;

        return _AyahCard(
          key: ValueKey<int>(ayah.ayahNumber),
          ayah: ayah,
          settings: settings,
          isBookmarked: isBookmarked,
          isLastRead: isLastRead,
          isMenuOpen: isMenuOpen,
          isPlaying: isPlaying,
          isHighlighted: isHighlighted,
          isSelected: isSelected,
          onBookmark: () => progress.toggleBookmark(
              surahNum, ayah.ayahNumber, _surahInfo?.nameEnglish ?? ''),
          onLastRead: () {
            if (isLastRead) {
              progress.clearLastRead();
            } else {
              progress.setLastRead(
                  surahNum, ayah.ayahNumber, _surahInfo?.nameEnglish ?? '');
            }
          },
          onCopy: () => _copyAyah(ayah, settings),
          onPlay: () => _playAyah(ayah.ayahNumber),
          onTap: () {
            setState(() {
              _selectedAyah = ayah.ayahNumber;
              _openMenuAyah = null; // close menu if open
            });
          },
          onToggleMenu: () => setState(() {
            _openMenuAyah = isMenuOpen ? null : ayah.ayahNumber;
            if (_openMenuAyah != null) _openTafsirAyah = null;
          }),
          isTafsirOpen: _openTafsirAyah == ayah.ayahNumber,
          onToggleTafsir: () async {
            final connectivity = await Connectivity().checkConnectivity();
            if (connectivity.contains(ConnectivityResult.none)) {
              final isDownloaded = await QuranService.instance
                      .getOfflineTafsir(surahNum, ayah.ayahNumber) !=
                  null;
              if (!isDownloaded) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Tafsir requires an internet connection.'),
                      backgroundColor: qt.emeraldDeep,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
            }
            setState(() {
              _openTafsirAyah =
                  _openTafsirAyah == ayah.ayahNumber ? null : ayah.ayahNumber;
              if (_openTafsirAyah != null) _openMenuAyah = null;
            });
          },
          surahList: widget.surahList,
        );
      },
    );
  }

  // ── Bismillah ─────────────────────────────────────────────────────────────
  Widget _buildBismillah(QuranTheme qt) {
    // No bismillah for At-Tawbah (9) and Al-Fatihah already contains it
    if (widget.surahNumber == 9 || widget.surahNumber == 1) {
      return const SizedBox(height: 16);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: qt.glassWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: qt.borderGlass),
            ),
            child: Text(
              'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'QPC Hafs',
                  fontSize: 24,
                  color: qt.emeraldGlow,
                  height: 1.8),
            ),
          ),
        ),
      ),
    );
  }

  // ── Nav footer ────────────────────────────────────────────────────────────
  Widget _buildNavFooter(QuranTheme qt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(children: [
        if (_prevSurah != null)
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => QuranReaderScreen(
                          surahNumber: _prevSurah!.number,
                          surahList: widget.surahList))),
              child: _navBtn(_prevSurah!.nameEnglish, isNext: false, qt: qt),
            ),
          )
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 12),
        if (_nextSurah != null)
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => QuranReaderScreen(
                          surahNumber: _nextSurah!.number,
                          surahList: widget.surahList))),
              child: _navBtn(_nextSurah!.nameEnglish, isNext: true, qt: qt),
            ),
          )
        else
          const Expanded(child: SizedBox()),
      ]),
    );
  }

  Widget _navBtn(String name, {required bool isNext, required QuranTheme qt}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: qt.glassWhite,
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
                    Icon(Icons.chevron_left_rounded,
                        color: qt.textMuted, size: 20),
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
        ),
      ),
    );
  }

  // ── Floating audio pill ───────────────────────────────────────────────────
  Widget _buildFloatingPill(QuranSettings settings, QuranTheme qt) {
    final isAnyPlaying = _isPlaying || _playingAyah != null;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isAnyPlaying
                  ? qt.emeraldDeep.withOpacity(0.95)
                  : qt.cardBg.withOpacity(0.88),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: isAnyPlaying
                    ? qt.emeraldLight.withOpacity(0.4)
                    : qt.borderGlass,
              ),
              boxShadow: [
                BoxShadow(
                  color: isAnyPlaying
                      ? qt.emeraldDeep.withOpacity(0.5)
                      : Colors.black26,
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Play mode toggle
              _pillBtn(
                icon: settings.playMode == PlayMode.ayah
                    ? Icons.format_list_numbered_rounded
                    : Icons.queue_music_rounded,
                label: settings.playMode == PlayMode.ayah ? 'Ayah' : 'Surah',
                active: false,
                onTap: () => settings.setPlayMode(
                    settings.playMode == PlayMode.ayah
                        ? PlayMode.surah
                        : PlayMode.ayah),
                qt: qt,
              ),
              const SizedBox(width: 4),
              _divider(qt),
              const SizedBox(width: 4),
              // Current position label
              if (settings.playMode == PlayMode.ayah &&
                  (_playingAyah != null || _selectedAyah != null))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${widget.surahNumber}:${_playingAyah ?? _selectedAyah}',
                    style: TextStyle(
                        color:
                            (isAnyPlaying || qt.brightness == Brightness.dark)
                                ? qt.emeraldLight
                                : qt.emeraldDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              // Main play/pause button
              GestureDetector(
                onTap: settings.playMode == PlayMode.ayah
                    ? () {
                        if (_playingAyah != null || _selectedAyah != null) {
                          _playAyah(_playingAyah ?? _selectedAyah!);
                        } else {
                          _playAyah(1);
                        }
                      }
                    : _toggleSurahPlay,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: qt.emeraldDeep.withOpacity(0.5),
                          blurRadius: 12)
                    ],
                  ),
                  child: Icon(
                      (settings.playMode == PlayMode.ayah
                              ? _ayahAudio.playing
                              : _isPlaying)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26),
                ),
              ),
              if ((settings.playMode == PlayMode.ayah &&
                      _playingAyah != null) ||
                  (settings.playMode == PlayMode.surah && _isPlaying)) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: settings.playMode == PlayMode.ayah
                      ? _stopAyahPlay
                      : _stopSurahPlay,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.stop_rounded,
                        color: Colors.redAccent, size: 20),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              _divider(qt),
              const SizedBox(width: 4),
              // Surah Info
              _pillBtn(
                icon: Icons.info_outline_rounded,
                label: 'Info',
                active: false,
                onTap: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SurahInfoScreen(
                        surahNumber: widget.surahNumber,
                        surahList: widget.surahList,
                      ),
                    ),
                  );
                  if (result != null &&
                      result is Map &&
                      result['ayah'] != null) {
                    _scrollToAyah(result['ayah'] as int);
                  }
                },
                qt: qt,
              ),
              if (settings.playMode == PlayMode.surah) ...[
                const SizedBox(width: 4),
                _divider(qt),
                const SizedBox(width: 4),
                _downloadProgress != null
                    ? Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          value: _downloadProgress,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                        ),
                      )
                    : _isSurahDownloaded
                        ? _pillBtn(
                            icon: Icons.download_done,
                            label: 'Downloaded',
                            active: false,
                            onTap: () {},
                            qt: qt,
                            iconColor: qt.emeraldLight,
                          )
                        : _pillBtn(
                            icon: Icons.download_for_offline_rounded,
                            label: 'Download',
                            active: false,
                            onTap: _downloadSurah,
                            qt: qt,
                          ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pillBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required QuranTheme qt,
    Color? iconColor,
  }) {
    final bool isDark = qt.brightness == Brightness.dark || _isAnyPlaying;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? qt.emeraldDeep.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: iconColor ??
                  (active
                      ? (qt.brightness == Brightness.dark
                          ? qt.emeraldGlow
                          : Colors.white)
                      : (isDark
                          ? Colors.white.withOpacity(0.8)
                          : qt.textMuted)),
              size: 18),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: active
                      ? (qt.brightness == Brightness.dark
                          ? qt.emeraldGlow
                          : Colors.white)
                      : (isDark ? Colors.white.withOpacity(0.7) : qt.textMuted),
                  fontSize: 8,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _divider(QuranTheme qt) => Container(
      width: 1,
      height: 28,
      color: _isAnyPlaying ? Colors.white24 : qt.borderGlass);

  // ── Settings bottom sheet ─────────────────────────────────────────────────
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(
        onTranslationChanged: _reloadTranslation,
        surahAudio: _surahAudioData,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah Card
// ─────────────────────────────────────────────────────────────────────────────
class _AyahCard extends StatelessWidget {
  final AyahData ayah;
  final QuranSettings settings;
  final bool isBookmarked;
  final bool isLastRead;
  final bool isMenuOpen;
  final bool isPlaying;
  final bool isHighlighted;
  final bool isSelected;
  final bool isTafsirOpen;
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
    required this.isMenuOpen,
    required this.isTafsirOpen,
    required this.isPlaying,
    required this.isHighlighted,
    required this.isSelected,
    required this.onBookmark,
    required this.onLastRead,
    required this.onCopy,
    required this.onPlay,
    required this.onTap,
    required this.onToggleMenu,
    required this.onToggleTafsir,
    required this.surahList,
  });

  bool get _isUrdu =>
      settings.translation == TranslationId.urJalandhari ||
      settings.translation == TranslationId.urWahiuddin;

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final arabic = ayah.arabicFor(settings.script);
    final isIndoPak = settings.script == ArabicScript.indoPak;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? qt.emeraldLight.withOpacity(0.12)
            : (isLastRead ? qt.emeraldDeep.withOpacity(0.08) : qt.cardBg),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? qt.emeraldGlow
              : (isLastRead
                  ? qt.emeraldLight.withOpacity(0.3)
                  : qt.borderGlass),
          width: isHighlighted ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: qt.emeraldLight.withOpacity(0.05),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ayah number chip
                  Row(children: [
                    _numberChip(ayah.ayahNumber, isSelected, qt),
                    const Spacer(),
                    if (isLastRead)
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

                  // Arabic text
                  Text(
                    arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: isIndoPak ? 'IndoPak' : 'QPC Hafs',
                      fontSize: settings.arabicFontSize,
                      color: qt.textPrimary,
                      height: 2.0,
                    ),
                  ),

                  // Transliteration
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

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(height: 1, color: qt.borderGlass),
                  ),

                  // Translation
                  if (settings.showTranslation)
                    Text(
                      ayah.translation,
                      textDirection:
                          _isUrdu ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: _isUrdu ? 'IndoPak' : null,
                        fontSize: _isUrdu
                            ? settings.translationFontSize + 3
                            : settings.translationFontSize,
                        color: qt.textSecondary,
                        height: _isUrdu ? 2.0 : 1.65,
                      ),
                    ),

                  // Action row
                  const SizedBox(height: 14),
                  _buildActionRow(qt),

                  // Tafsir Accordion
                  if (isTafsirOpen) ...[
                    const SizedBox(height: 16),
                    _buildTafsirAccordion(context, qt),
                  ],
                ]),
          ),
        ]),
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

  Widget _buildActionRow(QuranTheme qt) {
    return Row(children: [
      Text('${ayah.surahNumber}:${ayah.ayahNumber}',
          style: TextStyle(
              color: qt.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
      const Spacer(),
      _actionBtn(
        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        isBookmarked ? qt.emeraldLight : qt.textMuted,
        onBookmark,
      ),
      const SizedBox(width: 14),
      _actionBtn(
        isLastRead
            ? Icons.check_circle_rounded
            : Icons.check_circle_outline_rounded,
        isLastRead ? qt.emeraldLight : qt.textMuted,
        onLastRead,
      ),
      const SizedBox(width: 14),
      _actionBtn(
        isPlaying
            ? Icons.pause_circle_rounded
            : Icons.play_circle_outline_rounded,
        isPlaying ? qt.emeraldGlow : qt.textMuted,
        onPlay,
        size: 22,
      ),
      const SizedBox(width: 14),
      _actionBtn(Icons.copy_rounded, qt.textMuted, onCopy),
      const SizedBox(width: 14),
      _actionBtn(
        isTafsirOpen ? Icons.menu_book_rounded : Icons.menu_book_outlined,
        isTafsirOpen ? qt.emeraldLight : qt.textMuted,
        onToggleTafsir,
      ),
    ]);
  }

  Widget _buildTafsirAccordion(BuildContext context, QuranTheme qt) {
    final authors = ["Ibn Kathir", "Tazkirul Quran", "Ma'ariful Quran"];

    return Container(
      decoration: BoxDecoration(
        color: qt.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'READ TAFSIR',
              style: TextStyle(
                color: qt.emeraldLight,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...authors.map((author) {
            final isLast = author == authors.last;
            return Column(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TafsirScreen(
                          surahNumber: ayah.surahNumber,
                          ayahNumber: ayah.ayahNumber,
                          initialAuthor: author,
                          surahList: surahList,
                        ),
                      ),
                    );
                  },
                  borderRadius: isLast
                      ? const BorderRadius.vertical(bottom: Radius.circular(16))
                      : BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(
                          author,
                          style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: qt.textMuted, size: 12),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, color: qt.borderGlass, indent: 16),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap,
      {double size = 18}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: size),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  final VoidCallback onTranslationChanged;
  final SurahAudio? surahAudio;

  const _SettingsSheet({
    required this.onTranslationChanged,
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
          // Handle
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
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Theme Toggle
          _label('Appearance', qt),
          const SizedBox(height: 8),
          _themeToggle(settings, qt),
          const SizedBox(height: 20),

          // Arabic script
          _label('Arabic Script', qt),
          const SizedBox(height: 8),
          _scriptToggle(settings, qt),
          const SizedBox(height: 24),
          _sectionDivider(qt),
          const SizedBox(height: 20),

          // Translation
          _label('Translation', qt),
          const SizedBox(height: 8),
          _translationDropdown(context, settings, qt),
          const SizedBox(height: 20),

          // Toggles
          _toggle('Show Transliteration', settings.showTransliteration,
              settings.setShowTransliteration, qt),
          const SizedBox(height: 8),
          _toggle('Show Translation', settings.showTranslation,
              settings.setShowTranslation, qt),
          const SizedBox(height: 24),
          _sectionDivider(qt),
          const SizedBox(height: 20),

          // Preview Card
          _label('Preview', qt),
          const SizedBox(height: 8),
          _buildPreviewCard(settings, qt),
          const SizedBox(height: 16),

          // Font sizes
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

          const SizedBox(height: 8),
          // Play mode
          _label('Audio Mode', qt),
          const SizedBox(height: 8),
          _playModeToggle(settings, qt),
          const SizedBox(height: 16),

          // Reciter selection (only in Surah mode)
          if (settings.playMode == PlayMode.surah && surahAudio != null) ...[
            _label('Reciter', qt),
            const SizedBox(height: 8),
            _reciterDropdown(context, settings, qt),
            const SizedBox(height: 16),
          ],

          // Auto-continue
          _toggle('Auto-continue Ayahs', settings.ayahAutoContinue,
              settings.setAyahAutoContinue, qt),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildPreviewCard(QuranSettings settings, QuranTheme qt) {
    final isIndoPak = settings.script == ArabicScript.indoPak;
    final isUrdu = settings.translation == TranslationId.urJalandhari ||
        settings.translation == TranslationId.urWahiuddin;

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
          'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: isIndoPak ? 'IndoPak' : 'QPC Hafs',
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
          Text(
            'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
            textAlign: isUrdu ? TextAlign.right : TextAlign.left,
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontFamily: isUrdu ? 'IndoPak' : null,
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
      (ArabicScript.indoPak, 'IndoPak'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: qt.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: qt.borderGlass),
      ),
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
                      ? LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid])
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
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

  Widget _translationDropdown(
      BuildContext context, QuranSettings settings, QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: qt.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: qt.borderGlass),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TranslationId>(
          value: settings.translation,
          dropdownColor: qt.cardBg,
          isExpanded: true,
          style: TextStyle(color: qt.textPrimary, fontSize: 14),
          items: TranslationId.values
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              settings.setTranslation(v);
              onTranslationChanged();
            }
          },
        ),
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
        border: Border.all(color: qt.borderGlass),
      ),
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
        border: Border.all(color: qt.borderGlass),
      ),
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
        border: Border.all(color: qt.borderGlass),
      ),
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
          borderRadius: BorderRadius.circular(10),
        ),
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
        border: Border.all(color: qt.borderGlass),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.selectedReciterId,
          dropdownColor: qt.cardBg,
          isExpanded: true,
          style: TextStyle(color: qt.textPrimary, fontSize: 14),
          items: surahAudio!.reciters.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value.reciterName),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              settings.setSelectedReciterId(v);
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
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              qt.borderGlass.withOpacity(0.15),
              Colors.transparent,
            ],
          ),
        ),
      );
}
