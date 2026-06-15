import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/name_model.dart';
import '../services/data_service.dart';
import '../constants/quran_theme.dart';
import '../main.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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

  void _filterNames(String query) {
    setState(() {
      searchQuery = query;
      filteredNames = allNames
          .where((n) =>
              n.transliteration.toLowerCase().contains(query.toLowerCase()) ||
              n.meaning.toLowerCase().contains(query.toLowerCase()) ||
              n.name.contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── APPLE-LIKE HEADER (MATCHING PRAYER SCREEN) ──
          RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    qt.emeraldDeep,
                    qt.emeraldDeep.withOpacity(0.95),
                  ],
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
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _glassBtn(
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                        qt,
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
                      // Symmetric balancing spacer widget
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Citation Translucent Box - styled just like Prayer Screen's Hijri indicator
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
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterNames,
                  style: TextStyle(color: qt.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search by name or meaning...",
                    hintStyle: TextStyle(
                      color: qt.textMuted.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: qt.textMuted.withOpacity(0.8), size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _filterNames("");
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

          // ── LIST OF NAMES ──
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(qt.emeraldDeep),
                      strokeWidth: 3,
                    ),
                  )
                : filteredNames.isEmpty
                    ? _buildEmptyState(qt)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        cacheExtent: 350, // Proactive layout pre-rendering
                        itemCount: filteredNames.length,
                        itemBuilder: (context, index) {
                          final name = filteredNames[index];
                          return _buildNameCard(name, qt);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard(AsmaName name, QuranTheme qt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            _showDetailModal(name, qt);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Premium Styled Numeric Index Capsule Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: qt.emeraldDeep.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "${name.number}",
                      style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Meaning and Transliteration in premium typography hierarchy
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.transliteration,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: qt.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name.meaning,
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
                const SizedBox(width: 12),
                // Arabic Name styled with beautiful font rendering
                Text(
                  name.name,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 26,
                    color: qt.emeraldDeep,
                    fontFamily: 'QPC Hafs',
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailModal(AsmaName name, QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: qt.borderGlass,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Name #${name.number}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: qt.emeraldDeep,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name.name,
                style: TextStyle(
                  fontSize: 54,
                  fontFamily: 'QPC Hafs',
                  color: qt.emeraldDeep,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name.transliteration,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: qt.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name.meaning.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: qt.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: qt.borderGlass.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(
                "Meditate on this beautiful attribute of Allah to invite peace, blessings, and alignment into your spiritual path.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: qt.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(QuranTheme qt) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: qt.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "No Names Found",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: qt.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Try checking spelling or use another keyword.",
            style: TextStyle(
              fontSize: 12,
              color: qt.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(Widget child, QuranTheme qt, {VoidCallback? onTap}) {
    final bool isDark = qt.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : qt.glassWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}
