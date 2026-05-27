import 'dart:math' show min, max;
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

class _PrayerStatsScreenState extends State<PrayerStatsScreen> {
  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final tracker = context.watch<PrayerTracker>();

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        title: const Text(
          "Prayer Journey",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: qt.bg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroStats(qt, tracker),
            const SizedBox(height: 28),
            _buildSectionTitle(
              "Last 7 Days",
              "Daily prayer count at a glance",
              qt,
            ),
            const SizedBox(height: 12),
            _buildWeeklyBarChart(qt, tracker),
            const SizedBox(height: 28),
            _buildSectionTitle(
              "Prayer Breakdown",
              "How consistent you are with each prayer",
              qt,
            ),
            const SizedBox(height: 12),
            _buildPrayerBreakdown(qt, tracker),
            const SizedBox(height: 28),
            _buildSectionTitle(
              "Monthly Trend",
              "Completion rate over recent months",
              qt,
            ),
            const SizedBox(height: 12),
            _buildMonthlyTrend(qt, tracker),
            const SizedBox(height: 28),
            _buildSectionTitle(
              "Milestones",
              "Achievements unlocked on your journey",
              qt,
            ),
            const SizedBox(height: 12),
            _buildMilestones(qt, tracker),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String tooltip, QuranTheme qt) {
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
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: qt.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: tooltip,
          preferBelow: true,
          verticalOffset: 10,
          decoration: BoxDecoration(
            color: qt.emeraldDeep,
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
          child: Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: qt.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStats(QuranTheme qt, PrayerTracker tracker) {
    final stats = [
      _HeroStat(
        icon: Icons.local_fire_department_rounded,
        value: "${tracker.currentStreak}",
        label: "Current Streak",
        tooltip: "Consecutive days with all 5 prayers",
        color: Colors.orange,
      ),
      _HeroStat(
        icon: Icons.emoji_events_rounded,
        value: "${tracker.bestStreak}",
        label: "Best Streak",
        tooltip: "Longest run of perfect days ever",
        color: Colors.amber,
      ),
      _HeroStat(
        icon: Icons.calendar_month_rounded,
        value:
            "${(tracker.monthlyCompletionRate(DateTime.now().year, DateTime.now().month) * 100).toInt()}%",
        label: "This Month",
        tooltip: "Days with all 5 prayers this month",
        color: qt.emeraldDeep,
      ),
      _HeroStat(
        icon: Icons.mosque_rounded,
        value: "${tracker.totalPrayersLogged}",
        label: "Total Prayers",
        tooltip: "Lifetime prayers logged",
        color: Colors.teal,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [qt.emeraldMid, qt.emeraldDeep],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: qt.emeraldDeep.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                stats.sublist(0, 2).map((s) => _buildHeroStatItem(s)).toList(),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                stats.sublist(2, 4).map((s) => _buildHeroStatItem(s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem(_HeroStat stat) {
    return Tooltip(
      message: stat.tooltip,
      preferBelow: true,
      verticalOffset: 10,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(stat.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Clean 7-day bar chart — compact, no overflow, visually balanced
  Widget _buildWeeklyBarChart(QuranTheme qt, PrayerTracker tracker) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final key = _dateKey(date);
      final count = tracker.prayedCountForDate(key);
      return {
        'date': date,
        'count': count,
        'isToday': i == 6,
      };
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: days.map((day) {
                final count = day['count'] as int;
                final date = day['date'] as DateTime;
                final isToday = day['isToday'] as bool;
                // Minimum bar height so 0 doesn't disappear
                final barHeight =
                    count == 0 ? 6.0 : max(12.0, (count / 5) * 65);

                Color barColor;
                if (count == 5) {
                  barColor = qt.emeraldDeep;
                } else if (count >= 3) {
                  barColor = qt.emeraldMid;
                } else if (count > 0) {
                  barColor = Colors.orange;
                } else {
                  barColor = qt.borderGlass.withOpacity(0.5);
                }

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "$count",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: count == 5 ? qt.emeraldDeep : qt.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 18,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(9),
                          border: isToday
                              ? Border.all(
                                  color: qt.emeraldDeep.withOpacity(0.6),
                                  width: 1.5,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('E').format(date).substring(0, 1),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isToday ? qt.emeraldDeep : qt.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Today indicator dot
                      Container(
                        width: isToday ? 5 : 4,
                        height: isToday ? 5 : 4,
                        decoration: BoxDecoration(
                          color: isToday ? qt.emeraldDeep : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(qt.emeraldDeep, "5/5", qt),
              const SizedBox(width: 14),
              _legendItem(qt.emeraldMid, "3-4", qt),
              const SizedBox(width: 14),
              _legendItem(Colors.orange, "1-2", qt),
              const SizedBox(width: 14),
              _legendItem(qt.borderGlass.withOpacity(0.5), "0", qt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, QuranTheme qt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: qt.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerBreakdown(QuranTheme qt, PrayerTracker tracker) {
    final prayers = tracker.prayerNames;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: prayers.map((prayer) {
          final rate = tracker.prayerCompletionRate(prayer);
          final percentage = (rate * 100).toInt();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      prayer,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: qt.textPrimary,
                      ),
                    ),
                    Text(
                      "$percentage%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: percentage >= 80
                            ? Colors.green
                            : percentage >= 50
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 8,
                    backgroundColor: qt.borderGlass.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage >= 80
                          ? Colors.green
                          : percentage >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyTrend(QuranTheme qt, PrayerTracker tracker) {
    final trend = tracker.getMonthlyTrend(6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: trend.map((data) {
                final rate = data['rate'] as double;
                final height = rate == 0.0 ? 4.0 : max(4.0, rate * 120);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            qt.emeraldDeep,
                            qt.emeraldMid,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['month'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: qt.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${(rate * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 10,
                        color: qt.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
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
    final milestones = [
      _Milestone(
        id: 'first_prayer',
        icon: Icons.favorite_rounded,
        title: "First Step",
        description: "Log your first prayer",
        color: Colors.pink,
      ),
      _Milestone(
        id: 'streak_7',
        icon: Icons.local_fire_department_rounded,
        title: "On Fire",
        description: "7-day streak",
        color: Colors.orange,
      ),
      _Milestone(
        id: 'perfect_week',
        icon: Icons.star_rounded,
        title: "Perfect Week",
        description: "All prayers for 7 days",
        color: Colors.amber,
      ),
      _Milestone(
        id: 'streak_30',
        icon: Icons.nightlight_round,
        title: "Ramadan Ready",
        description: "30-day streak",
        color: Colors.indigo,
      ),
      _Milestone(
        id: 'centurion',
        icon: Icons.military_tech_rounded,
        title: "Centurion",
        description: "100 prayers logged",
        color: Colors.teal,
      ),
      _Milestone(
        id: 'year_of_light',
        icon: Icons.emoji_events_rounded,
        title: "Year of Light",
        description: "365 consecutive days",
        color: Colors.purple,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: milestones.map((m) {
        final achieved = tracker.hasMilestone(m.id);
        return Container(
          width: (MediaQuery.of(context).size.width - 52) / 2,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: achieved ? m.color.withOpacity(0.1) : qt.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: achieved ? m.color.withOpacity(0.3) : qt.borderGlass,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                m.icon,
                color: achieved ? m.color : qt.textMuted.withOpacity(0.4),
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                m.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: achieved ? qt.textPrimary : qt.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                m.description,
                style: TextStyle(
                  fontSize: 11,
                  color: achieved
                      ? qt.textSecondary
                      : qt.textMuted.withOpacity(0.6),
                ),
              ),
              if (achieved)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: m.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Achieved",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: m.color,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _HeroStat {
  final IconData icon;
  final String value;
  final String label;
  final String tooltip;
  final Color color;

  _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tooltip,
    required this.color,
  });
}

class _Milestone {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _Milestone({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
