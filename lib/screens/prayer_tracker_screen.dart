// lib/screens/prayer_tracker_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/prayer_tracker_provider.dart';
import '../constants/quran_theme.dart';

class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({super.key});

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  late PageController _pageController;
  late DateTime _selectedDate;
  int _currentPageIndex = 0;
  bool _showMonthView = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Index 0 = 365 days ago (oldest), last index (364) = today.
    // Swiping RIGHT (finger right, content slides from left) = past days.
    _pageController = PageController(initialPage: 364);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Index 0 = farthest past, last index = today.
  /// Swiping RIGHT → content from left → previous day.
  List<DateTime> _generateDates() {
    final dates = <DateTime>[];
    for (int i = 364; i >= 0; i--) {
      dates.add(DateTime.now().subtract(Duration(days: i)));
    }
    return dates;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final tracker = context.watch<PrayerTracker>();

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        title: const Text(
          "Prayer Tracker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: qt.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showMonthView
                  ? Icons.calendar_view_day_rounded
                  : Icons.calendar_month_rounded,
              color: qt.emeraldDeep,
            ),
            tooltip:
                _showMonthView ? "Switch to Day View" : "Switch to Month View",
            onPressed: () {
              setState(() {
                _showMonthView = !_showMonthView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBanner(qt, tracker),
          const SizedBox(height: 4),
          Expanded(
            child: _showMonthView
                ? _MonthCalendarView(
                    tracker: tracker,
                    qt: qt,
                    onDaySelected: (date) {
                      final diff = DateTime.now().difference(date).inDays;
                      final pageIndex =
                          364 - diff; // map today→364, yesterday→363, ...
                      if (diff >= 0 && diff < 365) {
                        setState(() {
                          _showMonthView = false;
                          _currentPageIndex = pageIndex;
                          _selectedDate = date;
                          _pageController.jumpToPage(pageIndex);
                        });
                      }
                    },
                  )
                : _DayPageView(
                    pageController: _pageController,
                    currentPageIndex: _currentPageIndex,
                    selectedDate: _selectedDate,
                    tracker: tracker,
                    qt: qt,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                        final dates = _generateDates();
                        if (index < dates.length) {
                          _selectedDate = dates[index];
                        }
                      });
                    },
                    dateKey: _dateKey,
                    generateDates: _generateDates,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBanner(QuranTheme qt, PrayerTracker tracker) {
    final todayCount = tracker.todayPrayedCount;
    final streak = tracker.currentStreak;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [qt.emeraldMid, qt.emeraldDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: qt.emeraldDeep.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.check_circle_outline_rounded,
            value: "$todayCount/5",
            label: "Today",
            color: Colors.white,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.2),
          ),
          _StatItem(
            icon: Icons.local_fire_department_rounded,
            value: "$streak",
            label: "Day Streak",
            color: Colors.white,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.2),
          ),
          _StatItem(
            icon: Icons.mosque_rounded,
            value:
                "${tracker.sortedDateKeys.fold<int>(0, (sum, k) => sum + tracker.prayedCountForDate(k))}",
            label: "Total Prayers",
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DAY PAGE VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _DayPageView extends StatelessWidget {
  final PageController pageController;
  final int currentPageIndex;
  final DateTime selectedDate;
  final PrayerTracker tracker;
  final QuranTheme qt;
  final void Function(int) onPageChanged;
  final String Function(DateTime) dateKey;
  final List<DateTime> Function() generateDates;

  const _DayPageView({
    required this.pageController,
    required this.currentPageIndex,
    required this.selectedDate,
    required this.tracker,
    required this.qt,
    required this.onPageChanged,
    required this.dateKey,
    required this.generateDates,
  });

  @override
  Widget build(BuildContext context) {
    final dates = generateDates();
    final currentDate = currentPageIndex < dates.length
        ? dates[currentPageIndex]
        : selectedDate;
    final monthName = DateFormat('MMMM yyyy').format(currentDate);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(monthName,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: qt.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text("Swipe right to see previous days",
              style: TextStyle(
                  fontSize: 11,
                  color: qt.textMuted,
                  fontWeight: FontWeight.w400)),
        ),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            itemCount: 365,
            itemBuilder: (context, index) {
              final dates = generateDates();
              if (index >= dates.length) return const SizedBox.shrink();
              final date = dates[index];
              final key = dateKey(date);
              final prayers = tracker.prayersForDate(key);
              final isToday = dateKey(DateTime.now()) == key;

              return _DayView(
                date: date,
                dateKey: key,
                prayers: prayers,
                isToday: isToday,
                qt: qt,
                tracker: tracker,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MONTH CALENDAR VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _MonthCalendarView extends StatefulWidget {
  final PrayerTracker tracker;
  final QuranTheme qt;
  final void Function(DateTime) onDaySelected;

  const _MonthCalendarView({
    required this.tracker,
    required this.qt,
    required this.onDaySelected,
  });

  @override
  State<_MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends State<_MonthCalendarView> {
  late DateTime _viewingMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewingMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewingMonth = DateTime(_viewingMonth.year, _viewingMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;
    final tracker = widget.tracker;
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(_viewingMonth);
    final lastDay =
        DateTime(_viewingMonth.year, _viewingMonth.month + 1, 0).day;
    final firstWeekday = _viewingMonth.weekday % 7;

    int completeDays = 0;
    int totalLogged = 0;
    for (int d = 1; d <= lastDay; d++) {
      final date = DateTime(_viewingMonth.year, _viewingMonth.month, d);
      final key = _dateKey(date);
      final count = tracker.prayedCountForDate(key);
      if (count > 0) totalLogged++;
      if (count == 5) completeDays++;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: qt.emeraldDeep),
                  onPressed: _prevMonth),
              Column(
                children: [
                  Text(monthName,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary)),
                  const SizedBox(height: 2),
                  Text("$completeDays complete · $totalLogged days logged",
                      style: TextStyle(
                          fontSize: 11,
                          color: qt.textMuted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              IconButton(
                  icon:
                      Icon(Icons.chevron_right_rounded, color: qt.emeraldDeep),
                  onPressed: _nextMonth),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
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
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.95,
              ),
              itemCount: firstWeekday + lastDay,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();
                final day = index - firstWeekday + 1;
                final date =
                    DateTime(_viewingMonth.year, _viewingMonth.month, day);
                final key = _dateKey(date);
                final isToday = key == _dateKey(now);
                final prayedCount = tracker.prayedCountForDate(key);
                final isFuture = date.isAfter(now);

                return _MonthDayCell(
                  day: day,
                  isToday: isToday,
                  prayedCount: prayedCount,
                  isFuture: isFuture,
                  qt: qt,
                  onTap: () {
                    if (!isFuture) widget.onDaySelected(date);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _MonthDayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final int prayedCount;
  final bool isFuture;
  final QuranTheme qt;
  final VoidCallback onTap;

  const _MonthDayCell({
    required this.day,
    required this.isToday,
    required this.prayedCount,
    required this.isFuture,
    required this.qt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color dotColor;
    bool showDot = false;

    if (isToday) {
      bg = qt.emeraldDeep;
      dotColor = Colors.white;
    } else if (prayedCount == 5) {
      bg = Colors.green.withOpacity(0.12);
      dotColor = Colors.green;
      showDot = true;
    } else if (prayedCount > 0) {
      bg = Colors.orange.withOpacity(0.10);
      dotColor = Colors.orange;
      showDot = true;
    } else {
      bg = Colors.transparent;
      dotColor = qt.textMuted;
    }

    return GestureDetector(
      onTap: isFuture ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? qt.emeraldDeep
                : showDot
                    ? dotColor.withOpacity(0.3)
                    : qt.borderGlass,
            width: isToday ? 0 : 1,
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: qt.emeraldDeep.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text("$day",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.white
                        : isFuture
                            ? qt.textMuted.withOpacity(0.4)
                            : qt.textPrimary,
                  )),
            ),
            if (showDot && !isToday)
              Positioned(
                bottom: 5,
                left: 0,
                right: 0,
                child: Center(
                    child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: dotColor, shape: BoxShape.circle))),
              ),
            if (isToday)
              Positioned(
                bottom: 5,
                left: 0,
                right: 0,
                child: Center(
                    child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle))),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DAY VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _DayView extends StatelessWidget {
  final DateTime date;
  final String dateKey;
  final Map<String, bool> prayers;
  final bool isToday;
  final QuranTheme qt;
  final PrayerTracker tracker;

  const _DayView({
    required this.date,
    required this.dateKey,
    required this.prayers,
    required this.isToday,
    required this.qt,
    required this.tracker,
  });

  IconData _getPrayerIcon(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return Icons.wb_twilight_rounded;
      case 'Dhuhr':
        return Icons.wb_sunny_rounded;
      case 'Asr':
        return Icons.sunny;
      case 'Maghrib':
        return Icons.brightness_4_rounded;
      case 'Isha':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE').format(date);
    final formattedDate = DateFormat('MMM d, yyyy').format(date);
    final prayedCount = tracker.prayedCountForDate(dateKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isToday ? qt.emeraldDeep.withOpacity(0.3) : qt.borderGlass,
                width: isToday ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayName,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: qt.textPrimary)),
                    const SizedBox(height: 2),
                    Text(formattedDate,
                        style: TextStyle(fontSize: 13, color: qt.textMuted)),
                  ],
                ),
                Row(
                  children: [
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text("Today",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: qt.emeraldDeep)),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: prayedCount == 5
                            ? Colors.green.withOpacity(0.1)
                            : prayedCount > 0
                                ? Colors.orange.withOpacity(0.1)
                                : qt.borderGlass.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text("$prayedCount/5",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: prayedCount == 5
                                ? Colors.green
                                : prayedCount > 0
                                    ? Colors.orange
                                    : qt.textMuted,
                          )),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...tracker.prayerNames.map((prayer) {
            final isPrayed = prayers[prayer] ?? false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => tracker.togglePrayerForDate(dateKey, prayer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color:
                        isPrayed ? Colors.green.withOpacity(0.08) : qt.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPrayed
                          ? Colors.green.withOpacity(0.3)
                          : qt.borderGlass,
                      width: isPrayed ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPrayed
                              ? Colors.green.withOpacity(0.15)
                              : qt.emeraldDeep.withOpacity(0.06),
                        ),
                        child: Icon(_getPrayerIcon(prayer),
                            color: isPrayed
                                ? Colors.green
                                : qt.emeraldDeep.withOpacity(0.6),
                            size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prayer,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: qt.textPrimary)),
                            const SizedBox(height: 2),
                            Text(isPrayed ? "Prayed ✓" : "Not yet prayed",
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isPrayed ? Colors.green : qt.textMuted,
                                    fontWeight: isPrayed
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPrayed
                              ? Colors.green
                              : qt.borderGlass.withOpacity(0.3),
                        ),
                        child: Icon(
                            isPrayed ? Icons.check_rounded : Icons.add_rounded,
                            color: Colors.white,
                            size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
