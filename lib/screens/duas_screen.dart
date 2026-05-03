import 'package:flutter/material.dart';
import '../models/dua_model.dart';
import '../services/data_service.dart';
import '../constants/quran_theme.dart';

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

  Future<List<Dua>>? _morningFuture;
  Future<List<Dua>>? _eveningFuture;
  Future<List<Dua>>? _duasFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _morningFuture =
        DataService.loadDuas('assets/data/duas/morning-adhkar.json');
    _eveningFuture =
        DataService.loadDuas('assets/data/duas/Evening-adhkar.json');
    _duasFuture = DataService.loadDuas('assets/data/duas/duas.json');
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
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
            flexibleSpace: FlexibleSpaceBar(background: _Banner()),
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
                      labelStyle:
                          const TextStyle(fontWeight: FontWeight.bold),
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

// ── Banner ──────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
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

// ── List builder ─────────────────────────────────────────────────────────────

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
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return Center(
              child: Text('No duas found',
                  style: TextStyle(color: qt.textMuted)));
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

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: list.length,
          itemBuilder: (ctx, i) =>
              _AccordionCard(dua: list[i], index: i, qt: qt),
        );
      },
    );
  }
}

// ── Accordion card ───────────────────────────────────────────────────────────

class _AccordionCard extends StatefulWidget {
  final Dua dua;
  final int index;
  final QuranTheme qt;

  const _AccordionCard(
      {required this.dua, required this.index, required this.qt});

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _expanded
              ? qt.emeraldDeep.withOpacity(0.45)
              : qt.borderGlass,
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
          // Header row
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
                        fontSize: 14,
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

          // Expandable body
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
                      // Arabic
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
                            fontFamily: 'QPC Hafs',
                            fontSize: 24,
                            height: 2.0,
                            color: qt.textPrimary,
                          ),
                        ),
                      ),

                      // Transliteration
                      if (dua.latin != null && dua.latin!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          dua.latin!,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: qt.emeraldDeep.withOpacity(0.85),
                            height: 1.6,
                          ),
                        ),
                      ],

                      // Translation
                      const SizedBox(height: 10),
                      Text(
                        dua.translation,
                        style: TextStyle(
                          fontSize: 14,
                          color: qt.textPrimary,
                          height: 1.6,
                        ),
                      ),

                      // Notes
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

                      // Benefits
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

                      // Source
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
    );
  }
}
