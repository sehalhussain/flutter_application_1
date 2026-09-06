import 'dart:math' show pi;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/prayer_service.dart';
import '../services/prayer_notification_service.dart';
import '../providers/prayer_tracker_provider.dart';
import '../providers/prayer_notification_provider.dart';
import '../services/whats_new_service.dart';
import '../constants/quran_theme.dart';
import '../constants/locations.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'prayer_stats_screen.dart';

/// Lightweight class to cache parsed monthly details so we don't perform heavy
/// string operations, parsing, and DateTime instantiations inside the layout loop.
class _ParsedDay {
  final Map<String, dynamic> rawData;
  final DateTime dateTime;
  final String dateKey;
  final String gregorianDay;
  final String hijriDay;

  _ParsedDay({
    required this.rawData,
    required this.dateTime,
    required this.dateKey,
    required this.gregorianDay,
    required this.hijriDay,
  });
}

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

  // Pre-cached parsed monthly data to run rendering at 60/120 FPS
  List<_ParsedDay>? _parsedCalendarDays;
  Map<String, dynamic>? _selectedDay;
  bool _isLoading = true;

  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  late AnimationController _slideController;
  Animation<Offset>? _slideAnimation;

  // Optimized Scroll Controller for high-performance scroll interpolation
  late ScrollController _mainScrollController;

  @override
  void initState() {
    super.initState();
    _fetchCalendar();
    PrayerService.instance.addListener(_onPrayerServiceChanged);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _mainScrollController = ScrollController();
    _mainScrollController.addListener(_onScroll);

    // Reschedule notifications for today when the prayer screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PrayerNotificationService.instance.rescheduleToday();
    });
  }

  @override
  void dispose() {
    PrayerService.instance.removeListener(_onPrayerServiceChanged);
    _confettiController.dispose();
    _slideController.dispose();
    _mainScrollController.removeListener(_onScroll);
    _mainScrollController.dispose();
    super.dispose();
  }

  /// Safe listener for bound controllers pointing to scroll updates
  void _onScroll() {}

  void _onPrayerServiceChanged() {
    _fetchCalendar();
    // Force reschedule notifications when location/calculation method changes
    // (old notifications have wrong times and must be cancelled first)
    PrayerNotificationService.instance.forceRescheduleToday();
  }

  Future<void> _fetchCalendar(
      {bool selectLastDay = false, int? targetDay}) async {
    setState(() => _isLoading = true);
    try {
      final data = await PrayerService.instance.getCalendarByMonth(
        _displayDate.year,
        _displayDate.month,
      );

      if (data != null && mounted) {
        // Pre-parse the calendar month to optimize layout frame metrics
        final parsedDays = data.map<_ParsedDay>((d) {
          final parts = d['date']['gregorian']['date'].split('-');
          final dateTime = DateTime(
            int.parse(parts[2]), // Year
            int.parse(parts[1]), // Month
            int.parse(parts[0]), // Day
          );
          return _ParsedDay(
            rawData: d,
            dateTime: dateTime,
            dateKey:
                '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
            gregorianDay: d['date']['gregorian']['day'],
            hijriDay: d['date']['hijri']['day'],
          );
        }).toList();

        setState(() {
          _calendarData = data;
          _parsedCalendarDays = parsedDays;

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
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  bool _isPostMidnightBeforeFajr(Map<String, dynamic>? timings) {
    if (timings == null) return false;
    final now = DateTime.now();
    final fajrStr = timings['Fajr'].toString().split(' ')[0];
    final parts = fajrStr.split(':');
    if (parts.length != 2) return false;
    final fajrMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes < fajrMinutes && now.hour < 5;
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
    final isDark = qt.brightness == Brightness.dark;

    // Rigid background overrides from UI system specs
    final Color appBg =
        isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7);
    final Color cardBg =
        isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFFFFFFF);

    final tracker = context.watch<PrayerTracker>();
    final notifProvider = context.watch<PrayerNotificationProvider>();
    final prayerService = context.watch<PrayerService>();
    final whatsNew = context.watch<WhatsNewService>();
    final showBellHighlight = whatsNew.shouldShowBellHighlight;
    final monthName = DateFormat('MMMM').format(_displayDate);
    final yearNum = _displayDate.year.toString();

    final List<BoxShadow>? cardShadow = isDark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ];

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    const double appBarHeight = 56.0;

    return Scaffold(
      backgroundColor: appBg,
      body: Stack(
        children: [
          // Main Body Horizontal Drag Detector for fluid day transitions
          GestureDetector(
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
                controller: _mainScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    24, statusBarHeight + appBarHeight + 12, 24, 32),
                children: [
                  if (_selectedDay != null) ...[
                    // Scroll-linked Morphing Typography Header Block (Cascades under the same line actions)
                    AnimatedBuilder(
                      animation: _mainScrollController,
                      builder: (context, child) {
                        final double offset = _mainScrollController.hasClients
                            ? _mainScrollController.offset
                            : 0.0;
                        final double opacity =
                            (1.0 - (offset / 60.0)).clamp(0.0, 1.0);

                        return Opacity(
                          opacity: opacity,
                          child: child,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "$yearNum  •  ${_selectedDay!['date']['hijri']['day']} ${_selectedDay!['date']['hijri']['month']['en']} ${_selectedDay!['date']['hijri']['year']} AH",
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: qt.textMuted.withOpacity(0.85),
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_left,
                                size: 15,
                                color: qt.textMuted.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Swipe to change date",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: qt.textMuted.withOpacity(0.6),
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              Icon(
                                Icons.arrow_right,
                                size: 15,
                                color: qt.textMuted.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => _showLocationBottomSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: qt.emeraldDeep.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      color: qt.emeraldDeep, size: 11),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${prayerService.currentCity ?? 'Select Location'}",
                                    style: TextStyle(
                                      color: qt.emeraldDeep,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color: qt.emeraldDeep, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle("Prayer Times", qt),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (showBellHighlight)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildNotificationBanner(qt, whatsNew),
                      ),
                    RepaintBoundary(
                      child: _buildPrayerTimesCard(qt, tracker, notifProvider,
                          cardBg, cardShadow, isDark),
                    ),
                    const SizedBox(height: 24),
                    RepaintBoundary(
                      child: _buildDailyProgress(
                          qt, tracker, cardBg, cardShadow, isDark),
                    ),
                    const SizedBox(height: 24),
                    _statsSectionHeader(qt, tracker),
                    const SizedBox(height: 14),
                    RepaintBoundary(
                      child: _buildStatsSummaryCard(
                          qt, tracker, cardBg, cardShadow, isDark),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Calendar Overview", qt),
                    const SizedBox(height: 14),
                    RepaintBoundary(
                      child: _buildCalendarCard(
                          qt, tracker, cardBg, cardShadow, isDark),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _mainScrollController,
              builder: (context, child) {
                final double offset = _mainScrollController.hasClients
                    ? _mainScrollController.offset
                    : 0.0;
                final double t = (offset / 80.0).clamp(0.0, 1.0);
                final double titleSize = 28.0 - (12.0 * t);

                return Container(
                  padding: EdgeInsets.fromLTRB(24, statusBarHeight, 24, 0),
                  height: statusBarHeight + appBarHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0C0C0E).withOpacity(t * 0.94)
                        : const Color(0xFFF2F2F7).withOpacity(t * 0.94),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(t * 0.06)
                            : Colors.black.withOpacity(t * 0.04),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _actionBtn(
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        qt,
                        onTap: () {
                          if (widget.onBackToHome != null) {
                            widget.onBackToHome!();
                          } else if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          _selectedDay != null
                              ? "${_selectedDay!['date']['gregorian']['day']} $monthName"
                              : monthName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: qt.textPrimary,
                            letterSpacing: -0.6 + (0.3 * t),
                          ),
                        ),
                      ),
                      _actionBtn(
                        const Icon(Icons.tune_rounded, size: 18),
                        qt,
                        onTap: () {
                          MainNavigation.goToTabStatic(context, 4);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Celebrate particles
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              blastDirection: -pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 35,
              maxBlastForce: 22,
              minBlastForce: 10,
              gravity: 0.15,
              particleDrag: 0.02,
              colors: const [
                Colors.green,
                Colors.teal,
                Colors.amber,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgress(QuranTheme qt, PrayerTracker tracker, Color cardBg,
      List<BoxShadow>? cardShadow, bool isDark) {
    final selectedDate = _selectedDateTime();
    if (selectedDate == null) return const SizedBox.shrink();

    final key = _dateKey(selectedDate);
    final count = tracker.prayedCountForDate(key);
    final allDone = count == 5;
    final isToday = _isSelectedDayToday();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: allDone
            ? (isDark
                ? qt.emeraldDeep.withOpacity(0.12)
                : qt.emeraldDeep.withOpacity(0.06))
            : cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allDone
              ? qt.emeraldDeep.withOpacity(0.3)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04)),
          width: 1,
        ),
        boxShadow: allDone ? null : cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: allDone
                  ? qt.emeraldDeep.withOpacity(0.2)
                  : qt.emeraldDeep.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              allDone ? Icons.check_circle_rounded : Icons.stars_rounded,
              color: qt.emeraldDeep,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? "Today's Focus" : "Day's Progress",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: count / 5,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    valueColor: AlwaysStoppedAnimation<Color>(qt.emeraldDeep),
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
              fontWeight: FontWeight.w600,
              color: qt.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner(QuranTheme qt, WhatsNewService whatsNew) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.emeraldDeep.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: qt.emeraldDeep.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: qt.emeraldDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New! Prayer Notifications',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: qt.emeraldDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap the bell icon → to get reminded when prayer time starts',
                  style: TextStyle(
                    fontSize: 12,
                    color: qt.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              whatsNew.clearBellHighlight();
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: qt.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesCard(
      QuranTheme qt,
      PrayerTracker tracker,
      PrayerNotificationProvider notifProvider,
      Color cardBg,
      List<BoxShadow>? cardShadow,
      bool isDark) {
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
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: cardShadow,
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

          double rowOpacity = 1.0;
          if (isSunrise) {
            rowOpacity = 0.5;
          } else if (isFutureDay) {
            rowOpacity = 0.8;
          } else if (isToday) {
            if (!isCurrent && !isNext) {
              final currentIdx = currentPrayer != null
                  ? prayerOrder.indexOf(currentPrayer)
                  : -1;
              final itemIdx = prayerOrder.indexOf(prayer);
              if (currentIdx != -1 && itemIdx > currentIdx + 1) {
                rowOpacity = 0.85;
              }
            }
          }

          String subText = "";
          if (isSunrise) {
            subText = "Sunrise time";
          } else if (isPrayed) {
            subText = "Completed ✓";
          } else if (isFutureDay) {
            subText = "";
          } else {
            if (!isToday) {
              subText = "Tap to mark as completed";
            } else {
              if (prayerTimePassed) {
                subText = "Tap to mark as completed";
              } else {
                subText = "";
              }
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: isCurrent
                  ? qt.emeraldDeep.withOpacity(0.05)
                  : Colors.transparent,
              border: Border(
                bottom: index == prayerOrder.length - 1
                    ? BorderSide.none
                    : BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.04),
                      ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: rowOpacity,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: isCurrent ? 18 : 14),
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
                                : Colors.transparent,
                            border: Border.all(
                              color: isPrayed
                                  ? Colors.green.withOpacity(0.4)
                                  : isCurrent
                                      ? qt.emeraldDeep.withOpacity(0.5)
                                      : (isDark
                                          ? Colors.white.withOpacity(0.12)
                                          : Colors.black.withOpacity(0.08)),
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
                                    _getPrayerIcon(prayer, filled: isCurrent),
                                    color: isCurrent
                                        ? qt.emeraldDeep
                                        : !canTrack && !isSunrise
                                            ? qt.textMuted.withOpacity(0.5)
                                            : qt.textPrimary.withOpacity(0.7),
                                    size: 16,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                                        ? FontWeight.w600
                                        : FontWeight.bold,
                                    fontSize: 15,
                                    color: isPrayed
                                        ? Colors.green
                                        : qt.textPrimary,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: qt.emeraldDeep,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                if (isNext) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: qt.emeraldDeep.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "UPCOMING",
                                      style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: qt.emeraldDeep,
                                          letterSpacing: 0.5),
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
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  color: isPrayed
                                      ? Colors.green.withOpacity(0.8)
                                      : isCurrent
                                          ? qt.textPrimary.withOpacity(0.6)
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
                              isCurrent ? FontWeight.w600 : FontWeight.bold,
                          fontSize: 13,
                          color: isPrayed
                              ? Colors.green
                              : isCurrent
                                  ? qt.emeraldDeep
                                  : qt.textSecondary,
                        ),
                      ),
                      // Sunrise has no bell — reserve identical space so its
                      // time aligns with the other rows' times.
                      if (isSunrise) const SizedBox(width: 8 + 28),
                      // Notification bell icon for prayer times (not Sunrise)
                      if (!isSunrise) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            // Clear what's new bell highlight on first interaction
                            if (context
                                .read<WhatsNewService>()
                                .shouldShowBellHighlight) {
                              context
                                  .read<WhatsNewService>()
                                  .clearBellHighlight();
                            }
                            final success = await notifProvider.toggle(prayer);
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              if (success &&
                                  notifProvider.successMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          notifProvider.isEnabled(prayer)
                                              ? Icons
                                                  .notifications_active_rounded
                                              : Icons.notifications_off_rounded,
                                          color: Colors.white.withOpacity(0.9),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(notifProvider.successMessage!),
                                      ],
                                    ),
                                    backgroundColor: qt.emeraldDeep,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    duration: const Duration(seconds: 2),
                                    elevation: 6,
                                  ),
                                );
                              } else if (!success &&
                                  notifProvider.errorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child:
                                              Text(notifProvider.errorMessage!),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    duration: const Duration(seconds: 3),
                                    elevation: 6,
                                  ),
                                );
                              }
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: notifProvider.isEnabled(prayer)
                                  ? qt.emeraldDeep.withOpacity(0.12)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: notifProvider.isEnabled(prayer)
                                    ? qt.emeraldDeep.withOpacity(0.3)
                                    : (isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.06)),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              notifProvider.isEnabled(prayer)
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              size: 14,
                              color: notifProvider.isEnabled(prayer)
                                  ? qt.emeraldDeep
                                  : qt.textMuted.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
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

    String effectiveKey = _dateKey(selectedDate);

    // Check if the user is looking at today's calendar item
    final isSelectedDateToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    final timings = _selectedDay?['timings'];

    // Apply post-midnight offset ONLY when editing today's active schedule
    final postMidnightIsha = isSelectedDateToday &&
        prayer == 'Isha' &&
        _isPostMidnightBeforeFajr(timings);

    if (postMidnightIsha) {
      final yesterday = today.subtract(const Duration(days: 1));
      effectiveKey = _dateKey(yesterday);
    }

    final beforeCount = tracker.prayedCountForDate(effectiveKey);

    HapticFeedback.lightImpact();

    tracker.togglePrayerForDate(effectiveKey, prayer).then((_) {
      final afterCount = tracker.prayedCountForDate(effectiveKey);
      if (beforeCount == 4 && afterCount == 5) {
        _triggerCelebration();
        HapticFeedback.mediumImpact();
      }
    });
  }

  Widget _statsSectionHeader(QuranTheme qt, PrayerTracker tracker) {
    final totalPossible = tracker.totalPrayersLogged + tracker.totalMissed;
    final overallRate = totalPossible > 0
        ? ((tracker.totalPrayersLogged / totalPossible) * 100).round()
        : 0;

    return GestureDetector(
      onTap: () {
        MainNavigation.pushOnShell(context, const PrayerStatsScreen());
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSectionTitle("Prayer Stats", qt),
          Row(
            children: [
              if (totalPossible > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: overallRate >= 80
                        ? qt.emeraldDeep.withOpacity(0.1)
                        : overallRate >= 50
                            ? Colors.amber.withOpacity(0.1)
                            : const Color(0xFFEF6461).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$overallRate%",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: overallRate >= 80
                          ? qt.emeraldDeep
                          : overallRate >= 50
                              ? Colors.amber
                              : const Color(0xFFEF6461),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: qt.textMuted.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummaryCard(QuranTheme qt, PrayerTracker tracker,
      Color cardBg, List<BoxShadow>? cardShadow, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryMetric(
              value: tracker.totalPrayersLogged.toString(),
              label: "Completed",
              color: qt.emeraldDeep,
              qt: qt,
            ),
          ),
          _summaryDivider(qt, isDark),
          Expanded(
            child: _summaryMetric(
              value: tracker.totalMissed.toString(),
              label: "Missed",
              color: const Color(0xFFEF6461).withOpacity(0.9),
              qt: qt,
            ),
          ),
          _summaryDivider(qt, isDark),
          Expanded(
            child: _summaryMetric(
              value: "${tracker.currentStreak}",
              label: "Day Streak",
              color: Colors.amber,
              qt: qt,
              sub:
                  tracker.bestStreak > 0 ? "Best: ${tracker.bestStreak}" : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required String value,
    required String label,
    required Color color,
    required QuranTheme qt,
    String? sub,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: qt.textMuted,
          ),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub,
              style: TextStyle(
                fontSize: 9.5,
                color: qt.textMuted.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryDivider(QuranTheme qt, bool isDark) {
    return Container(
      width: 1,
      height: 36,
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
    );
  }

  Widget _buildCalendarCard(QuranTheme qt, PrayerTracker tracker, Color cardBg,
      List<BoxShadow>? cardShadow, bool isDark) {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: cardShadow,
      ),
      child: Column(
        children: [
          if (englishMonth.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _prevMonth,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.chevron_left_rounded,
                              color: qt.emeraldDeep, size: 16),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        englishMonth,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: qt.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _nextMonth,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.chevron_right_rounded,
                              color: qt.emeraldDeep, size: 16),
                        ),
                      ),
                    ],
                  ),
                  if (hijriDateString.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hijriDateString,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: qt.emeraldDeep,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (englishMonth.isNotEmpty)
            Divider(
              color: isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04),
              height: 1,
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendDot(qt.emeraldDeep, "All Done", qt),
                _legendDot(Colors.amber, "Partial", qt),
                _legendDot(const Color(0xFFEF6461), "Missed", qt),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                    child: Center(
                        child: Text(d,
                            style: TextStyle(
                                color: qt.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 11)))))
                .toList(),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_parsedCalendarDays != null)
            _buildCalendarGrid(qt, tracker, isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(QuranTheme qt, PrayerTracker tracker, bool isDark) {
    if (_parsedCalendarDays == null || _parsedCalendarDays!.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstDay = _parsedCalendarDays!.first.dateTime;
    int paddingDays = firstDay.weekday == 7 ? 0 : firstDay.weekday;

    final daysInMonth = _parsedCalendarDays!.length;
    final totalItems = paddingDays + daysInMonth;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

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
        final parsedDay = _parsedCalendarDays![index - paddingDays];
        final isSelected = _selectedDay == parsedDay.rawData;

        final isToday = parsedDay.dateTime.year == todayDateOnly.year &&
            parsedDay.dateTime.month == todayDateOnly.month &&
            parsedDay.dateTime.day == todayDateOnly.day;

        final prayedCount = tracker.prayedCountForDate(parsedDay.dateKey);
        final allDone = prayedCount == 5;
        final someDone = prayedCount > 0 && prayedCount < 5;

        Color? statusColor;
        if (allDone) {
          statusColor = qt.emeraldDeep;
        } else if (someDone) {
          statusColor = Colors.amber;
        } else if (parsedDay.dateTime.isBefore(todayDateOnly)) {
          statusColor = const Color(0xFFEF6461);
        }

        currentRow.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDay = parsedDay.rawData);
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? qt.emeraldDeep.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? qt.emeraldDeep.withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dates displayed cleanly in center of cell
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            parsedDay.gregorianDay,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color:
                                  isSelected ? qt.emeraldDeep : qt.textPrimary,
                            ),
                          ),
                          Text(
                            parsedDay.hijriDay,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? qt.emeraldDeep.withOpacity(0.8)
                                  : qt.textMuted.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      // Elegantly placed indicator dots at the top right of cell to prevent visual clutter
                      if (statusColor != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      // High-end minimalist line underline for current active day
                      if (isToday)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 12,
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: qt.emeraldDeep,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
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

  Widget _buildSectionTitle(String title, QuranTheme qt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: qt.emeraldDeep,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: qt.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, QuranTheme qt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: qt.textPrimary.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showLocationBottomSheet(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF141416) : const Color(0xFFFFFFFF),
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
              top: 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.62,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                setModalState(() => searchQuery = val),
                            style:
                                TextStyle(color: qt.textPrimary, fontSize: 14),
                            cursorColor: qt.emeraldDeep,
                            decoration: InputDecoration(
                              hintText: "Search city...",
                              hintStyle: TextStyle(
                                color: qt.textMuted.withOpacity(0.7),
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: qt.textMuted.withOpacity(0.6),
                                  size: 18),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          await PrayerService.instance.fetchDeviceLocation();
                          await _fetchCalendar();
                        },
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.my_location_rounded,
                              color: qt.emeraldDeep, size: 20),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount:
                          filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.04),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.public_rounded,
                                color: qt.emeraldDeep, size: 20),
                            title: Text(
                              'Custom search: "$searchQuery"',
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
                              color: qt.textMuted.withOpacity(0.6), size: 18),
                          title: Text(
                            loc['city']!,
                            style: TextStyle(
                              color: qt.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            loc['country']!,
                            style: TextStyle(
                              color: qt.textMuted.withOpacity(0.8),
                              fontSize: 11,
                            ),
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

  Widget _actionBtn(Widget child, QuranTheme qt, {VoidCallback? onTap}) {
    final bool isDark = qt.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Center(
          child: IconTheme(
            data: IconThemeData(
              color: isDark ? Colors.white.withOpacity(0.9) : qt.emeraldDeep,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
