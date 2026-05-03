import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import '../constants/quran_theme.dart';
import '../constants/locations.dart';
import 'package:intl/intl.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

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
  }

  Future<void> _fetchCalendar() async {
    setState(() => _isLoading = true);
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
          }, orElse: () => data[0]);
          _selectedDay = todayData;
        } else {
          _selectedDay = data[0];
        }
        _isLoading = false;
      });
    } else {
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [qt.emeraldDeep, qt.emeraldMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 48, height: 48),
                      GestureDetector(
                        onTap: () {
                          _showLocationBottomSheet(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_city,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "${PrayerService.instance.currentCity ?? 'Unknown'}, ${PrayerService.instance.currentCountry ?? ''}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: _prevMonth,
                      ),
                      Column(
                        children: [
                          Text(monthName,
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(yearNum,
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white70)),
                          if (hijriDateString.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(hijriDateString,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Selected Day info
                  if (_selectedDay != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: qt.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: qt.borderGlass),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Selected Date",
                                      style: TextStyle(
                                          color: qt.emeraldDeep,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      "${_selectedDay!['date']['gregorian']['day']} ${_selectedDay!['date']['gregorian']['month']['en']}",
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: qt.textPrimary)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      "${_selectedDay!['date']['hijri']['day']} ${_selectedDay!['date']['hijri']['month']['en']}",
                                      style: TextStyle(
                                          color: qt.textSecondary,
                                          fontSize: 14)),
                                  Text(
                                      "${_selectedDay!['date']['hijri']['year']} AH",
                                      style: TextStyle(
                                          color: qt.textMuted, fontSize: 12)),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildPrayerTimesGrid(qt, _selectedDay!['timings']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Calendar Grid
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: qt.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: qt.borderGlass),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month, color: qt.emeraldDeep),
                            const SizedBox(width: 8),
                            Text("$monthName $yearNum",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: qt.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          )
                        else if (_calendarData != null)
                          _buildCalendarGrid(qt),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimesGrid(QuranTheme qt, Map<String, dynamic> timings) {
    final prayerOrder = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final nextPrayer = _getNextPrayer(timings);

    // Check if selected day is today
    bool isToday = false;
    if (_selectedDay != null) {
      final parts = _selectedDay!['date']['gregorian']['date'].split('-');
      final d = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final today = DateTime.now();
      isToday =
          d.year == today.year && d.month == today.month && d.day == today.day;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: prayerOrder.map((prayer) {
        final time = timings[prayer].toString().split(' ')[0];
        final isNext = isToday && prayer == nextPrayer;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isNext ? qt.emeraldDeep : qt.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isNext ? qt.emeraldDeep : qt.borderGlass),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(prayer,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isNext ? Colors.white : qt.textPrimary)),
              Text(time,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isNext ? Colors.white : qt.textSecondary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid(QuranTheme qt) {
    if (_calendarData == null || _calendarData!.isEmpty)
      return const SizedBox.shrink();

    // Calculate first day of month padding
    final firstDayData =
        _calendarData!.first['date']['gregorian']['date'].split('-');
    final firstDay = DateTime(int.parse(firstDayData[2]),
        int.parse(firstDayData[1]), int.parse(firstDayData[0]));
    // 1 = Monday, 7 = Sunday
    // if we want Sunday as first day:
    int paddingDays = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    final daysInMonth = _calendarData!.length;

    return Column(
      children: [
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
        const SizedBox(height: 12),
        GridView.builder(
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
                            color: isSelected ? Colors.white : qt.textPrimary)),
                    Text(dayData['date']['hijri']['day'],
                        style: TextStyle(
                            fontSize: 9,
                            color: isSelected ? Colors.white70 : qt.textMuted)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
}
