import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HadithReaderSettings extends ChangeNotifier {
  double _arabicFontSize = 26.0;
  double _translationFontSize = 16.0;

  double get arabicFontSize => _arabicFontSize;
  double get translationFontSize => _translationFontSize;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _arabicFontSize = prefs.getDouble('hadith_arabic_size') ?? 26.0;
    _translationFontSize = prefs.getDouble('hadith_translation_size') ?? 16.0;
    notifyListeners();
  }

  Future<void> setArabicFontSize(double value) async {
    _arabicFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadith_arabic_size', value);
  }

  Future<void> setTranslationFontSize(double value) async {
    _translationFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadith_translation_size', value);
  }
}

class HadithReaderSettingsProvider {
  static HadithReaderSettings of(BuildContext context, {bool listen = true}) {
    return Provider.of<HadithReaderSettings>(context, listen: listen);
  }
}
