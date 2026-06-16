import 'dart:math' show pi;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/prayer_service.dart';
import '../providers/prayer_tracker_provider.dart';
import '../constants/quran_theme.dart';
import '../constants/locations.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'prayer_stats_screen.dart';

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

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

  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3),
  );
  final ScrollController _dateScrollController = ScrollController();

  late AnimationController _slideController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchCalendar();
    PrayerService.instance.addListener(_onPrayerServiceChanged);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    PrayerService.instance.removeListener(_onPrayerServiceChanged);
    _confettiController.dispose();
    _dateScrollController.dispose();
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
            _selectedDay = data.firstWhere((d) {
              final parts = d['date']['gregorian']['date'].split('-');
              return int.parse(parts[0]) == targetDay;
            }, orElse: () => data[0] as Map<String, dynamic>);
          } else if (selectLastDay) {
            _selectedDay = data.last;
          } else {
            final existingDayStr = _selectedDay?['date']?['gregorian']?['day'];
            final existingDay = existingDayStr != null
                ? int.tryParse(existingDayStr.toString())
                : null;

            if (existingDay != null && existingDay <= data.length) {
              _selectedDay = data.firstWhere((d) {
                final parts = d['date']['gregorian']['date'].split('-');
                return int.parse(parts[0]) == existingDay;
              }, orElse: () => data[0] as Map<String, dynamic>);
            } else {
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
          }
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedDay(animate: false);
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToSelectedDay({bool animate = true}) {
    if (_dateScrollController.hasClients &&
        _calendarData != null &&
        _selectedDay != null) {
      final index = _calendarData!.indexOf(_selectedDay!);
      if (index != -1) {
        final double screenWidth = MediaQuery.of(context).size.width;

        // Dynamic horizontal layout math based on inactive (48px) and active (72px) states
        double targetOffset = 0.0;
        const double spacing = 8.0;

        for (int i = 0; i < index; i++) {
          targetOffset += 48.0 + spacing;
        }

        // Adding half the width of the active selected item (72.0)
        targetOffset += 72.0 / 2.0;

        // Account for horizontal list padding-left (16.0)
        targetOffset += 16.0;

        // Subtract half screen width to keep selected item at center-stage
        targetOffset -= screenWidth / 2.0;

        final double maxScroll = _dateScrollController.position.maxScrollExtent;
        final double minScroll = _dateScrollController.position.minScrollExtent;
        final double clampedOffset = targetOffset.clamp(minScroll, maxScroll);

        if (animate) {
          _dateScrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else {
          _dateScrollController.jumpTo(clampedOffset);
        }
      }
    }
  }

  void _prevMonth() {
    if (_selectedDay == null) return;
    final currentSelectedDate = _selectedDateTime();
    if (currentSelectedDate == null) return;

    final currentDay = currentSelectedDate.day;

    int targetYear = _displayDate.year;
    int targetMonth = _displayDate.month - 1;
    if (targetMonth == 0) {
      targetMonth = 12;
      targetYear -= 1;
    }

    final maxDaysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = currentDay.clamp(1, maxDaysInTargetMonth);

    setState(() {
      _displayDate = DateTime(targetYear, targetMonth, 1);
    });
    _fetchCalendar(targetDay: targetDay);
  }

  void _nextMonth() {
    if (_selectedDay == null) return;
    final currentSelectedDate = _selectedDateTime();
    if (currentSelectedDate == null) return;

    final currentDay = currentSelectedDate.day;

    int targetYear = _displayDate.year;
    int targetMonth = _displayDate.month + 1;
    if (targetMonth == 13) {
      targetMonth = 1;
      targetYear += 1;
    }

    final maxDaysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = currentDay.clamp(1, maxDaysInTargetMonth);

    setState(() {
      _displayDate = DateTime(targetYear, targetMonth, 1);
    });
    _fetchCalendar(targetDay: targetDay);
  }

  void _prevDay() async {
    if (_calendarData == null || _selectedDay == null || _isLoading) return;
    final currentIndex = _calendarData!.indexOf(_selectedDay!);
    if (currentIndex > 0) {
      _animateDayChange(-1, () {
        setState(() => _selectedDay = _calendarData![currentIndex - 1]);
        _scrollToSelectedDay();
      });
    } else {
      setState(() {
        _displayDate = DateTime(_displayDate.year, _displayDate.month - 1, 1);
      });
      await _fetchCalendar(selectLastDay: true);
      _animateDayChange(-1, () {});
    }
  }

  void _nextDay() async {
    if (_calendarData == null || _selectedDay == null || _isLoading) return;
    final currentIndex = _calendarData!.indexOf(_selectedDay!);
    if (currentIndex < _calendarData!.length - 1) {
      _animateDayChange(1, () {
        setState(() => _selectedDay = _calendarData![currentIndex + 1]);
        _scrollToSelectedDay();
      });
    } else {
      setState(() {
        _displayDate = DateTime(_displayDate.year, _displayDate.month + 1, 1);
      });
      await _fetchCalendar(targetDay: 1);
      _animateDayChange(1, () {});
    }
  }

  void _animateDayChange(int direction, VoidCallback onComplete) {
    onComplete();
    _slideAnimation = Tween<Offset>(
      begin: Offset(direction * 0.12, 0),
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

  Map<String, String?> _getCurrentAndNextPrayer(Map<String, dynamic>? timings) {
    if (timings == null) return {'current': null, 'next': null};
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final prayerOrder = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final Map<String, int> prayerMinutes = {};

    for (final prayer in prayerOrder) {
      final timeStr = timings[prayer].toString().split(' ')[0];
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        prayerMinutes[prayer] = h * 60 + m;
      }
    }

    String? current;
    String? next;

    for (int i = 0; i < prayerOrder.length; i++) {
      final p = prayerOrder[i];
      final pMin = prayerMinutes[p];
      if (pMin == null) continue;

      if (currentMinutes >= pMin) {
        current = p;
      } else {
        next = p;
        break;
      }
    }

    if (current == null) {
      current = 'Isha';
      next = 'Fajr';
    } else if (next == null) {
      current = 'Isha';
      next = 'Fajr';
    }

    return {'current': current, 'next': next};
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

    return Scaffold(
      backgroundColor: qt.bg,
      body: Stack(
        children: [
          Column(
            children: [
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 54, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        qt.emeraldDeep,
                        qt.emeraldDeep.withOpacity(0.95),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: qt.emeraldDeep.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _glassBtn(
                            const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 18),
                            qt,
                            onTap: () {
                              if (widget.onBackToHome != null) {
                                widget.onBackToHome!();
                              } else if (Navigator.canPop(context)) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          Column(
                            children: [
                              Text(
                                _selectedDay != null
                                    ? "${_selectedDay!['date']['gregorian']['day']} $monthName"
                                    : monthName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                yearNum,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.55),
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          _glassBtn(
                            const Icon(Icons.tune_rounded,
                                color: Colors.white, size: 18),
                            qt,
                            onTap: () {
                              MainNavigation.goToTabStatic(context, 4);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_selectedDay != null)
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded,
                                      color: Colors.white.withOpacity(0.6),
                                      size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${_selectedDay!['date']['hijri']['day']} ${_selectedDay!['date']['hijri']['month']['en']} ${_selectedDay!['date']['hijri']['year']} AH",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            GestureDetector(
                              onTap: () => _showLocationBottomSheet(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 11),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${prayerService.currentCity ?? 'Location'}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                        size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 250) {
                      _prevDay();
                    } else if (details.primaryVelocity! < -250) {
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                      children: [
                        if (_calendarData != null && !_isLoading)
                          RepaintBoundary(
                            child: KeepAliveWrapper(
                              child: Container(
                                height: 74,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: ListView.builder(
                                  controller: _dateScrollController,
                                  scrollDirection: Axis.horizontal,
                                  cacheExtent: 250,
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _calendarData!.length,
                                  itemBuilder: (context, index) {
                                    final dayData = _calendarData![index];
                                    final isSelected = _selectedDay == dayData;

                                    final parts = dayData['date']['gregorian']
                                            ['date']
                                        .split('-');
                                    final dDate = DateTime(
                                      int.parse(parts[2]),
                                      int.parse(parts[1]),
                                      int.parse(parts[0]),
                                    );

                                    final today = DateTime.now();
                                    final isToday = dDate.year == today.year &&
                                        dDate.month == today.month &&
                                        dDate.day == today.day;

                                    final dayKey = _dateKey(dDate);
                                    final prayedCount =
                                        tracker.prayedCountForDate(dayKey);
                                    final allDone = prayedCount == 5;
                                    final someDone =
                                        prayedCount > 0 && prayedCount < 5;

                                    final weekdayStr = DateFormat('E')
                                        .format(dDate)
                                        .toUpperCase();

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(
                                              () => _selectedDay = dayData);
                                          _scrollToSelectedDay();
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          width: isSelected ? 72 : 48,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? qt.emeraldDeep
                                                    .withOpacity(0.04)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: isSelected
                                                ? Border.all(
                                                    color: qt.emeraldDeep
                                                        .withOpacity(0.04),
                                                    width: 1.5,
                                                  )
                                                : null,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                weekdayStr,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? qt.textMuted
                                                      : qt.textMuted
                                                          .withOpacity(0.6),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                dayData['date']['gregorian']
                                                    ['day'],
                                                style: TextStyle(
                                                  fontSize:
                                                      isSelected ? 15 : 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: isSelected
                                                      ? qt.textPrimary
                                                      : qt.textPrimary
                                                          .withOpacity(isToday
                                                              ? 0.9
                                                              : 0.5),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (dDate.isBefore(DateTime(
                                                  today.year,
                                                  today.month,
                                                  today.day + 1)))
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: allDone
                                                        ? Colors.green
                                                        : (someDone
                                                            ? Colors.amber
                                                            : Colors
                                                                .transparent),
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              else
                                                const SizedBox(height: 4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              if (_selectedDay != null) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionTitle("Prayer Times", qt),
                                    Row(
                                      children: [
                                        Icon(Icons.swipe_rounded,
                                            size: 13,
                                            color:
                                                qt.textMuted.withOpacity(0.6)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Swipe to change date",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                qt.textMuted.withOpacity(0.6),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                RepaintBoundary(
                                  child: _buildPrayerTimesCard(qt, tracker),
                                ),
                                const SizedBox(height: 24),
                                RepaintBoundary(
                                  child: _buildDailyProgress(qt, tracker),
                                ),
                                const SizedBox(height: 24),
                                RepaintBoundary(
                                  child: _buildStatsSummaryCard(qt, tracker),
                                ),
                                const SizedBox(height: 24),
                              ],
                              _buildSectionTitle("Calendar Overview", qt),
                              const SizedBox(height: 24),
                              RepaintBoundary(
                                child: _buildCalendarCard(qt, tracker),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Confetti particles
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

  Widget _buildDailyProgress(QuranTheme qt, PrayerTracker tracker) {
    final selectedDate = _selectedDateTime();
    if (selectedDate == null) return const SizedBox.shrink();

    final key = _dateKey(selectedDate);
    final count = tracker.prayedCountForDate(key);
    final allDone = count == 5;
    final isToday = _isSelectedDayToday();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: allDone
            ? const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              )
            : null,
        color: allDone ? null : qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allDone
              ? Colors.green.withOpacity(0.3)
              : qt.borderGlass.withOpacity(0.4),
          width: allDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: allDone
                ? Colors.green.withOpacity(0.12)
                : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: allDone
                  ? Colors.white.withOpacity(0.2)
                  : qt.emeraldDeep.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone ? Icons.check_circle_rounded : Icons.stars_rounded,
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
                  isToday ? "Today's Focus" : "Day's Progress",
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
              fontWeight: FontWeight.w800,
              color: allDone ? Colors.white : qt.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesCard(QuranTheme qt, PrayerTracker tracker) {
    final prayerOrder = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerMeta = _getCurrentAndNextPrayer(_selectedDay?['timings']);
    final currentPrayer = prayerMeta['current'];
    final nextPrayer = prayerMeta['next'];
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(prayerOrder.length, (index) {
          final prayer = prayerOrder[index];
          final time =
              _selectedDay?['timings'][prayer].toString().split(' ')[0] ??
                  '--:--';

          final isSunrise = (prayer == 'Sunrise');
          final isCurrent = isToday && prayer == currentPrayer;
          final isNext = isToday && prayer == nextPrayer;
          final isPrayed = prayers[prayer] ?? false;

          final prayerTimePassed = isToday
              ? _hasPrayerTimePassed(prayer, _selectedDay?['timings'])
              : true;

          final canTrack = !isSunrise && !isFutureDay && prayerTimePassed;

          // Unified future/Sunrise row visual dimming logic
          double rowOpacity = 1.0;
          if (isSunrise) {
            rowOpacity = 0.45;
          } else if (isFutureDay) {
            rowOpacity = 0.8; // Very subtle dimming for all future-day prayers
          } else if (isToday) {
            if (!isCurrent && !isNext) {
              final currentIdx = currentPrayer != null
                  ? prayerOrder.indexOf(currentPrayer)
                  : -1;
              final itemIdx = prayerOrder.indexOf(prayer);
              if (currentIdx != -1 && itemIdx > currentIdx + 1) {
                rowOpacity =
                    0.8; // Very subtle dimming for chronologically subsequent items
              }
            }
          }

          // Build contextually correct descriptive subtexts
          String subText = "";
          if (isSunrise) {
            subText = "Sunrise time";
          } else if (isPrayed) {
            subText = "Completed ✓";
          } else if (isFutureDay) {
            subText = "";
          } else {
            if (!isToday) {
              subText = "Tap to mark as prayed";
            } else {
              if (prayerTimePassed) {
                subText = "Tap to mark as prayed";
              } else {
                subText = "";
              }
            }
          }

          return Container(
            decoration: BoxDecoration(
              // Extremely subtle dipped color background highlights for the active current prayer
              color: isCurrent
                  ? qt.emeraldDeep.withOpacity(0.06)
                  : Colors.transparent,
              border: Border(
                bottom: index == prayerOrder.length - 1
                    ? BorderSide.none
                    : BorderSide(color: qt.borderGlass.withOpacity(0.2)),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: rowOpacity,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: isCurrent ? 16 : 13),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: canTrack
                            ? () => _togglePrayer(prayer, tracker)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPrayed
                                ? Colors.green.withOpacity(0.12)
                                : qt.bg, // Removed dark highlights on active icon background container
                            border: Border.all(
                              color: isPrayed
                                  ? Colors.green.withOpacity(0.4)
                                  : isCurrent
                                      ? qt.emeraldDeep.withOpacity(0.5)
                                      : qt.borderGlass.withOpacity(0.4),
                              width: isPrayed || isCurrent ? 1.5 : 1.0,
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
                                    _getPrayerIcon(prayer,
                                        filled:
                                            isCurrent), // Render filled solid icons for active prayer
                                    color: isCurrent
                                        ? qt.emeraldDeep
                                        : !canTrack && !isSunrise
                                            ? qt.textMuted.withOpacity(0.5)
                                            : qt.textPrimary.withOpacity(0.8),
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  prayer,
                                  style: TextStyle(
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.bold,
                                    fontSize: isCurrent ? 16 : 15,
                                    color: isPrayed
                                        ? Colors.green
                                        : qt.textPrimary, // Force normal primary color text on current row
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  // Sleek minimalistic current status indicator dot
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                if (isNext) ...[
                                  const SizedBox(width: 8),
                                  // Minimalist Stacked Upcoming / Next Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: qt.emeraldLight.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Upcoming",
                                          style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w500,
                                              color: qt.textPrimary,
                                              letterSpacing: 0.3),
                                        ),
                                        const SizedBox(height: 1),
                                      ],
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            if (subText.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isPrayed || isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isPrayed
                                      ? Colors.green
                                      : isCurrent
                                          ? qt.textPrimary.withOpacity(0.7)
                                          : qt.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _to12Hour(time),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight:
                              isCurrent ? FontWeight.w800 : FontWeight.bold,
                          fontSize: isCurrent ? 14 : 13,
                          color: isPrayed
                              ? Colors.green
                              : isCurrent
                                  ? qt.emeraldDeep
                                  : qt.textSecondary,
                        ),
                      ),
                    ],
                  ),
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

    HapticFeedback.lightImpact();

    tracker.togglePrayerForDate(key, prayer).then((_) {
      final afterCount = tracker.prayedCountForDate(key);
      if (beforeCount == 4 && afterCount == 5) {
        _triggerCelebration();
        HapticFeedback.mediumImpact();
      }
    });
  }

  Widget _buildStatsSummaryCard(QuranTheme qt, PrayerTracker tracker) {
    final currentStreak = tracker.currentStreak;
    final bestStreak = tracker.bestStreak;
    final totalPrayers = tracker.totalPrayersLogged;

    return GestureDetector(
      onTap: () {
        MainNavigation.pushOnShell(context, const PrayerStatsScreen());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.insights_rounded,
                      color: qt.emeraldDeep, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Prayer Streak & Insights",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary,
                        ),
                      ),
                      Text(
                        "Tap to view detailed analytics",
                        style: TextStyle(
                          fontSize: 10,
                          color: qt.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: qt.textMuted.withOpacity(0.7), size: 14),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statTile(
                  icon: Icons.local_fire_department_rounded,
                  value: "$currentStreak",
                  label: "Active Streak",
                  color: Colors.orange,
                  qt: qt,
                ),
                const SizedBox(width: 8),
                _statTile(
                  icon: Icons.workspace_premium_rounded,
                  value: "$bestStreak",
                  label: "Best Streak",
                  color: Colors.amber,
                  qt: qt,
                ),
                const SizedBox(width: 8),
                _statTile(
                  icon: Icons.mosque,
                  value: "$totalPrayers",
                  label: "Total Logged",
                  color: qt.emeraldDeep,
                  qt: qt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required QuranTheme qt,
  }) {
    final isDark = qt.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : qt.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qt.borderGlass.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: qt.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard(QuranTheme qt, PrayerTracker tracker) {
    String englishMonth = "";
    String hijriDateString = "";

    if (_calendarData != null && _calendarData!.isNotEmpty) {
      final firstDay = _calendarData!.first['date'];
      englishMonth = firstDay['gregorian']['month']['en'];
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (englishMonth.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _prevMonth,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: qt.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: qt.borderGlass.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.chevron_left_rounded,
                              color: qt.emeraldDeep, size: 18),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            englishMonth,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: qt.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _nextMonth,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: qt.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: qt.borderGlass.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.chevron_right_rounded,
                              color: qt.emeraldDeep, size: 18),
                        ),
                      ),
                    ],
                  ),
                  if (hijriDateString.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hijriDateString,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: qt.emeraldDeep,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (englishMonth.isNotEmpty)
            Divider(color: qt.borderGlass.withOpacity(0.3), height: 1),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final legendDark = qt.brightness == Brightness.dark;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: qt.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _legendDot(
                      legendDark
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFD1FAE5),
                      'All Done',
                      legendDark
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFF065F46),
                    ),
                    _legendDot(
                      legendDark
                          ? const Color(0xFF713F12)
                          : const Color(0xFFFEF3C7),
                      'Partial',
                      legendDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFF92400E),
                    ),
                    _legendDot(
                      legendDark
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFFFEE2E2),
                      'Missed',
                      legendDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF991B1B),
                    ),
                  ],
                ),
              );
            },
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
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
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
    final totalItems = paddingDays + daysInMonth;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final isDark = qt.brightness == Brightness.dark;

    List<Widget> rows = [];
    List<Widget> currentRow = [];

    for (int index = 0; index < totalItems; index++) {
      if (index > 0 && index % 7 == 0) {
        rows.add(Row(children: List.from(currentRow)));
        currentRow.clear();
      }

      if (index < paddingDays) {
        currentRow.add(const Expanded(child: SizedBox.shrink()));
      } else {
        final dataIndex = index - paddingDays;
        final dayData = _calendarData![dataIndex];
        final isSelected = _selectedDay == dayData;

        final parts = dayData['date']['gregorian']['date'].split('-');
        final dDate = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final isToday = dDate.year == todayDateOnly.year &&
            dDate.month == todayDateOnly.month &&
            dDate.day == todayDateOnly.day;

        final dayKey = _dateKey(dDate);
        final prayedCount = tracker.prayedCountForDate(dayKey);
        final allDone = prayedCount == 5;
        final someDone = prayedCount > 0 && prayedCount < 5;

        Color? completionBg;
        if (!isSelected) {
          if (allDone) {
            completionBg =
                isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
          } else if (someDone) {
            completionBg =
                isDark ? const Color(0xFF713F12) : const Color(0xFFFEF3C7);
          } else if (dDate.isBefore(todayDateOnly)) {
            completionBg =
                isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
          }
        }

        currentRow.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDay = dayData);
                  _scrollToSelectedDay();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 40,
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
                                      ? (isDark
                                          ? Colors.white70
                                          : qt.textPrimary)
                                      : qt.textPrimary))),
                      const SizedBox(height: 1),
                      Text(dayData['date']['hijri']['day'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 8,
                              color: isSelected
                                  ? Colors.white60
                                  : (completionBg != null && isDark
                                      ? Colors.white54
                                      : qt.textMuted))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(const Expanded(child: SizedBox.shrink()));
      }
      rows.add(Row(children: currentRow));
    }

    return Column(
      children: rows,
    );
  }

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

  IconData _getPrayerIcon(String prayer, {bool filled = false}) {
    switch (prayer) {
      case 'Fajr':
        return Icons.wb_twilight_rounded;
      case 'Sunrise':
        return filled ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined;
      case 'Dhuhr':
        return filled ? Icons.wb_sunny_rounded : Icons.sunny;
      case 'Asr':
        return filled ? Icons.cloud_rounded : Icons.filter_drama_outlined;
      case 'Maghrib':
        return filled ? Icons.nights_stay_rounded : Icons.nights_stay_outlined;
      case 'Isha':
        return filled ? Icons.bedtime_rounded : Icons.bedtime_outlined;
      default:
        return Icons.access_time_rounded;
    }
  }

  Widget _legendDot(Color color, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: textColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, QuranTheme qt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.5,
          height: 15,
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
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.62,
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: qt.borderGlass,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                          style: TextStyle(color: qt.textPrimary),
                          decoration: InputDecoration(
                            hintText: "Search city...",
                            hintStyle:
                                TextStyle(color: qt.textMuted, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: qt.textMuted, size: 20),
                            filled: true,
                            fillColor: qt.cardBg,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: qt.borderGlass),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: qt.borderGlass.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: qt.emeraldDeep.withOpacity(0.15)),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.my_location_rounded,
                              color: qt.emeraldDeep, size: 20),
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount:
                          filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(
                          color: qt.borderGlass.withOpacity(0.3), height: 1),
                      itemBuilder: (context, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.public_rounded,
                                color: qt.emeraldDeep),
                            title: Text(
                              'Custom entry: "$searchQuery"',
                              style: TextStyle(
                                color: qt.emeraldDeep,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
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
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.location_on_outlined,
                              color: qt.textMuted, size: 20),
                          title: Text(
                            loc['city']!,
                            style: TextStyle(
                              color: qt.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            loc['country']!,
                            style: TextStyle(color: qt.textMuted, fontSize: 12),
                          ),
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}
