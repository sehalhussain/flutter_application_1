import 'dart:math' show pi;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/prayer_service.dart';
import '../providers/prayer_tracker_provider.dart';
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

class _PrayerScreenState extends State<PrayerScreen>
    with TickerProviderStateMixin {
  DateTime _displayDate = DateTime.now();
  List<dynamic>? _calendarData;
  Map<String, dynamic>? _selectedDay;
  bool _isLoading = true;

  late ConfettiController _confettiController;

  // Animation controllers for card swipe transitions
  late AnimationController _slideController;
  Animation<Offset>? _slideAnimation;
  int _slideDirection = 0; // -1 = left (next), 1 = right (prev)

  @override
  void initState() {
    super.initState();
    _fetchCalendar();
    PrayerService.instance.addListener(_onPrayerServiceChanged);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    PrayerService.instance.removeListener(_onPrayerServiceChanged);
    _confettiController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onPrayerServiceChanged() => _fetchCalendar();

  Future<void> _fetchCalendar(
      {bool selectLastDay = false, int? targetDay}) async {
    setState(() => _isLoading = true);
    try {
      final data = await PrayerService.instance.getCalendarByMonth(
        _displayDate.year,
        _displayDate.month,
      );

      if (data != null && mounted) {
        setState(() {
          _calendarData = data;
          if (targetDay != null) {
            // Target specific date when swiping forward into a new month
            _selectedDay = data.firstWhere((d) {
              final parts = d['date']['gregorian']['date'].split('-');
              return int.parse(parts[0]) == targetDay;
            }, orElse: () => data[0] as Map<String, dynamic>);
          } else if (selectLastDay) {
            // Target last day of month when swiping back into previous month
            _selectedDay = data.last;
          } else {
            // Default load behavior for current month/today
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

  /// Go to previous day (swipe RIGHT) - Now crosses month boundary seamlessly!
  void _prevDay() async {
    if (_calendarData == null || _selectedDay == null || _isLoading) return;
    final currentIndex = _calendarData!.indexOf(_selectedDay!);
    if (currentIndex > 0) {
      _animateDayChange(-1, () {
        setState(() => _selectedDay = _calendarData![currentIndex - 1]);
      });
    } else {
      // We are on the 1st of the month! Automatically switch to the previous month's last day
      setState(() {
        _displayDate = DateTime(_displayDate.year, _displayDate.month - 1, 1);
      });
      await _fetchCalendar(selectLastDay: true);
      _animateDayChange(-1, () {});
    }
  }

  /// Go to next day (swipe LEFT) - Now crosses month boundary seamlessly!
  void _nextDay() async {
    if (_calendarData == null || _selectedDay == null || _isLoading) return;
    final currentIndex = _calendarData!.indexOf(_selectedDay!);
    if (currentIndex < _calendarData!.length - 1) {
      _animateDayChange(1, () {
        setState(() => _selectedDay = _calendarData![currentIndex + 1]);
      });
    } else {
      // We are on the last day of the month! Automatically switch to the next month's 1st day
      setState(() {
        _displayDate = DateTime(_displayDate.year, _displayDate.month + 1, 1);
      });
      await _fetchCalendar(targetDay: 1);
      _animateDayChange(1, () {});
    }
  }

  void _animateDayChange(int direction, VoidCallback onComplete) {
    onComplete();
    _slideDirection = direction;
    _slideAnimation = Tween<Offset>(
      begin: Offset(direction * 0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward(from: 0);
  }

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
      if (pTime.compareTo(timeStr) > 0) return prayer;
    }
    return 'Fajr';
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _selectedDateTime() {
    if (_selectedDay == null) return null;
    final parts = _selectedDay!['date']['gregorian']['date'].split('-');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  bool _isSelectedDayFuture() {
    final selectedDate = _selectedDateTime();
    if (selectedDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return selectedDate.isAfter(today);
  }

  void _triggerCelebration() => _confettiController.play();

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final tracker = context.watch<PrayerTracker>();
    final prayerService = context.watch<PrayerService>();
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
      body: Stack(
        children: [
          Column(
            children: [
              // ── IMMERSIVE HEADER SECTION ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [qt.emeraldDeep, qt.emeraldMid],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: qt.emeraldDeep.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
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
                        Text(
                          monthName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        _glassBtn(
                          const Icon(Icons.tune_rounded,
                              color: Colors.white, size: 20),
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
                    Text(
                      yearNum,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavButton(Icons.chevron_left_rounded, _prevMonth),
                        if (hijriDateString.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              hijriDateString,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        _buildNavButton(
                            Icons.chevron_right_rounded, _nextMonth),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => _showLocationBottomSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "${prayerService.currentCity ?? 'Unknown'}, ${prayerService.currentCountry ?? ''}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── FLOATING DATE SELECTOR BAR ──
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: qt.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: qt.borderGlass.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.calendar_today_rounded,
                              color: qt.emeraldDeep, size: 18),
                        ),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: qt.textPrimary),
                              ),
                              if (_selectedDay != null)
                                Text(
                                  "${_selectedDay!['date']['hijri']['day']} ${_selectedDay!['date']['hijri']['month']['en']} ${_selectedDay!['date']['hijri']['year']} AH",
                                  style: TextStyle(
                                      fontSize: 11, color: qt.textMuted),
                                ),
                            ],
                          ),
                        ),
                        if (_selectedDay != null &&
                            _getNextPrayer(_selectedDay?['timings']) != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: qt.emeraldDeep.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Next: ${_getNextPrayer(_selectedDay?['timings'])}",
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

              // ── CONTENT AREA ──
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 200) {
                      _prevDay();
                    } else if (details.primaryVelocity! < -200) {
                      _nextDay();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) {
                      final offset = _slideAnimation?.value ?? Offset.zero;
                      return Transform.translate(
                        offset: Offset(
                          offset.dx * MediaQuery.of(context).size.width,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        if (_selectedDay != null) ...[
                          _buildDailyProgress(qt, tracker),
                          const SizedBox(height: 24),
                        ],
                        if (_selectedDay != null) ...[
                          _buildSectionTitle("Prayer Times", qt),
                          const SizedBox(height: 12),
                          _buildPrayerTimesCard(qt, tracker),
                          const SizedBox(height: 24),
                        ],
                        _buildSectionTitle("Calendar", qt),
                        const SizedBox(height: 12),
                        _buildCalendarCard(qt, tracker),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Confetti explosion on full prayer checklist completion!
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              blastDirection: -pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 40,
              maxBlastForce: 25,
              minBlastForce: 12,
              gravity: 0.15,
              particleDrag: 0.02,
              colors: const [
                Colors.green,
                Colors.teal,
                Colors.amber,
                Colors.orange,
                Colors.lightGreen,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DAILY PROGRESS BAR ──
  Widget _buildDailyProgress(QuranTheme qt, PrayerTracker tracker) {
    final selectedDate = _selectedDateTime();
    if (selectedDate == null) return const SizedBox.shrink();

    final key = _dateKey(selectedDate);
    final count = tracker.prayedCountForDate(key);
    final allDone = count == 5;
    final isToday = _isSelectedDayToday();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: allDone
            ? const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              )
            : null,
        color: allDone ? null : qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? Colors.green.withOpacity(0.3)
              : qt.borderGlass.withOpacity(0.4),
          width: allDone ? 1.5 : 1,
        ),
        boxShadow: allDone
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: allDone
                  ? Colors.white.withOpacity(0.2)
                  : qt.emeraldDeep.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone
                  ? Icons.check_circle_rounded
                  : Icons.track_changes_rounded,
              color: allDone ? Colors.white : qt.emeraldDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? "Today's Checklist" : "Day's Checklist",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: allDone ? Colors.white : qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: count / 5,
                    minHeight: 6,
                    backgroundColor: allDone
                        ? Colors.white.withOpacity(0.2)
                        : qt.borderGlass.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allDone ? Colors.white : qt.emeraldDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "$count/5",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: allDone ? Colors.white : qt.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── PREMIUM PRAYER TIMES CARD (Ultra-Clean merged icons layout) ──
  Widget _buildPrayerTimesCard(QuranTheme qt, PrayerTracker tracker) {
    final prayerOrder = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final nextPrayer = _getNextPrayer(_selectedDay?['timings']);
    final isFutureDay = _isSelectedDayFuture();

    bool isToday = false;
    if (_selectedDay != null) {
      final parts = _selectedDay!['date']['gregorian']['date'].split('-');
      final d = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final today = DateTime.now();
      isToday =
          d.year == today.year && d.month == today.month && d.day == today.day;
    }

    final selectedDate = _selectedDateTime();
    final trackerKey = selectedDate != null ? _dateKey(selectedDate) : null;
    final prayers =
        trackerKey != null ? tracker.prayersForDate(trackerKey) : {};

    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: Column(
        children: List.generate(prayerOrder.length, (index) {
          final prayer = prayerOrder[index];
          final time =
              _selectedDay?['timings'][prayer].toString().split(' ')[0] ??
                  '--:--';
          final isNext = isToday && prayer == nextPrayer;
          final isPrayed = prayers[prayer] ?? false;

          // Checking tracker validity
          final prayerTimePassed = isToday
              ? _hasPrayerTimePassed(prayer, _selectedDay?['timings'])
              : true;
          final canTrack =
              prayer != 'Sunrise' && !isFutureDay && prayerTimePassed;

          return Container(
            decoration: BoxDecoration(
              color: isNext
                  ? qt.emeraldDeep.withOpacity(0.04)
                  : Colors.transparent,
              border: Border(
                bottom: index == prayerOrder.length - 1
                    ? BorderSide.none
                    : BorderSide(color: qt.borderGlass.withOpacity(0.2)),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Unified Interaction & Status Lead Circle (Cleans up dual icon layout!)
                    GestureDetector(
                      onTap: canTrack
                          ? () => _togglePrayer(prayer, tracker)
                          : null,
                      child: Tooltip(
                        message: !canTrack
                            ? (prayer == 'Sunrise'
                                ? 'Sunrise'
                                : isFutureDay
                                    ? 'Upcoming'
                                    : 'Upcoming at ${_to12Hour(time)}')
                            : (isPrayed
                                ? 'Unmark $prayer'
                                : 'Mark $prayer as prayed'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPrayed
                                ? Colors.green.withOpacity(0.12)
                                : isNext
                                    ? qt.emeraldDeep.withOpacity(0.08)
                                    : qt.bg,
                            border: Border.all(
                              color: isPrayed
                                  ? Colors.green.withOpacity(0.4)
                                  : isNext
                                      ? qt.emeraldDeep.withOpacity(0.3)
                                      : qt.borderGlass.withOpacity(0.4),
                              width: isPrayed || isNext ? 1.5 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: isPrayed
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.green,
                                    size: 18,
                                  )
                                : Icon(
                                    _getPrayerIcon(prayer),
                                    color: isNext
                                        ? qt.emeraldDeep
                                        : !canTrack && prayer != 'Sunrise'
                                            ? qt.textMuted.withOpacity(0.5)
                                            : qt.textPrimary.withOpacity(0.8),
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Label / Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                prayer,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color:
                                      isPrayed ? Colors.green : qt.textPrimary,
                                ),
                              ),
                              if (isNext) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: qt.emeraldDeep,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "NEXT",
                                    style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPrayed
                                ? "Prayed ✓"
                                : (prayer == 'Sunrise'
                                    ? "Sun rises"
                                    : !canTrack
                                        ? (isFutureDay
                                            ? "Upcoming"
                                            : "Not started yet")
                                        : "Tap to mark as prayed"),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isPrayed
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isPrayed ? Colors.green : qt.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Display Time
                    Text(
                      _to12Hour(time),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isPrayed
                            ? Colors.green
                            : isNext
                                ? qt.emeraldDeep
                                : qt.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _togglePrayer(String prayer, PrayerTracker tracker) {
    final selectedDate = _selectedDateTime();
    if (selectedDate == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (selectedDate.isAfter(today)) return;

    final key = _dateKey(selectedDate);
    final beforeCount = tracker.prayedCountForDate(key);

    tracker.togglePrayerForDate(key, prayer).then((_) {
      final afterCount = tracker.prayedCountForDate(key);
      if (beforeCount == 4 && afterCount == 5) {
        _triggerCelebration();
      }
    });
  }

  // ── PREMIUM CALENDAR OVERVIEW CARD ──
  Widget _buildCalendarCard(QuranTheme qt, PrayerTracker tracker) {
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          if (englishMonth.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: qt.emeraldDeep, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        englishMonth,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$hijriMonth $hijriYear AH",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: qt.emeraldDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (englishMonth.isNotEmpty)
            Divider(color: qt.borderGlass.withOpacity(0.3), height: 1),
          const SizedBox(height: 12),

          // Cleaner Legend Row (Grabs correct Theme scope dynamically)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: qt.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendDot(const Color(0xFFD1FAE5), 'All Prayed',
                    Colors.green.shade800),
                _legendDot(const Color(0xFFFEF3C7), 'Some Prayed',
                    Colors.orange.shade800),
                _legendDot(const Color(0xFFFEE2E2), 'None Prayed',
                    Colors.red.shade800),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                    child: Center(
                        child: Text(d,
                            style: TextStyle(
                                color: qt.textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)))))
                .toList(),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )
          else if (_calendarData != null)
            _buildCalendarGrid(qt, tracker),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(QuranTheme qt, PrayerTracker tracker) {
    if (_calendarData == null || _calendarData!.isEmpty) {
      return const SizedBox.shrink();
    }

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
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.95,
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

        final dayKey = _dateKey(dDate);
        final prayedCount = tracker.prayedCountForDate(dayKey);
        final allDone = prayedCount == 5;
        final someDone = prayedCount > 0 && prayedCount < 5;

        Color? completionBg;
        if (!isSelected) {
          if (allDone) {
            completionBg = const Color(0xFFD1FAE5);
          } else if (someDone) {
            completionBg = const Color(0xFFFEF3C7);
          } else if (dDate
              .isBefore(DateTime(today.year, today.month, today.day))) {
            completionBg = const Color(0xFFFEE2E2);
          }
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = dayData),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? qt.emeraldDeep
                  : completionBg ?? Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? qt.emeraldDeep
                    : isToday
                        ? qt.emeraldDeep
                        : qt.borderGlass.withOpacity(0.3),
                width: isSelected ? 1.5 : (isToday ? 1.2 : 0.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayData['date']['gregorian']['day'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isSelected
                            ? Colors.white
                            : (completionBg != null
                                ? qt.textPrimary
                                : qt.textPrimary))),
                const SizedBox(height: 1),
                Text(dayData['date']['hijri']['day'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8,
                        color: isSelected ? Colors.white70 : qt.textMuted)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── HELPER UTILITIES ──

  bool _isSelectedDayToday() {
    if (_selectedDay == null) return false;
    final parts = _selectedDay!['date']['gregorian']['date'].split('-');
    final d =
        DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    final today = DateTime.now();
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }

  bool _hasPrayerTimePassed(String prayer, Map<String, dynamic>? timings) {
    if (timings == null) return false;
    final timeStr = timings[prayer].toString().split(' ')[0];
    if (timeStr == '--:--') return false;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final parts = timeStr.split(':');
    final prayerMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return currentMinutes >= prayerMinutes;
  }

  IconData _getPrayerIcon(String prayer) {
    switch (prayer) {
      case 'Fajr':
        return Icons.wb_twilight_rounded;
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
        return Icons.access_time_rounded;
    }
  }

  // Fetches state theme context dynamically to resolve the Undefined name 'qt' error!
  Widget _legendDot(Color color, String label, Color textColor) {
    final qt = QuranTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: qt.textPrimary.withOpacity(0.8),
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSectionTitle(String title, QuranTheme qt) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: qt.emeraldDeep,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary,
                letterSpacing: -0.2)),
      ],
    );
  }

  // ── LOCATION SELECTOR SHEET ──
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
                            prefixIcon:
                                Icon(Icons.search_rounded, color: qt.textMuted),
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
                          color: qt.emeraldDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.my_location_rounded,
                              color: qt.emeraldDeep),
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
                            leading: Icon(Icons.public_rounded,
                                color: qt.emeraldDeep),
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
          color: isDark ? Colors.white.withOpacity(0.08) : qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}
