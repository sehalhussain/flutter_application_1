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
import '../models/hadith_models.dart';
import '../services/quran_service.dart';
import '../services/hadith_db.dart';
import '../services/hadith_service.dart';
import '../constants/quran_theme.dart';
import '../services/prayer_service.dart';
import '../main.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'asma_list_screen.dart';
import 'hadith/hadith_home_screen.dart';
import 'hadith/hadith_chapter_screen.dart';
import 'hadith/hadith_reader_screen.dart';
import 'quran/quran_home_screen.dart';
import 'quran/quran_reader_screen.dart';
import 'duas/duas_screen.dart';
import 'hijri_calendar_screen.dart';
import 'package:flutter_islamic_icons/flutter_islamic_icons.dart';
import 'prayer_stats_screen.dart';
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
  Future<Hadith?>? _hadithFuture;
  Future<List<AsmaName>>? _namesFuture;
  Map<String, dynamic>? _todayTimings;

  // ── Coalesce rapid PrayerService notifications (e.g. setup wizard changing
  // city + asr + hijri in quick succession) so the home screen only re-fetches
  // prayer timings once. This avoids the visible "refresh / flicker" that
  // happens when multiple setState()s fire in the same frame.
  Timer? _timingsRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _refreshAyah();
    _refreshHadith();
    _initPrayerTimings();
    _namesFuture = _loadNamesInIsolate();
    PrayerService.instance.addListener(_onPrayerServiceChanged);
  }

  @override
  void dispose() {
    _timingsRefreshDebounce?.cancel();
    PrayerService.instance.removeListener(_onPrayerServiceChanged);
    super.dispose();
  }

  void _onPrayerServiceChanged() {
    // Debounce: collapse bursts of notifyListeners() into a single re-fetch.
    _timingsRefreshDebounce?.cancel();
    _timingsRefreshDebounce = Timer(
      const Duration(milliseconds: 250),
      _initPrayerTimings,
    );
  }

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

  void _refreshHadith() {
    final future = HadithService.instance.getRandomHadith();
    if (mounted) {
      setState(() {
        _hadithFuture = future;
      });
    } else {
      _hadithFuture = future;
    }
  }

  Future<void> _handleRefresh() async {
    final namesFuture = _loadNamesInIsolate();
    final ayahFuture = QuranService.instance.getRandomAyah();
    final hadithFuture = HadithService.instance.getRandomHadith();

    setState(() {
      _namesFuture = namesFuture;
      _ayahFuture = ayahFuture;
      _hadithFuture = hadithFuture;
    });

    await Future.wait([
      _ayahFuture ?? Future.value(),
      _hadithFuture ?? Future.value(),
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
              const SizedBox(height: 24),

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

              // --- HADITH OF THE DAY ---
              _HadithSection(future: _hadithFuture, qt: qt),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATE HEADER
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
        if (timings != null) ...[
          Text(
            greeting,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: qt.emeraldDeep.withOpacity(0.7),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${timings!['date']['gregorian']['day']} ${timings!['date']['gregorian']['month']['en']}",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: qt.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withOpacity(0.06),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              "${timings!['date']['hijri']['day']} ${timings!['date']['hijri']['month']['en']} ${timings!['date']['hijri']['year']} AH",
              style: TextStyle(
                color: qt.emeraldDeep,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 2),
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
// PRAYER CARD — ISOLATED COUNTDOWN
// ═══════════════════════════════════════════════════════════════════════════

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
    with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _decayTimer;
  late DateTime _now;
  bool _isExpanded = false;

  // Controls whether the center shows the temporary "Tap to unmark" hint helper
  bool _showFullPrayedLabel = false;

  // Expansion Animation Controller
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  // Premium Micro-interaction Sweep Feedback Controllers
  late final AnimationController _feedbackController;
  late final Animation<double> _subtleScaleAnimation;
  late final Animation<double> _subtleBorderAnimation;
  late final Animation<double> _sheenTranslationAnimation;

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

    // Luxuriously slow sheen transition (1500ms) for high-end aesthetic feel
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Microscopic 1% swell to suggest response to active touch without childish bouncing
    _subtleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.012)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.012, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 70,
      ),
    ]).animate(_feedbackController);

    // Premium glowing breath on card boundaries
    _subtleBorderAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.12, end: 0.35)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.35, end: 0.12)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 75,
      ),
    ]).animate(_feedbackController);

    // Expanded range to make the metallic light glide feel long and dramatic
    _sheenTranslationAnimation = Tween<double>(begin: -1.8, end: 2.4).animate(
      CurvedAnimation(
        parent: _feedbackController,
        curve: Curves.easeInOutCubic,
      ),
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
    _decayTimer?.cancel();
    _expandController.dispose();
    _feedbackController.dispose();
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

    var start = parse(current);
    var end = parse(next);

    if (start.isAfter(now)) {
      start = start.subtract(const Duration(days: 1));
    }

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

  bool _hasPrayerTimePassed(String prayer, Map<String, dynamic> pTimings) {
    final timeStr = pTimings[prayer]?.toString().split(' ')[0];
    if (timeStr == null || timeStr == '--:--') return false;
    final parts = timeStr.split(':');
    if (parts.length < 2) return false;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final prayerMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return currentMinutes >= prayerMinutes;
  }

  void _toggleCurrentPrayer(String prayer, PrayerTracker tracker) {
    HapticFeedback.lightImpact();
    final beforeCount = tracker.todayPrayedCount;
    final todayPrayers = tracker.todayPrayers;
    final isAlreadyPrayed = todayPrayers[prayer] ?? false;

    // Trigger highly polished feedback glow and sweep shimmer on logging
    if (!isAlreadyPrayed) {
      _feedbackController.forward(from: 0.0);

      // Momentarily enter high focus "Active" mode to let user celebrate success
      setState(() {
        _showFullPrayedLabel = true;
      });

      // After 4 seconds, slowly decay back into clean "Ambient" mode
      _decayTimer?.cancel();
      _decayTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showFullPrayedLabel = false;
          });
        }
      });
    } else {
      // Direct unmarking: Cancel decay layout instantly but don't animate size changes
      // simultaneously with the fade to ensure a smooth transition
      _decayTimer?.cancel();
    }

    tracker.togglePrayer(prayer).then((_) {
      if (!mounted) return;
      final afterCount = tracker.todayPrayedCount;
      if (beforeCount == 4 && afterCount == 5) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MashaAllah! All 5 prayers completed today! 🤲',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        HapticFeedback.selectionClick();
      }
    });
  }

  Widget _buildMarkPrayerButton({
    required String currentPrayer,
    required String currentTimeStr,
    required bool isPrayed,
    required bool timePassed,
    required VoidCallback onTap,
  }) {
    final IconData iconData;
    final String label;
    final String sublabel;
    final double bgOpacity;
    final double borderOpacity;
    final double iconBgOpacity;
    final double iconOpacity;
    final double textOpacity;
    final double subtextOpacity;
    final bool isInteractive;

    if (isPrayed) {
      iconData = Icons.check_rounded;
      label = '$currentPrayer prayed';
      sublabel = 'Tap to unmark';
      bgOpacity = 0.14;
      borderOpacity = 0.18;
      iconBgOpacity = 0.22;
      iconOpacity = 0.95;
      textOpacity = 0.95;
      subtextOpacity = 0.6;
      isInteractive = true;
    } else if (timePassed) {
      iconData = Icons.add_rounded;
      label = 'Mark $currentPrayer as prayed';
      sublabel = 'Tap to log this prayer';
      bgOpacity = 0.08;
      borderOpacity = 0.05;
      iconBgOpacity = 0.22;
      iconOpacity = 0.95;
      textOpacity = 0.95;
      subtextOpacity = 0.6;
      isInteractive = true;
    } else {
      iconData = Icons.lock_outline_rounded;
      label = '$currentPrayer at ${_formatTime(currentTimeStr)}';
      sublabel = 'Available after prayer time';
      bgOpacity = 0.06;
      borderOpacity = 0.08;
      iconBgOpacity = 0.10;
      iconOpacity = 0.55;
      textOpacity = 0.75;
      subtextOpacity = 0.45;
      isInteractive = false;
    }

    return GestureDetector(
      onTap: isInteractive ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(bgOpacity),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(borderOpacity),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(iconBgOpacity),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: Colors.white.withOpacity(iconOpacity),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(textOpacity),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(subtextOpacity),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isInteractive)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
          ],
        ),
      ),
    );
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

    return Consumer<PrayerTracker>(
      builder: (context, tracker, _) {
        final todayPrayers = tracker.todayPrayers;
        final isCurrentPrayed = todayPrayers[currentPrayer] ?? false;
        final currentTimePassed =
            nextIdx == 0 ? true : _hasPrayerTimePassed(currentPrayer, pTimings);

        return ScaleTransition(
          scale: _subtleScaleAnimation,
          child: AnimatedBuilder(
            animation: _feedbackController,
            builder: (context, child) {
              return Stack(
                children: [
                  // ── BASE CARD ──
                  Container(
                    padding: const EdgeInsets.only(
                        left: 24, right: 24, top: 22, bottom: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          qt.emeraldMid,
                          qt.emeraldDeep,
                          qt.emeraldDeep.withBlue(qt.emeraldDeep.blue + 10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(_subtleBorderAnimation.value),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),

                  // ── HOVERING SHIMMER SHEEN OVERLAY (Slow cinematic sweep) ──
                  if (_feedbackController.isAnimating)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final translation =
                                _sheenTranslationAnimation.value * width;
                            return Transform(
                              transform: Matrix4.translationValues(
                                  translation, 0.0, 0.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.01),
                                      Colors.white.withOpacity(0.1),
                                      Colors.white.withOpacity(0.01),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ═══════════════════════════════════════════════════════
                //  AYAH CITATION
                // ═══════════════════════════════════════════════════════
                Text(
                  '"The Prayer is enjoined upon the believers at stated times." (Quran 4:103)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ═══════════════════════════════════════════════════════
                //  NOW & NEXT DISPLAY
                // ═══════════════════════════════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Now Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "NOW",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentPrayer,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
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
                                color: Colors.white.withOpacity(0.8),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatTime(currentTimeStr),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Centered dynamic status with smooth, simple cross-fade transitions
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: isCurrentPrayed
                              ? GestureDetector(
                                  key: ValueKey(
                                      'completed_state_$currentPrayer'),
                                  onTap: () {
                                    // Easily re-open manual unmark options if collapsed
                                    if (!_showFullPrayedLabel) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _showFullPrayedLabel = true;
                                      });
                                    } else {
                                      _toggleCurrentPrayer(
                                          currentPrayer, tracker);
                                    }
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Highly compact glassy emerald check badge
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.18),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xFF34D399),
                                          size: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$currentPrayer prayed",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w400,
                                          fontSize: 9,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      // Soft decay layout that slides shut elegantly
                                      AnimatedSize(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOutCubic,
                                        child: _showFullPrayedLabel
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Tap to unmark",
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.45),
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  key: ValueKey(
                                      'countdown_state_$currentPrayer'),
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      countdown,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(.7),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
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
                      ),
                    ),

                    // Next Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "NEXT",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextPrayer,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
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

                const SizedBox(height: 14),

                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCurrentPrayed
                          ? const Color(0xFF34D399)
                          : Colors.white70,
                    ),
                  ),
                ),

                // ═══════════════════════════════════════════════════════
                //  ALWAYS VISIBLE ACTION BAR (Disappears gracefully when completed)
                // ═══════════════════════════════════════════════════════
                if (!isCurrentPrayed) ...[
                  const SizedBox(height: 14),
                  _buildMarkPrayerButton(
                    currentPrayer: currentPrayer,
                    currentTimeStr: currentTimeStr,
                    isPrayed: isCurrentPrayed,
                    timePassed: currentTimePassed,
                    onTap: () => _toggleCurrentPrayer(currentPrayer, tracker),
                  ),
                ],

                // ═══════════════════════════════════════════════════════
                //  EXPANDED CONTENT: Pristine daily list schedule
                // ═══════════════════════════════════════════════════════
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
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
                                            color:
                                                Colors.white.withOpacity(0.55),
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
                //  COLLAPSE / EXPAND HANDLE
                // ═══════════════════════════════════════════════════════
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: _toggleExpand,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded
                              ? "Tap to collapse"
                              : "View full schedule",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESSENTIALS SECTION
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
        // Section Header (uppercase, letter-spaced)
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 14, color: qt.emeraldLight),
            const SizedBox(width: 8),
            Text(
              "ESSENTIALS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: qt.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
                MainNavigation.pushOnShell(context, const DuasScreen());
              },
              qt: qt,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 2: Hadith Library — premium list tile style
        _PremiumEssentialTile(
          icon: FlutterIslamicIcons.solidMohammad,
          iconColor: qt.brightness == Brightness.dark
              ? const Color(0xFFFFB74D)
              : Colors.blue.shade600,
          iconBg: qt.brightness == Brightness.dark
              ? const Color(0xFFFFB74D).withOpacity(0.12)
              : const Color(0xFFE3F2FD),
          title: "Hadith Library",
          subtitle: "Browse authentic narrations",
          onTap: () {
            MainNavigation.pushOnShell(context, const HadithHomeScreen());
          },
          qt: qt,
        ),
        const SizedBox(height: 16),

        // Row 3: Hijri Calendar
        _PremiumEssentialTile(
          icon: Icons.calendar_month_rounded,
          iconColor: qt.brightness == Brightness.dark
              ? const Color(0xFFFFB74D)
              : Colors.blue.shade600,
          iconBg: qt.brightness == Brightness.dark
              ? const Color(0xFFFFB74D).withOpacity(0.12)
              : const Color(0xFFE3F2FD),
          title: "Hijri Calendar",
          subtitle: "View Islamic events and dates",
          onTap: () {
            MainNavigation.pushOnShell(context, const HijriCalendarScreen());
          },
          qt: qt,
        ),
        const SizedBox(height: 16),

        // ─── Expandable: Qibla + Prayer Stats ───
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
              Consumer<PrayerTracker>(
                builder: (context, tracker, _) {
                  final todayCount = tracker.todayPrayedCount;
                  final streak = tracker.currentStreak;
                  return _PremiumEssentialTile(
                    icon: Icons.mosque_rounded,
                    iconColor: Colors.green.shade600,
                    iconBg: Colors.green.withOpacity(
                      qt.brightness == Brightness.dark ? 0.12 : 0.08,
                    ),
                    title: "Prayer Stats",
                    subtitle: todayCount > 0
                        ? "$todayCount/5 today · $streak-day streak"
                        : "Check your prayer consistency",
                    onTap: () {
                      MainNavigation.pushOnShell(
                          context, const PrayerStatsScreen());
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

        const SizedBox(height: 16),

        // ─── Modern Toggle Pill with subtle border and fill ───
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _isExpanded = !_isExpanded);
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.05),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: qt.emeraldDeep.withOpacity(0.15),
                  width: 1.0,
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
                  const SizedBox(width: 8),
                  Text(
                    _isExpanded ? "Show Less" : "More Tools",
                    style: TextStyle(
                      color: qt.emeraldDeep,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
// ASMA SLIDER
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
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: qt.emeraldLight),
                const SizedBox(width: 8),
                Text(
                  "ASMA UL HUSNA",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: qt.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                MainNavigation.pushOnShell(context, const AsmaListScreen());
              },
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
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: qt.cardBg,
                                  borderRadius: BorderRadius.circular(24),
                                  // THE CHANGE: Switch hard border colors of cards to ultra-soft glass boundaries
                                  border: Border.all(
                                    color: qt.borderGlass.withOpacity(0.12),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        qt.brightness == Brightness.dark
                                            ? 0.15
                                            : 0.04,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
        // Section Header
        Row(
          children: [
            Icon(Icons.format_quote_rounded, size: 14, color: qt.emeraldLight),
            const SizedBox(width: 8),
            Text(
              "GUIDANCE FROM QURAN",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: qt.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
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
          HapticFeedback.lightImpact();
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
            // THE CHANGE: Switch hard border colors of cards to ultra-soft glass boundaries
            border: Border.all(
              color: qt.borderGlass.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
// HADITH SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _HadithSection extends StatelessWidget {
  final Future<Hadith?>? future;
  final QuranTheme qt;

  const _HadithSection({required this.future, required this.qt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section Header
        Row(
          children: [
            Icon(FlutterIslamicIcons.solidMohammad,
                size: 14, color: qt.emeraldLight),
            const SizedBox(width: 8),
            Text(
              "GUIDANCE FROM SUNNAH",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: qt.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<Hadith?>(
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
                "Unable to load Hadith",
                style: TextStyle(color: qt.textMuted),
              );
            }
            return SizedBox(
              width: double.infinity,
              child: _HadithCard(hadith: snapshot.data!, qt: qt),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HADITH CARD
// ═══════════════════════════════════════════════════════════════════════════

class _HadithCard extends StatelessWidget {
  final Hadith hadith;
  final QuranTheme qt;

  const _HadithCard({required this.hadith, required this.qt});

  String _bookNameFromAsset(String assetPath) {
    final fileName =
        assetPath.split('/').last.replaceAll('.db', '').replaceAll('.json', '');
    if (fileName == 'riyad_assalihin') return 'Riyad as Salihin';
    // Map DB file names to display names via the spec registry.
    for (final spec in HadithDb.flatBooks) {
      if (spec.assetPath.contains(fileName)) return spec.name;
    }
    return fileName.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    // Derive a clean book name from the asset path.
    final bookTitle = _bookNameFromAsset(hadith.bookAsset);

    return RepaintBoundary(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              MainNavigation.pushOnShell(
                context,
                HadithReaderScreen(
                  hadith: hadith,
                  bookTitle: bookTitle,
                  chapterTitle: hadith.chapterTitle,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: qt.cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: qt.borderGlass.withOpacity(0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hadith.title.isNotEmpty) ...[
                    Text(
                      hadith.title,
                      style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    hadith.narrator,
                    style: TextStyle(
                      fontSize: 13,
                      color: qt.emeraldDeep,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hadith.englishText
                        .trim()
                        .split('\n\n')
                        .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
                        .join('\n\n'),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 14,
                      color: qt.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Book name badge (tappable)
                      GestureDetector(
                        onTap: () {
                          final chapter = HadithChapter(
                            num: '',
                            englishTitle: hadith.chapterTitle,
                            arabicTitle: '',
                            hadithList: const [],
                            hadithCount: 0,
                            chapterKey: hadith.chapterTitle,
                          );
                          MainNavigation.pushOnShell(
                            context,
                            HadithChapterScreen(
                              chapter: chapter,
                              bookAsset: hadith.bookAsset,
                              bookName: bookTitle,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  size: 11, color: qt.emeraldDeep),
                              const SizedBox(width: 5),
                              Text(
                                bookTitle,
                                style: TextStyle(
                                  color: qt.emeraldDeep,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Chapter badge (tappable)
                      if (hadith.chapterTitle.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            final chapter = HadithChapter(
                              num: '',
                              englishTitle: hadith.chapterTitle,
                              arabicTitle: '',
                              hadithList: const [],
                              hadithCount: 0,
                              chapterKey: hadith.chapterTitle,
                            );
                            MainNavigation.pushOnShell(
                              context,
                              HadithChapterScreen(
                                chapter: chapter,
                                bookAsset: hadith.bookAsset,
                                bookName: bookTitle,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: qt.emeraldDeep.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_outlined,
                                    size: 11, color: qt.emeraldDeep),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    hadith.chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: qt.emeraldDeep,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (hadith.localNum.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tag_rounded,
                                  size: 11, color: qt.emeraldDeep),
                              const SizedBox(width: 5),
                              Text(
                                'Hadith #${hadith.localNum}',
                                style: TextStyle(
                                  color: qt.emeraldDeep,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESSENTIAL CARD — square tile style
// ═══════════════════════════════════════════════════════════════════════════

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
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 160,
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(24),
              // THE CHANGE: Switch hard border colors of cards to ultra-soft glass boundaries
              border: Border.all(
                color: qt.borderGlass.withOpacity(0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                )
              ],
            ),
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

/// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM ESSENTIAL TILE — horizontal list tile style matching menu_screen
/// ═══════════════════════════════════════════════════════════════════════════

class _PremiumEssentialTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final QuranTheme qt;

  const _PremiumEssentialTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            // THE CHANGE: Switch hard border colors of cards to ultra-soft glass boundaries
            border: Border.all(
              color: qt.borderGlass.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
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
// QIBLA COMPASS CARD
/// ═══════════════════════════════════════════════════════════════════════════

class _QiblaCompassCard extends StatefulWidget {
  final double? qiblaDirection;
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
    HapticFeedback.lightImpact();
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

    if (direction == null) {
      return _buildEmptyCard(qt);
    }

    if (!_hasCompass) {
      return _buildStaticInfo(qt, direction, canActivate: false);
    }

    if (!_isActive) {
      return _buildStaticInfo(qt, direction,
          canActivate: true, onTap: _toggleActive);
    }

    return _buildLiveCompass(qt, direction);
  }

  Widget _buildEmptyCard(QuranTheme qt) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(24),
          // THE CHANGE: Switch hard border colors of cards to ultra-soft glass boundaries
          border: Border.all(
            color: qt.borderGlass.withOpacity(0.12),
            width: 1.0,
          ),
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
            // THE CHANGE: Switch hard border colors of cards to ultra-soft glass boundaries
            border: Border.all(
              color: qt.borderGlass.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
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

  Widget _buildLiveCompass(QuranTheme qt, double direction) {
    final rotation =
        _deviceHeading != null ? (direction - _deviceHeading!) : direction;
    final isAligned = _isAligned;
    final dirName = _getDirectionName(direction);
    final degreeText = "${direction.toStringAsFixed(0)}°";

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _toggleActive,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              // THE CHANGE: Switching heavy borders to active state color transitions
              color:
                  isAligned ? qt.emeraldDeep : qt.emeraldDeep.withOpacity(0.3),
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
