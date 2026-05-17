// lib/services/translation_download_service.dart
//
// Manages downloading translations on demand, tracking progress,
// and checking whether a translation is already downloaded.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/downloadable_translation.dart';

class TranslationDownloadService extends ChangeNotifier {
  // ── Singleton ─────────────────────────────────────────────────────────────
  TranslationDownloadService._();
  static final TranslationDownloadService instance =
      TranslationDownloadService._();

  // ── State ─────────────────────────────────────────────────────────────────
  final Map<String, double> _downloadProgress = {}; // id → 0.0–1.0
  final Map<String, bool> _downloaded = {}; // id → true/false
  final Map<String, StreamSubscription?> _activeDownloads = {};

  // ── Getters ───────────────────────────────────────────────────────────────
  double? progressFor(String id) => _downloadProgress[id];
  bool? isDownloaded(String id) => _downloaded[id];
  bool isDownloading(String id) => _activeDownloads.containsKey(id);
  Map<String, bool> get downloadedStatus => Map.unmodifiable(_downloaded);
  Map<String, double> get downloadProgress =>
      Map.unmodifiable(_downloadProgress);

  // ── Path helpers ──────────────────────────────────────────────────────────
  Future<Directory> get _translationsDir async {
    final dir = await getApplicationDocumentsDirectory();
    final transDir = Directory('${dir.path}/translations');
    if (!await transDir.exists()) {
      await transDir.create(recursive: true);
    }
    return transDir;
  }

  Future<String> _filePath(String id) async {
    final dir = await _translationsDir;
    return '${dir.path}/translation_$id.json';
  }

  /// Returns the path to a downloaded translation file, or null if not downloaded.
  Future<String?> getDownloadedPath(String id) async {
    final file = File(await _filePath(id));
    if (await file.exists()) return file.path;
    return null;
  }

  // ── Check download status ────────────────────────────────────────────────
  Future<void> refreshDownloadedStatus() async {
    for (final t in kDownloadableTranslations) {
      final path = await getDownloadedPath(t.id);
      _downloaded[t.id] = path != null;
    }
    Future.microtask(notifyListeners);
  }

  /// Check if a specific translation is downloaded.
  Future<bool> checkIfDownloaded(String id) async {
    final path = await getDownloadedPath(id);
    final isDown = path != null;
    _downloaded[id] = isDown;
    return isDown;
  }

  // ── Download ──────────────────────────────────────────────────────────────
  Future<void> downloadTranslation(
    DownloadableTranslation translation, {
    Function(double)? onProgress,
  }) async {
    final id = translation.id;

    // Already downloading
    if (_activeDownloads.containsKey(id)) return;

    // Already downloaded — just mark it
    if (_downloaded[id] == true) {
      Future.microtask(notifyListeners);
      return;
    }

    final completer = Completer<void>();
    _downloadProgress[id] = 0.0;
    Future.microtask(notifyListeners);

    try {
      final response = await http.get(Uri.parse(translation.url));
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download ${translation.displayName}: HTTP ${response.statusCode}');
      }

      // Stream-style progress simulation (http package doesn't give incremental progress
      // for the whole file easily, but we can use the body bytes length)
      final bytes = response.bodyBytes;
      final totalBytes = bytes.length;
      int received = 0;

      // We'll save in chunks to show progress
      final file = File(await _filePath(id));
      final sink = file.openWrite();

      // Write in chunks of ~16KB so we can update progress
      const chunkSize = 16 * 1024;
      for (int offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, bytes.length);
        sink.add(bytes.sublist(offset, end));
        received = end;
        final progress = received / totalBytes;
        _downloadProgress[id] = progress;
        onProgress?.call(progress);
        // Notify UI on each chunk
        Future.microtask(notifyListeners);
        // Yield to event loop so UI can update
        await Future.delayed(Duration.zero);
      }

      await sink.flush();
      await sink.close();

      _downloaded[id] = true;
      _downloadProgress[id] = 1.0;
      Future.microtask(notifyListeners);

      // Validate JSON
      final savedContent = await file.readAsString();
      try {
        json.decode(savedContent) as Map<String, dynamic>;
      } catch (_) {
        // Invalid JSON — delete and throw
        await file.delete();
        _downloaded[id] = false;
        _downloadProgress.remove(id);
        Future.microtask(notifyListeners);
        throw Exception(
            'Downloaded file for ${translation.displayName} is corrupted');
      }
    } catch (e) {
      _downloadProgress.remove(id);
      _downloaded[id] = false;
      Future.microtask(notifyListeners);
      rethrow;
    } finally {
      _activeDownloads.remove(id);
      Future.microtask(notifyListeners);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> deleteTranslation(String id) async {
    final file = File(await _filePath(id));
    if (await file.exists()) {
      await file.delete();
    }
    _downloaded[id] = false;
    _downloadProgress.remove(id);
    Future.microtask(notifyListeners);
  }

  Future<void> deleteAllTranslations() async {
    for (final t in kDownloadableTranslations) {
      await deleteTranslation(t.id);
    }
  }

  // ── Load downloaded translation JSON ──────────────────────────────────────
  /// Loads the downloaded translation JSON into memory.
  /// Returns null if not downloaded.
  Future<Map<String, dynamic>?> loadTranslationJson(String id) async {
    final path = await getDownloadedPath(id);
    if (path == null) return null;
    try {
      final file = File(path);
      final content = await file.readAsString();
      return json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading translation $id: $e');
      return null;
    }
  }

  // ── Get list of downloaded translation files for management ───────────────
  Future<List<File>> getDownloadedTranslationFiles() async {
    final dir = await _translationsDir;
    if (!await dir.exists()) return [];
    return dir.listSync().whereType<File>().toList();
  }
}
