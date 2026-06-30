import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/name_model.dart';
import '../services/data_service.dart';
import '../constants/quran_theme.dart';
import '../main.dart';
import 'asma_detail_modal.dart';

class AsmaListScreen extends StatefulWidget {
  const AsmaListScreen({super.key});

  @override
  State<AsmaListScreen> createState() => _AsmaListScreenState();
}

class _AsmaListScreenState extends State<AsmaListScreen> {
  List<AsmaName> allNames = [];
  List<AsmaName> filteredNames = [];
  String searchQuery = "";
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // ── Pre-cached styles ──
  late final TextStyle _tsNumber;
  late final TextStyle _tsTranslit;
  late final TextStyle _tsMeaning;
  late final TextStyle _tsArabic;
  late final TextStyle _tsSearchHint;
  late final TextStyle _tsEmptyTitle;
  late final TextStyle _tsEmptySub;

  // ── Pre-cached decorations ──
  late final BoxDecoration _cardDecoration;
  late final BoxDecoration _numberDecoration;
  late final BoxDecoration _searchDecoration;
  late final BoxDecoration _headerGradient;
  late final BoxDecoration _glassBtnDecoration;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheThemeAssets();
  }

  void _cacheThemeAssets() {
    final qt = QuranTheme.of(context);
    final emerald08 = qt.emeraldDeep.withOpacity(0.08);
    final emerald15 = qt.emeraldDeep.withOpacity(0.15);
    final border40 = qt.borderGlass.withOpacity(0.4);
    final isDark = qt.brightness == Brightness.dark;

    _tsNumber = TextStyle(
      color: qt.emeraldDeep,
      fontWeight: FontWeight.w800,
      fontSize: 12,
    );
    _tsTranslit = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: qt.textPrimary,
      letterSpacing: -0.3,
    );
    _tsMeaning = TextStyle(
      fontSize: 12,
      color: qt.textMuted,
      height: 1.3,
    );
    _tsArabic = TextStyle(
      fontSize: 26,
      color: qt.emeraldDeep,
      fontFamily: 'QPC Hafs',
    );
    _tsSearchHint = TextStyle(
      color: qt.textMuted.withOpacity(0.8),
      fontSize: 14,
    );
    _tsEmptyTitle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: qt.textPrimary,
    );
    _tsEmptySub = TextStyle(
      fontSize: 12,
      color: qt.textMuted,
    );

    _cardDecoration = BoxDecoration(
      color: qt.cardBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border40),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.015),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
    _numberDecoration = BoxDecoration(
      color: emerald08,
      shape: BoxShape.circle,
      border: Border.all(color: emerald15, width: 1),
    );
    _searchDecoration = BoxDecoration(
      color: qt.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border40),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
    _headerGradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [qt.emeraldDeep, qt.emeraldDeep.withOpacity(0.95)],
      ),
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      boxShadow: [
        BoxShadow(
          color: qt.emeraldDeep.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
    _glassBtnDecoration = BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.08) : qt.glassWhite,
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final names = await DataService.loadNames();
    if (!mounted) return;
    setState(() {
      allNames = names;
      filteredNames = names;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      final lower = query.toLowerCase();
      setState(() {
        searchQuery = query;
        filteredNames = lower.isEmpty
            ? allNames
            : allNames.where((n) {
                return n.transliteration.toLowerCase().contains(lower) ||
                    n.meaning.toLowerCase().contains(lower) ||
                    n.name.contains(query);
              }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── HEADER ──
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 28),
              decoration: _headerGradient,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _glassBtn(
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          MainNavigation.popShell(context);
                        },
                      ),
                      Column(
                        children: [
                          const Text(
                            "Asma ul Husna",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "THE 99 NAMES OF ALLAH",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.55),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        const Text(
                          "\"And to Allah belong the best names, \n so invoke Him by them.\"",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Surah Al-A'raf (7:180)",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── FLOATING SEARCH BAR ──
          Transform.translate(
            offset: const Offset(0, -22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: _searchDecoration,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: qt.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search by name or meaning...",
                    hintStyle: _tsSearchHint,
                    prefixIcon: Icon(Icons.search_rounded,
                        color: qt.textMuted.withOpacity(0.8), size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged("");
                            },
                            child: Icon(Icons.clear_rounded,
                                color: qt.textMuted, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ── LIST ──
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(qt.emeraldDeep),
                      strokeWidth: 3,
                    ),
                  )
                : filteredNames.isEmpty
                    ? _buildEmptyState()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      prototypeItem: _buildNameCard(allNames.first),
      itemCount: filteredNames.length,
      itemBuilder: (context, index) => _buildNameCard(filteredNames[index]),
    );
  }

  Widget _buildNameCard(AsmaName name) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _cardDecoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              final index = allNames.indexOf(name);
              AsmaDetailModal.show(
                context,
                names: allNames,
                initialIndex: index >= 0 ? index : 0,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: _numberDecoration,
                    child: Center(
                      child: Text(
                        "${name.number}",
                        style: _tsNumber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.transliteration, style: _tsTranslit),
                        const SizedBox(height: 3),
                        Text(
                          name.meaning,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _tsMeaning,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name.name,
                    textDirection: TextDirection.rtl,
                    style: _tsArabic,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: QuranTheme.of(context).textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text("No Names Found", style: _tsEmptyTitle),
          const SizedBox(height: 4),
          Text(
            "Try checking spelling or use another keyword.",
            style: _tsEmptySub,
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(Widget child, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: _glassBtnDecoration,
        child: Center(child: child),
      ),
    );
  }
}
