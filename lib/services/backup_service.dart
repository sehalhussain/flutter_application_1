import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/quran_theme.dart';
import '../models/downloadable_translation.dart';
import 'translation_download_service.dart';

class BackupService {
  static const String _backupFileName = "kitably_backup.json";
  static const int _backupVersion = 2;

  /// All known SharedPreferences keys that contain **user data** worth backing up.
  ///
  /// Excludes transient caches (prayer times, calendar) and any other ephemeral
  /// values that would be recalculated automatically.
  static const List<String> _userDataKeys = [
    'prayer_city',
    'prayer_country',
    'prayer_lat',
    'prayer_lng',
    'prayer_asr_method',
    'prayer_calc_method',
    'prayer_hijri_adj',
    'prayer_setup_completed',
    'prayer_tracker_log',
    'app_theme_mode',
    'app_show_bismillah_splash',
    'quran_script',
    'quran_translation',
    'quran_transliteration',
    'quran_show_translation',
    'quran_arabic_size',
    'quran_trans_size',
    'quran_play_mode',
    'quran_auto_continue',
    'quran_reciter_id',
    'quran_ayah_reciter_id',
    'quran_reader_tips_seen',
    'quran_bookmarks',
    'quran_recent_reads_v2',
    'dua_arabic_size',
    'dua_translation_size',
    'dua_show_transliteration',
    'dua_show_translation',
    'dua_favorites',
    'dua_pinned_categories',
    'hadith_arabic_size',
    'hadith_translation_size',
    'hadith_favorites',
    'hadith_last_read',
  ];

  // ── Export ──────────────────────────────────────────────────────────────────

  /// Shows a bottom sheet (matching the app's modal style) letting the user
  /// choose whether to save the backup to a file they pick or share via apps.
  static Future<void> exportBackup(BuildContext context) async {
    final qt = QuranTheme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: qt.borderGlass,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Export Backup",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Choose how you want to export your bookmarks, duas, hadith favorites, prayer logs, and settings.",
              style: TextStyle(
                fontSize: 13,
                color: qt.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _buildExportOptionTile(
              qt: qt,
              icon: Icons.save_alt_rounded,
              title: "Save to device",
              subtitle: "Pick a folder to store the backup file",
              onTap: () {
                Navigator.pop(ctx);
                _doSaveToDevice(context, qt);
              },
            ),
            const SizedBox(height: 12),
            _buildExportOptionTile(
              qt: qt,
              icon: Icons.share_rounded,
              title: "Share via apps",
              subtitle: "Send via email, Drive, or other apps",
              onTap: () {
                Navigator.pop(ctx);
                _doShareViaApps(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Styled option card matching the menu screen's bottom sheet style.
  static Widget _buildExportOptionTile({
    required QuranTheme qt,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: qt.borderGlass.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: qt.emeraldDeep, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: qt.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: qt.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  /// Builds the backup JSON payload and returns the raw string + file path.
  static Future<(String json, String tempPath)> _buildBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> backupData = {};
    for (final key in _userDataKeys) {
      final value = prefs.get(key);
      if (value != null) {
        backupData[key] = value;
      }
    }

    final extraKeys = prefs.getKeys().where((k) =>
        !_userDataKeys.contains(k) &&
        !k.startsWith('prayer_cache') &&
        !k.startsWith('calendar_cache'));
    for (final key in extraKeys) {
      backupData[key] = prefs.get(key);
    }

    final translationDownloadIds = <String>[];
    for (final t in kDownloadableTranslations) {
      if (TranslationDownloadService.instance.isDownloaded(t.id) == true) {
        translationDownloadIds.add(t.id);
      }
    }

    final backupPayload = {
      'version': _backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'translation_downloads': translationDownloadIds,
      'data': backupData,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupPayload);

    final tempDir = await getTemporaryDirectory();
    final backupFile = File('${tempDir.path}/$_backupFileName');
    await backupFile.writeAsString(jsonStr);

    return (jsonStr, backupFile.path);
  }

  /// Opens a native save-file dialog so the user picks exactly where to save.
  static Future<void> _doSaveToDevice(
      BuildContext context, QuranTheme qt) async {
    try {
      final (jsonStr, _) = await _buildBackupPayload();

      // saveFile on Android/iOS requires bytes — pass the file content directly
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final outputPath = await FilePicker.saveFile(
        dialogTitle: 'Save Backup',
        fileName: _backupFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (outputPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Backup saved successfully!"),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF26A69A),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup export failed: $e")),
        );
      }
    }
  }

  /// Shares the backup via the native share sheet.
  static Future<void> _doShareViaApps(BuildContext context) async {
    try {
      final (_, tempPath) = await _buildBackupPayload();

      final xFile = XFile(tempPath, mimeType: 'application/json');
      await Share.shareXFiles([xFile], subject: 'Kitably App Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup export failed: $e")),
        );
      }
    }
  }

  // ── Import / Restore ────────────────────────────────────────────────────────

  static Future<bool> importBackup(BuildContext context) async {
    try {
      // Pick the file
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final Map<String, dynamic> decoded = json.decode(jsonStr);

        final Map<String, dynamic> backupData;

        // Detect format: new versioned format vs old flat format
        if (decoded.containsKey('version') && decoded.containsKey('data')) {
          backupData = decoded['data'] as Map<String, dynamic>;
        } else {
          // Old backup from before versioning – flat SharedPreferences dump
          backupData = decoded;
        }

        final prefs = await SharedPreferences.getInstance();

        // Restore values
        for (final key in backupData.keys) {
          final value = backupData[key];
          if (value is String)
            await prefs.setString(key, value);
          else if (value is int)
            await prefs.setInt(key, value);
          else if (value is double)
            await prefs.setDouble(key, value);
          else if (value is bool)
            await prefs.setBool(key, value);
          else if (value is List) {
            // SharedPreferences only accepts List<String>
            final stringList = value.map((e) => e.toString()).toList();
            await prefs.setStringList(key, stringList);
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Backup restored successfully! Restart the app to see all changes."),
              duration: Duration(seconds: 4),
              backgroundColor: Color(0xFF26A69A),
            ),
          );
        }
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Restore failed: Make sure it is a valid backup file. Error: $e"),
          ),
        );
      }
    }
    return false;
  }
}
