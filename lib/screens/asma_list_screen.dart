import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/name_model.dart';
import '../services/data_service.dart';
import '../constants/quran_theme.dart';
import '../main.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';

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

  final GlobalKey _imageCaptureKey = GlobalKey();

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showWatermark = false; // <-- Add this

  // ── Pre-cached styles ──
  late final TextStyle _tsNumber;
  late final TextStyle _tsTranslit;
  late final TextStyle _tsMeaning;
  late final TextStyle _tsArabic;
  late final TextStyle _tsModalNumber;
  late final TextStyle _tsModalArabic;
  late final TextStyle _tsModalTranslit;
  late final TextStyle _tsModalMeaning;
  late final TextStyle _tsReflectionLabel;
  late final TextStyle _tsReflectionBody;
  late final TextStyle _tsSearchHint;
  late final TextStyle _tsEmptyTitle;
  late final TextStyle _tsEmptySub;

  // ── Pre-cached decorations ──
  late final BoxDecoration _cardDecoration;
  late final BoxDecoration _numberDecoration;
  late final BoxDecoration _searchDecoration;
  late final BoxDecoration _headerGradient;
  late final BoxDecoration _glassBtnDecoration;
  late final BoxDecoration _modalNumberPill;
  late final BoxDecoration _reflectionCard;

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
    _tsModalNumber = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: qt.emeraldDeep,
      letterSpacing: 1.2,
    );
    _tsModalArabic = TextStyle(
      fontSize: 56,
      fontFamily: 'QPC Hafs',
      color: qt.emeraldDeep,
      height: 1.2,
    );
    _tsModalTranslit = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: qt.textPrimary,
      letterSpacing: -0.3,
    );
    _tsModalMeaning = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: qt.textMuted,
      letterSpacing: 1.0,
    );
    _tsReflectionLabel = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: qt.emeraldDeep.withOpacity(0.7),
      letterSpacing: 1.2,
    );
    _tsReflectionBody = TextStyle(
      fontSize: 15,
      color: qt.textSecondary,
      height: 1.75,
      fontStyle: FontStyle.italic,
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
    _modalNumberPill = BoxDecoration(
      color: emerald08,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: emerald15, width: 1),
    );
    _reflectionCard = BoxDecoration(
      color: qt.emeraldDeep.withOpacity(0.04),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: qt.emeraldDeep.withOpacity(0.08)),
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
              _showDetailModal(name);
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

  void _showDetailModal(AsmaName name) {
    final qt = QuranTheme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        final sheetHeight = (MediaQuery.of(context).size.height * 0.78) +
            bottomInset; // Slightly taller for buttons

        return Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: qt.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Column(
              children: [
                // ── SCROLLABLE CONTENT AREA ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                    child: Column(
                      children: [
                        // Drag Handle
                        Container(
                          width: 38,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 28),
                          decoration: BoxDecoration(
                            color: qt.borderGlass,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),

                        // ── REPAINT BOUNDARY STARTS HERE (This is what gets captured as an image) ──
                        RepaintBoundary(
                          key: _imageCaptureKey,
                          child: Column(
                            children: [
                              // Number Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: _modalNumberPill,
                                child: Text("NAME #${name.number}",
                                    style: _tsModalNumber),
                              ),
                              const SizedBox(height: 28),

                              // Arabic Name
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: qt.emeraldDeep.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(name.name, style: _tsModalArabic),
                              ),
                              const SizedBox(height: 20),

                              // Transliteration
                              Text(name.transliteration,
                                  style: _tsModalTranslit),
                              const SizedBox(height: 10),

                              // Meaning
                              Text(
                                name.meaning.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: _tsModalMeaning,
                              ),
                              const SizedBox(height: 32),

                              // Divider
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Divider(
                                    color: qt.borderGlass.withOpacity(0.5),
                                    thickness: 1),
                              ),
                              const SizedBox(height: 28),

                              // Centered Reflection Label
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 28,
                                        height: 1,
                                        decoration: BoxDecoration(
                                            color:
                                                qt.emeraldDeep.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(1))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_stories_rounded,
                                              size: 15,
                                              color: qt.emeraldDeep
                                                  .withOpacity(0.7)),
                                          const SizedBox(width: 8),
                                          Text("REFLECTION",
                                              style: _tsReflectionLabel),
                                        ],
                                      ),
                                    ),
                                    Container(
                                        width: 28,
                                        height: 1,
                                        decoration: BoxDecoration(
                                            color:
                                                qt.emeraldDeep.withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(1))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Reflection Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 24),
                                decoration: _reflectionCard,
                                child: Text(
                                  name.reflection,
                                  textAlign: TextAlign.center,
                                  style: _tsReflectionBody,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── SUBTLE WATERMARK FOR IMAGE (Hidden until capture) ──
                              if (_showWatermark)
                                Text(
                                  "Download Kitably",
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: qt.textMuted.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // ── REPAINT BOUNDARY ENDS HERE ──
                      ],
                    ),
                  ),
                ),

                // ── BOTTOM ACTION BUTTONS (Safe from image capture) ──
                Container(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
                  decoration: BoxDecoration(
                    color: qt.cardBg,
                    border: Border(
                        top:
                            BorderSide(color: qt.borderGlass.withOpacity(0.4))),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Share Text Button
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _shareAsText(name, qt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: qt.borderGlass.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.text_fields_rounded,
                                      size: 18, color: qt.textSecondary),
                                  const SizedBox(width: 8),
                                  Text("Share Text",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: qt.textSecondary,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Share Image Button
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _shareAsImage(name, qt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: qt.emeraldDeep,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.image_rounded,
                                      size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Share Image",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── HELPER 1: Share as Text ──
  void _shareAsText(AsmaName name, QuranTheme qt) {
    final String shareText = """
🌿 ${name.name} (${name.transliteration})
 ${name.meaning}

✨ "${name.reflection}"

Download Kitably: https://kitably.pages.dev
""";

    Share.share(shareText, subject: "${name.transliteration} - Asma ul Husna");
  }

  // ── HELPER 2: Share as Image ──
  Future<void> _shareAsImage(AsmaName name, QuranTheme qt) async {
    try {
      // 1. Show the watermark temporarily
      setState(() => _showWatermark = true);

      // 2. Wait 50ms to ensure the rasterizer has drawn the new text
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Capture the RepaintBoundary
      final boundary = _imageCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _showWatermark = false); // Reset if it fails
        return;
      }

      // 4. Convert to image (3.0 pixel ratio for crisp stories/posts)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        setState(() => _showWatermark = false);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 5. Hide the watermark immediately after capturing
      setState(() => _showWatermark = false);

      // 6. Save to temporary directory
      final directory = await getTemporaryDirectory();
      final filePath =
          "${directory.path}/kitably_${name.transliteration.replaceAll(' ', '_')}.png";
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // 7. Share the image file
      await Share.shareXFiles(
        [XFile(filePath, name: "${name.transliteration}_Kitably.png")],
        text: "${name.transliteration} - The ${name.meaning}",
      );
    } catch (e) {
      debugPrint("Error sharing image: $e");
      // Make absolutely sure it gets turned off even if an error occurs
      if (mounted) setState(() => _showWatermark = false);
    }
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
