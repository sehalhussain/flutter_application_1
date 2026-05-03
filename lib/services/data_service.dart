import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/name_model.dart';
import '../models/dua_model.dart';

class DataService {
  static List<AsmaName>? _cacheNames;

  static Future<List<AsmaName>> loadNames() async {
    if (_cacheNames != null) return _cacheNames!;
    try {
      final ByteData data = await rootBundle.load('assets/data/names/asmaulhusna.json');
      
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

      _cacheNames = dataList.map((item) => AsmaName.fromJson(item as Map<String, dynamic>)).toList();
      return _cacheNames!;
    } catch (e) {
      print("Error loading JSON: $e");
      return [];
    }
  }

  static Future<List<Dua>> loadDuas(String assetPath) async {
    try {
      final String s = await rootBundle.loadString(assetPath);
      final List<dynamic> decoded = await compute((String data) {
        return json.decode(data);
      }, s);

      return decoded.map((item) => Dua.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print("Error loading Duas JSON from $assetPath: $e");
      return [];
    }
  }
}
