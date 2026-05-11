import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import '../constants/quran_theme.dart';
import '../constants/locations.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────
//  Hijri month names (1-indexed)
// ─────────────────────────────────────────────────────────
const List<String> _hijriMonthNames = [
  '', // placeholder for 1-indexed access
  'Muharram',
  'Safar',
  'Rabi\' al-Awwal',
  'Rabi\' al-Thani',
  'Jumada al-Awwal',
  'Jumada al-Thani',
  'Rajab',
  'Sha\'ban',
  'Ramadan',
  'Shawwal',
  'Dhu al-Qi\'dah',
  'Dhu al-Hijjah',
];

// ─────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────
class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  // Current Hijri month/year we are browsing
  int _hijriMonth = 1;
  int _hijriYear = 1446;

  List<dynamic>? _calendarData;
  bool _isLoading = true;
  bool _hasError = false;

  // Today's Hijri date (extracted from first successful load)
  int? _todayHijriDay;
  int? _todayHijriMonth;
  int? _todayHijriYear;

  @override
  void initState() {
    super.initState();
    _initWithToday();
  }

  // ── Derive today's Hijri date from the timings cache, then load calendar ──
  Future<void> _initWithToday() async {
    final timings = await PrayerService.instance.getTodayTimings();
    if (timings != null && mounted) {
      final hijri = timings['date']['hijri'];
      _todayHijriDay = int.tryParse(hijri['day'].toString());
      _todayHijriMonth = int.tryParse(hijri['month']['number'].toString());
      _todayHijriYear = int.tryParse(hijri['year'].toString());

      if (_todayHijriMonth != null && _todayHijriYear != null) {
        _hijriMonth = _todayHijriMonth!;
        _hijriYear = _todayHijriYear!;
      }
    }
    _fetchCalendar();
  }

  Future<void> _fetchCalendar() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _calendarData = null;
    });

    final data = await PrayerService.instance
        .getHijriCalendarByMonth(_hijriYear, _hijriMonth);

    if (!mounted) return;
    setState(() {
      _calendarData = data;
      _isLoading = false;
      _hasError = data == null;
    });
  }

  void _prevMonth() {
    setState(() {
      _hijriMonth--;
      if (_hijriMonth < 1) {
        _hijriMonth = 12;
        _hijriYear--;
      }
    });
    _fetchCalendar();
  }

  void _nextMonth() {
    setState(() {
      _hijriMonth++;
      if (_hijriMonth > 12) {
        _hijriMonth = 1;
        _hijriYear++;
      }
    });
    _fetchCalendar();
  }

  // ── Gregorian date-range string for the current Hijri month ──
  String _gregorianRange() {
    if (_calendarData == null || _calendarData!.isEmpty) return '';
    final first = _calendarData!.first['date']['gregorian'];
    final last = _calendarData!.last['date']['gregorian'];

    String fmt(Map<dynamic, dynamic> g) {
      final parts = g['date'].toString().split('-');
      // format: DD-MM-YYYY
      final dt = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      return DateFormat('MMM d').format(dt);
    }

    final lastYear = last['year'].toString();
    return '${fmt(first)} – ${fmt(last)}, $lastYear';
  }

  // ── Is a day entry "today"? ──
  bool _isToday(Map<dynamic, dynamic> dayData) {
    if (_todayHijriDay == null ||
        _todayHijriMonth == null ||
        _todayHijriYear == null) return false;
    final h = dayData['date']['hijri'];
    return int.tryParse(h['day'].toString()) == _todayHijriDay &&
        int.tryParse(h['month']['number'].toString()) == _todayHijriMonth &&
        int.tryParse(h['year'].toString()) == _todayHijriYear;
  }

  // ── Extract holidays list from a day entry ──
  List<String> _holidays(Map<dynamic, dynamic> dayData) {
    final hols = dayData['date']['hijri']['holidays'];
    if (hols == null) return [];
    return List<String>.from(hols as List);
  }

  // ── Start-of-week offset for first day of the Hijri month ──
  int _startOffset() {
    if (_calendarData == null || _calendarData!.isEmpty) return 0;
    final parts =
        _calendarData!.first['date']['gregorian']['date'].toString().split('-');
    final dt = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
    // weekday: Mon=1 … Sun=7 → Sun first column (index 0)
    return dt.weekday % 7; // Sun=0, Mon=1, ... Sat=6
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final monthName = _hijriMonth >= 1 && _hijriMonth <= 12
        ? _hijriMonthNames[_hijriMonth]
        : 'Month $_hijriMonth';
    final range = _gregorianRange();

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // --- IMMERSIVE HEADER SECTION ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
            ),
            child: Column(
              children: [
                // Top row: Back button only
                Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 48, height: 48),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
                const SizedBox(height: 10),

                // Month Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavButton(Icons.chevron_left, _prevMonth),
                    Column(
                      children: [
                        Text(monthName,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Text('$_hijriYear AH',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                letterSpacing: 1.2)),
                        if (range.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(range,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                      ],
                    ),
                    _buildNavButton(Icons.chevron_right, _nextMonth),
                  ],
                ),

                const SizedBox(height: 12),

                // Location - Centered below month, compact
                GestureDetector(
                  onTap: () => _showLocationBottomSheet(context, qt),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "${PrayerService.instance.currentCity ?? 'Unknown'}, ${PrayerService.instance.currentCountry ?? ''}",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- CONTENT AREA ---
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: qt.emeraldDeep),
                  )
                : _hasError
                    ? _buildError(qt)
                    : _buildBody(qt),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  BODY — grid + important dates
  // ══════════════════════════════════════════════════════
  Widget _buildBody(QuranTheme qt) {
    final data = _calendarData!;
    final offset = _startOffset();
    final totalCells = offset + data.length;

    // ── Collect events for the "Important Dates" list ──
    final events = <Map<dynamic, dynamic>>[];
    for (final day in data) {
      final hols = _holidays(day);
      if (hols.isNotEmpty) events.add(day);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Weekday Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: TextStyle(
                              color: qt.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),

        // Calendar grid
        _buildGrid(qt, data, offset, totalCells),
        const SizedBox(height: 28),

        // Important dates
        if (events.isNotEmpty) ...[
          _buildSectionTitle("Important Dates", qt),
          const SizedBox(height: 14),
          ...events.map((day) => _buildEventCard(qt, day)),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, QuranTheme qt) {
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
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: qt.textPrimary)),
      ],
    );
  }

  // ── Calendar grid ──
  Widget _buildGrid(
    QuranTheme qt,
    List<dynamic> data,
    int offset,
    int totalCells,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.85,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox.shrink();

        final dayData = data[index - offset] as Map<dynamic, dynamic>;
        final hijriDay = dayData['date']['hijri']['day'].toString();
        final gregDay = dayData['date']['gregorian']['day'].toString();
        final hols = _holidays(dayData);
        final today = _isToday(dayData);
        final hasEvent = hols.isNotEmpty;

        return _DayCell(
          hijriDay: hijriDay,
          gregDay: gregDay,
          isToday: today,
          hasEvent: hasEvent,
          qt: qt,
          onTap: hasEvent
              ? () => _showDayDetail(context, qt, dayData, hols)
              : null,
        );
      },
    );
  }

  // ── Event Card ──
  Widget _buildEventCard(QuranTheme qt, Map<dynamic, dynamic> day) {
    final h = day['date']['hijri'];
    final g = day['date']['gregorian'];
    final hols = _holidays(day);
    final hDay = h['day'].toString();
    final hMonth = h['month']['en'].toString();
    final gDay = g['day'].toString();
    final gMonth = g['month']['en'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: qt.emeraldDeep.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(hDay,
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
        title: Text(
          hols.join(' • '),
          style: TextStyle(
              color: qt.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '$hDay $hMonth  •  $gDay $gMonth',
            style: TextStyle(color: qt.textMuted, fontSize: 11),
          ),
        ),
        trailing: Icon(Icons.star_rounded, color: qt.emeraldDeep, size: 18),
      ),
    );
  }

  // ── Error state ──
  Widget _buildError(QuranTheme qt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: qt.textMuted),
          const SizedBox(height: 16),
          Text('Could not load calendar',
              style: TextStyle(
                  color: qt.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Check your internet connection and try again.',
              style: TextStyle(color: qt.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: qt.emeraldDeep,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            onPressed: _fetchCalendar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Day detail bottom sheet ──
  void _showDayDetail(
    BuildContext context,
    QuranTheme qt,
    Map<dynamic, dynamic> dayData,
    List<String> hols,
  ) {
    final h = dayData['date']['hijri'];
    final g = dayData['date']['gregorian'];
    final hDay = h['day'].toString();
    final hMonth = h['month']['en'].toString();
    final hYear = h['year'].toString();
    final gDay = g['day'].toString();
    final gMonth = g['month']['en'].toString();
    final gYear = g['year'].toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: qt.borderGlass,
                      borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.star_rounded, color: qt.emeraldDeep, size: 26),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$hDay $hMonth $hYear AH',
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                    Text('$gDay $gMonth $gYear',
                        style: TextStyle(color: qt.textMuted, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...hols.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: qt.emeraldDeep, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(h,
                            style: TextStyle(
                                color: qt.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Location picker sheet ──
  void _showLocationBottomSheet(BuildContext context, QuranTheme qt) {
    String q = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          final filtered = POPULAR_LOCATIONS.where((loc) {
            final text = '${loc['city']} ${loc['country']}'.toLowerCase();
            return text.contains(q.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.68,
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setModal(() => q = v),
                        style: TextStyle(color: qt.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search city...',
                          hintStyle: TextStyle(color: qt.textMuted),
                          prefixIcon: Icon(Icons.search, color: qt.textMuted),
                          filled: true,
                          fillColor: qt.cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14)),
                      child: IconButton(
                        icon: Icon(Icons.my_location, color: qt.emeraldDeep),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          await PrayerService.instance.fetchDeviceLocation();
                          _fetchCalendar();
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final loc = filtered[i];
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
                            _fetchCalendar();
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
}

// ─────────────────────────────────────────────────────────
//  Individual Day Cell widget
// ─────────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final String hijriDay;
  final String gregDay;
  final bool isToday;
  final bool hasEvent;
  final QuranTheme qt;
  final VoidCallback? onTap;

  const _DayCell({
    required this.hijriDay,
    required this.gregDay,
    required this.isToday,
    required this.hasEvent,
    required this.qt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isToday
        ? qt.emeraldDeep
        : hasEvent
            ? qt.emeraldDeep.withOpacity(0.1)
            : Colors.transparent;

    final border = isToday
        ? qt.emeraldDeep
        : hasEvent
            ? qt.emeraldDeep.withOpacity(0.4)
            : qt.borderGlass;

    final hijriColor = isToday ? Colors.white : qt.textPrimary;
    final gregColor = isToday ? Colors.white70 : qt.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: isToday ? 0 : 1),
          boxShadow: isToday
              ? [
                  BoxShadow(
                      color: qt.emeraldDeep.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(hijriDay,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hijriColor)),
                  const SizedBox(height: 1),
                  Text(gregDay,
                      style: TextStyle(fontSize: 9, color: gregColor)),
                ],
              ),
            ),
            if (hasEvent && !isToday)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: qt.emeraldDeep, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
