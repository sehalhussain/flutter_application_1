// lib/providers/quran_settings_provider.dart
//
// Persists all reader preferences via shared_preferences.
// Wrap your QuranHomeScreen (or MaterialApp) with QuranSettingsProvider.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

class QuranSettings extends ChangeNotifier {
  // ── Defaults ──────────────────────────────────────────────────────────────
  ArabicScript _script = ArabicScript.uthmani;
  TranslationId _translation = TranslationId.enSahih;
  bool _showTransliteration = true;
  bool _showTranslation = true;
  double _arabicFontSize = 32.0;
  double _translationFontSize = 15.0;
  PlayMode _playMode = PlayMode.ayah;
  bool _ayahAutoContinue = true;
  String _selectedReciterId = "1"; // Default to Mishary Rashid Al Afasy
  String _selectedAyahReciterId = "mishary";
  ThemeMode _themeMode = ThemeMode.system;

  // ── Getters ───────────────────────────────────────────────────────────────
  ArabicScript get script => _script;
  TranslationId get translation => _translation;
  bool get showTransliteration => _showTransliteration;
  bool get showTranslation => _showTranslation;
  double get arabicFontSize => _arabicFontSize;
  double get translationFontSize => _translationFontSize;
  PlayMode get playMode => _playMode;
  bool get ayahAutoContinue => _ayahAutoContinue;
  String get selectedReciterId => _selectedReciterId;
  String get selectedAyahReciterId => _selectedAyahReciterId;
  ThemeMode get themeMode => _themeMode;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final scriptIdx = prefs.getInt('quran_script') ?? 0;
    _script =
        ArabicScript.values[scriptIdx.clamp(0, ArabicScript.values.length - 1)];

    final transIdx = prefs.getInt('quran_translation') ?? 0;
    _translation = TranslationId
        .values[transIdx.clamp(0, TranslationId.values.length - 1)];

    _showTransliteration = prefs.getBool('quran_transliteration') ?? true;
    _showTranslation = prefs.getBool('quran_show_translation') ?? true;
    _arabicFontSize = prefs.getDouble('quran_arabic_size') ?? 32.0;
    _translationFontSize = prefs.getDouble('quran_trans_size') ?? 15.0;
    _ayahAutoContinue = prefs.getBool('quran_auto_continue') ?? false;

    final pmIdx = prefs.getInt('quran_play_mode') ?? 1;
    _playMode = PlayMode.values[pmIdx.clamp(0, PlayMode.values.length - 1)];

    _selectedReciterId = prefs.getString('quran_reciter_id') ?? "1";
    _selectedAyahReciterId = prefs.getString('quran_ayah_reciter_id') ?? "mishary";

    final themeIdx = prefs.getInt('app_theme_mode') ?? 0;
    _themeMode =
        ThemeMode.values[themeIdx.clamp(0, ThemeMode.values.length - 1)];

    notifyListeners();
  }

  // ── Setters (auto-persist) ────────────────────────────────────────────────
  Future<void> setScript(ArabicScript v) async {
    _script = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setInt('quran_script', v.index);
  }

  Future<void> setTranslation(TranslationId v) async {
    _translation = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setInt('quran_translation', v.index);
  }

  Future<void> setShowTransliteration(bool v) async {
    _showTransliteration = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setBool('quran_transliteration', v);
  }

  Future<void> setShowTranslation(bool v) async {
    _showTranslation = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setBool('quran_show_translation', v);
  }

  Future<void> setArabicFontSize(double v) async {
    _arabicFontSize = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setDouble('quran_arabic_size', v);
  }

  Future<void> setTranslationFontSize(double v) async {
    _translationFontSize = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setDouble('quran_trans_size', v);
  }

  Future<void> setPlayMode(PlayMode v) async {
    _playMode = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setInt('quran_play_mode', v.index);
  }

  Future<void> setAyahAutoContinue(bool v) async {
    _ayahAutoContinue = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setBool('quran_auto_continue', v);
  }

  Future<void> setSelectedReciterId(String v) async {
    _selectedReciterId = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setString('quran_reciter_id', v);
  }

  Future<void> setSelectedAyahReciterId(String v) async {
    _selectedAyahReciterId = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setString('quran_ayah_reciter_id', v);
  }

  Future<void> setThemeMode(ThemeMode v) async {
    _themeMode = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    p.setInt('app_theme_mode', v.index);
  }
}

// ── Provider widget ───────────────────────────────────────────────────────────
class QuranSettingsProvider {
  static QuranSettings of(BuildContext context, {bool listen = true}) {
    return Provider.of<QuranSettings>(context, listen: listen);
  }
}
