// lib/models/downloadable_translation.dart
//
// Defines downloadable translation metadata — NOT bundled in the app.
// Users download these on demand to keep the app small.

enum TranslationFormat { json, sqlite }

class DownloadableTranslation {
  final String id;
  final String displayName;
  final String language;
  final String url;
  final bool isBuiltin;
  final TranslationFormat format;

  const DownloadableTranslation({
    required this.id,
    required this.displayName,
    required this.language,
    required this.url,
    this.isBuiltin = false,
    this.format = TranslationFormat.json,
  });

  /// Detect format from URL extension if not explicitly set.
  bool get isSqlite =>
      format == TranslationFormat.sqlite || url.endsWith('.db');
}

/// List of translations that can be downloaded on demand.
/// These follow the same JSON structure as built-in translations:
///   { "1:1": { "t": "translation text" }, ... }
const kDownloadableTranslations = [
  DownloadableTranslation(
    id: 'bengali',
    displayName: 'Bengali – Sheikh Mujibur Rahman',
    language: 'Bengali',
    url: 'https://kitably-api.pages.dev/bengali/index.json',
  ),
  DownloadableTranslation(
    id: 'tamil',
    displayName: 'Tamil – Sheikh Omar Sharif',
    language: 'Tamil',
    url: 'https://kitably-api.pages.dev/tamil/index.json',
  ),
  DownloadableTranslation(
    id: 'malyalam',
    displayName: 'Malyalam – Karakunnu',
    language: 'Malyalam',
    url: 'https://kitably-api.pages.dev/malyalam/index.json',
  ),
  DownloadableTranslation(
    id: 'french',
    displayName: 'French – Montada Islamic foundation',
    language: 'French',
    url: 'https://kitably-api.pages.dev/french/index.json',
  ),
  DownloadableTranslation(
    id: 'spanish',
    displayName: 'Spanish – Noor International Center',
    language: 'Spanish',
    url: 'https://kitably-api.pages.dev/spanish/index.json',
    format: TranslationFormat.sqlite, // Server serves a SQLite DB file
  ),
  DownloadableTranslation(
    id: 'telugu',
    displayName: 'Telugu – Noor International Center',
    language: 'Telugu',
    url: 'https://kitably-api.pages.dev/telugu/index.json',
    format: TranslationFormat.sqlite, // Server serves a SQLite DB file
  ),
];
