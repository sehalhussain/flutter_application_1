// lib/constants/sajdah_data.dart
//
// Compile-time constant map of all 15 Quran sajdah verses.
// No JSON parsing, no I/O, no GC overhead — instant lookup.
// Data source: assets/data/juz/quran-metadata-sajda.json

import '../models/quran_models.dart';

/// Map of verse_key -> SajdahMetadata for all 15 sajdah verses.
const kSajdahData = <String, SajdahMetadata>{
  '7:206': SajdahMetadata(
      sajdahNumber: 1, verseKey: '7:206', sajdahType: 'optional'),
  '13:15': SajdahMetadata(
      sajdahNumber: 2, verseKey: '13:15', sajdahType: 'optional'),
  '16:50': SajdahMetadata(
      sajdahNumber: 3, verseKey: '16:50', sajdahType: 'optional'),
  '17:109': SajdahMetadata(
      sajdahNumber: 4, verseKey: '17:109', sajdahType: 'optional'),
  '19:58': SajdahMetadata(
      sajdahNumber: 5, verseKey: '19:58', sajdahType: 'optional'),
  '22:18': SajdahMetadata(
      sajdahNumber: 6, verseKey: '22:18', sajdahType: 'optional'),
  '25:60': SajdahMetadata(
      sajdahNumber: 7, verseKey: '25:60', sajdahType: 'optional'),
  '27:26': SajdahMetadata(
      sajdahNumber: 8, verseKey: '27:26', sajdahType: 'optional'),
  '32:15': SajdahMetadata(
      sajdahNumber: 9, verseKey: '32:15', sajdahType: 'required'),
  '38:24': SajdahMetadata(
      sajdahNumber: 10, verseKey: '38:24', sajdahType: 'optional'),
  '41:38': SajdahMetadata(
      sajdahNumber: 11, verseKey: '41:38', sajdahType: 'required'),
  '53:62': SajdahMetadata(
      sajdahNumber: 12, verseKey: '53:62', sajdahType: 'required'),
  '84:21': SajdahMetadata(
      sajdahNumber: 13, verseKey: '84:21', sajdahType: 'optional'),
  '96:19': SajdahMetadata(
      sajdahNumber: 14, verseKey: '96:19', sajdahType: 'required'),
  '22:77': SajdahMetadata(
      sajdahNumber: 15, verseKey: '22:77', sajdahType: 'optional'),
};
