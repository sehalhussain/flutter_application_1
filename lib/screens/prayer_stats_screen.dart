import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/prayer_tracker_provider.dart';
import '../constants/quran_theme.dart';

class PrayerStatsScreen extends StatefulWidget {
  const PrayerStatsScreen({super.key});

  @override
  State<PrayerStatsScreen> createState() => _PrayerStatsScreenState();
}

class _PrayerStatsScreenState extends State<PrayerStatsScreen>
    with SingleTickerProviderStateMixin {
  DateTime _displayDate = DateTime.now();
  int _weekOffset = 0;
  TabController? _tabController;

  TabController get _tabs =>
      _tabController ??= TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _prevMonth() {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_displayDate.year, _displayDate.month + 1, 1);
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    setState(() {
      _displayDate = next;
    });
  }

  void _prevWeek() {
    setState(() => _weekOffset--);
  }

  void _nextWeek() {
    if (_weekOffset < 0) {
      setState(() => _weekOffset++);
    }
  }

  List<Map<String, dynamic>> _getWeekDays(PrayerTracker tracker) {
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final startDate = currentMonday.add(Duration(days: _weekOffset * 7));
    return List.generate(7, (i) {
      final date = startDate.add(Duration(days: i));
      final key = _dateKey(date);
      final count = tracker.prayedCountForDate(key);
      return {
        'date': date,
        'count': count,
        'isToday': date.year == now.year &&
            date.month == now.month &&
            date.day == now.day,
        'isFuture': date.isAfter(DateTime(now.year, now.month, now.day)),
      };
    });
  }

  List<Map<String, dynamic>> _getFullMonthDays(PrayerTracker tracker) {
    final daysInMonth =
        DateTime(_displayDate.year, _displayDate.month + 1, 0).day;
    final days = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_displayDate.year, _displayDate.month, d);
      final key = _dateKey(date);
      final count = tracker.prayedCountForDate(key);
      days.add({
        'date': date,
        'day': d,
        'count': count,
        'key': key,
        'hasData': tracker.prayersForDate(key).isNotEmpty,
        'isFuture': date.isAfter(DateTime(now.year, now.month, now.day)),
      });
    }
    return days;
  }

  Map<String, double> _accuratePrayerRates(PrayerTracker tracker) {
    final prayers = tracker.prayerNames;
    final rates = <String, double>{};
    final allLoggedDays = <String>{};
    for (final key in tracker.sortedDateKeys) {
      final dayData = tracker.prayersForDate(key);
      if (dayData.isNotEmpty) {
        allLoggedDays.add(key);
      }
    }
    final totalDays = allLoggedDays.length;
    if (totalDays == 0) {
      for (final p in prayers) {
        rates[p] = 0.0;
      }
      return rates;
    }
    for (final prayer in prayers) {
      int prayed = 0;
      for (final key in allLoggedDays) {
        final dayData = tracker.prayersForDate(key);
        if (dayData[prayer] == true) {
          prayed++;
        }
      }
      rates[prayer] = prayed / totalDays;
    }
    return rates;
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final tracker = context.watch<PrayerTracker>();
    final monthName = DateFormat('MMMM').format(_displayDate);
    final yearNum = _displayDate.year.toString();
    final weekDays = _getWeekDays(tracker);
    final monthDays = _getFullMonthDays(tracker);
    final accurateRates = _accuratePrayerRates(tracker);

    int complete = 0;
    int totalPrayedMonth = 0;
    for (final day in monthDays) {
      final count = day['count'] as int;
      totalPrayedMonth += count;
      if (count == 5) {
        complete++;
      }
    }
    final totalDays = monthDays.length;
    final monthlyRate = totalDays > 0 ? complete / totalDays : 0.0;

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        title: Text(
          "Prayer Journey",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: qt.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: qt.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: qt.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          _buildMonthPeriodSelector(qt, monthName, yearNum),
          _buildCalmTabPill(qt),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                /* Tab 1: Short Term Weekly Focus */
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLifetimeHeroSection(qt, tracker),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Weekly Devotion", qt),
                      _buildSectionSubtitle(
                          "Track your weekly daily rhythm. Swipe or tap arrows to navigate.",
                          qt),
                      const SizedBox(height: 14),
                      _buildWeeklyChart(qt, weekDays),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Prayer Consistency", qt),
                      _buildSectionSubtitle(
                          "Your individual prayer completion frequency across all logged days.",
                          qt),
                      const SizedBox(height: 14),
                      _buildPrayerBreakdown(qt, tracker, accurateRates),
                    ],
                  ),
                ),
                /* Tab 2: Long Term Monthly Review */
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthlyDevotionSummaryCard(qt, monthName, complete,
                          totalDays, monthlyRate, totalPrayedMonth),
                      const SizedBox(height: 24),
                      _buildSectionTitle("$monthName Calendar", qt),
                      _buildSectionSubtitle(
                          "A comprehensive look at your monthly submission progress.",
                          qt),
                      const SizedBox(height: 14),
                      _buildGregorianCalendarGrid(
                          qt, tracker, monthDays, monthName, yearNum),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Monthly Progression", qt),
                      _buildSectionSubtitle(
                          "Perfect completion metrics captured over the last 6 months.",
                          qt),
                      const SizedBox(height: 14),
                      _buildMonthlyTrend(qt, tracker),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Milestones & Badges", qt),
                      _buildSectionSubtitle(
                          "Honorable seals representing active devotion on your path.",
                          qt),
                      const SizedBox(height: 14),
                      _buildMilestones(qt, tracker),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPeriodSelector(
      QuranTheme qt, String monthName, String yearNum) {
    final now = DateTime.now();
    final canGoNext =
        !(_displayDate.year == now.year && _displayDate.month == now.month);
    final isDark = qt.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _prevMonth,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : qt.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: qt.textPrimary, size: 16),
            ),
          ),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  color: qt.emeraldLight, size: 16),
              const SizedBox(width: 8),
              Text(
                "$monthName $yearNum",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary,
                    letterSpacing: -0.2),
              ),
            ],
          ),
          GestureDetector(
            onTap: canGoNext ? _nextMonth : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: canGoNext
                    ? (isDark ? Colors.white.withValues(alpha: 0.06) : qt.bg)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: canGoNext
                    ? qt.textPrimary
                    : qt.textMuted.withValues(alpha: 0.2),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalmTabPill(QuranTheme qt) {
    final isDark = qt.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : qt.cardBg,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
      ),
      child: TabBar(
        controller: _tabs,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: qt.textMuted,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [qt.emeraldMid, qt.emeraldDeep],
          ),
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on_rounded, size: 15),
                SizedBox(width: 6),
                Text("Weekly Focus",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.brightness_3_rounded, size: 15),
                SizedBox(width: 6),
                Text("Monthly Review",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyDevotionSummaryCard(QuranTheme qt, String monthName,
      int complete, int totalDays, double rate, int totalPrayed) {
    final isDark = qt.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [qt.cardBg, qt.bg]
              : [qt.emeraldMid, qt.emeraldDeep, const Color(0xFF031E17)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? qt.borderGlass.withValues(alpha: 0.5)
                : Colors.transparent),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: qt.emeraldDeep.withValues(alpha: 0.12),
                blurRadius: 15,
                offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child:
                    Icon(Icons.spa_rounded, color: qt.emeraldLight, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$monthName Summary",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? qt.textPrimary : Colors.white,
                    ),
                  ),
                  Text(
                    "Your monthly spiritual growth",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? qt.textMuted
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _summarySmallCard(
                  complete.toString(),
                  "Perfect Days",
                  isDark ? qt.textPrimary : Colors.white,
                  isDark ? qt.textMuted : Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              _summarySmallCard(
                  "${(rate * 100).toInt()}%",
                  "Devotion Rate",
                  isDark ? qt.textPrimary : Colors.white,
                  isDark ? qt.textMuted : Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              _summarySmallCard(
                  totalPrayed.toString(),
                  "Total Prayers",
                  isDark ? qt.textPrimary : Colors.white,
                  isDark ? qt.textMuted : Colors.white.withValues(alpha: 0.7)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Overall Monthly Devotion",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? qt.textPrimary
                        : Colors.white.withValues(alpha: 0.8)),
              ),
              Text(
                "${(rate * 100).round()}%",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? qt.emeraldLight : qt.emeraldLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                rate >= 0.8
                    ? qt.emeraldLight
                    : (rate >= 0.5 ? Colors.orangeAccent : Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySmallCard(
      String value, String label, Color vColor, Color lColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: vColor, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: lColor, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
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
                color: qt.emeraldDeep, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary,
                letterSpacing: -0.2)),
      ],
    );
  }

  Widget _buildSectionSubtitle(String subtitle, QuranTheme qt) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Text(subtitle,
          style: TextStyle(
              fontSize: 12,
              color: qt.textMuted,
              fontWeight: FontWeight.w400,
              height: 1.3)),
    );
  }

  Widget _buildLifetimeHeroSection(QuranTheme qt, PrayerTracker tracker) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.nature_people_rounded,
                  color: qt.emeraldLight, size: 17),
              const SizedBox(width: 6),
              Text(
                "Salah Record & Streak",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary,
                    letterSpacing: -0.1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _heroTile(
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.orange,
                    value: "${tracker.currentStreak}",
                    label: "Current Streak",
                    qt: qt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroTile(
                    icon: Icons.emoji_events_rounded,
                    color: Colors.amber,
                    value: "${tracker.bestStreak}",
                    label: "Best Streak",
                    qt: qt),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _heroTile(
                    icon: Icons.calendar_month_rounded,
                    color: Colors.teal,
                    value:
                        "${(tracker.monthlyCompletionRate(DateTime.now().year, DateTime.now().month) * 100).toInt()}%",
                    label: "This Month",
                    qt: qt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroTile(
                    icon: Icons.mosque_rounded,
                    color: const Color(0xFF0284C7),
                    value: "${tracker.totalPrayersLogged}",
                    label: "Total Prayers",
                    qt: qt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required QuranTheme qt,
  }) {
    final isDark = qt.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : qt.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: qt.textPrimary),
                ),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 10,
                      color: qt.textMuted,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(QuranTheme qt, List<Map<String, dynamic>> days) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _prevWeek,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: qt.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: qt.emeraldLight, size: 13),
                ),
              ),
              Text(
                _weekOffset == 0 ? "This Week" : _getWeekLabel(days),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary),
              ),
              GestureDetector(
                onTap: _weekOffset < 0 ? _nextWeek : null,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _weekOffset < 0 ? qt.bg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _weekOffset < 0
                        ? qt.emeraldLight
                        : qt.textMuted.withValues(alpha: 0.15),
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: days.map((day) {
                final count = day['count'] as int;
                final date = day['date'] as DateTime;
                final isToday = day['isToday'] as bool;
                final isFuture = day['isFuture'] as bool;
                final barH = count == 0 ? 4.0 : max(8.0, (count / 5) * 75);

                Color barColor;
                if (isFuture) {
                  barColor = qt.borderGlass.withValues(alpha: 0.1);
                } else if (count == 5) {
                  barColor = const Color(0xFF10B981);
                } else if (count >= 3) {
                  barColor = qt.emeraldLight;
                } else if (count > 0) {
                  barColor = Colors.orangeAccent;
                } else {
                  barColor = qt.borderGlass.withValues(alpha: 0.25);
                }

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isFuture)
                        Text(
                          "$count",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: count == 5
                                  ? const Color(0xFF10B981)
                                  : qt.textSecondary),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        width: 14,
                        height: barH,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                          border: isToday
                              ? Border.all(color: qt.emeraldDeep, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('E').format(date).substring(0, 1),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday ? qt.emeraldLight : qt.textMuted),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF10B981), "5 Done", qt),
              const SizedBox(width: 10),
              _legendDot(qt.emeraldLight, "3-4", qt),
              const SizedBox(width: 10),
              _legendDot(Colors.orangeAccent, "1-2", qt),
              const SizedBox(width: 10),
              _legendDot(qt.borderGlass.withValues(alpha: 0.25), "0", qt),
            ],
          ),
        ],
      ),
    );
  }

  String _getWeekLabel(List<Map<String, dynamic>> weekDays) {
    if (weekDays.isEmpty) return "This Week";
    final first = weekDays.first['date'] as DateTime;
    final last = weekDays.last['date'] as DateTime;
    final fmt = DateFormat('MMM d');
    if (first.month == last.month && first.year == last.year) {
      return "${fmt.format(first)} - ${last.day}";
    }
    return "${fmt.format(first)} - ${fmt.format(last)}";
  }

  Widget _legendDot(Color color, String label, QuranTheme qt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: qt.textMuted)),
      ],
    );
  }

  Widget _buildPrayerBreakdown(
      QuranTheme qt, PrayerTracker tracker, Map<String, double> rates) {
    final prayers = tracker.prayerNames;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: prayers.map((prayer) {
          final rate = rates[prayer] ?? 0.0;
          final pct = (rate * 100).toInt();

          Color focusColor;
          if (pct >= 80) {
            focusColor = const Color(0xFF10B981);
          } else if (pct >= 50) {
            focusColor = Colors.orangeAccent;
          } else {
            focusColor = Colors.redAccent;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: focusColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          prayer,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: qt.textPrimary),
                        ),
                      ],
                    ),
                    Text(
                      "$pct%",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: focusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
                    backgroundColor: qt.borderGlass.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(focusColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGregorianCalendarGrid(QuranTheme qt, PrayerTracker tracker,
      List<Map<String, dynamic>> monthDays, String monthName, String yearNum) {
    final now = DateTime.now();

    if (monthDays.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text("No records available",
            style: TextStyle(color: qt.textMuted, fontSize: 13)),
      );
    }

    final firstDay = monthDays.first['date'] as DateTime;
    int paddingDays = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final gridItems = <Map<String, dynamic>?>[];
    for (int i = 0; i < paddingDays; i++) {
      gridItems.add(null);
    }
    for (final d in monthDays) {
      gridItems.add(d);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                        child: Center(
                            child: Text(
                      d,
                      style: TextStyle(
                          color: qt.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ))))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            (gridItems.length / 7).ceil(),
            (rowIdx) {
              final rowChildren = <Widget>[];
              for (int col = 0; col < 7; col++) {
                final idx = rowIdx * 7 + col;
                if (idx < gridItems.length) {
                  final day = gridItems[idx];
                  if (day == null) {
                    rowChildren.add(const Expanded(child: SizedBox()));
                  } else {
                    final date = day['date'] as DateTime;
                    final count = day['count'] as int;
                    final isToday = date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;

                    Color? bg;
                    if (count == 5) {
                      bg = const Color(0xFFD1FAE5);
                    } else if (count > 0 && count < 5) {
                      bg = const Color(0xFFFEF3C7);
                    } else if (day['hasData'] as bool) {
                      bg = const Color(0xFFFEE2E2);
                    } else if (!(day['isFuture'] as bool)) {
                      bg = qt.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF3F4F6);
                    }

                    rowChildren.add(
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(1.5),
                          height: 32,
                          decoration: BoxDecoration(
                            color: bg ?? Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isToday
                                ? Border.all(color: qt.emeraldDeep, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              "${date.day}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isToday
                                    ? qt.emeraldLight
                                    : bg != null
                                        ? Colors.black87
                                        : qt.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                } else {
                  rowChildren.add(const Expanded(child: SizedBox()));
                }
              }
              return Row(children: rowChildren);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrend(QuranTheme qt, PrayerTracker tracker) {
    final trend = tracker.getMonthlyTrend(6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: trend.map((data) {
                final rate = data['rate'] as double;
                final h = rate == 0.0 ? 4.0 : max(4.0, rate * 85);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [qt.emeraldDeep, qt.emeraldLight],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['month'] as String,
                      style: TextStyle(
                          fontSize: 10,
                          color: qt.textMuted,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      "${(rate * 100).toInt()}%",
                      style: TextStyle(
                          fontSize: 9,
                          color: qt.textSecondary,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestones(QuranTheme qt, PrayerTracker tracker) {
    final list = [
      _Milestone('first_prayer', Icons.favorite_rounded, "First Step",
          "Log your first prayer", Colors.pink),
      _Milestone('streak_7', Icons.local_fire_department_rounded, "On Fire",
          "7-day streak", Colors.orange),
      _Milestone('perfect_week', Icons.star_rounded, "Perfect Week",
          "All prayers for 7 days", Colors.amber),
      _Milestone('streak_30', Icons.nightlight_round, "Ramadan Ready",
          "30-day streak", Colors.indigo),
      _Milestone('centurion', Icons.military_tech_rounded, "Centurion",
          "100 prayers logged", Colors.teal),
      _Milestone('year_of_light', Icons.emoji_events_rounded, "Year of Light",
          "365 consecutive days", Colors.purple),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, idx) {
        final m = list[idx];
        final achieved = tracker.hasMilestone(m.id);
        final isDark = qt.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: achieved
                ? m.color.withValues(alpha: isDark ? 0.08 : 0.05)
                : qt.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: achieved
                  ? m.color.withValues(alpha: 0.3)
                  : qt.borderGlass.withValues(alpha: 0.4),
              width: achieved ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(m.icon,
                      color: achieved
                          ? m.color
                          : qt.textMuted.withValues(alpha: 0.3),
                      size: 22),
                  if (achieved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Active",
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: m.color)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                m.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: achieved ? qt.textPrimary : qt.textMuted),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  m.description,
                  style: TextStyle(
                      fontSize: 10,
                      color: achieved
                          ? qt.textSecondary
                          : qt.textMuted.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Milestone {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  _Milestone(this.id, this.icon, this.title, this.description, this.color);
}
