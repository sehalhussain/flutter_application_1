import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../services/data_service.dart';
import '../models/name_model.dart';
import '../models/quran_models.dart';
import '../providers/quran_progress_provider.dart';
import '../services/quran_service.dart';
import '../constants/quran_theme.dart';
import '../services/prayer_service.dart';

import 'asma_list_screen.dart';
import 'hadith/hadith_home_screen.dart';
import 'quran/quran_home_screen.dart';
import 'quran/quran_reader_screen.dart';
import 'prayer_screen.dart';
import 'duas_screen.dart';
import 'hijri_calendar_screen.dart';

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

              // --- LAST READ BANNER ---
              Consumer<QuranProgress>(
                builder: (context, progress, child) {
                  final lastRead = progress.lastRead;
                  if (lastRead == null) return const SizedBox.shrink();
                  return _LastReadBanner(lr: lastRead, qt: qt);
                },
              ),
              const SizedBox(height: 10),

              // --- PRAYER CARD (with isolated countdown) ---
              _PrayerCard(timings: _todayTimings, qt: qt),
              const SizedBox(height: 32),

              // --- ESSENTIALS SECTION ---
              _EssentialsSection(qt: qt, onRefreshAyah: _refreshAyah),
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
// LAST READ BANNER ( Extracted widget — localized rebuilds )
// ═══════════════════════════════════════════════════════════════════════════

class _LastReadBanner extends StatelessWidget {
  final LastReadPosition lr;
  final QuranTheme qt;

  const _LastReadBanner({required this.lr, required this.qt});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: qt.borderGlass),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          onTap: () async {
            final surahs = await QuranService.instance.loadSurahList();
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuranReaderScreen(
                  surahNumber: lr.surah,
                  initialAyah: lr.ayah,
                  surahList: surahs,
                ),
              ),
            );
          },
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.menu_book, color: qt.emeraldDeep, size: 24),
          ),
          title: Text(
            "Last Read",
            style: TextStyle(
              color: qt.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "${lr.surahName} • Ayah ${lr.ayah}",
            style: TextStyle(
              color: qt.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: qt.textMuted),
        ),
      ),
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

  const _PrayerCard({required this.timings, required this.qt});

  @override
  State<_PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<_PrayerCard> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;
    final timings = widget.timings;

    if (timings == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        height: 200,
        decoration: BoxDecoration(
          color: qt.emeraldMid,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
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
    final hours = diff.inHours.toString().padLeft(2, '0');
    final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
    final countdown = "-$hours:$mins:$secs";

    String formatTime(String time) {
      final p = time.split(':');
      final dt = DateTime(2022, 1, 1, int.parse(p[0]), int.parse(p[1]));
      return DateFormat.jm().format(dt);
    }

    final otherPrayers = prayerOrder
        .where((p) => p != currentPrayer && p != nextPrayer)
        .toList();

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [qt.emeraldDeep, qt.emeraldMid],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CURRENT: ${currentPrayer.toUpperCase()}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      formatTime(currentTimeStr),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "NEXT: ${nextPrayer.toUpperCase()}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      formatTime(nextTimeStr),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      countdown,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PrayerTime(
                    name: otherPrayers[0],
                    time: formatTime(
                        pTimings[otherPrayers[0]].toString().split(' ')[0]),
                    isNext: false,
                  ),
                  _PrayerDivider(),
                  _PrayerTime(
                    name: otherPrayers[1],
                    time: formatTime(
                        pTimings[otherPrayers[1]].toString().split(' ')[0]),
                    isNext: false,
                  ),
                  _PrayerDivider(),
                  _PrayerTime(
                    name: otherPrayers[2],
                    time: formatTime(
                        pTimings[otherPrayers[2]].toString().split(' ')[0]),
                    isNext: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTime extends StatelessWidget {
  final String name;
  final String time;
  final bool isNext;

  const _PrayerTime({
    required this.name,
    required this.time,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PrayerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESSENTIALS SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _EssentialsSection extends StatelessWidget {
  final QuranTheme qt;
  final VoidCallback onRefreshAyah;

  const _EssentialsSection({required this.qt, required this.onRefreshAyah});

  @override
  Widget build(BuildContext context) {
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
        Row(
          children: [
            _EssentialCard(
              title: "Holy Quran",
              subtitle: "Read, Listen & Reflect",
              color: qt.emeraldDeep.withOpacity(0.12),
              icon: Icons.menu_book,
              iconColor: qt.emeraldDeep,
              onTap: () async {
                final surahs = await QuranService.instance.loadSurahList();
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranHomeScreen()),
                ).then((_) => onRefreshAyah());
              },
              qt: qt,
            ),
            const SizedBox(width: 16),
            _EssentialCard(
              title: "Daily Duas",
              subtitle: "Authentic Supplications",
              color: const Color(0xFFFFF0D1).withOpacity(
                qt.brightness == Brightness.dark ? 0.15 : 1.0,
              ),
              icon: Icons.front_hand,
              iconColor: const Color(0xFFFFB74D),
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
        _WideEssentialCard(
          title: "Hadith Library",
          subtitle: "Browse authentic narrations and save your favorites",
          color: Color.fromRGBO(
            255,
            243,
            224,
            qt.brightness == Brightness.dark ? 0.15 : 1.0,
          ),
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFFEF6C00),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HadithHomeScreen()),
            );
          },
          qt: qt,
        ),
        const SizedBox(height: 16),
        _WideEssentialCard(
          title: "Hijri Calendar",
          subtitle: qt.brightness == Brightness.dark
              ? "View Islamic Events"
              : "View Islamic Events",
          color: const Color(0xFFE3F2FD).withOpacity(
            qt.brightness == Brightness.dark ? 0.15 : 1.0,
          ),
          icon: Icons.calendar_month_rounded,
          iconColor: Colors.blue.shade600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HijriCalendarScreen()),
            );
          },
          qt: qt,
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
            padding: const EdgeInsets.all(20),
            height: 180,
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: qt.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: qt.textMuted,
                    height: 1.3,
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
