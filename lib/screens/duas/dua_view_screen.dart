import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/quran_theme.dart';
import '../../models/dua_models.dart';
import '../../providers/dua_progress_provider.dart';
import '../../providers/dua_settings_provider.dart';

/// Dedicated full-screen page to view a single dua in detail.
class DuaViewScreen extends StatelessWidget {
  final DuaItem dua;
  final String segmentName;
  final String categoryName;
  final String titleName;
  final Color segmentColor;

  const DuaViewScreen({
    super.key,
    required this.dua,
    required this.segmentName,
    required this.categoryName,
    required this.titleName,
    this.segmentColor = const Color(0xFF5B7DB1),
  });

  void _showFontSettings(BuildContext context) {
    final settings = DuaSettingsProvider.of(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _FontSizeSheet(settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Premium Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
              boxShadow: [
                BoxShadow(
                  color: qt.emeraldDeep.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Navigator.canPop(context)
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const Expanded(
                      child: Text(
                        'Dua Detail',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // ── Added Settings Icon ──
                    Tooltip(
                      message: 'Reading settings',
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          icon: const Icon(Icons.tune_rounded,
                              color: Colors.white, size: 22),
                          onPressed: () => _showFontSettings(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$segmentName › $categoryName',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 32 + MediaQuery.of(context).padding.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: qt.borderGlass.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: qt.emeraldDeep.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _DuaViewContent(
                  dua: dua,
                  segmentName: segmentName,
                  categoryName: categoryName,
                  titleName: titleName,
                  segmentColor: segmentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The inner content widget of the DuaViewScreen.
class _DuaViewContent extends StatelessWidget {
  final DuaItem dua;
  final String segmentName;
  final String categoryName;
  final String titleName;
  final Color segmentColor;

  const _DuaViewContent({
    required this.dua,
    required this.segmentName,
    required this.categoryName,
    required this.titleName,
    required this.segmentColor,
  });

  void _showCopiedSnackbar(BuildContext context, QuranTheme qt) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.white.withValues(alpha: 0.9), size: 18),
            const SizedBox(width: 8),
            const Text('Dua copied to clipboard'),
          ],
        ),
        backgroundColor: qt.emeraldDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        duration: const Duration(seconds: 2),
        elevation: 6,
      ),
    );
  }

  static String _buildText({
    required String? arabic,
    required String? latin,
    required String? translation,
    required String? source,
    required bool showLatin,
    required bool showTranslation,
    bool includeSource = false,
  }) {
    final parts = <String>[];
    if (arabic != null && arabic.isNotEmpty) parts.add(arabic);
    if (showLatin && latin != null && latin.isNotEmpty) parts.add(latin);
    if (showTranslation && translation != null && translation.isNotEmpty) {
      parts.add(translation);
    }
    if (includeSource && source != null && source.isNotEmpty) {
      parts.add('Source: $source');
    }
    return parts.where((p) => p.isNotEmpty).join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final settings = DuaSettingsProvider.of(context, listen: true);
    final progress = DuaProgressProvider.of(context, listen: true);
    final isFav = progress.isFavorite(dua.id);

    final showLatin = DuaSettingsProvider.of(context, listen: false)
        .showTransliteration as bool;
    final showTranslation =
        DuaSettingsProvider.of(context, listen: false).showTranslation as bool;

    final hasArabic = dua.arabic != null && dua.arabic!.isNotEmpty;
    final hasLatin = showLatin && dua.latin != null && dua.latin!.isNotEmpty;
    final hasTranslation = showTranslation &&
        dua.translation != null &&
        dua.translation!.isNotEmpty;
    final hasBenefits = dua.benefits != null && dua.benefits!.isNotEmpty;
    final hasSource = dua.source != null && dua.source!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top Action Bar (Badges & Icons) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
          child: Row(
            children: [
              // Left side: Badges
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Badge(
                    icon: Icons.tag_rounded,
                    label: '${dua.id}',
                    color: qt.emeraldDeep,
                    qt: qt,
                  ),
                  if (dua.repeat > 1) ...[
                    const SizedBox(width: 6),
                    _Badge(
                      icon: Icons.replay_rounded,
                      label: '${dua.repeat}×',
                      color: qt.emeraldDeep,
                      qt: qt,
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // Right side: Simple Icon Buttons with Tooltips
              Tooltip(
                message: 'Share',
                child: IconButton(
                  icon:
                      Icon(Icons.share_rounded, size: 20, color: qt.textMuted),
                  onPressed: () {
                    final text = _buildText(
                      arabic: dua.arabic,
                      latin: dua.latin,
                      translation: dua.translation,
                      source: dua.source,
                      showLatin: showLatin,
                      showTranslation: showTranslation,
                      includeSource: true,
                    );
                    Share.share(text, subject: '$titleName – $segmentName');
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
              Tooltip(
                message: 'Copy',
                child: IconButton(
                  icon: Icon(Icons.copy_rounded, size: 19, color: qt.textMuted),
                  onPressed: () {
                    final text = _buildText(
                      arabic: dua.arabic,
                      latin: dua.latin,
                      translation: dua.translation,
                      source: null,
                      showLatin: showLatin,
                      showTranslation: showTranslation,
                    );
                    Clipboard.setData(ClipboardData(text: text));
                    _showCopiedSnackbar(context, qt);
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
              Tooltip(
                message: isFav ? 'Remove from favorites' : 'Add to favorites',
                child: IconButton(
                  icon: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 20,
                    color: isFav ? Colors.redAccent.shade400 : qt.textMuted,
                  ),
                  onPressed: () => progress.toggleFavorite(DuaFavorite(
                    duaId: dua.id,
                    segmentName: segmentName,
                    categoryName: categoryName,
                    titleName: titleName,
                    latin: dua.latin,
                    translation: dua.translation,
                  )),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ],
          ),
        ),

        // ── Centered Title Row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(
            titleName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: qt.textMuted,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),

        // ── Gradient Divider ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  qt.borderGlass.withValues(alpha: 0.0),
                  qt.borderGlass.withValues(alpha: 0.5),
                  qt.borderGlass.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // ── Arabic Section ──
        if (hasArabic)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: qt.emeraldDeep.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dua.arabic!,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'IndopakN',
                      fontSize: settings.arabicFontSize,
                      height: 1.8,
                      color: qt.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Transliteration Section ──
        if (hasLatin) ...[
          if (hasArabic) const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: qt.brightness == Brightness.dark
                            ? qt.emeraldGlow
                            : qt.emeraldDeep,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TRANSLITERATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: qt.emeraldDeep.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dua.latin!,
                  style: TextStyle(
                    fontSize: settings.translationFontSize,
                    fontStyle: FontStyle.italic,
                    color: qt.brightness == Brightness.dark
                        ? qt.emeraldGlow
                        : qt.emeraldDeep.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Translation Section ──
        if (hasTranslation) ...[
          if (hasArabic || hasLatin) const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: qt.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TRANSLATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: qt.textMuted.withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dua.translation!,
                  style: TextStyle(
                    fontSize: settings.translationFontSize,
                    color: qt.textPrimary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Benefits Section ──
        if (hasBenefits) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: qt.emeraldDeep.withValues(alpha: 0.1),
                  strokeAlign: -1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 14, color: qt.emeraldDeep),
                      const SizedBox(width: 6),
                      Text(
                        'BENEFITS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: qt.emeraldDeep.withValues(alpha: 0.7),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dua.benefits!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: qt.textMuted,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // ── Source Section ──
        if (hasSource) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 12, color: qt.textMuted.withValues(alpha: 0.35)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dua.source!,
                    style: TextStyle(
                      fontSize: 11,
                      color: qt.textMuted.withValues(alpha: 0.45),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (!hasBenefits && !hasSource) const SizedBox(height: 20),
      ],
    );
  }
}

/// Compact badge chip for ID and repeat count.
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final QuranTheme qt;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.qt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Font size adjustment bottom sheet (Ported from DuaTitleScreen)
class _FontSizeSheet extends StatefulWidget {
  final DuaSettings settings;
  const _FontSizeSheet({required this.settings});

  @override
  State<_FontSizeSheet> createState() => _FontSizeSheetState();
}

class _FontSizeSheetState extends State<_FontSizeSheet> {
  late double _arabicSize;
  late double _translationSize;
  late bool _showTransliteration;
  late bool _showTranslation;

  @override
  void initState() {
    super.initState();
    _arabicSize = widget.settings.arabicFontSize;
    _translationSize = widget.settings.translationFontSize;
    _showTransliteration = widget.settings.showTransliteration;
    _showTranslation = widget.settings.showTranslation;
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, 32 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -10),
          )
        ],
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
                color: qt.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Reading Settings',
              style: TextStyle(
                  color: qt.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Live preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: qt.emeraldDeep.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '\u{0628}\u{0650}\u{0633}\u{0652}\u{0645}\u{0650} \u{0627}\u{0644}\u{0644}\u{0651}\u{064e}\u{0647}\u{0650} \u{0627}\u{0644}\u{0631}\u{0651}\u{064e}\u{062d}\u{0652}\u{0645}\u{064e}\u{0646}\u{0650} \u{0627}\u{0644}\u{0631}\u{0651}\u{064e}\u{062d}\u{0650}\u{064a}\u{0645}\u{0650}',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'IndopakN',
                    fontSize: _arabicSize.clamp(16, 50),
                    height: 2.5,
                    color: qt.textPrimary,
                  ),
                ),
                if (_showTransliteration) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Bismillah hir-Rahman nir-Rahim',
                    style: TextStyle(
                      fontSize: _translationSize.clamp(11, 34),
                      fontStyle: FontStyle.italic,
                      color: qt.brightness == Brightness.dark
                          ? qt.emeraldGlow
                          : qt.emeraldDeep.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                ],
                if (_showTranslation) ...[
                  const SizedBox(height: 6),
                  Text(
                    'In the name of Allah, the Most Gracious, the Most Merciful',
                    style: TextStyle(
                      fontSize: _translationSize.clamp(11, 34),
                      color: qt.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Arabic font size
          Text('Arabic Font Size',
              style: TextStyle(color: qt.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.text_fields_rounded, size: 16, color: qt.textMuted),
              Expanded(
                child: Slider(
                  value: _arabicSize,
                  min: 16.0,
                  max: 50.0,
                  divisions: 17,
                  activeColor: qt.emeraldDeep,
                  inactiveColor: qt.borderGlass,
                  label: '${_arabicSize.round()}',
                  onChanged: (v) => setState(() => _arabicSize = v),
                  onChangeEnd: (v) => widget.settings.setArabicFontSize(v),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${_arabicSize.round()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Translation font size
          Text('Translation Font Size',
              style: TextStyle(color: qt.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.text_fields_rounded, size: 16, color: qt.textMuted),
              Expanded(
                child: Slider(
                  value: _translationSize,
                  min: 11.0,
                  max: 34.0,
                  divisions: 23,
                  activeColor: qt.emeraldDeep,
                  inactiveColor: qt.borderGlass,
                  label: '${_translationSize.round()}',
                  onChanged: (v) => setState(() => _translationSize = v),
                  onChangeEnd: (v) => widget.settings.setTranslationFontSize(v),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text('${_translationSize.round()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Toggle: Show Transliteration
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transliteration',
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    Text('Show/hide Latin transliteration',
                        style: TextStyle(color: qt.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: _showTransliteration,
                onChanged: (v) {
                  setState(() => _showTransliteration = v);
                  widget.settings.setShowTransliteration(v);
                },
                activeColor: qt.emeraldDeep,
                activeTrackColor: qt.emeraldDeep.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Toggle: Show Translation
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Translation',
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    Text('Show/hide English translation',
                        style: TextStyle(color: qt.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: _showTranslation,
                onChanged: (v) {
                  setState(() => _showTranslation = v);
                  widget.settings.setShowTranslation(v);
                },
                activeColor: qt.emeraldDeep,
                activeTrackColor: qt.emeraldDeep.withValues(alpha: 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
