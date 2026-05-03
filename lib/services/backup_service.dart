import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  static const String _backupFileName = "assalah_backup.json";

  static Future<void> exportBackup(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Filter out caching keys so we only backup important user data (bookmarks, location, settings)
      final keys = prefs.getKeys().where((k) => 
        !k.startsWith('prayer_cache') && 
        !k.startsWith('calendar_cache')
      );

      final Map<String, dynamic> backupData = {};
      for (final key in keys) {
        backupData[key] = prefs.get(key);
      }

      final jsonStr = json.encode(backupData);

      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/$_backupFileName');
      await backupFile.writeAsString(jsonStr);

      // Trigger the native share intent
      final xFile = XFile(backupFile.path, mimeType: 'application/json');
      await Share.shareXFiles([xFile], subject: 'As-Salah App Backup');
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup export failed: $e")),
        );
      }
    }
  }

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
        final Map<String, dynamic> backupData = json.decode(jsonStr);

        final prefs = await SharedPreferences.getInstance();
        
        // Restore values
        for (final key in backupData.keys) {
          final value = backupData[key];
          if (value is String) await prefs.setString(key, value);
          else if (value is int) await prefs.setInt(key, value);
          else if (value is double) await prefs.setDouble(key, value);
          else if (value is bool) await prefs.setBool(key, value);
          else if (value is List) await prefs.setStringList(key, List<String>.from(value));
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Backup restored successfully! Restart the app to see all changes."),
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
          SnackBar(content: Text("Restore failed: Make sure it is a valid backup file. Error: $e")),
        );
      }
    }
    return false;
  }
}
