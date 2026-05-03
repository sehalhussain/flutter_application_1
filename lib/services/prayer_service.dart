import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerService {
  PrayerService._();
  static final PrayerService instance = PrayerService._();

  final String _baseUrl = 'https://api.aladhan.com/v1';

  // State
  String? currentCity;
  String? currentCountry;
  int asrMethod = 0; // 0 = Standard (Shafi, Maliki, Hanbali), 1 = Hanafi

  Future<void> initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    currentCity = prefs.getString('prayer_city');
    currentCountry = prefs.getString('prayer_country');
    asrMethod = prefs.getInt('prayer_asr_method') ?? 0;

    if (currentCity == null || currentCountry == null) {
      currentCity = 'Kolkata';
      currentCountry = 'India';
      await setLocation('Kolkata', 'India');
    }
  }

  Future<void> setAsrMethod(int method) async {
    asrMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('prayer_asr_method', method);
  }

  Future<void> setLocation(String city, String country) async {
    currentCity = city;
    currentCountry = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prayer_city', city);
    await prefs.setString('prayer_country', country);
  }

  Future<bool> fetchDeviceLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subAdministrativeArea ?? 'London';
        String country = place.country ?? 'United Kingdom';
        await setLocation(city, country);
        return true;
      }
    } catch (e) {
      print("Error getting location: $e");
    }
    return false;
  }

  // Fetch Timings for Today
  // method 4 = Umm Al-Qura University, Makkah
  Future<Map<String, dynamic>?> getTodayTimings({int method = 4}) async {
    if (currentCity == null || currentCountry == null) {
      await initLocation();
    }
    
    final city = currentCity ?? 'Kolkata';
    final country = currentCountry ?? 'India';
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final school = asrMethod;
    
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'prayer_cache_today_$school';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr != null) {
      try {
        final cachedMap = json.decode(cachedDataStr);
        if (cachedMap['city'] == city && cachedMap['country'] == country && cachedMap['date'] == todayStr) {
          return cachedMap['data'];
        }
      } catch (e) {
        // Handle malformed cache silently
      }
    }

    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl/timingsByCity?city=$city&country=$country&method=$method&school=$school'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timingsData = data['data'];
        
        await prefs.setString(cacheKey, json.encode({
          'city': city,
          'country': country,
          'date': todayStr,
          'data': timingsData,
        }));
        
        return timingsData;
      }
    } catch (e) {
      print('Failed to load timings: $e');
    }
    return null;
  }

  // Fetch Calendar for Month
  Future<List<dynamic>?> getCalendarByMonth(int year, int month, {int method = 4}) async {
     if (currentCity == null || currentCountry == null) {
      await initLocation();
    }
    
    final city = currentCity ?? 'Kolkata';
    final country = currentCountry ?? 'India';
    final school = asrMethod;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'calendar_cache_current_$school';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr != null) {
      try {
        final cachedMap = json.decode(cachedDataStr);
        if (cachedMap['city'] == city && cachedMap['country'] == country && cachedMap['year'] == year && cachedMap['month'] == month) {
          return cachedMap['data'];
        }
      } catch (e) {
        // Handle malformed cache silently
      }
    }

    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl/calendarByCity?city=$city&country=$country&month=$month&year=$year&method=$method&school=$school'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final calendarData = data['data'];

        await prefs.setString(cacheKey, json.encode({
          'city': city,
          'country': country,
          'year': year,
          'month': month,
          'data': calendarData,
        }));

        return calendarData;
      }
    } catch (e) {
      print('Failed to load calendar: $e');
    }
    return null;
  }

  // Fetch Calendar for a HIJRI month (returns Gregorian dates for each day)
  Future<List<dynamic>?> getHijriCalendarByMonth(int hijriYear, int hijriMonth, {int method = 4}) async {
    if (currentCity == null || currentCountry == null) {
      await initLocation();
    }

    final city = currentCity ?? 'Kolkata';
    final country = currentCountry ?? 'India';
    final school = asrMethod;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'hijri_cal_${hijriYear}_${hijriMonth}_${school}_${city}_$country';
    final cachedDataStr = prefs.getString(cacheKey);

    if (cachedDataStr != null) {
      try {
        final cachedList = json.decode(cachedDataStr) as List<dynamic>;
        return cachedList;
      } catch (e) {
        // malformed cache – fall through to network
      }
    }

    try {
      final response = await http.get(Uri.parse(
          '$_baseUrl/hijriCalendarByCity?city=$city&country=$country'
          '&month=$hijriMonth&year=$hijriYear&method=$method&school=$school'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final calendarData = data['data'] as List<dynamic>;

        await prefs.setString(cacheKey, json.encode(calendarData));
        return calendarData;
      }
    } catch (e) {
      print('Failed to load Hijri calendar: $e');
    }
    return null;
  }
}
