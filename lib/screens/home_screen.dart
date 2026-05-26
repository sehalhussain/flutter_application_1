import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:math' as math;
import '../models/name_model.dart';
import '../models/quran_models.dart';
import '../services/quran_service.dart';
import '../constants/quran_theme.dart';
import '../services/prayer_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'asma_list_screen.dart';
import 'hadith/hadith_home_screen.dart';
import 'quran/quran_home_screen.dart';
import 'quran/quran_reader_screen.dart';
import 'duas_screen.dart';
import 'hijri_calendar_screen.dart';
import 'package:flutter_islamic_icons/flutter_islamic_icons.dart';
import 'prayer_tracker_screen.dart';
import '../providers/prayer_tracker_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ISOLATE-FRIENDLY PARSERS
// ═══════════════════════════════════════════════════════════════════════════

List<AsmaName> _parseAsmaNames(String jsonString) {
  final Map<String, dynamic> decoded = jsonDecode(jsonString);
  final List<dynamic> data = decoded['data'];
  return data.map((item) => AsmaName.fromJson(item)).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<AyahData>? _ayahFuture;
  Future<List<AsmaName>>? _namesFuture;
  Map<String, dynamic>? _todayTimings;

  @override
  void initState() {
    super.initState();
    _refreshAyah();
    _initPrayerTimings();
    _namesFuture = _loadNamesInIsolate();
    // Listen for PrayerService changes (location, asr, hijri adj changed in other screens)
    PrayerService.instance.addListener(_onPrayerServiceChanged);
  }

  @override
  void dispose() {
    PrayerService.instance.removeListener(_onPrayerServiceChanged);
    super.dispose();
  }

  void _onPrayerServiceChanged() {
    _initPrayerTimings();
  }

  /// Offload JSON parsing to background isolate.
  Future<List<AsmaName>> _loadNamesInIsolate() async {
    final jsonString =
        await rootBundle.loadString('assets/data/names/asmaulhusna.json');
    return compute(_parseAsmaNames, jsonString);
  }

  Future<void> _initPrayerTimings() async {
    final timings = await PrayerService.instance.getTodayTimings();
    if (mounted) {
      setState(() {
        _todayTimings = timings;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "GOOD MORNING";
    if (hour < 17) return "GOOD AFTERNOON";
    return "GOOD EVENING";
  }

  void _refreshAyah() {
    final future = QuranService.instance.getRandomAyah();
    if (mounted) {
      setState(() {
        _ayahFuture = future;
      });
    } else {
      _ayahFuture = future;
    }
  }

  Future<void> _handleRefresh() async {
    final namesFuture = _loadNamesInIsolate();
    final ayahFuture = QuranService.instance.getRandomAyah();

    setState(() {
      _namesFuture = namesFuture;
      _ayahFuture = ayahFuture;
    });

    await Future.wait([
      _ayahFuture ?? Future.value(),
      _namesFuture ?? Future.value(),
      _initPrayerTimings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: qt.emeraldDeep,
          backgroundColor: qt.cardBg,
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // --- DATE HEADER ---
              _DateHeader(
                greeting: _getGreeting(),
                timings: _todayTimings,
                qt: qt,
              ),
              const SizedBox(height: 32),

              // --- PRAYER CARD (with isolated countdown) ---
              _PrayerCard(timings: _todayTimings, qt: qt),
              const SizedBox(height: 32),

              // --- ESSENTIALS SECTION ---
              _EssentialsSection(
                qt: qt,
                onRefreshAyah: _refreshAyah,
                qiblaDirection: PrayerService.instance.qiblaDirection,
              ),
              const SizedBox(height: 32),

              // --- ASMA UL HUSNA SLIDER ---
              _AsmaSlider(future: _namesFuture, qt: qt),
              const SizedBox(height: 32),

              // --- AYAH OF THE DAY ---
              _AyahSection(future: _ayahFuture, qt: qt),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATE HEADER ( Stateless — no rebuild issues )
// ═══════════════════════════════════════════════════════════════════════════

class _DateHeader extends StatelessWidget {
  final String greeting;
  final Map<String, dynamic>? timings;
  final QuranTheme qt;

  const _DateHeader({
    required this.greeting,
    required this.timings,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 11,
            color: qt.textMuted,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        if (timings != null) ...[
          Text(
            "${timings!['date']['gregorian']['day']} ${timings!['date']['gregorian']['month']['en']}",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: qt.textPrimary,
            ),
          ),
          Text(
            "${timings!['date']['hijri']['day']} ${timings!['date']['hijri']['month']['en']} ${timings!['date']['hijri']['year']} AH",
            style: TextStyle(
              color: qt.emeraldDeep,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRAYER CARD — ISOLATED COUNTDOWN ( THE BIG FIX )
// ═══════════════════════════════════════════════════════════════════════════
//
// CRITICAL: This widget has its OWN Timer and setState.
// The 1-second countdown ONLY rebuilds this card, NOT the entire HomeScreen.

class _PrayerCard extends StatefulWidget {
  final Map<String, dynamic>? timings;
  final QuranTheme qt;

  const _PrayerCard({
    required this.timings,
    required this.qt,
  });

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late DateTime _now;
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) {
          setState(() {
            _now = DateTime.now();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

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

  double _calculatePrayerProgress(
    String current,
    String next,
    DateTime now,
  ) {
    DateTime parse(String t) {
      final p = t.split(':');
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(p[0]),
        int.parse(p[1]),
      );
    }

    final start = parse(current);
    var end = parse(next);

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    final total = end.difference(start).inSeconds;
    final passed = now.difference(start).inSeconds;

    if (total == 0) return 0.0;
    return (passed / total).clamp(0.0, 1.0);
  }

  String _formatTime(String time) {
    try {
      final p = time.split(':');
      final dt = DateTime(2026, 1, 1, int.parse(p[0]), int.parse(p[1]));
      return DateFormat.jm().format(dt);
    } catch (_) {
      return time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;
    final timings = widget.timings;

    if (timings == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: qt.emeraldDeep,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    }

    final pTimings = timings['timings'];
    final timeStr =
        "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}";
    final prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    String nextPrayer = 'Fajr';
    String nextTimeStr = pTimings['Fajr'].toString().split(' ')[0];

    for (final prayer in prayerOrder) {
      final pTime = pTimings[prayer].toString().split(' ')[0];
      if (pTime.compareTo(timeStr) > 0) {
        nextPrayer = prayer;
        nextTimeStr = pTime;
        break;
      }
    }

    int nextIdx = prayerOrder.indexOf(nextPrayer);
    String currentPrayer = nextIdx == 0 ? 'Isha' : prayerOrder[nextIdx - 1];
    String currentTimeStr = pTimings[currentPrayer].toString().split(' ')[0];

    final parts = nextTimeStr.split(':');
    var targetDate = DateTime(
      _now.year,
      _now.month,
      _now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (targetDate.isBefore(_now)) {
      targetDate = targetDate.add(const Duration(days: 1));
    }

    final diff = targetDate.difference(_now);
    final countdown = "${diff.inHours.toString().padLeft(2, '0')}:"
        "${(diff.inMinutes % 60).toString().padLeft(2, '0')}:"
        "${(diff.inSeconds % 60).toString().padLeft(2, '0')}";

    final progress = _calculatePrayerProgress(
      currentTimeStr,
      nextTimeStr,
      _now,
    );

    final otherPrayers = prayerOrder
        .where((p) => p != currentPrayer && p != nextPrayer)
        .toList();

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggleExpand,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding:
              const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                qt.emeraldMid,
                qt.emeraldDeep,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══════════════════════════════════════════════════════
              //  AYAH HEADER
              // ═══════════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Text(
                      'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَوْقُوتًا',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.6,
                        fontFamily: 'QPC Hafs',
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Indeed, the prayer is prescribed for the believers at specified times. (Quran 4:103)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // ═══════════════════════════════════════════════════════
              //  NOW & NEXT with inline countdown
              // ═══════════════════════════════════════════════════════
              Row(
                crossAxisAlignment: CrossAxisAlignment.end, // Align to bottom
                children: [
                  // Now
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Now",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPrayer,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getPrayerIcon(currentPrayer),
                              size: 12,
                              color: Colors.white.withOpacity(1),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatTime(currentTimeStr),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── CENTER: Inline countdown ──
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 2), // Slight offset to align with time row
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          countdown,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.7),
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Remaining",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Next
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Next",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextPrayer,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _formatTime(nextTimeStr),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              _getPrayerIcon(nextPrayer),
                              size: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white70,
                  ),
                ),
              ),

              // ═══════════════════════════════════════════════════════
              //  EXPANDED: Other prayers only
              // ═══════════════════════════════════════════════════════
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),

                    // Other prayers panel with dividers
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: otherPrayers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final prayer = entry.value;
                          final isLast = index == otherPrayers.length - 1;

                          return Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        prayer,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.55),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(pTimings[prayer]
                                            .toString()
                                            .split(' ')[0]),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Divider between prayers (not after last)
                                if (!isLast)
                                  Container(
                                    width: 1,
                                    height: 24,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════════════════
              //  TAP HINT — Visually centered
              // ═══════════════════════════════════════════════════════
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _toggleExpand,
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // ← KEY: shrink to content
                    children: [
                      Text(
                        _isExpanded ? "Tap to collapse" : "Tap to expand",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 0), // Add this to control bottom padding
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESSENTIALS SECTION — Quran + Hadith (square), Duas (wide), Qibla (wide), Hijri (wide)
// ═══════════════════════════════════════════════════════════════════════════

class _EssentialsSection extends StatefulWidget {
  final QuranTheme qt;
  final VoidCallback onRefreshAyah;
  final double? qiblaDirection;

  const _EssentialsSection({
    required this.qt,
    required this.onRefreshAyah,
    this.qiblaDirection,
  });

  @override
  State<_EssentialsSection> createState() => _EssentialsSectionState();
}

class _EssentialsSectionState extends State<_EssentialsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;

    return Column(
      children: [
        Text(
          "Essentials",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: qt.textPrimary,
          ),
        ),
        const SizedBox(height: 20),

        // Row 1: Quran (left) + Daily Duas (right)
        Row(
          children: [
            _EssentialCard(
              title: "Holy Quran",
              subtitle: "Read, Listen & Reflect",
              color: qt.emeraldDeep.withOpacity(0.12),
              icon: Icons.book_rounded,
              iconColor: qt.brightness == Brightness.dark
                  ? const Color.fromARGB(255, 155, 255, 213)
                  : qt.emeraldDeep,
              onTap: () async {
                await QuranService.instance.loadSurahList();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranHomeScreen()),
                ).then((_) => widget.onRefreshAyah());
              },
              qt: qt,
            ),
            const SizedBox(width: 16),
            _EssentialCard(
              title: "Authentic Duas",
              subtitle: "Dua for Every Moment",
              color: const Color.fromARGB(255, 252, 245, 233).withOpacity(
                qt.brightness == Brightness.dark ? 0.15 : 1.0,
              ),
              icon: FlutterIslamicIcons.solidPrayingPerson,
              iconColor: qt.brightness == Brightness.dark
                  ? const Color.fromARGB(255, 155, 255, 213)
                  : const Color(0xFFFFB74D),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DuasScreen()),
                );
              },
              qt: qt,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 2: Hadith Library — wide card
        _WideEssentialCard(
          title: "Hadith Library",
          subtitle: "Browse authentic narrations",
          color: const Color(0xFFE3F2FD).withOpacity(
            qt.brightness == Brightness.dark ? 0.15 : 1.0,
          ),
          icon: FlutterIslamicIcons.solidMohammad,
          iconColor: qt.brightness == Brightness.dark
              ? const Color(0xFFFFB74D)
              : Colors.blue.shade600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HadithHomeScreen()),
            );
          },
          qt: qt,
        ),
        const SizedBox(height: 16),

        // Row 3: Hijri Calendar — always visible
        _WideEssentialCard(
          title: "Hijri Calendar",
          subtitle: "View Islamic events and dates",
          color: const Color(0xFFE3F2FD).withOpacity(
            qt.brightness == Brightness.dark ? 0.15 : 1.0,
          ),
          icon: Icons.calendar_month_rounded,
          iconColor: qt.brightness == Brightness.dark
              ? const Color(0xFFFFB74D)
              : Colors.blue.shade600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HijriCalendarScreen()),
            );
          },
          qt: qt,
        ),
        const SizedBox(height: 16),

        // ─── Expandable: Qibla + future tools ───
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QiblaCompassCard(
                qiblaDirection: widget.qiblaDirection,
                qt: qt,
              ),
              const SizedBox(height: 16),
              // Prayer Tracker card
              Consumer<PrayerTracker>(
                builder: (context, tracker, _) {
                  final todayCount = tracker.todayPrayedCount;
                  final streak = tracker.currentStreak;
                  return _WideEssentialCard(
                    title: "Prayer Tracker",
                    subtitle: todayCount > 0
                        ? "$todayCount/5 today · $streak-day streak"
                        : "Track your daily prayers",
                    color: Colors.green.withOpacity(
                      qt.brightness == Brightness.dark ? 0.15 : 0.08,
                    ),
                    icon: Icons.mosque_rounded,
                    iconColor: Colors.green.shade600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrayerTrackerScreen()),
                      );
                    },
                    qt: qt,
                  );
                },
              ),
            ],
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 280),
          firstCurve: Curves.easeInOut,
          secondCurve: Curves.easeInOut,
          sizeCurve: Curves.easeInOut,
        ),

        const SizedBox(height: 12),

        // ─── Toggle Pill ───
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: qt.emeraldDeep.withOpacity(0.3), // Colored border
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.apps_rounded,
                    size: 16,
                    color: qt.emeraldDeep,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isExpanded ? "Show Less" : "More Tools",
                    style: TextStyle(
                      color: qt.emeraldDeep, // Brand color instead of muted
                      fontSize: 13,
                      fontWeight: FontWeight.w700, // Bolder
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: qt.emeraldDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ASMA SLIDER — OPTIMIZED WITH PAGINATION & REPAINBOUNDARY
// ═══════════════════════════════════════════════════════════════════════════

class _AsmaSlider extends StatefulWidget {
  final Future<List<AsmaName>>? future;
  final QuranTheme qt;

  const _AsmaSlider({required this.future, required this.qt});

  @override
  State<_AsmaSlider> createState() => _AsmaSliderState();
}

class _AsmaSliderState extends State<_AsmaSlider> {
  final ScrollController _scrollController = ScrollController();
  int _limit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (_limit < 99) {
        setState(() => _limit += 20);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Asma ul Husna",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AsmaListScreen()),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: qt.emeraldDeep.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  "View All",
                  style: TextStyle(
                    color: qt.emeraldDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<AsmaName>>(
          future: widget.future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(height: 120);
            }
            final names = snapshot.data!.take(_limit).toList();

            return SizedBox(
              height: 220,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: names.length,
                itemBuilder: (context, index) {
                  final name = names[index];
                  return RepaintBoundary(
                    child: IntrinsicWidth(
                      child: Container(
                        height: double.infinity,
                        constraints: const BoxConstraints(minWidth: 240),
                        margin: const EdgeInsets.only(right: 16),
                        child: Stack(
                          children: [
                            // Card Background
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: qt.cardBg,
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(color: qt.borderGlass),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromARGB(255, 0, 0, 0)
                                          .withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Content
                            Align(
                              alignment: Alignment.center,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(name.number.toString().padLeft(2, '0'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: qt.textMuted,
                                        )),
                                    Text(
                                      name.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 36,
                                        color: qt.emeraldDeep,
                                        fontFamily: 'QPC Hafs',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      name.transliteration.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: qt.textPrimary,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name.meaning,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: qt.textMuted,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AYAH SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _AyahSection extends StatelessWidget {
  final Future<AyahData>? future;
  final QuranTheme qt;

  const _AyahSection({required this.future, required this.qt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "Guidance from Quran",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: qt.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<AyahData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: qt.emeraldDeep),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Text(
                "Unable to load Ayah",
                style: TextStyle(color: qt.textMuted),
              );
            }
            // Wrap in SizedBox to force full width matching parent ListView padding
            return SizedBox(
              width: double.infinity,
              child: _AyahCard(ayah: snapshot.data!, qt: qt),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AYAH CARD
// ═══════════════════════════════════════════════════════════════════════════

class _AyahCard extends StatelessWidget {
  final AyahData ayah;
  final QuranTheme qt;

  const _AyahCard({required this.ayah, required this.qt});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () async {
          final surahs = await QuranService.instance.loadSurahList();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuranReaderScreen(
                surahNumber: ayah.surahNumber,
                initialAyah: ayah.ayahNumber,
                surahList: surahs,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Column(
            children: [
              Text(
                ayah.uthmani,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'QPC Hafs',
                  fontSize: 24,
                  height: 2.0,
                  color: qt.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                ayah.translation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: qt.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: qt.emeraldDeep.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "SURAH ${ayah.surahNumber} : AYAH ${ayah.ayahNumber}",
                  style: TextStyle(
                    color: qt.emeraldDeep,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESSENTIAL CARDS
// ═══════════════════════════════════════════════════════════════════════════

// --- Optimized Component Cards ---
class _EssentialCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final QuranTheme qt;

  const _EssentialCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 160, // Sized down beautifully from 180 to fit grid balance
            decoration: BoxDecoration(
                color: qt.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: qt.borderGlass, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: qt.textMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide-style essential card (full width, horizontal layout)
class _WideEssentialCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final QuranTheme qt;

  const _WideEssentialCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: qt.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: qt.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: qt.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
// QIBLA COMPASS CARD – premium, intuitive, no raw degrees
// ═══════════════════════════════════════════════════════════════════════════

class _QiblaCompassCard extends StatefulWidget {
  final double? qiblaDirection; // bearing from user to Kaaba
  final QuranTheme qt;

  const _QiblaCompassCard({
    this.qiblaDirection,
    required this.qt,
  });

  @override
  State<_QiblaCompassCard> createState() => _QiblaCompassCardState();
}

class _QiblaCompassCardState extends State<_QiblaCompassCard> {
  bool _hasCompass = false;
  bool _isActive = false;

  StreamSubscription<CompassEvent>? _compassSub;
  double? _deviceHeading;
  bool _isAligned = false;

  static const double _alignmentTolerance = 8.0;

  @override
  void initState() {
    super.initState();
    _checkCompassAvailability();
  }

  Future<void> _checkCompassAvailability() async {
    try {
      final stream = FlutterCompass.events;
      if (mounted) setState(() => _hasCompass = stream != null);
    } catch (_) {
      if (mounted) setState(() => _hasCompass = false);
    }
  }

  void _startCompass() {
    if (!_hasCompass || _compassSub != null) return;
    _compassSub = FlutterCompass.events?.listen((event) {
      if (!mounted || event.heading == null) return;
      setState(() {
        _deviceHeading = event.heading;
        _isAligned = _calculateAlignment(
          widget.qiblaDirection ?? 0,
          _deviceHeading!,
        );
      });
    });
  }

  void _stopCompass() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  bool _calculateAlignment(double qibla, double heading) {
    double diff = (qibla - heading) % 360;
    if (diff < 0) diff += 360;
    return diff <= _alignmentTolerance || diff >= 360 - _alignmentTolerance;
  }

  void _toggleActive() {
    if (widget.qiblaDirection == null || !_hasCompass) return;
    setState(() {
      _isActive = !_isActive;
      if (_isActive) {
        _startCompass();
      } else {
        _stopCompass();
        _deviceHeading = null;
        _isAligned = false;
      }
    });
  }

  @override
  void dispose() {
    _stopCompass();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;
    final direction = widget.qiblaDirection;

    // No location – prompt
    if (direction == null) {
      return _buildEmptyCard(qt);
    }

    // Devices without compass always show static text, no activation
    if (!_hasCompass) {
      return _buildStaticInfo(qt, direction, canActivate: false);
    }

    // Devices with compass – show static text when inactive, compass when active
    if (!_isActive) {
      return _buildStaticInfo(qt, direction,
          canActivate: true, onTap: _toggleActive);
    }

    // Active – live compass
    return _buildLiveCompass(qt, direction);
  }

  // ──────────── EMPTY STATE ────────────
  Widget _buildEmptyCard(QuranTheme qt) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Row(
          children: [
            Icon(Icons.explore_off_outlined, size: 28, color: qt.textMuted),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Qibla Direction",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary)),
                  const SizedBox(height: 4),
                  Text("Set your location to find the direction",
                      style: TextStyle(fontSize: 12, color: qt.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────── STATIC INFO (inactive state for both) ────────
  Widget _buildStaticInfo(
    QuranTheme qt,
    double direction, {
    required bool canActivate,
    VoidCallback? onTap,
  }) {
    final dirName = _getDirectionName(direction);
    final degreeText = "${direction.toStringAsFixed(0)}°";

    return RepaintBoundary(
      child: GestureDetector(
        onTap: canActivate ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Row(
            children: [
              // Simple icon, no compass face
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: qt.emeraldDeep.withOpacity(0.06),
                ),
                child: Icon(Icons.explore_rounded,
                    size: 28, color: qt.emeraldDeep.withOpacity(0.7)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Qibla Direction",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    if (!canActivate)
                      // Non-compass device: show direction + note
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 13, color: qt.emeraldDeep),
                              children: [
                                TextSpan(
                                  text: "Kaaba is to the $dirName  ",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: degreeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: qt.textMuted,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Based on your city, not your facing",
                            style: TextStyle(
                                fontSize: 11,
                                color: qt.textMuted,
                                fontWeight: FontWeight.w400),
                          ),
                        ],
                      )
                    else
                      // Compass device, not yet activated
                      Text(
                        "Tap to activate compass",
                        style: TextStyle(
                            fontSize: 12,
                            color: qt.textMuted,
                            fontWeight: FontWeight.w400),
                      ),
                  ],
                ),
              ),
              if (canActivate)
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: qt.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────── LIVE COMPASS (active) ────────────
  Widget _buildLiveCompass(QuranTheme qt, double direction) {
    final rotation =
        _deviceHeading != null ? (direction - _deviceHeading!) : direction;
    final isAligned = _isAligned;
    final dirName = _getDirectionName(direction);
    final degreeText = "${direction.toStringAsFixed(0)}°";

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggleActive, // tap again to deactivate
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isAligned ? qt.emeraldDeep : qt.emeraldDeep.withOpacity(0.6),
              width: isAligned ? 2.0 : 1.0,
            ),
            boxShadow: isAligned
                ? [
                    BoxShadow(
                      color: qt.emeraldDeep.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Compass face with rotating arrow + Kaaba dot
              _buildCompassFace(
                qt,
                rotation: rotation,
                arrowColor: qt.emeraldDeep,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Qibla Direction",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    // Always show direction details when compass is active
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: qt.emeraldDeep),
                        children: [
                          TextSpan(
                            text: "Kaaba is to the $dirName  ",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: degreeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: qt.textMuted,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isAligned)
                      Text(
                        "Straight ahead",
                        style: TextStyle(
                          fontSize: 12,
                          color: qt.emeraldDeep,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        "Rotate your device slowly",
                        style: TextStyle(
                          fontSize: 12,
                          color: qt.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                isAligned ? Icons.check_circle_rounded : Icons.sensors_rounded,
                size: 20,
                color: qt.emeraldDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──── SHARED COMPASS FACE (used only when active) ────
  Widget _buildCompassFace(
    QuranTheme qt, {
    required double rotation,
    required Color arrowColor,
  }) {
    final arrowRad = rotation * math.pi / 180;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: qt.emeraldDeep.withOpacity(0.3)),
              color: qt.bg,
            ),
          ),
          // Kaaba indicator dot at top
          Positioned(
            top: 6,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: qt.emeraldDeep,
              ),
            ),
          ),
          // Rotating arrow points toward Kaaba
          Transform.rotate(
            angle: arrowRad,
            child: Icon(
              Icons.navigation_rounded,
              size: 24,
              color: arrowColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getDirectionName(double degrees) {
    final dirs = [
      'North',
      'Northeast',
      'East',
      'Southeast',
      'South',
      'Southwest',
      'West',
      'Northwest'
    ];
    final index = ((degrees + 22.5) ~/ 45) % 8;
    return dirs[index];
  }
}
