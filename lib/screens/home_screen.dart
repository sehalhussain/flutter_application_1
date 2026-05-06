import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/name_model.dart';
import '../models/quran_models.dart';
import '../providers/quran_progress_provider.dart';
import 'asma_list_screen.dart';
import 'package:provider/provider.dart';
import 'hadith/hadith_home_screen.dart';
import 'quran/quran_home_screen.dart';
import 'quran/quran_reader_screen.dart';
import '../services/quran_service.dart';
import '../constants/quran_theme.dart';
import '../services/prayer_service.dart';
import 'prayer_screen.dart';
import 'duas_screen.dart';
import 'hijri_calendar_screen.dart';
import 'dart:async';
import 'package:intl/intl.dart' hide TextDirection;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<AyahData>? _ayahFuture;
  Future<List<AsmaName>>? _namesFuture;
  Map<String, dynamic>? _todayTimings;
  Timer? _timer;

  final ScrollController _namesScrollController = ScrollController();
  int _namesLimit = 20;

  @override
  void initState() {
    super.initState();
    _refreshAyah();
    _initPrayerTimings();
    _namesFuture = DataService.loadNames();

    _namesScrollController.addListener(() {
      if (_namesScrollController.position.pixels >=
          _namesScrollController.position.maxScrollExtent - 400) {
        if (_namesLimit < 99) {
          setState(() {
            _namesLimit += 20;
          });
        }
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _namesScrollController.dispose();
    super.dispose();
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
    setState(() {
      _ayahFuture = QuranService.instance.getRandomAyah();
    });
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _namesFuture = DataService.loadNames();
      _namesLimit = 20;
      _refreshAyah();
    });

    // Wait for everything to load before dismissing the refresh indicator
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
              Column(
                children: [
                  Text(_getGreeting(),
                      style: TextStyle(
                          fontSize: 11,
                          color: qt.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0)),
                  const SizedBox(height: 8),
                  if (_todayTimings != null) ...[
                    Text(
                        "${_todayTimings!['date']['gregorian']['day']} ${_todayTimings!['date']['gregorian']['month']['en']}",
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: qt.textPrimary)),
                    Text(
                        "${_todayTimings!['date']['hijri']['day']} ${_todayTimings!['date']['hijri']['month']['en']} ${_todayTimings!['date']['hijri']['year']} AH",
                        style: TextStyle(
                            color: qt.emeraldDeep,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // --- LAST READ BANNER ---
              Consumer<QuranProgress>(
                builder: (context, progress, child) {
                  final lastRead = progress.lastRead;
                  if (lastRead == null) return const SizedBox.shrink();
                  return _buildLastReadBanner(context, lastRead, qt);
                },
              ),
              const SizedBox(height: 10),

              // --- PRAYER CARD ---
              _buildPrayerCard(qt, _todayTimings),
              const SizedBox(height: 32),

              // --- ESSENTIALS SECTION ---
              Text("Essentials",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: qt.textPrimary)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildEssentialCard(
                    "Holy Quran",
                    "Read, Listen & Reflect",
                    qt.emeraldDeep.withOpacity(0.12),
                    Icons.menu_book,
                    qt.emeraldDeep,
                    onTap: () async {
                      final surahs =
                          await QuranService.instance.loadSurahList();
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QuranHomeScreen()),
                      ).then((_) => _refreshAyah()); // Refresh when coming back
                    },
                    qt: qt,
                  ),
                  const SizedBox(width: 16),
                  _buildEssentialCard(
                    "Daily Duas",
                    "Authentic Supplications",
                    const Color(0xFFFFF0D1).withOpacity(
                        qt.brightness == Brightness.dark ? 0.15 : 1.0),
                    Icons.front_hand,
                    const Color(0xFFFFB74D),
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
              _buildWideEssentialCard(
                "Hadith Library",
                "Browse authentic narrations and save your favorites",
                Color.fromRGBO(255, 243, 224,
                    qt.brightness == Brightness.dark ? 0.15 : 1.0),
                Icons.menu_book_rounded,
                const Color(0xFFEF6C00),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HadithHomeScreen()),
                  );
                },
                qt: qt,
              ),
              const SizedBox(height: 16),
              _buildWideEssentialCard(
                "Hijri Calendar",
                _todayTimings != null
                    ? "${_todayTimings!['date']['hijri']['day']} ${_todayTimings!['date']['hijri']['month']['en']}, ${_todayTimings!['date']['hijri']['year']} AH • View Islamic Events"
                    : "View Islamic Events",
                const Color(0xFFE3F2FD)
                    .withOpacity(qt.brightness == Brightness.dark ? 0.15 : 1.0),
                Icons.calendar_month_rounded,
                Colors.blue.shade600,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HijriCalendarScreen()),
                  );
                },
                qt: qt,
              ),

              const SizedBox(height: 32),

              // --- ASMA UL HUSNA SLIDER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Asma ul Husna",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AsmaListScreen())),
                    child: Text("View All",
                        style: TextStyle(
                            color: qt.emeraldDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAsmaSlider(context, qt),

              const SizedBox(height: 32),

              // --- AYAH OF THE DAY ---
              Text("Guidance from Quran",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: qt.textPrimary)),
              const SizedBox(height: 16),
              FutureBuilder<AyahData>(
                future: _ayahFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: qt.emeraldDeep),
                    ));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Text("Unable to load Ayah",
                        style: TextStyle(color: qt.textMuted));
                  }
                  return _buildAyahCard(snapshot.data!, qt);
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        )));
  }

  Widget _buildAsmaSlider(BuildContext context, QuranTheme qt) {
    return FutureBuilder<List<AsmaName>>(
      future: _namesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120);
        }
        final names = snapshot.data!.take(_namesLimit).toList();

        return SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _namesScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: names.length,
            itemBuilder: (context, index) {
              final name = names[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: qt.borderGlass),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name.name,
                        style: TextStyle(
                            fontSize: 32,
                            color: qt.emeraldDeep,
                            fontFamily: 'QPC Hafs')),
                    const SizedBox(height: 4),
                    Text(name.transliteration,
                        style: TextStyle(
                            fontSize: 14,
                            color: qt.textPrimary,
                            fontWeight: FontWeight.bold)),
                    Text(name.meaning,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: qt.textMuted)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLastReadBanner(
      BuildContext context, LastReadPosition lr, QuranTheme qt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () async {
          final surahs = await QuranService.instance.loadSurahList();
          if (!mounted) return;
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
        title: Text("Last Read",
            style: TextStyle(
                color: qt.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        subtitle: Text("${lr.surahName} • Ayah ${lr.ayah}",
            style: TextStyle(
                color: qt.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        trailing: Icon(Icons.chevron_right, color: qt.textMuted),
      ),
    );
  }

  Widget _buildPrayerCard(QuranTheme qt, Map<String, dynamic>? timings) {
    if (timings == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        height: 200,
        decoration: BoxDecoration(
          color: qt.emeraldMid,
          borderRadius: BorderRadius.circular(24),
        ),
        child:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final pTimings = timings['timings'];
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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

    // calculate countdown
    final parts = nextTimeStr.split(':');
    var targetDate = DateTime(
        now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    if (targetDate.isBefore(now)) {
      targetDate = targetDate.add(const Duration(days: 1)); // next day fajr
    }
    final diff = targetDate.difference(now);
    final hours = diff.inHours.toString().padLeft(2, '0');
    final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
    final countdown = "-$hours:$mins:$secs";

    // format time 12hr
    String formatTime(String time) {
      final p = time.split(':');
      final dt = DateTime(2022, 1, 1, int.parse(p[0]), int.parse(p[1]));
      return DateFormat.jm().format(dt);
    }

    return Container(
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
                  Text("CURRENT: ${currentPrayer.toUpperCase()}",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  Text(formatTime(currentTimeStr),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("NEXT: ${nextPrayer.toUpperCase()}",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                  Text(formatTime(nextTimeStr),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Text(countdown,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
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
                _buildPrayerTime(
                    "Fajr",
                    formatTime(pTimings['Fajr'].toString().split(' ')[0]),
                    nextPrayer == 'Fajr'),
                _buildDivider(),
                _buildPrayerTime(
                    "Dhuhr",
                    formatTime(pTimings['Dhuhr'].toString().split(' ')[0]),
                    nextPrayer == 'Dhuhr'),
                _buildDivider(),
                _buildPrayerTime(
                    "Asr",
                    formatTime(pTimings['Asr'].toString().split(' ')[0]),
                    nextPrayer == 'Asr'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTime(String name, String time, bool isNext) {
    return Column(
      children: [
        Text(name,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 4),
        Text(time,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(height: 20, width: 1, color: Colors.white.withOpacity(0.2));

  Widget _buildEssentialCard(String title, String subtitle, Color color,
      IconData icon, Color iconColor,
      {required VoidCallback onTap, required QuranTheme qt}) {
    return Expanded(
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
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: qt.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11, color: qt.textMuted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideEssentialCard(String title, String subtitle, Color color,
      IconData icon, Color iconColor,
      {required VoidCallback onTap, required QuranTheme qt}) {
    return GestureDetector(
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
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: qt.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: qt.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahCard(AyahData ayah, QuranTheme qt) {
    return GestureDetector(
      onTap: () async {
        final surahs = await QuranService.instance.loadSurahList();
        if (!mounted) return;
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
                  color: qt.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              ayah.translation,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, color: qt.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    letterSpacing: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
