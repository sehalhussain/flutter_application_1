import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/name_model.dart';
import '../models/dua_models.dart';

class DataService {
  static List<AsmaName>? _cacheNames;
  static List<DuaSegment>? _cacheDuas;

  static Future<List<AsmaName>> loadNames() async {
    if (_cacheNames != null) return _cacheNames!;
    try {
      final ByteData data =
          await rootBundle.load('assets/data/names/asmaulhusna.json');

      // Single compute call — JSON decode + model parsing,
      // all off the main thread. No main-thread work at all.
      _cacheNames = await compute(_parseNamesIsolate, data);
      return _cacheNames!;
    } catch (e) {
      debugPrint("Error loading Names JSON: $e");
      return [];
    }
  }

  /// Everything here runs on a background isolate.
  static List<AsmaName> _parseNamesIsolate(ByteData b) {
    final String raw = utf8.decode(b.buffer.asUint8List());
    final dynamic decoded = json.decode(raw);

    final List<dynamic> dataList;
    if (decoded is List) {
      dataList = decoded;
    } else if (decoded is Map && decoded.containsKey('data')) {
      dataList = decoded['data'] as List<dynamic>;
    } else {
      dataList = [];
    }

    return List<AsmaName>.generate(
      dataList.length,
      (i) => AsmaName.fromJson(dataList[i] as Map<String, dynamic>),
      growable: false,
    );
  }

  /// Load the consolidated duas JSON and return the list of segments.
  /// Uses in-memory cache to avoid re-parsing on subsequent navigations.
  static Future<List<DuaSegment>> loadDuas(String assetPath) async {
    if (_cacheDuas != null) return _cacheDuas!;
    try {
      final ByteData data = await rootBundle.load(assetPath);

      // Merged into a single compute — decode + parse in one isolate spin
      // instead of two separate compute calls.
      _cacheDuas = await compute(_parseDuasIsolate, data);
      return _cacheDuas!;
    } catch (e) {
      debugPrint("Error loading Duas JSON from $assetPath: $e");
      return [];
    }
  }

  /// Everything here runs on a background isolate.
  static List<DuaSegment> _parseDuasIsolate(ByteData b) {
    final String raw = utf8.decode(b.buffer.asUint8List());
    final dynamic decoded = json.decode(raw);

    final List<dynamic> dataList;
    if (decoded is List) {
      dataList = decoded;
    } else if (decoded is Map && decoded.containsKey('segments')) {
      dataList = decoded['segments'] as List<dynamic>;
    } else {
      dataList = [];
    }

    return List<DuaSegment>.generate(
      dataList.length,
      (i) => DuaSegment.fromJson(dataList[i] as Map<String, dynamic>),
      growable: false,
    );
  }

  /// Clear caches (e.g. on language change or memory pressure)
  static void clearNameCache() {
    _cacheNames = null;
  }

  static void clearDuaCache() {
    _cacheDuas = null;
  }
}
