// ───────────────────────────────────────────────────────────────────────────
//  Predefined Islamic events / important dates mapped by Hijri (month, day).
//
//  Key format: "MM-DD" where MM = month number (01-12), DD = day number.
//  Year-specific events (e.g. Eid depending on moon sighting) are tracked
//  to their canonical Hijri dates.  These match the locally-calculated
//  calendar produced by _buildHijriDateInIsolate.
// ───────────────────────────────────────────────────────────────────────────

/// Returns a list of event names for the given Hijri month and day,
/// or an empty list if nothing important falls on that date.
List<String> eventsForHijriDate(int month, int day) {
  final key =
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  return _fixedEvents[key] ?? [];
}

/// Events that always fall on the same Hijri day (regardless of Gregorian shift).
const Map<String, List<String>> _fixedEvents = {
  // Muharram
  '01-01': ['Islamic New Year'],
  '01-10': ['Day of Ashura'],

  // Safar — no widely agreed fixed events (most are cultural)

  // Rabi' al-Awwal
  '03-12': ['Mawlid al-Nabi (Birth of the Prophet)'],

  // Rabi' al-Thani — none

  // Jumada al-Awwal — none

  // Jumada al-Thani — none

  // Rajab
  '07-27': ["Isra' and Mi'raj"],

  // Sha'ban
  '08-15': ['Mid-Sha\'ban (Nisfu Sha\'ban)'],

  // Ramadan
  '09-01': ['First Day of Ramadan'],
  '09-21': ['Laylat al-Qadr (21st Ramadan)'],
  '09-23': ['Laylat al-Qadr (23rd Ramadan)'],
  '09-25': ['Laylat al-Qadr (25th Ramadan)'],
  '09-27': ['Laylat al-Qadr (27th Ramadan)'],
  '09-29': ['Laylat al-Qadr (29th Ramadan)'],

  // Shawwal
  '10-01': ['Eid al-Fitr'],

  // Dhu al-Qi'dah — none

  // Dhu al-Hijjah
  '12-09': ['Day of Arafah'],
  '12-10': ['Eid al-Adha'],
  '12-11': ['Days of Tashreeq'],
  '12-12': ['Days of Tashreeq'],
  '12-13': ['Days of Tashreeq'],
};
