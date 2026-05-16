import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../models/dua_model.dart';
import '../constants/quran_theme.dart';
import '../providers/dua_settings_provider.dart';
import 'dart:ui';

// ═══════════════════════════════════════════════════════════════════════════
// ISOLATE-FRIENDLY JSON PARSER
// ═══════════════════════════════════════════════════════════════════════════

List<Dua> _parseDuas(String jsonString) {
  final List<dynamic> parsed = jsonDecode(jsonString);
  return parsed.map((item) => Dua.fromJson(item)).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Debounce timer for search
  Timer? _debounceTimer;

  Future<List<Dua>>? _morningFuture;
  Future<List<Dua>>? _eveningFuture;
  Future<List<Dua>>? _duasFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _morningFuture = _loadDuasInIsolate('assets/data/duas/morning-adhkar.json');
    _eveningFuture = _loadDuasInIsolate('assets/data/duas/Evening-adhkar.json');
    _duasFuture = _loadDuasInIsolate('assets/data/duas/duas.json');

    _searchController.addListener(_onSearchChanged);
  }

  /// Debounced search: waits 300ms after user stops typing before filtering.
  /// This prevents rebuilding the entire list on every keystroke.
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.toLowerCase());
      }
    });
  }

  Future<List<Dua>> _loadDuasInIsolate(String path) async {
    final jsonString = await rootBundle.loadString(path);
    return compute(_parseDuas, jsonString);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Dua> _filter(List<Dua> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((d) {
      return d.title.toLowerCase().contains(_searchQuery) ||
          d.arabic.contains(_searchQuery) ||
          d.translation.toLowerCase().contains(_searchQuery) ||
          (d.latin?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const DuaSettingsSheet(),
    );
  }

  Widget _glassBtn(Widget child, QuranTheme qt) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: qt.glassWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: qt.borderGlass),
            ),
            child: Center(child: child),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Scaffold(
      backgroundColor: qt.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: qt.cardBg,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: const FlexibleSpaceBar(background: _Banner()),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: GestureDetector(
                  onTap: _openSettings,
                  child: Center(
                    child: _glassBtn(
                        const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 18),
                        qt),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(96),
              child: Container(
                color: qt.cardBg,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: qt.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search duas...',
                          hintStyle: TextStyle(color: qt.textMuted),
                          prefixIcon:
                              Icon(Icons.search_rounded, color: qt.textMuted),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded,
                                      color: qt.textMuted),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: qt.bg,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: qt.borderGlass, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: qt.emeraldDeep, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      labelColor: qt.emeraldDeep,
                      unselectedLabelColor: qt.textMuted,
                      indicatorColor: qt.emeraldDeep,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: 'Morning'),
                        Tab(text: 'Evening'),
                        Tab(text: 'Duas'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _DuaList(future: _morningFuture, filter: _filter),
            _DuaList(future: _eveningFuture, filter: _filter),
            _DuaList(future: _duasFuture, filter: _filter),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B4D32), Color(0xFF1A8A57), Color(0xFF0B4D32)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 110),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'ٱدْعُونِىٓ أَسْتَجِبْ لَكُمْ',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'QPC Hafs',
                      fontSize: 22,
                      color: Colors.white,
                      height: 1.9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"Call upon Me; I will respond to you."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withOpacity(0.88),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '— Surah Ghafir (40:60)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.65),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
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
// LIST BUILDER (OPTIMIZED)
// ═══════════════════════════════════════════════════════════════════════════

class _DuaList extends StatelessWidget {
  final Future<List<Dua>>? future;
  final List<Dua> Function(List<Dua>) filter;

  const _DuaList({required this.future, required this.filter});

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return FutureBuilder<List<Dua>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: qt.emeraldDeep));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child:
                  Text('No duas found', style: TextStyle(color: qt.textMuted)));
        }

        final list = filter(snapshot.data!);
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: qt.textMuted),
                const SizedBox(height: 12),
                Text('No duas match your search',
                    style: TextStyle(color: qt.textMuted, fontSize: 15)),
              ],
            ),
          );
        }

        // Cache font sizes once at list level to avoid per-card provider lookups
        final settings = DuaSettingsProvider.of(context);
        final arabicFontSize = settings.arabicFontSize;
        final translationFontSize = settings.translationFontSize;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: list.length,
          // Add keys for better diffing and recycling
          itemBuilder: (ctx, i) => _AccordionCard(
            key: ValueKey(list[i].title + i.toString()),
            dua: list[i],
            index: i,
            qt: qt,
            arabicFontSize: arabicFontSize,
            translationFontSize: translationFontSize,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCORDION CARD (OPTIMIZED)
// ═══════════════════════════════════════════════════════════════════════════

class _AccordionCard extends StatefulWidget {
  final Dua dua;
  final int index;
  final QuranTheme qt;
  final double arabicFontSize;
  final double translationFontSize;

  const _AccordionCard({
    super.key, // ValueKey from parent
    required this.dua,
    required this.index,
    required this.qt,
    required this.arabicFontSize,
    required this.translationFontSize,
  });

  @override
  State<_AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<_AccordionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _expand;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 280), vsync: this);
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotate = Tween<double>(begin: 0, end: 0.5).animate(_expand);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final qt = widget.qt;
    final dua = widget.dua;

    // RepaintBoundary prevents the entire card from repainting during scroll
    // when only a small part changed. Huge win for scroll performance.
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                _expanded ? qt.emeraldDeep.withOpacity(0.45) : qt.borderGlass,
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: _expanded
              ? [
                  BoxShadow(
                    color: qt.emeraldDeep.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: qt.emeraldDeep.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: qt.emeraldDeep,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dua.title,
                        style: TextStyle(
                          fontSize: widget.translationFontSize, // ← was 14
                          fontWeight: FontWeight.w600,
                          color: qt.textPrimary,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _rotate,
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: qt.emeraldDeep, size: 24),
                    ),
                  ],
                ),
              ),
            ),
            SizeTransition(
              sizeFactor: _expand,
              axisAlignment: -1,
              child: Column(
                children: [
                  Divider(height: 1, color: qt.borderGlass),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            dua.arabic,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'indopak',
                              fontSize: widget.arabicFontSize,
                              height: 2.0,
                              color: qt.textPrimary,
                            ),
                          ),
                        ),
                        if (dua.latin != null && dua.latin!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            dua.latin!,
                            style: TextStyle(
                              fontSize: widget.translationFontSize - 1,
                              fontStyle: FontStyle.italic,
                              color: qt.brightness == Brightness.dark
                                  ? qt.emeraldGlow
                                  : qt.emeraldDeep,
                              height: 1.6,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          dua.translation,
                          style: TextStyle(
                            fontSize: widget.translationFontSize,
                            color: qt.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        if (dua.notes != null && dua.notes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Note: ${dua.notes!}',
                            style: TextStyle(
                              fontSize: 12,
                              color: qt.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (dua.benefits != null &&
                            dua.benefits!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: qt.emeraldDeep.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: qt.emeraldDeep.withOpacity(0.15)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 15, color: qt.emeraldDeep),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Benefit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: qt.emeraldDeep,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dua.benefits!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: qt.textMuted,
                                            height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (dua.source != null && dua.source!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  size: 13, color: qt.textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dua.source!,
                                  style: TextStyle(
                                      fontSize: 11, color: qt.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class DuaSettingsSheet extends StatelessWidget {
  const DuaSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = DuaSettingsProvider.of(context);
    final qt = QuranTheme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: qt.borderGlass)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: qt.textMuted.withAlpha(80),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Dua Reader Settings',
              style: TextStyle(
                  color: qt.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 12),
          Text('Arabic Font Size',
              style: TextStyle(color: qt.textSecondary, fontSize: 13)),
          Slider(
            value: settings.arabicFontSize,
            min: 18,
            max: 42,
            divisions: 12,
            activeColor: qt.emeraldDeep,
            inactiveColor: qt.emeraldDeep.withAlpha((0.25 * 255).round()),
            label: settings.arabicFontSize.round().toString(),
            onChanged: settings.setArabicFontSize,
          ),
          const SizedBox(height: 12),
          Text('Translation Font Size',
              style: TextStyle(color: qt.textSecondary, fontSize: 13)),
          Slider(
            value: settings.translationFontSize,
            min: 12,
            max: 24,
            divisions: 12,
            activeColor: qt.emeraldDeep,
            inactiveColor: qt.emeraldDeep.withAlpha((0.25 * 255).round()),
            label: settings.translationFontSize.round().toString(),
            onChanged: settings.setTranslationFontSize,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: qt.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Preview',
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 12),
                Text('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'QPC Hafs',
                        fontSize: settings.arabicFontSize,
                        height: 1.8,
                        color: qt.textPrimary)),
                const SizedBox(height: 12),
                Text('Rabbana atina fid-dunya hasanatan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: qt.emeraldDeep,
                        fontSize: settings.translationFontSize - 1,
                        height: 1.5)),
                const SizedBox(height: 10),
                Text('The font size settings will apply to all Duas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: qt.textSecondary,
                        fontSize: settings.translationFontSize,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
