import 'dart:ui';
import 'package:flutter/material.dart';
import '/models/quran_models.dart';
import '/services/quran_service.dart';
import '/providers/quran_progress_provider.dart';
import '/constants/juz_data.dart';
import '/constants/quran_theme.dart';
import 'quran_reader_screen.dart';

class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen>
    with SingleTickerProviderStateMixin {
  List<SurahInfo> _surahList = [];
  List<SurahInfo> _filtered = [];
  bool _loading = true;
  String _search = '';
  int _tabIndex = 0; // 0=Surah 1=Juz 2=Bookmarks 3=Popular

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSurahs();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      final list = await QuranService.instance.loadSurahList();
      if (!mounted) return;
      setState(() {
        _surahList = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading surahs: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch(String q) {
    _search = q;
    final lq = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _surahList
          : _surahList
              .where((s) =>
                  s.nameEnglish.toLowerCase().contains(lq) ||
                  s.nameMeaning.toLowerCase().contains(lq) ||
                  s.nameArabic.contains(q) ||
                  '${s.number}'.contains(q))
              .toList();
    });
  }

  void _openReader(int surah, {int? initialAyah}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuranReaderScreen(
        surahNumber: surah,
        initialAyah: initialAyah,
        surahList: _surahList,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Scaffold(
      backgroundColor: qt.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _buildHeader(qt),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(qt.emeraldLight),
                        strokeWidth: 2))
                : _buildBody(qt),
          ),
          _buildBottomNav(qt),
        ]),
      ),
    );
  }

  Widget _buildHeader(QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: qt.bg,
        border: Border(bottom: BorderSide(color: qt.borderGlass)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: _glassButton(Icon(Icons.arrow_back_ios_new_rounded,
                color: qt.textPrimary, size: 18), qt),
          ),
          const Spacer(),
          Text('AL-QURAN',
            style: TextStyle(
                fontSize: 12,
                color: qt.textMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0)),
          const Spacer(),
          _glassButton(
              Icon(Icons.search_rounded, color: qt.textPrimary, size: 20), qt),
        ]),
        const SizedBox(height: 24),
        Text('القرآن الكريم',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'QPC Hafs',
                fontSize: 32,
                color: qt.brightness == Brightness.dark ? qt.emeraldGlow : qt.emeraldDeep,
                height: 1.2)),
        const SizedBox(height: 4),
        Text('The Holy Quran',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: qt.textPrimary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _glassButton(Widget child, QuranTheme qt) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildBody(QuranTheme qt) {
    // We use a single ListView.builder for all tabs to ensure lazy loading
    // and maximum performance.
    
    // Calculate total items based on current tab
    int itemCount = 0;
    if (_tabIndex == 0) itemCount = _filtered.length + 2; // +2 for Banner & Search
    else if (_tabIndex == 1) itemCount = kJuzData.length + 2;
    else if (_tabIndex == 2) itemCount = QuranProgressProvider.of(context).bookmarks.length + 2;
    else if (_tabIndex == 3) itemCount = kPopularSections.length + 2;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return _buildLastReadBanner(qt);
        if (index == 1) return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _buildSearchBar(qt),
        );
        
        final listIndex = index - 2;
        
        switch (_tabIndex) {
          case 0:
            if (_filtered.isEmpty) return _emptyState('No surahs found', qt);
            final s = _filtered[listIndex];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SurahTile(surah: s, onTap: () => _openReader(s.number)),
            );
          case 1:
            final j = kJuzData[listIndex];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _buildJuzTile(j, qt),
            );
          case 2:
            final bms = QuranProgressProvider.of(context).bookmarks;
            if (bms.isEmpty) return _emptyState('No bookmarks yet', qt);
            final bm = bms[listIndex];
            final s = _surahList.firstWhere((s) => s.number == bm.surah, orElse: () => _surahList.first);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SurahTile(surah: s, onTap: () => _openReader(bm.surah, initialAyah: bm.ayah)),
            );
          case 3:
            final item = kPopularSections[listIndex];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _buildPopularTile(item, qt),
            );
          default:
            return const SizedBox();
        }
      },
    );
  }

  Widget _emptyState(String text, QuranTheme qt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Text(text, style: TextStyle(color: qt.textMuted, fontSize: 16)),
      ),
    );
  }

  Widget _buildLastReadBanner(QuranTheme qt) {
    final progress = QuranProgressProvider.of(context);
    final lr = progress.lastRead;
    if (lr == null) return const SizedBox(height: 16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: GestureDetector(
        onTap: () => _openReader(lr.surah, initialAyah: lr.ayah),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.menu_book_rounded,
                  color: qt.emeraldDeep, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONTINUE READING',
                    style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(lr.surahName,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text('Ayah ${lr.ayah}',
                    style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 13)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _buildSearchBar(QuranTheme qt) {
    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: qt.borderGlass),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: qt.textPrimary, fontSize: 15),
        cursorColor: qt.emeraldLight,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: 'Search surah name, number…',
          hintStyle: TextStyle(color: qt.textMuted, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: qt.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildJuzTile(JuzEntry j, QuranTheme qt) {
    return GestureDetector(
      onTap: () => _openReader(j.startSurah, initialAyah: j.startAyah),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Juz ${j.juzNumber}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Starts at ${j.startSurahName}',
                  style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text('Surah ${j.startSurah}, Ayah ${j.startAyah}',
                  style: TextStyle(color: qt.textMuted, fontSize: 11)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _buildPopularTile(PopularSection item, QuranTheme qt) {
    return GestureDetector(
      onTap: () => _openReader(item.surahNumber, initialAyah: item.startAyah),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Icon(Icons.star_rounded, color: Colors.white, size: 22))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  style: TextStyle(
                      color: qt.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text(item.arabicTitle,
                  style: TextStyle(
                      fontFamily: 'QPC Hafs',
                      color: qt.textSecondary,
                      fontSize: 16)),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 18),
        ]),
      ),
    );
  }

  Widget _buildBottomNav(QuranTheme qt) {
    const tabs = [
      (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Surah'),
      (Icons.layers_outlined, Icons.layers_rounded, 'Juz'),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Bookmarks'),
      (Icons.star_border_rounded, Icons.star_rounded, 'Popular'),
    ];
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 4, top: 4),
      decoration: BoxDecoration(
        color: qt.cardBg,
        border: Border(top: BorderSide(color: qt.borderGlass)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? tabs[i].$2 : tabs[i].$1, color: active ? qt.emeraldDeep : qt.textMuted),
                  Text(tabs[i].$3, style: TextStyle(color: active ? qt.emeraldDeep : qt.textMuted, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahInfo surah;
  final VoidCallback onTap;
  const _SurahTile({required this.surah, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: qt.borderGlass),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [qt.emeraldDeep, qt.emeraldMid]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text('${surah.number}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(surah.nameEnglish, style: TextStyle(color: qt.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(surah.nameMeaning, style: TextStyle(color: qt.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Row(children: [
                  _pill(surah.revelationType, surah.revelationType == 'Meccan' ? const Color(0xFF78350F) : const Color(0xFF1E3A5F), qt),
                  const SizedBox(width: 6),
                  _pill('${surah.totalAyahs} Ayahs', qt.emeraldDeep, qt),
                ]),
              ],
            )),
            Text(surah.nameArabic,
                style: TextStyle(fontFamily: 'QPC Hafs', fontSize: 22, color: qt.emeraldDeep)),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String label, Color bg, QuranTheme qt) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: bg, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}
