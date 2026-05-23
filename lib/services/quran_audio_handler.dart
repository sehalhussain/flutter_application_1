import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Managed configuration handler for our global background player.
///
/// Under the hood, [just_audio_background] automatically spins up the Android
/// Foreground Service and updates notifications whenever a player loads an
/// [AudioSource] containing a [MediaItem] tag.
class QuranAudioHandler {
  // ── Singleton Constructor ─────────────────────────────────────────────────
  QuranAudioHandler._() {
    _configureSession();
  }

  /// Global instance to share the single player across screens.
  static final QuranAudioHandler instance = QuranAudioHandler._();

  // ── Player Instance ───────────────────────────────────────────────────────
  // CRITICAL: just_audio_background only allows ONE active AudioPlayer instance in the app.
  // Creating multiple AudioPlayer instances will trigger a fatal runtime crash.
  final AudioPlayer _player = AudioPlayer();

  /// Both getters point to the SAME underlying player instance. This completely
  /// avoids runtime background conflicts while maintaining 100% compatibility
  /// with your existing UI and screen event listeners.
  AudioPlayer get ayahPlayer => _player;
  AudioPlayer get surahPlayer => _player;

  // ── Audio session setup ──────────────────────────────────────────────────
  Future<void> _configureSession() async {
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
    } catch (_) {}
  }

  // ── Background Audio Helpers ─────────────────────────────────────────────

  /// Loads an audio URL into the Player with the correct background metadata tag.
  Future<void> setAyahSource(String url,
      {required String surahName, required int ayahNumber}) async {
    final source = AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(
        id: 'quran_ayah_${surahName}_$ayahNumber',
        title: '$surahName — Ayah $ayahNumber',
        artist: 'Quran Recitation',
        album: 'Al-Quran',
      ),
    );
    await _player.setAudioSource(source);
  }

  /// Loads an audio URL (or local file path) into the Player with background metadata tag.
  Future<void> setSurahSource(String sourcePath,
      {required String surahName,
      String? reciterName,
      bool isLocal = false}) async {
    final MediaItem metadata = MediaItem(
      id: 'quran_surah_$surahName',
      title: surahName,
      artist: reciterName ?? 'Quran Recitation',
      album: 'Al-Quran',
    );

    final AudioSource source = isLocal
        ? AudioSource.file(sourcePath, tag: metadata)
        : AudioSource.uri(Uri.parse(sourcePath), tag: metadata);

    await _player.setAudioSource(source);
  }

  // ── Clean Up ─────────────────────────────────────────────────────────────
  void dispose() {
    _player.dispose();
  }
}
