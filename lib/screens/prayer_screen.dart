import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import '../constants/quran_theme.dart';
import '../constants/locations.dart';
import 'package:intl/intl.dart';
import 'menu_screen.dart';

class PrayerScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const PrayerScreen({super.key, this.onBackToHome});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  DateTime _displayDate = DateTime.now();
  List<dynamic>? _calendarData;
  Map<String, dynamic>? _selectedDay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCalendar();
    // React to PrayerService changes (location, asr, hijri adj changed in other screens)
    PrayerService.instance.addListener(_onPrayerServiceChanged);
  }

  @override
  void dispose() {
    PrayerService.instance.removeListener(_onPrayerServiceChanged);
    super.dispose();
  }

  void _onPrayerServiceChanged() {
    _fetchCalendar();
  }

  Future<void> _fetchCalendar() async {
    setState(() => _isLoading = true);
    try {
      final data = await PrayerService.instance.getCalendarByMonth(
        _displayDate.year,
        _displayDate.month,
      );

      if (data != null && mounted) {
        setState(() {
          _calendarData = data;

          final today = DateTime.now();
          if (_displayDate.year == today.year &&
              _displayDate.month == today.month) {
            final todayData = data.firstWhere((d) {
              final parts = d['date']['gregorian']['date'].split('-');
              return int.parse(parts[0]) == today.day;
            }, orElse: () => data[0] as Map<String, dynamic>);
            _selectedDay = todayData;
          } else {
            _selectedDay = data[0];
          }
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month - 1, 1);
    });
    _fetchCalendar();
  }

  void _nextMonth() {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month + 1, 1);
    });
    _fetchCalendar();
  }

  /// Converts a "HH:mm" 24-hour string to "h:mm am/pm" 12-hour format.
  String _to12Hour(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour < 12 ? 'AM' : 'PM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }

  String? _getNextPrayer(Map<String, dynamic>? timings) {
    if (timings == null) return null;
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    for (final prayer in prayerOrder) {
      final pTime = timings[prayer].toString().split(' ')[0];
      if (pTime.compareTo(timeStr) > 0) {
        return prayer;
      }
    }
    return 'Fajr';
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final monthName = DateFormat('MMMM').format(_displayDate);
    final yearNum = _displayDate.year.toString();

    String hijriDateString = "";
    if (_calendarData != null && _calendarData!.isNotEmpty) {
      final start = _calendarData!.first['date']['hijri'];
      final end = _calendarData!.last['date']['hijri'];
      if (start['month']['en'] == end['month']['en']) {
        hijriDateString = "${start['month']['en']} ${start['year']} AH";
      } else if (start['year'] == end['year']) {
        hijriDateString =
            "${start['month']['en']} - ${end['month']['en']} ${start['year']} AH";
      } else {
        hijriDateString =
            "${start['month']['en']} ${start['year']} - ${end['month']['en']} ${end['year']} AH";
      }
    }

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // --- IMMERSIVE HEADER SECTION ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 50),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
            ),
            child: Column(
              children: [
                // Top row: Back arrow (L) | Month name (center) | Settings (R)
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (widget.onBackToHome != null) {
                            widget.onBackToHome!();
                          } else if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    Text(monthName,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const Spacer(),
                    // ← GLASS SETTINGS BUTTON REPLACES YEAR
                    _glassBtn(
                      const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                      qt,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MenuScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── YEAR MOVED HERE ──
                Text(
                  yearNum,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Navigation row: chevrons + hijri date string
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavButton(Icons.chevron_left, _prevMonth),
                    if (hijriDateString.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(hijriDateString,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    _buildNavButton(Icons.chevron_right, _nextMonth),
                  ],
                ),

                const SizedBox(height: 16),

                // Location - Centered below month
                GestureDetector(
                  onTap: () => _showLocationBottomSheet(context),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            "${PrayerService.instance.currentCity ?? 'Unknown'}, ${PrayerService.instance.currentCountry ?? ''}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- FLOATING DATE SELECTOR BAR ---
          Transform.translate(
            offset: const Offset(0, -25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: qt.borderGlass),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: qt.emeraldDeep, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDay != null
                                ? "${_selectedDay!['date']['gregorian']['day']} ${_selectedDay!['date']['gregorian']['month']['en']} ${_selectedDay!['date']['gregorian']['year']}"
                                : "Select a date",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: qt.textPrimary),
                          ),
                          if (_selectedDay != null)
                            Text(
                              "${_selectedDay!['date']['hijri']['day']} ${_selectedDay!['date']['hijri']['month']['en']} ${_selectedDay!['date']['hijri']['year']} AH",
                              style:
                                  TextStyle(fontSize: 12, color: qt.textMuted),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: qt.emeraldDeep.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getNextPrayer(_selectedDay?['timings']) != null
                            ? "Next: ${_getNextPrayer(_selectedDay?['timings'])}"
                            : "",
                        style: TextStyle(
                            color: qt.emeraldDeep,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- CONTENT AREA ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                // Prayer Times Card
                if (_selectedDay != null) ...[
                  _buildSectionTitle("Prayer Times", qt),
                  const SizedBox(height: 12),
                  _buildPrayerTimesCard(qt, _selectedDay!['timings']),
                  const SizedBox(height: 24),
                ],

                // Calendar Grid Card
                _buildSectionTitle("Calendar", qt),
                const SizedBox(height: 12),
                _buildCalendarCard(qt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildSectionTitle(String title, QuranTheme qt) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: qt.emeraldDeep,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary)),
      ],
    );
  }

  Widget _buildPrayerTimesCard(QuranTheme qt, Map<String, dynamic> timings) {
    final prayerOrder = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final nextPrayer = _getNextPrayer(timings);

    bool isToday = false;
    if (_selectedDay != null) {
      final parts = _selectedDay!['date']['gregorian']['date'].split('-');
      final d = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final today = DateTime.now();
      isToday =
          d.year == today.year && d.month == today.month && d.day == today.day;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: prayerOrder.map((prayer) {
          final time = timings[prayer].toString().split(' ')[0];
          final isNext = isToday && prayer == nextPrayer;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isNext ? qt.emeraldDeep : qt.bg,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: isNext ? qt.emeraldDeep : qt.borderGlass),
            ),
            child: Row(
              children: [
                // Prayer Icon/Indicator
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isNext
                        ? Colors.white.withOpacity(0.2)
                        : qt.emeraldDeep.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _getPrayerIcon(prayer),
                      color: isNext ? Colors.white : qt.emeraldDeep,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Prayer Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prayer,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isNext ? Colors.white : qt.textPrimary)),
                      if (isNext)
                        Text("Up Next",
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.7))),
                    ],
                  ),
                ),
                // Time (12-hour format)
                Text(_to12Hour(time),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isNext ? Colors.white : qt.textSecondary)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getPrayerIcon(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return Icons.wb_twilight;
      case 'Sunrise':
        return Icons.wb_sunny_outlined;
      case 'Dhuhr':
        return Icons.sunny;
      case 'Asr':
        return Icons.filter_drama_outlined;
      case 'Maghrib':
        return Icons.nights_stay_outlined;
      case 'Isha':
        return Icons.bedtime_outlined;
      default:
        return Icons.access_time;
    }
  }

  Widget _buildCalendarCard(QuranTheme qt) {
    String englishMonth = "";
    String hijriMonth = "";
    String hijriYear = "";

    if (_calendarData != null && _calendarData!.isNotEmpty) {
      final firstDay = _calendarData!.first['date'];
      englishMonth = firstDay['gregorian']['month']['en'];
      hijriMonth = firstDay['hijri']['month']['en'];
      hijriYear = firstDay['hijri']['year'];
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: [
          // Month Name Header - English & Hijri
          if (englishMonth.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month,
                          color: qt.emeraldDeep, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        englishMonth,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$hijriMonth $hijriYear AH",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: qt.emeraldDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Divider
          if (englishMonth.isNotEmpty)
            Divider(color: qt.borderGlass, height: 1),

          const SizedBox(height: 16),

          // Weekday Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                    child: Center(
                        child: Text(d,
                            style: TextStyle(
                                color: qt.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)))))
                .toList(),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            )
          else if (_calendarData != null)
            _buildCalendarGrid(qt),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(QuranTheme qt) {
    if (_calendarData == null || _calendarData!.isEmpty)
      return const SizedBox.shrink();

    final firstDayData =
        _calendarData!.first['date']['gregorian']['date'].split('-');
    final firstDay = DateTime(int.parse(firstDayData[2]),
        int.parse(firstDayData[1]), int.parse(firstDayData[0]));
    int paddingDays = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    final daysInMonth = _calendarData!.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: paddingDays + daysInMonth,
      itemBuilder: (context, index) {
        if (index < paddingDays) return const SizedBox.shrink();

        final dataIndex = index - paddingDays;
        final dayData = _calendarData![dataIndex];
        final isSelected = _selectedDay == dayData;

        final parts = dayData['date']['gregorian']['date'].split('-');
        final dDate = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final today = DateTime.now();
        final isToday = dDate.year == today.year &&
            dDate.month == today.month &&
            dDate.day == today.day;

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = dayData),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? qt.emeraldDeep
                  : (isToday
                      ? qt.emeraldDeep.withOpacity(0.1)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected
                      ? qt.emeraldDeep
                      : (isToday ? qt.emeraldDeep : qt.borderGlass)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayData['date']['gregorian']['day'],
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? Colors.white : qt.textPrimary)),
                const SizedBox(height: 2),
                Text(dayData['date']['hijri']['day'],
                    style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.white70 : qt.textMuted)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocationBottomSheet(BuildContext context) {
    final qt = QuranTheme.of(context);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = POPULAR_LOCATIONS.where((loc) {
            final text = "${loc['city']} ${loc['country']}".toLowerCase();
            return text.contains(searchQuery.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                          style: TextStyle(color: qt.textPrimary),
                          decoration: InputDecoration(
                            hintText: "Search city...",
                            hintStyle: TextStyle(color: qt.textMuted),
                            prefixIcon: Icon(Icons.search, color: qt.textMuted),
                            filled: true,
                            fillColor: qt.cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.my_location, color: qt.emeraldDeep),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);
                            await PrayerService.instance.fetchDeviceLocation();
                            await _fetchCalendar();
                          },
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount:
                          filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            leading: Icon(Icons.public, color: qt.emeraldDeep),
                            title: Text('Search for "$searchQuery"',
                                style: TextStyle(
                                    color: qt.emeraldDeep,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('Worldwide search',
                                style: TextStyle(
                                    color: qt.textMuted, fontSize: 12)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              setState(() => _isLoading = true);
                              await PrayerService.instance
                                  .setLocation(searchQuery, '');
                              await _fetchCalendar();
                            },
                          );
                        }

                        final locIndex =
                            searchQuery.isNotEmpty ? index - 1 : index;
                        final loc = filtered[locIndex];
                        return ListTile(
                          leading: Icon(Icons.location_on_outlined,
                              color: qt.textMuted),
                          title: Text(loc['city']!,
                              style: TextStyle(
                                  color: qt.textPrimary,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(loc['country']!,
                              style:
                                  TextStyle(color: qt.textMuted, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);
                            await PrayerService.instance
                                .setLocation(loc['city']!, loc['country']!);
                            await _fetchCalendar();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _glassBtn(Widget child, QuranTheme qt, {VoidCallback? onTap}) {
    final bool isDark = qt.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Center(child: child),
      ),
    );
  }
}
