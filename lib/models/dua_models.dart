// ═══════════════════════════════════════════════════════════════════════════
// NEW HIERARCHICAL DUA MODELS (for duas_reorganized.json)
// ═══════════════════════════════════════════════════════════════════════════

class DuaSegment {
  final int segmentId;
  final String segmentName;
  final List<DuaCategory> categories;

  DuaSegment({
    required this.segmentId,
    required this.segmentName,
    required this.categories,
  });

  factory DuaSegment.fromJson(Map<String, dynamic> json) {
    return DuaSegment(
      segmentId: json['segment_id'] as int,
      segmentName: json['segment_name'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => DuaCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DuaCategory {
  final int categoryId;
  final String categoryName;
  final List<DuaTitle> titles;

  DuaCategory({
    required this.categoryId,
    required this.categoryName,
    required this.titles,
  });

  factory DuaCategory.fromJson(Map<String, dynamic> json) {
    return DuaCategory(
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String,
      titles: (json['titles'] as List<dynamic>)
          .map((e) => DuaTitle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DuaTitle {
  final int titleId;
  final String titleName;
  final List<DuaItem> duas;

  DuaTitle({
    required this.titleId,
    required this.titleName,
    required this.duas,
  });

  factory DuaTitle.fromJson(Map<String, dynamic> json) {
    return DuaTitle(
      titleId: json['title_id'] as int,
      titleName: json['title_name'] as String,
      duas: (json['duas'] as List<dynamic>)
          .map((e) => DuaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DuaItem {
  final int id;
  final String? arabic;
  final String? latin;
  final String? translation;
  final String? source;
  final String? benefits;
  final int repeat; // Kept as fallback metric if needed

  DuaItem({
    required this.id,
    this.arabic,
    this.latin,
    this.translation,
    this.source,
    this.benefits,
    this.repeat = 1,
  });

  factory DuaItem.fromJson(Map<String, dynamic> json) {
    return DuaItem(
      id: (json['id'] as num).toInt(),
      arabic: json['arabic'] as String?,
      latin: json['latin'] as String?,
      translation: json['translation'] as String?,
      source: json['source'] as String?,
      benefits: json['benefits'] as String?,
      repeat: (json['repeat'] as num?)?.toInt() ?? 1,
    );
  }

  /// Extract a short descriptive title for the card header.
  String get computedTitle {
    if (latin != null && latin!.isNotEmpty && latin!.length < 80) {
      return latin!;
    }
    final t = translation?.trim() ?? '';
    if (t.isEmpty) return 'Dua #$id';

    // Try first sentence break
    final periodIdx = t.indexOf('. ');
    if (periodIdx > 5 && periodIdx < 70) {
      return t.substring(0, periodIdx + 1);
    }
    // Try first bracket group
    final bracketIdx = t.indexOf(')');
    if (bracketIdx > 5 && bracketIdx < 70) {
      return t.substring(0, bracketIdx + 1);
    }
    if (t.length > 60) {
      return '${t.substring(0, 57)}...';
    }
    return t;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FLATTENED DISPLAY MODEL for ListView rendering
// ═══════════════════════════════════════════════════════════════════════════

enum DuaListTileType { categoryHeader, titleHeader, duaCard }

class DuaFlatItem {
  final DuaListTileType type;
  final String? categoryName;
  final String? titleName;
  final DuaItem? item;
  final int totalItems; // for title header count badge

  DuaFlatItem.category(this.categoryName)
      : type = DuaListTileType.categoryHeader,
        titleName = null,
        item = null,
        totalItems = 0;

  DuaFlatItem.title(this.titleName, this.totalItems)
      : type = DuaListTileType.titleHeader,
        categoryName = null,
        item = null;

  DuaFlatItem.card(this.item)
      : type = DuaListTileType.duaCard,
        categoryName = null,
        titleName = null,
        totalItems = 0;
}

/// Flatten a DuaSegment into a sequential display list for ListView.
List<DuaFlatItem> flattenSegment(DuaSegment segment) {
  final list = <DuaFlatItem>[];
  for (final cat in segment.categories) {
    list.add(DuaFlatItem.category(cat.categoryName));
    for (final tl in cat.titles) {
      list.add(DuaFlatItem.title(tl.titleName, tl.duas.length));
      for (final item in tl.duas) {
        list.add(DuaFlatItem.card(item));
      }
    }
  }
  return list;
}

/// Search through a flattened list and return matched indices.
List<bool> searchFlatList(List<DuaFlatItem> flatList, String query) {
  if (query.isEmpty) return List.filled(flatList.length, true);
  final q = query.toLowerCase();

  return flatList.map((f) {
    if (f.type == DuaListTileType.categoryHeader) {
      return f.categoryName?.toLowerCase().contains(q) ?? false;
    }
    if (f.type == DuaListTileType.titleHeader) {
      return f.titleName?.toLowerCase().contains(q) ?? false;
    }
    if (f.type == DuaListTileType.duaCard && f.item != null) {
      final d = f.item!;
      return (d.arabic?.toLowerCase().contains(q) ?? false) ||
          (d.latin?.toLowerCase().contains(q) ?? false) ||
          (d.translation?.toLowerCase().contains(q) ?? false) ||
          (d.source?.toLowerCase().contains(q) ?? false) ||
          (d.benefits?.toLowerCase().contains(q) ?? false);
    }
    return false;
  }).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// NEW: Multi-segment helpers (for the reorganized 6-segment structure)
// ═══════════════════════════════════════════════════════════════════════════

/// Flatten ALL segments into a single list with segment headers.
List<DuaFlatItem> flattenAllSegments(List<DuaSegment> segments) {
  final list = <DuaFlatItem>[];
  for (final seg in segments) {
    // Add segment header
    list.add(DuaFlatItem.category(seg.segmentName));
    for (final cat in seg.categories) {
      list.add(DuaFlatItem.category('  ${cat.categoryName}'));
      for (final tl in cat.titles) {
        list.add(DuaFlatItem.title(tl.titleName, tl.duas.length));
        for (final item in tl.duas) {
          list.add(DuaFlatItem.card(item));
        }
      }
    }
  }
  return list;
}

/// Search across all segments.
List<bool> searchAllSegments(List<DuaFlatItem> flatList, String query) {
  if (query.isEmpty) return List.filled(flatList.length, true);
  final q = query.toLowerCase();

  return flatList.map((f) {
    if (f.type == DuaListTileType.categoryHeader) {
      return f.categoryName?.toLowerCase().contains(q) ?? false;
    }
    if (f.type == DuaListTileType.titleHeader) {
      return f.titleName?.toLowerCase().contains(q) ?? false;
    }
    if (f.type == DuaListTileType.duaCard && f.item != null) {
      final d = f.item!;
      return (d.arabic?.toLowerCase().contains(q) ?? false) ||
          (d.latin?.toLowerCase().contains(q) ?? false) ||
          (d.translation?.toLowerCase().contains(q) ?? false) ||
          (d.source?.toLowerCase().contains(q) ?? false) ||
          (d.benefits?.toLowerCase().contains(q) ?? false);
    }
    return false;
  }).toList();
}
