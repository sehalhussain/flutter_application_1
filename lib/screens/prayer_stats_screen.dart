import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/prayer_tracker_provider.dart';
import '../constants/quran_theme.dart';
import '../main.dart';

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

  // ── Helpers ──────────────────────────────────────────────────────────

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _missedColor = Color(0xFFEF6461);

  // ── Computed Stats (from first logged prayer) ────────────────────────

  DateTime? _firstLoggedDate(PrayerTracker t) {
    final keys = t.sortedDateKeys;
    return keys.isEmpty ? null : DateTime.parse(keys.last);
  }

  int _totalTrackingDays(PrayerTracker t) {
    final first = _firstLoggedDate(t);
    if (first == null) return 0;
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final f = DateTime(first.year, first.month, first.day);
    return today.difference(f).inDays + 1;
  }

  Map<String, Map<String, int>> _prayerStats(PrayerTracker t) {
    final totalDays = _totalTrackingDays(t);
    final result = <String, Map<String, int>>{};
    for (final prayer in t.prayerNames) {
      int prayed = 0;
      for (final key in t.sortedDateKeys) {
        if (t.prayersForDate(key)[prayer] == true) prayed++;
      }
      result[prayer] = {
        'prayed': prayed,
        'missed': totalDays - prayed,
        'total': totalDays,
      };
    }
    return result;
  }

  // ── Navigation ───────────────────────────────────────────────────────

  void _prevMonth() => setState(() =>
      _displayDate = DateTime(_displayDate.year, _displayDate.month - 1, 1));

  void _nextMonth() {
    final now = DateTime.now();
    if (_displayDate.isBefore(DateTime(now.year, now.month, 1))) {
      setState(() => _displayDate =
          DateTime(_displayDate.year, _displayDate.month + 1, 1));
    }
  }

  void _prevWeek() => setState(() => _weekOffset--);
  void _nextWeek() {
    if (_weekOffset < 0) setState(() => _weekOffset++);
  }

  // ── Data Helpers ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _weekDays(PrayerTracker t) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = monday.add(Duration(days: _weekOffset * 7));
    return List.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return {
        'date': d,
        'count': t.prayedCountForDate(_dateKey(d)),
        'isToday':
            d.year == now.year && d.month == now.month && d.day == now.day,
        'isFuture': d.isAfter(DateTime(now.year, now.month, now.day)),
      };
    });
  }

  List<Map<String, dynamic>> _monthDays(PrayerTracker t) {
    final dim = DateTime(_displayDate.year, _displayDate.month + 1, 0).day;
    final now = DateTime.now();
    return List.generate(dim, (i) {
      final d = DateTime(_displayDate.year, _displayDate.month, i + 1);
      return {
        'date': d,
        'count': t.prayedCountForDate(_dateKey(d)),
        'isFuture': d.isAfter(DateTime(now.year, now.month, now.day)),
      };
    });
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final tracker = context.watch<PrayerTracker>();
    final hasData = tracker.sortedDateKeys.isNotEmpty;

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        title: Text(
          "Prayer Stats",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: qt.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: qt.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: qt.textPrimary, size: 20),
          onPressed: () {
            if (!MainNavigation.popShell(context)) Navigator.maybePop(context);
          },
        ),
      ),
      body: !hasData
          ? _emptyState(qt)
          : Column(
              children: [
                _tabBar(qt),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _overviewTab(qt, tracker),
                      _calendarTab(qt, tracker),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _emptyState(QuranTheme qt) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mosque_rounded,
                size: 48, color: qt.textMuted.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text("No prayers logged yet",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: qt.textSecondary)),
            const SizedBox(height: 6),
            Text("Start tracking your daily prayers\nto see stats here.",
                style: TextStyle(fontSize: 13, color: qt.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      );

  // ── Tab Bar ──────────────────────────────────────────────────────────

  Widget _tabBar(QuranTheme qt) {
    final dark = qt.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 42,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.05) : qt.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabs,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: qt.textMuted,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(colors: [qt.emeraldMid, qt.emeraldDeep]),
        ),
        tabs: const [
          Tab(
              child: Text("Overview",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Tab(
              child: Text("Calendar",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  OVERVIEW TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _overviewTab(QuranTheme qt, PrayerTracker t) {
    final stats = _prayerStats(t);
    final totalPrayed = stats.values.fold<int>(0, (s, v) => s + v['prayed']!);
    final totalMissed = stats.values.fold<int>(0, (s, v) => s + v['missed']!);
    final totalDays = _totalTrackingDays(t);
    final first = _firstLoggedDate(t);
    final week = _weekDays(t);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (first != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 14, color: qt.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text(
                    "Tracking since ${DateFormat('MMM d, yyyy').format(first)}  ·  $totalDays days",
                    style: TextStyle(
                        fontSize: 12,
                        color: qt.textMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // Passes the Provider directly to the Hero Card
          _heroCard(qt, totalPrayed, totalMissed, t),
          const SizedBox(height: 28),

          _sectionTitle("Prayer Consistency", qt),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 2, bottom: 12),
            child: Text(
              "Per-prayer completion from your first logged day.",
              style: TextStyle(fontSize: 12, color: qt.textMuted),
            ),
          ),
          _consistencyCard(qt, stats),
          const SizedBox(height: 28),

          _sectionTitle("This Week", qt),
          const SizedBox(height: 12),
          _weekChart(qt, week),
        ],
      ),
    );
  }

  // ── Hero Card ────────────────────────────────────────────────────────

  Widget _heroCard(QuranTheme qt, int prayed, int missed, PrayerTracker t) {
    final dark = qt.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.15 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _metricCol(
              value: prayed.toString(),
              label: "Prayed",
              color: qt.emeraldLight,
              qt: qt,
            ),
          ),
          _vDiv(qt),
          Expanded(
            child: _metricCol(
              value: missed.toString(),
              label: "Missed",
              color: _missedColor,
              qt: qt,
            ),
          ),
          _vDiv(qt),
          Expanded(
            child: _metricCol(
              value: "${t.currentStreak}",
              label: "Day Streak",
              color: Colors.amber,
              qt: qt,
              sub: "Best: ${t.bestStreak}",
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCol({
    required String value,
    required String label,
    required Color color,
    required QuranTheme qt,
    String? sub,
  }) =>
      Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: qt.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                sub,
                style: TextStyle(
                    fontSize: 10, color: qt.textMuted.withValues(alpha: 0.6)),
              ),
            ),
        ],
      );

  Widget _vDiv(QuranTheme qt) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
            width: 1,
            height: 48,
            color: qt.borderGlass.withValues(alpha: 0.35)),
      );

  // ── Consistency Card ─────────────────────────────────────────────────

  Widget _consistencyCard(QuranTheme qt, Map<String, Map<String, int>> stats) {
    final dark = qt.brightness == Brightness.dark;
    final lastIdx = stats.keys.length - 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.1 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: stats.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final prayer = e.key;
          final prayed = e.value['prayed']!;
          final missed = e.value['missed']!;
          final total = e.value['total']!;
          final rate = total > 0 ? prayed / total : 0.0;
          final pct = (rate * 100).toInt();
          final clr = pct >= 80
              ? qt.emeraldLight
              : pct >= 50
                  ? Colors.amber
                  : _missedColor;

          return Padding(
            padding: EdgeInsets.only(bottom: i < lastIdx ? 18 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(prayer,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: qt.textPrimary)),
                    Text("$pct%",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: clr)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 5,
                    backgroundColor: qt.borderGlass.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(clr),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text("$prayed of $total prayed",
                        style: TextStyle(fontSize: 11, color: qt.textMuted)),
                    const Spacer(),
                    Text("$missed missed",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                missed > 0 ? FontWeight.w600 : FontWeight.w400,
                            color: missed > 0 ? _missedColor : qt.textMuted)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Weekly Chart ─────────────────────────────────────────────────────

  Widget _weekChart(QuranTheme qt, List<Map<String, dynamic>> days) {
    final dark = qt.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.1 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.arrow_back_ios_new_rounded, _prevWeek, qt),
              Text(
                _weekOffset == 0 ? "This Week" : _weekLabel(days),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: qt.textPrimary),
              ),
              _navBtn(Icons.arrow_forward_ios_rounded,
                  _weekOffset < 0 ? _nextWeek : null, qt),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: days.map((d) {
                final count = d['count'] as int;
                final date = d['date'] as DateTime;
                final isToday = d['isToday'] as bool;
                final isFuture = d['isFuture'] as bool;
                final h = count == 0 ? 4.0 : max(8.0, (count / 5) * 68);

                final clr = isFuture
                    ? qt.borderGlass.withValues(alpha: 0.08)
                    : count == 5
                        ? const Color(0xFF10B981)
                        : count >= 3
                            ? qt.emeraldLight
                            : count > 0
                                ? Colors.amber
                                : isToday
                                    ? qt.emeraldLight.withValues(alpha: 0.3)
                                    : qt.borderGlass.withValues(alpha: 0.2);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isFuture)
                        Text(
                          "$count",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: count == 5
                                ? const Color(0xFF10B981)
                                : qt.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        width: 16,
                        height: h,
                        decoration: BoxDecoration(
                          color: clr,
                          borderRadius: BorderRadius.circular(5),
                          border: isToday
                              ? Border.all(color: qt.emeraldDeep, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('E').format(date).substring(0, 2),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? qt.emeraldLight : qt.textMuted,
                        ),
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
              _legendDot(const Color(0xFF10B981), "5/5", qt),
              const SizedBox(width: 14),
              _legendDot(qt.emeraldLight, "3–4", qt),
              const SizedBox(width: 14),
              _legendDot(Colors.amber, "1–2", qt),
              const SizedBox(width: 14),
              _legendDot(qt.borderGlass.withValues(alpha: 0.2), "0", qt),
            ],
          ),
        ],
      ),
    );
  }

  String _weekLabel(List<Map<String, dynamic>> w) {
    if (w.isEmpty) return "This Week";
    final f = DateFormat('MMM d');
    final a = w.first['date'] as DateTime;
    final b = w.last['date'] as DateTime;
    return a.month == b.month && a.year == b.year
        ? "${f.format(a)} – ${b.day}"
        : "${f.format(a)} – ${f.format(b)}";
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CALENDAR TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _calendarTab(QuranTheme qt, PrayerTracker t) {
    final monthName = DateFormat('MMMM').format(_displayDate);
    final year = _displayDate.year.toString();
    final days = _monthDays(t);
    final now = DateTime.now();
    final isCurrMonth =
        _displayDate.year == now.year && _displayDate.month == now.month;
    final elapsed = isCurrMonth ? now.day : days.length;

    int perfect = 0, totalPrayed = 0;
    for (final d in days) {
      final c = d['count'] as int;
      totalPrayed += c;
      if (c == 5) perfect++;
    }
    final rate =
        elapsed > 0 ? (totalPrayed / (elapsed * 5)).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _monthSelector(qt, monthName, year),
          const SizedBox(height: 18),
          _monthStatsRow(qt, perfect, totalPrayed, rate, elapsed),
          const SizedBox(height: 24),
          _sectionTitle("$monthName Calendar", qt),
          const SizedBox(height: 12),
          _calendarGrid(qt, days, t),
          const SizedBox(height: 10),
          _calLegend(qt),
          const SizedBox(height: 28),
          _sectionTitle("Monthly Trend", qt),
          const SizedBox(height: 12),
          _monthlyTrend(qt, t),
          const SizedBox(height: 28),
          _sectionTitle("Milestones", qt),
          const SizedBox(height: 12),
          _milestones(qt, t),
        ],
      ),
    );
  }

  // ── Month Selector ───────────────────────────────────────────────────

  Widget _monthSelector(QuranTheme qt, String month, String year) {
    final now = DateTime.now();
    final canNext =
        !(_displayDate.year == now.year && _displayDate.month == now.month);
    final dark = qt.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navBtn(Icons.arrow_back_ios_new_rounded, _prevMonth, qt),
          Text("$month $year",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: qt.textPrimary,
                  letterSpacing: -0.2)),
          _navBtn(
              Icons.arrow_forward_ios_rounded, canNext ? _nextMonth : null, qt),
        ],
      ),
    );
  }

  // ── Month Stats Row ──────────────────────────────────────────────────

  Widget _monthStatsRow(
      QuranTheme qt, int perfect, int totalPrayed, double rate, int elapsed) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: qt.brightness == Brightness.dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(
        children: [
          Expanded(child: _miniStat("$perfect", "Perfect Days", qt)),
          _vDiv(qt),
          Expanded(child: _miniStat("$totalPrayed", "Prayed", qt)),
          _vDiv(qt),
          Expanded(
              child: _miniStat("${(rate * 100).toInt()}%", "Completion", qt)),
        ],
      ),
    );
  }

  Widget _miniStat(String val, String label, QuranTheme qt) => Column(
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: qt.textPrimary,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: qt.textMuted)),
        ],
      );

  // ── Calendar Grid ────────────────────────────────────────────────────

  Widget _calendarGrid(
      QuranTheme qt, List<Map<String, dynamic>> days, PrayerTracker t) {
    final dark = qt.brightness == Brightness.dark;
    final now = DateTime.now();
    if (days.isEmpty) return const SizedBox();

    final firstDay = days.first['date'] as DateTime;
    final pad = firstDay.weekday == 7 ? 0 : firstDay.weekday;
    final items = <Map<String, dynamic>?>[...List.filled(pad, null), ...days];
    final firstLogged = _firstLoggedDate(t);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                color: qt.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.5)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          ...List.generate((items.length / 7).ceil(), (r) {
            final row = <Widget>[];
            for (int c = 0; c < 7; c++) {
              final idx = r * 7 + c;
              if (idx < items.length && items[idx] != null) {
                final d = items[idx]!;
                final date = d['date'] as DateTime;
                final count = d['count'] as int;
                final isFuture = d['isFuture'] as bool;
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

                final isBeforeTracking = firstLogged != null &&
                    date.isBefore(DateTime(
                        firstLogged.year, firstLogged.month, firstLogged.day));

                Color? bg;
                if (!isFuture && !isBeforeTracking) {
                  if (count == 5) {
                    bg = const Color(0xFFD1FAE5);
                  } else if (count > 0) {
                    bg = const Color(0xFFFEF3C7);
                  } else {
                    bg = const Color(0xFFFEE2E2);
                  }
                }

                row.add(
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      height: 36,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: qt.emeraldDeep, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          "${date.day}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isToday
                                ? qt.emeraldDeep
                                : bg != null
                                    ? Colors.black87
                                    : isBeforeTracking
                                        ? qt.textMuted.withValues(alpha: 0.25)
                                        : qt.textMuted.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                row.add(const Expanded(child: SizedBox(height: 36)));
              }
            }
            return Row(children: row);
          }),
        ],
      ),
    );
  }

  // ── Calendar Legend ───────────────────────────────────────────────────

  Widget _calLegend(QuranTheme qt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _calLegItem(
              const Color(0xFFD1FAE5), "All Prayed", const Color(0xFF065F46)),
          const SizedBox(width: 16),
          _calLegItem(
              const Color(0xFFFEF3C7), "Partial", const Color(0xFF92400E)),
          const SizedBox(width: 16),
          _calLegItem(
              const Color(0xFFFEE2E2), "Missed", const Color(0xFF991B1B)),
        ],
      ),
    );
  }

  Widget _calLegItem(Color bg, String label, Color textColor) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
        ],
      );

  // ── Monthly Trend ────────────────────────────────────────────────────

  Widget _monthlyTrend(QuranTheme qt, PrayerTracker t) {
    final trend = t.getMonthlyTrend(6);
    final dark = qt.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: dark
            ? Border.all(color: qt.borderGlass.withValues(alpha: 0.3))
            : null,
      ),
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: trend.map((d) {
            final rate = d['rate'] as double;
            final h = rate == 0.0 ? 4.0 : max(4.0, rate * 72);
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
                const SizedBox(height: 8),
                Text(d['month'] as String,
                    style: TextStyle(
                        fontSize: 10,
                        color: qt.textMuted,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text("${(rate * 100).toInt()}%",
                    style: TextStyle(
                        fontSize: 9,
                        color: qt.textSecondary,
                        fontWeight: FontWeight.w700)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Milestones ───────────────────────────────────────────────────────

  Widget _milestones(QuranTheme qt, PrayerTracker t) {
    final data = [
      (
        'first_prayer',
        Icons.favorite_rounded,
        "First Step",
        "Log your first prayer",
        Colors.pink
      ),
      (
        'streak_7',
        Icons.local_fire_department_rounded,
        "On Fire",
        "7-day streak",
        Colors.orange
      ),
      (
        'perfect_week',
        Icons.star_rounded,
        "Perfect Week",
        "7 days, all prayers",
        Colors.amber
      ),
      (
        'streak_30',
        Icons.nightlight_round,
        "Ramadan Ready",
        "30-day streak",
        Colors.indigo
      ),
      (
        'centurion',
        Icons.military_tech_rounded,
        "Centurion",
        "100 prayers logged",
        Colors.teal
      ),
      (
        'year_of_light',
        Icons.emoji_events_rounded,
        "Year of Light",
        "365 consecutive days",
        Colors.purple
      ),
    ];

    final dark = qt.brightness == Brightness.dark;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, i) {
        final (id, icon, title, desc, color) = data[i];
        final done = t.hasMilestone(id);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                done ? color.withValues(alpha: dark ? 0.08 : 0.04) : qt.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done
                  ? color.withValues(alpha: 0.3)
                  : qt.borderGlass.withValues(alpha: 0.25),
              width: done ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon,
                      color: done ? color : qt.textMuted.withValues(alpha: 0.2),
                      size: 20),
                  if (done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("Done",
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: done ? qt.textPrimary : qt.textMuted)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(
                      fontSize: 10,
                      color: done
                          ? qt.textSecondary
                          : qt.textMuted.withValues(alpha: 0.45))),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String title, QuranTheme qt) => Row(
        children: [
          Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                  color: qt.emeraldDeep,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: qt.textPrimary,
                  letterSpacing: -0.2)),
        ],
      );

  Widget _navBtn(IconData icon, VoidCallback? onTap, QuranTheme qt) {
    final dark = qt.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap != null
              ? (dark ? Colors.white.withValues(alpha: 0.06) : qt.bg)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: onTap != null
              ? qt.textPrimary
              : qt.textMuted.withValues(alpha: 0.15),
          size: 14,
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, QuranTheme qt) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: qt.textMuted)),
        ],
      );
}
