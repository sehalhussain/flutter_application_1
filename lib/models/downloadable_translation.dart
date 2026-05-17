// lib/models/downloadable_translation.dart
//
// Defines downloadable translation metadata — NOT bundled in the app.
// Users download these on demand to keep the app small.

class DownloadableTranslation {
  final String id;
  final String displayName;
  final String language;
  final String url;
  final bool isBuiltin; // false for all downloadable translations

  const DownloadableTranslation({
    required this.id,
    required this.displayName,
    required this.language,
    required this.url,
    this.isBuiltin = false,
  });
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
];
