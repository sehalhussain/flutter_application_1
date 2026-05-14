import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DuaSettings extends ChangeNotifier {
  double _arabicFontSize = 24.0;
  double _translationFontSize = 14.0;

  double get arabicFontSize => _arabicFontSize;
  double get translationFontSize => _translationFontSize;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _arabicFontSize = prefs.getDouble('dua_arabic_size') ?? 24.0;
    _translationFontSize = prefs.getDouble('dua_translation_size') ?? 14.0;
    notifyListeners();
  }

  Future<void> setArabicFontSize(double value) async {
    _arabicFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dua_arabic_size', value);
  }

  Future<void> setTranslationFontSize(double value) async {
    _translationFontSize = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dua_translation_size', value);
  }
}

class DuaSettingsProvider {
  static DuaSettings of(BuildContext context, {bool listen = true}) {
    return Provider.of<DuaSettings>(context, listen: listen);
  }
}
