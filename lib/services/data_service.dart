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

      final dynamic decoded = await compute((ByteData b) {
        final String s = utf8.decode(b.buffer.asUint8List());
        return json.decode(s);
      }, data);

      final List<dynamic> dataList;
      if (decoded is List) {
        dataList = decoded;
      } else if (decoded is Map && decoded.containsKey('data')) {
        dataList = decoded['data'] as List<dynamic>;
      } else {
        dataList = [];
      }

      _cacheNames = dataList
          .map((item) => AsmaName.fromJson(item as Map<String, dynamic>))
          .toList();
      return _cacheNames!;
    } catch (e) {
      print("Error loading JSON: $e");
      return [];
    }
  }

  /// Load the consolidated duas JSON and return the list of segments.
  /// Uses in-memory cache to avoid re-parsing on subsequent navigations.
  static Future<List<DuaSegment>> loadDuas(String assetPath) async {
    if (_cacheDuas != null) return _cacheDuas!;
    try {
      final ByteData data = await rootBundle.load(assetPath);

      // Decode + parse JSON on a background isolate
      final List<Map<String, dynamic>> rawList = await compute(
        (ByteData b) {
          final String s = utf8.decode(b.buffer.asUint8List());
          final dynamic decoded = json.decode(s);
          final List<dynamic> dataList;
          if (decoded is List) {
            dataList = decoded;
          } else if (decoded is Map && decoded.containsKey('segments')) {
            dataList = decoded['segments'] as List<dynamic>;
          } else {
            dataList = [];
          }
          return dataList.cast<Map<String, dynamic>>();
        },
        data,
      );

      // Parse models on a background isolate too
      _cacheDuas = await compute(
        (List<Map<String, dynamic>> list) =>
            list.map((m) => DuaSegment.fromJson(m)).toList(),
        rawList,
      );
      return _cacheDuas!;
    } catch (e) {
      debugPrint("Error loading Duas JSON from $assetPath: $e");
      return [];
    }
  }

  /// Clear dua cache (e.g. on language change or memory pressure)
  static void clearDuaCache() {
    _cacheDuas = null;
  }
}
