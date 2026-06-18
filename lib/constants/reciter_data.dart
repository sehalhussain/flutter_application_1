// lib/constants/reciter_data.dart
//
// Custom reciter data for Yasser Al Dossary with Urdu Translation
// URL pattern: https://dn720703.ca.archive.org/0/items/TheholyQuranUrduYasserAlDossari/{surahNumber}%20{surahName}.mp3

/// ID used across the app to identify this custom reciter.
const kYasserUrduReciterId = 'yasser_urdu';

/// Display name for the custom reciter.
const kYasserUrduReciterName = 'Yasser Al Dossary with Urdu Translation';

/// Surah names in English, index 0 → Surah 1 (Al-Fatiha), index 113 → Surah 114 (An-Nas).
const kSurahNamesForUrl = [
  'Al Fatiha',
  'Al Baqarah',
  'Al Imran',
  'An Nisa',
  "Al Ma'idah",
  "Al An'am",
  "Al A'raf",
  'Al Anfal',
  'At Tawbah',
  'Yunus',
  'Hud',
  'Yusuf',
  'Ar Rad',
  'Ibrahim',
  'Al Hijr',
  'An Nahl',
  'Al Isra',
  'Al Kahf',
  'Maryam',
  'Ta Ha',
  'Al Anbiya',
  'Al Hajj',
  "Al Mu'minun",
  'An Nur',
  'Al Furqan',
  "Ash Shu'ara",
  'An Naml',
  'Al Qasas',
  'Al Ankabut',
  'Ar Rum',
  'Luqman',
  'As Sajda',
  'Al Ahzab',
  'Saba',
  'Fatir',
  'Ya Sin',
  'As Saffat',
  'Sad',
  'Az Zumar',
  'Ghafir',
  'Fussilat',
  'Ash Shuura',
  'Az Zukhruf',
  'Ad Dukhan',
  'Al Jathiya',
  'Al Ahqaf',
  'Muhammad',
  'Al Fath',
  'Al Hujurat',
  'Qaf',
  'Adh Dhariyat',
  'At Tur',
  'An Najm',
  'Al Qamar',
  'Ar Rahman',
  'Al Waqia',
  'Al Hadid',
  'Al Mujadila',
  'Al Hashr',
  'Al Mumtahina',
  'As Saff',
  "Al Jumu'a",
  'Al Munafiqun',
  'At Taghabun',
  'At Talaq',
  'At Tahrim',
  'Al Mulk',
  'Al Qalam',
  'Al Haqqa',
  "Al Ma'arij",
  'Nuh',
  'Al Jin',
  'Al Muzzammil',
  'Al Mudathir',
  'Al Qiyama',
  'Al Insan',
  'Al Mursalat',
  'An Naba',
  "An Nazi'at",
  'Abasa',
  'At Takwir',
  'Al Infitar',
  'Al Mutaffifin',
  'Al Inshiqaq',
  'Al Buruj',
  'At Tariq',
  'Al Ala',
  'Al Ghashiya',
  'Al Fajr',
  'Al Balad',
  'Ash Shams',
  'Al Layl',
  'Ad Duha',
  'Al Sharh',
  'At Tin',
  'Al Alaq',
  'Al Qadr',
  'Al Bayyina',
  'Az Zalzala',
  'Al Adiyat',
  'Al Qaria',
  'At Takathur',
  'Al Asr',
  'Al Humaza',
  'Al Fil',
  'Quraysh',
  "Al Ma'un",
  'Al Kauthar',
  'Al Kafirun',
  'An Nasr',
  'Al Masad',
  'Al Ikhlas',
  'Al Falaq',
  'An Nas',
];

/// Construct the audio URL for a given surah number using the Yasser Al Dossary
/// with Urdu Translation archive.
///
/// Example: surah 1 → "https://dn720703.ca.archive.org/0/items/TheholyQuranUrduYasserAlDossari/001%20Al%20Fatiha.mp3"
String getYasserUrduSurahUrl(int surahNumber) {
  if (surahNumber < 1 || surahNumber > 114) {
    throw ArgumentError('Surah number must be between 1 and 114');
  }
  final index = surahNumber - 1;
  final paddedNumber = surahNumber.toString().padLeft(3, '0');
  final surahName = kSurahNamesForUrl[index];
  return 'https://dn720703.ca.archive.org/0/items/TheholyQuranUrduYasserAlDossari/$paddedNumber%20$surahName.mp3';
}
