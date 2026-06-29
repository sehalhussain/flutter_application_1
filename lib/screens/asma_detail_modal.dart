import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/name_model.dart';
import '../constants/quran_theme.dart';

class AsmaDetailModal extends StatefulWidget {
  final List<AsmaName> names;
  final int initialIndex;

  const AsmaDetailModal({
    super.key,
    required this.names,
    required this.initialIndex,
  });

  static void show(
    BuildContext context, {
    required List<AsmaName> names,
    required int initialIndex,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => AsmaDetailModal(
        names: names,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<AsmaDetailModal> createState() => _AsmaDetailModalState();
}

class _AsmaDetailModalState extends State<AsmaDetailModal>
    with SingleTickerProviderStateMixin {
  final GlobalKey _imageCaptureKey = GlobalKey();
  late int _currentIndex;
  late AsmaName _currentName;

  // ── Premium Animation System ──
  late AnimationController _animController;
  int _direction = 0; // -1 = going back, 0 = initial, 1 = going forward

  // Computed animations
  Animation<double> get _opacityAnim =>
      Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ));

  Animation<double> get _scaleAnim =>
      Tween<double>(begin: 0.97, end: 1.0).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ));

  Animation<Offset> get _slideAnim => Tween<Offset>(
        begin: Offset(_direction * 0.025, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ));

  Animation<double> get _reflectionOpacity =>
      Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
      ));

  Animation<Offset> get _reflectionSlide => Tween<Offset>(
        begin: Offset(0, 0.015),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic),
      ));

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentName = widget.names[_currentIndex];
    _direction = 0;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToNext() {
    if (_currentIndex < widget.names.length - 1) {
      HapticFeedback.selectionClick();
      _animController.value = 0.0;
      _direction = 1;

      setState(() {
        _currentIndex++;
        _currentName = widget.names[_currentIndex];
      });

      _animController.forward();
    }
  }

  void _goToPrev() {
    if (_currentIndex > 0) {
      HapticFeedback.selectionClick();
      _animController.value = 0.0;
      _direction = -1;

      setState(() {
        _currentIndex--;
        _currentName = widget.names[_currentIndex];
      });

      _animController.forward();
    }
  }

  // ── Pre-cached styles ──
  late final TextStyle _tsModalNumber;
  late final TextStyle _tsModalArabic;
  late final TextStyle _tsModalTranslit;
  late final TextStyle _tsModalMeaning;
  late final TextStyle _tsReflectionLabel;
  late final TextStyle _tsReflectionBody;
  late final TextStyle _tsCounter;

  // ── Pre-cached decorations ──
  late final BoxDecoration _modalNumberPill;
  late final BoxDecoration _reflectionCard;
  late final BoxDecoration _arabicContainer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheThemeAssets();
  }

  void _cacheThemeAssets() {
    final qt = QuranTheme.of(context);
    final emerald08 = qt.emeraldDeep.withOpacity(0.08);
    final emerald15 = qt.emeraldDeep.withOpacity(0.15);

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
    _tsCounter = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: qt.textMuted.withOpacity(0.6),
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
    _arabicContainer = BoxDecoration(
      color: qt.emeraldDeep.withOpacity(0.03),
      borderRadius: BorderRadius.circular(20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final sheetHeight =
        (MediaQuery.of(context).size.height * 0.78) + bottomInset;

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
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity > 300) {
                    _goToPrev();
                  } else if (velocity < -300) {
                    _goToNext();
                  }
                },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
                  child: RepaintBoundary(
                    key: _imageCaptureKey,
                    child: ColoredBox(
                      color: qt.bg,
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              // Handle
                              Container(
                                width: 38,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 28),
                                decoration: BoxDecoration(
                                  color: qt.borderGlass,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),

                              // Number pill with subtle animation
                              FadeTransition(
                                opacity: _opacityAnim,
                                child: SlideTransition(
                                  position: _slideAnim,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: _modalNumberPill,
                                    child: Text(
                                      "NAME #${_currentName.number}",
                                      style: _tsModalNumber,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Arabic Name with subtle floating chevrons
                              FadeTransition(
                                opacity: _opacityAnim,
                                child: SlideTransition(
                                  position: _slideAnim,
                                  child: Transform.scale(
                                    scale: _scaleAnim.value,
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 40, vertical: 20),
                                          decoration: _arabicContainer,
                                          alignment: Alignment.center,
                                          child: Text(
                                            _currentName.name,
                                            textAlign: TextAlign.center,
                                            textDirection: TextDirection.rtl,
                                            style: _tsModalArabic,
                                          ),
                                        ),

                                        // Subtle left chevron (previous)
                                        if (_currentIndex > 0)
                                          Positioned(
                                            left: 6,
                                            top: 0,
                                            bottom: 0,
                                            child: GestureDetector(
                                              onTap: _goToPrev,
                                              behavior: HitTestBehavior.opaque,
                                              child: Center(
                                                child: Icon(
                                                  Icons.chevron_left_rounded,
                                                  size: 20,
                                                  color: qt.emeraldDeep
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                            ),
                                          ),

                                        // Subtle right chevron (next)
                                        if (_currentIndex <
                                            widget.names.length - 1)
                                          Positioned(
                                            right: 6,
                                            top: 0,
                                            bottom: 0,
                                            child: GestureDetector(
                                              onTap: _goToNext,
                                              behavior: HitTestBehavior.opaque,
                                              child: Center(
                                                child: Icon(
                                                  Icons.chevron_right_rounded,
                                                  size: 20,
                                                  color: qt.emeraldDeep
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Transliteration
                              FadeTransition(
                                opacity: _opacityAnim,
                                child: SlideTransition(
                                  position: _slideAnim,
                                  child: Transform.scale(
                                    scale: _scaleAnim.value,
                                    child: Text(
                                      _currentName.transliteration,
                                      style: _tsModalTranslit,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Meaning
                              FadeTransition(
                                opacity: _opacityAnim,
                                child: Text(
                                  _currentName.meaning.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: _tsModalMeaning,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Counter
                              FadeTransition(
                                opacity: _opacityAnim,
                                child: Text(
                                  "${_currentIndex + 1} of ${widget.names.length}",
                                  style: _tsCounter,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Divider
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Divider(
                                  color: qt.borderGlass.withOpacity(0.5),
                                  thickness: 1,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Reflection header - staggered animation
                              FadeTransition(
                                opacity: _reflectionOpacity,
                                child: SlideTransition(
                                  position: _reflectionSlide,
                                  child: Center(
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
                                                BorderRadius.circular(1),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.auto_stories_rounded,
                                                size: 15,
                                                color: qt.emeraldDeep
                                                    .withOpacity(0.7),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "REFLECTION",
                                                style: _tsReflectionLabel,
                                              ),
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
                                                BorderRadius.circular(1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Reflection card - staggered animation
                              FadeTransition(
                                opacity: _reflectionOpacity,
                                child: SlideTransition(
                                  position: _reflectionSlide,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 24),
                                    decoration: _reflectionCard,
                                    child: Text(
                                      _currentName.reflection,
                                      textAlign: TextAlign.center,
                                      style: _tsReflectionBody,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Buttons
            Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
              decoration: BoxDecoration(
                color: qt.cardBg,
                border: Border(
                    top: BorderSide(color: qt.borderGlass.withOpacity(0.4))),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _shareAsText(_currentName),
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
                              Text(
                                "Share Text",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: qt.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _shareAsImage(_currentName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_rounded,
                                  size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Share Image",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
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
  }

  void _shareAsText(AsmaName name) {
    final String shareText = """
🌿 ${name.name} (${name.transliteration})
 ${name.meaning}

✨ "${name.reflection}"
""";
    Share.share(shareText, subject: "${name.transliteration} - Asma ul Husna");
  }

  Future<void> _shareAsImage(AsmaName name) async {
    try {
      final boundary = _imageCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final filePath =
          "${directory.path}/kitably_${name.transliteration.replaceAll(' ', '_')}.png";
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(filePath, name: "${name.transliteration}_Kitably.png")],
        text: "${name.transliteration} - The ${name.meaning}",
      );
    } catch (e) {
      debugPrint("Error sharing image: $e");
    }
  }
}
