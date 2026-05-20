import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:adhan/adhan.dart' as adhan;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/locations.dart';
import '../constants/islamic_events.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ISOLATE DATA CLASSES  —  everything needed to calculate in background
// ═══════════════════════════════════════════════════════════════════════════

class _PrayerCalcInput {
  final double lat;
  final double lng;
  final int year;
  final int month;
  final int day;
  final int methodIndex;
  final int asrMethod;
  final int hijriAdjustment;

  _PrayerCalcInput({
    required this.lat,
    required this.lng,
    required this.year,
    required this.month,
    required this.day,
    required this.methodIndex,
    required this.asrMethod,
    required this.hijriAdjustment,
  });
}

class _MonthCalcInput {
  final double lat;
  final double lng;
  final int year;
  final int month;
  final int methodIndex;
  final int asrMethod;
  final int hijriAdjustment;

  _MonthCalcInput({
    required this.lat,
    required this.lng,
    required this.year,
    required this.month,
    required this.methodIndex,
    required this.asrMethod,
    required this.hijriAdjustment,
  });
}

class _HijriMonthCalcInput {
  final double lat;
  final double lng;
  final int hijriYear;
  final int hijriMonth;
  final int methodIndex;
  final int asrMethod;
  final int hijriAdjustment;

  _HijriMonthCalcInput({
    required this.lat,
    required this.lng,
    required this.hijriYear,
    required this.hijriMonth,
    required this.methodIndex,
    required this.asrMethod,
    required this.hijriAdjustment,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRAYER SERVICE
// ═══════════════════════════════════════════════════════════════════════════

class PrayerService {
  PrayerService._();
  static final PrayerService instance = PrayerService._();

  // ── Location State ──
  String? currentCity;
  String? currentCountry;
  double? _latitude;
  double? _longitude;

  // ── Calculation Settings ──
  int asrMethod = 0; // 0 = Shafi, 1 = Hanafi
  int calculationMethod = 0; // see _methodList below
  int hijriAdjustment = 0; // -2 to +2 days

  // ── Available calculation methods ──
  static const List<Map<String, dynamic>> calculationMethods = [
    {'id': 0, 'name': 'Muslim World League', 'short': 'MWL'},
    {'id': 1, 'name': 'Egyptian General Authority', 'short': 'Egypt'},
    {
      'id': 2,
      'name': 'Karachi University of Islamic Sciences',
      'short': 'Karachi'
    },
    {'id': 3, 'name': 'Umm al-Qura University, Makkah', 'short': 'Umm al-Qura'},
    {'id': 4, 'name': 'Dubai (UAE)', 'short': 'Dubai'},
    {'id': 5, 'name': 'Moonsighting Committee', 'short': 'Moonsighting'},
    {'id': 6, 'name': 'Islamic Society of North America', 'short': 'ISNA'},
    {'id': 7, 'name': 'Kuwait', 'short': 'Kuwait'},
    {'id': 8, 'name': 'Qatar', 'short': 'Qatar'},
    {'id': 9, 'name': 'Singapore', 'short': 'Singapore'},
    {'id': 10, 'name': 'Turkey (Diyanet)', 'short': 'Turkey'},
    {'id': 11, 'name': 'Tehran University', 'short': 'Tehran'},
    {'id': 12, 'name': 'Jafari / Shia Ithna-Ashari', 'short': 'Jafari'},
  ];

  // ═══════════════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    currentCity = prefs.getString('prayer_city');
    currentCountry = prefs.getString('prayer_country');
    asrMethod = prefs.getInt('prayer_asr_method') ?? 0;
    calculationMethod = prefs.getInt('prayer_calc_method') ?? 0;
    hijriAdjustment = prefs.getInt('prayer_hijri_adj') ?? 0;

    if (currentCity == null || currentCountry == null) {
      currentCity = 'Kolkata';
      currentCountry = 'India';
      await setLocation('Kolkata', 'India');
    } else {
      await _ensureCoordinates();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  COORDINATES
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _ensureCoordinates() async {
    if (_latitude != null && _longitude != null) return;

    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('prayer_lat');
    final lng = prefs.getDouble('prayer_lng');

    if (lat != null && lng != null) {
      _latitude = lat;
      _longitude = lng;
      return;
    }
    await _geocodeCurrentLocation();
  }

  Future<void> _geocodeCurrentLocation() async {
    if (currentCity == null) return;
    try {
      final locations = await locationFromAddress(
        currentCountry != null && currentCountry!.isNotEmpty
            ? '$currentCity, $currentCountry'
            : currentCity!,
      );
      if (locations.isNotEmpty) {
        _latitude = locations.first.latitude;
        _longitude = locations.first.longitude;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('prayer_lat', _latitude!);
        await prefs.setDouble('prayer_lng', _longitude!);
      }
    } catch (e) {
      print('Geocoding failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SETTERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> setAsrMethod(int method) async {
    asrMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prayer_asr_method', method);
    await _clearPrayerCaches();
  }

  Future<void> setCalculationMethod(int method) async {
    calculationMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prayer_calc_method', method);
    await _clearPrayerCaches();
  }

  Future<void> setHijriAdjustment(int adjustment) async {
    hijriAdjustment = adjustment;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prayer_hijri_adj', adjustment);
    await _clearPrayerCaches();
  }

  Future<void> setLocation(String city, String country) async {
    currentCity = city;
    currentCountry = country;
    _latitude = null;
    _longitude = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_city', city);
    await prefs.setString('prayer_country', country);
    await prefs.remove('prayer_lat');
    await prefs.remove('prayer_lng');
    await _clearPrayerCaches();

    // Check if location exists in our predefined list with known coordinates
    final match = POPULAR_LOCATIONS.cast<Map<String, dynamic>?>().firstWhere(
          (loc) =>
              loc != null &&
              loc['city'] == city &&
              loc['country'] == country &&
              loc.containsKey('lat') &&
              loc.containsKey('lng'),
          orElse: () => null,
        );

    if (match != null) {
      _latitude = match['lat'] as double;
      _longitude = match['lng'] as double;
      await prefs.setDouble('prayer_lat', _latitude!);
      await prefs.setDouble('prayer_lng', _longitude!);
    } else {
      // Custom location — need internet for geocoding
      await _geocodeCurrentLocation();
    }
  }

  Future<bool> fetchDeviceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subAdministrativeArea ?? 'London';
        String country = place.country ?? 'United Kingdom';
        _latitude = position.latitude;
        _longitude = position.longitude;
        currentCity = city;
        currentCountry = country;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('prayer_city', city);
        await prefs.setString('prayer_country', country);
        await prefs.setDouble('prayer_lat', _latitude!);
        await prefs.setDouble('prayer_lng', _longitude!);
        await _clearPrayerCaches();
        return true;
      }
    } catch (e) {
      print("Error getting location: $e");
    }
    return false;
  }

  Future<void> _clearPrayerCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) =>
        k.startsWith('prayer_cache_') ||
        k.startsWith('calendar_cache_') ||
        k.startsWith('hijri_cal_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CALCULATION PARAMETERS
  // ═══════════════════════════════════════════════════════════════════════

  adhan.CalculationParameters _getParams() {
    final methods = [
      adhan.CalculationMethod.muslim_world_league,
      adhan.CalculationMethod.egyptian,
      adhan.CalculationMethod.karachi,
      adhan.CalculationMethod.umm_al_qura,
      adhan.CalculationMethod.dubai,
      adhan.CalculationMethod.moon_sighting_committee,
      adhan.CalculationMethod.north_america,
      adhan.CalculationMethod.kuwait,
      adhan.CalculationMethod.qatar,
      adhan.CalculationMethod.singapore,
      adhan.CalculationMethod.turkey,
      adhan.CalculationMethod.tehran,
      adhan.CalculationMethod.other,
    ];
    final idx = calculationMethod.clamp(0, methods.length - 1);
    var params = methods[idx].getParameters();
    params.madhab = asrMethod == 1 ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    return params;
  }

  adhan.Coordinates get _coordinates {
    return adhan.Coordinates(_latitude ?? 22.5726, _longitude ?? 88.3639);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TODAY'S TIMINGS  —  OFF MAIN THREAD
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getTodayTimings({int method = 1}) async {
    if (currentCity == null) await initLocation();
    await _ensureCoordinates();

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final school = asrMethod;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'prayer_cache_today_${school}_$calculationMethod';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr != null) {
      try {
        final cachedMap = json.decode(cachedDataStr);
        if (cachedMap['city'] == currentCity &&
            cachedMap['country'] == currentCountry &&
            cachedMap['date'] == todayStr &&
            cachedMap['hijriAdj'] == hijriAdjustment) {
          return cachedMap['data'];
        }
      } catch (e) {
        // malformed cache
      }
    }

    try {
      final input = _PrayerCalcInput(
        lat: _latitude!,
        lng: _longitude!,
        year: now.year,
        month: now.month,
        day: now.day,
        methodIndex: calculationMethod,
        asrMethod: asrMethod,
        hijriAdjustment: hijriAdjustment,
      );

      // ── RUN IN ISOLATE ──
      final result = await Isolate.run(() => _calculateDayInIsolate(input));

      final timingsData = {
        'timings': result['timings'],
        'date': {
          'gregorian': result['gregorian'],
          'hijri': result['hijri'],
        },
      };

      await prefs.setString(
        cacheKey,
        json.encode({
          'city': currentCity,
          'country': currentCountry,
          'date': todayStr,
          'hijriAdj': hijriAdjustment,
          'data': timingsData,
        }),
      );

      return timingsData;
    } catch (e) {
      print('Failed to calculate timings: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MONTHLY CALENDAR  —  OFF MAIN THREAD
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>?> getCalendarByMonth(int year, int month,
      {int method = 4}) async {
    if (currentCity == null) await initLocation();
    await _ensureCoordinates();

    final school = asrMethod;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        'calendar_cache_${year}_${month}_${school}_$calculationMethod';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr != null) {
      try {
        final cachedMap = json.decode(cachedDataStr);
        if (cachedMap['city'] == currentCity &&
            cachedMap['country'] == currentCountry &&
            cachedMap['hijriAdj'] == hijriAdjustment) {
          return cachedMap['data'];
        }
      } catch (e) {
        // malformed cache
      }
    }

    try {
      final input = _MonthCalcInput(
        lat: _latitude!,
        lng: _longitude!,
        year: year,
        month: month,
        methodIndex: calculationMethod,
        asrMethod: asrMethod,
        hijriAdjustment: hijriAdjustment,
      );

      // ── RUN IN ISOLATE ──
      final calendarData =
          await Isolate.run(() => _calculateMonthInIsolate(input));

      await prefs.setString(
        cacheKey,
        json.encode({
          'city': currentCity,
          'country': currentCountry,
          'year': year,
          'month': month,
          'hijriAdj': hijriAdjustment,
          'data': calendarData,
        }),
      );

      return calendarData;
    } catch (e) {
      print('Failed to calculate calendar: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HIJRI CALENDAR  —  OFF MAIN THREAD
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>?> getHijriCalendarByMonth(int hijriYear, int hijriMonth,
      {int method = 4}) async {
    if (currentCity == null) await initLocation();
    await _ensureCoordinates();

    final school = asrMethod;
    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        'hijri_cal_${hijriYear}_${hijriMonth}_${school}_${calculationMethod}_${currentCity}_$currentCountry';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr != null) {
      try {
        final cachedMap = json.decode(cachedDataStr);
        if (cachedMap['hijriAdj'] == hijriAdjustment) {
          return cachedMap['data'];
        }
      } catch (e) {
        // malformed cache
      }
    }

    try {
      final input = _HijriMonthCalcInput(
        lat: _latitude!,
        lng: _longitude!,
        hijriYear: hijriYear,
        hijriMonth: hijriMonth,
        methodIndex: calculationMethod,
        asrMethod: asrMethod,
        hijriAdjustment: hijriAdjustment,
      );

      // ── RUN IN ISOLATE ──
      final calendarData =
          await Isolate.run(() => _calculateHijriMonthInIsolate(input));

      await prefs.setString(
        cacheKey,
        json.encode({
          'hijriAdj': hijriAdjustment,
          'data': calendarData,
        }),
      );

      return calendarData;
    } catch (e) {
      print('Failed to calculate Hijri calendar: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ISOLATE WORKERS  —  NO UI, NO SHARED PREFERENCES, PURE MATH
  // ═══════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _calculateDayInIsolate(_PrayerCalcInput input) {
    final coords = adhan.Coordinates(input.lat, input.lng);
    final params = _buildParamsFromIndex(input.methodIndex, input.asrMethod);
    final dc = adhan.DateComponents(input.year, input.month, input.day);
    final pt = adhan.PrayerTimes(coords, dc, params);

    final date = DateTime(input.year, input.month, input.day);
    return {
      'timings': {
        'Fajr': _formatTime(pt.fajr),
        'Sunrise': _formatTime(pt.sunrise),
        'Dhuhr': _formatTime(pt.dhuhr),
        'Asr': _formatTime(pt.asr),
        'Maghrib': _formatTime(pt.maghrib),
        'Isha': _formatTime(pt.isha),
      },
      'gregorian': {
        'date':
            '${input.year}-${input.month.toString().padLeft(2, '0')}-${input.day.toString().padLeft(2, '0')}',
        'day': input.day.toString().padLeft(2, '0'),
        'month': {'en': _gregMonthName(input.month), 'number': input.month},
        'year': input.year.toString(),
      },
      'hijri': _buildHijriDateInIsolate(date, input.hijriAdjustment),
    };
  }

  static List<Map<String, dynamic>> _calculateMonthInIsolate(
      _MonthCalcInput input) {
    final coords = adhan.Coordinates(input.lat, input.lng);
    final params = _buildParamsFromIndex(input.methodIndex, input.asrMethod);
    final daysInMonth = DateTime(input.year, input.month + 1, 0).day;
    final result = <Map<String, dynamic>>[];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(input.year, input.month, day);
      final dc = adhan.DateComponents(input.year, input.month, day);
      final pt = adhan.PrayerTimes(coords, dc, params);

      result.add({
        'date': {
          'gregorian': {
            'date':
                '${day.toString().padLeft(2, '0')}-${input.month.toString().padLeft(2, '0')}-${input.year}',
            'day': day.toString().padLeft(2, '0'),
            'month': {'en': _gregMonthName(input.month), 'number': input.month},
            'year': input.year.toString(),
          },
          'hijri': _buildHijriDateInIsolate(date, input.hijriAdjustment),
        },
        'timings': {
          'Fajr': _formatTime(pt.fajr),
          'Sunrise': _formatTime(pt.sunrise),
          'Dhuhr': _formatTime(pt.dhuhr),
          'Asr': _formatTime(pt.asr),
          'Maghrib': _formatTime(pt.maghrib),
          'Isha': _formatTime(pt.isha),
        },
      });
    }
    return result;
  }

  static List<Map<String, dynamic>> _calculateHijriMonthInIsolate(
      _HijriMonthCalcInput input) {
    final coords = adhan.Coordinates(input.lat, input.lng);
    final params = _buildParamsFromIndex(input.methodIndex, input.asrMethod);

    // Find Gregorian start of this Hijri month
    final gregorianStart =
        _hijriToGregorianStart(input.hijriYear, input.hijriMonth);
    DateTime current = gregorianStart.subtract(const Duration(days: 2));

    final result = <Map<String, dynamic>>[];

    while (true) {
      final dc = adhan.DateComponents(current.year, current.month, current.day);
      final pt = adhan.PrayerTimes(coords, dc, params);

      final hijri = _buildHijriDateInIsolate(current, input.hijriAdjustment);
      final hMonthNum = hijri['month']['number'] as int;
      final hYear = int.parse(hijri['year'].toString());

      if (hYear == input.hijriYear && hMonthNum == input.hijriMonth) {
        result.add({
          'date': {
            'gregorian': {
              'date':
                  '${current.day.toString().padLeft(2, '0')}-${current.month.toString().padLeft(2, '0')}-${current.year}',
              'day': current.day.toString().padLeft(2, '0'),
              'month': {
                'en': _gregMonthName(current.month),
                'number': current.month
              },
              'year': current.year.toString(),
            },
            'hijri': hijri,
          },
          'timings': {
            'Fajr': _formatTime(pt.fajr),
            'Sunrise': _formatTime(pt.sunrise),
            'Dhuhr': _formatTime(pt.dhuhr),
            'Asr': _formatTime(pt.asr),
            'Maghrib': _formatTime(pt.maghrib),
            'Isha': _formatTime(pt.isha),
          },
        });
      } else if (hYear > input.hijriYear ||
          (hYear == input.hijriYear && hMonthNum > input.hijriMonth)) {
        break;
      }

      current = current.add(const Duration(days: 1));
      if (result.length > 35) break;
    }
    return result;
  }

  // ── Build params in isolate (no instance state available) ──
  static adhan.CalculationParameters _buildParamsFromIndex(
      int methodIndex, int asrMethod) {
    final methods = [
      adhan.CalculationMethod.muslim_world_league,
      adhan.CalculationMethod.egyptian,
      adhan.CalculationMethod.karachi,
      adhan.CalculationMethod.umm_al_qura,
      adhan.CalculationMethod.dubai,
      adhan.CalculationMethod.moon_sighting_committee,
      adhan.CalculationMethod.north_america,
      adhan.CalculationMethod.kuwait,
      adhan.CalculationMethod.qatar,
      adhan.CalculationMethod.singapore,
      adhan.CalculationMethod.turkey,
      adhan.CalculationMethod.tehran,
      adhan.CalculationMethod.other,
    ];
    final idx = methodIndex.clamp(0, methods.length - 1);
    var params = methods[idx].getParameters();
    params.madhab = asrMethod == 1 ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    return params;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  STATIC HELPERS  —  usable in isolates
  // ═══════════════════════════════════════════════════════════════════════

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String _gregMonthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[month];
  }

  static Map<String, dynamic> _buildHijriDateInIsolate(
      DateTime gregorianDate, int adjustment) {
    // Apply adjustment
    final adjusted = gregorianDate.add(Duration(days: adjustment));
    final hijri = HijriCalendar.fromDate(adjusted);

    final holidays = eventsForHijriDate(hijri.hMonth, hijri.hDay);

    return {
      'day': hijri.hDay.toString().padLeft(2, '0'),
      'month': {
        'en': hijri.longMonthName,
        'number': hijri.hMonth,
      },
      'year': hijri.hYear.toString(),
      'holidays': holidays,
    };
  }

  static DateTime _hijriToGregorianStart(int hijriYear, int hijriMonth) {
    final hijri = HijriCalendar()
      ..hYear = hijriYear
      ..hMonth = hijriMonth
      ..hDay = 1;
    return hijri.hijriToGregorian(hijriYear, hijriMonth, 1);
  }
}
