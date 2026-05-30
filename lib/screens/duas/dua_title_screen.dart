import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/quran_theme.dart';
import '../../models/dua_models.dart';
import '../../providers/dua_progress_provider.dart';
import '../../providers/dua_settings_provider.dart';

/// Shows titles as a clean list. Tapping a title expands to show duas below.
class DuaTitleScreen extends StatefulWidget {
  final DuaCategory? category;
  final List<DuaCategory>? allCategories;
  final String segmentName;
  final Color segmentColor;

  const DuaTitleScreen({
    super.key,
    this.category,
    this.allCategories,
    required this.segmentName,
    required this.segmentColor,
  });

  @override
  State<DuaTitleScreen> createState() => _DuaTitleScreenState();
}

class _DuaTitleScreenState extends State<DuaTitleScreen> {
  final Set<String> _expandedTitles = {};
  // Precomputed once — avoids re-iterating categories on every build
  late final List<_Entry> _titleEntries;
  late final String _screenTitle;

  String _key(int catId, int titleId) => '$catId-$titleId';
  bool _isExpanded(int catId, int titleId) =>
      _expandedTitles.contains(_key(catId, titleId));

  void _toggle(int catId, int titleId) {
    setState(() {
      final k = _key(catId, titleId);
      if (_expandedTitles.contains(k)) {
        _expandedTitles.remove(k);
      } else {
        _expandedTitles.add(k);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _titleEntries = _buildEntries();
    _screenTitle = widget.category?.categoryName ?? 'All Duas';
  }

  List<_Entry> _buildEntries() {
    final categories = widget.category != null
        ? [widget.category!]
        : (widget.allCategories ?? []);
    final entries = <_Entry>[];
    for (final cat in categories) {
      for (final t in cat.titles) {
        entries.add(_Entry(
          categoryId: cat.categoryId,
          categoryName: cat.categoryName,
          title: t,
        ));
      }
    }
    return entries;
  }

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
    final titleEntries = _titleEntries;
    final showAllMode = widget.allCategories != null;

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Immersive Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, topPadding + 8, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
            ),
            child: Column(
              children: [
                // Top row: Back | Title (center) | Font settings
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
                    Expanded(
                      child: Text(
                        _screenTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Font settings button
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
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: titleEntries.isEmpty
                ? Center(
                    child: Text('No titles found',
                        style: TextStyle(color: qt.textMuted)))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        20, 16, 20, 32 + MediaQuery.of(context).padding.bottom),
                    itemCount: titleEntries.length,
                    itemBuilder: (context, index) {
                      final entry = titleEntries[index];
                      final expanded =
                          _isExpanded(entry.categoryId, entry.title.titleId);
                      final title = entry.title;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category label for "All" mode
                            if (showAllMode &&
                                (index == 0 ||
                                    titleEntries[index - 1].categoryName !=
                                        entry.categoryName))
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, top: 8, bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: widget.segmentColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(entry.categoryName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: qt.textMuted,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3)),
                                  ],
                                ),
                              ),

                            // Title row
                            GestureDetector(
                              onTap: () =>
                                  _toggle(entry.categoryId, title.titleId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: qt.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: expanded
                                        ? qt.emeraldDeep.withOpacity(0.25)
                                        : qt.borderGlass,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title.titleName,
                                        style: TextStyle(
                                          color: qt.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: qt.emeraldDeep.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('${title.duas.length}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: qt.emeraldDeep,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                        expanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: qt.textMuted,
                                        size: 22),
                                  ],
                                ),
                              ),
                            ),

                            // Expanded duas — instant, no animation
                            if (expanded)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  children: title.duas
                                      .map((dua) => _DuaCard(
                                            dua: dua,
                                            segmentName: widget.segmentName,
                                            categoryName: entry.categoryName,
                                            titleName: title.titleName,
                                          ))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  final int categoryId;
  final String categoryName;
  final DuaTitle title;
  const _Entry({
    required this.categoryId,
    required this.categoryName,
    required this.title,
  });
}

/// Font size adjustment bottom sheet
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
                color: qt.textMuted.withOpacity(0.3),
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
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: qt.borderGlass),
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
                          : qt.emeraldDeep.withOpacity(0.85),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Premium dua card — full width, source always visible, settings controlled.
/// Separate StatelessWidget so only visible cards rebuild on settings change.
class _DuaCard extends StatelessWidget {
  final DuaItem dua;
  final String segmentName;
  final String categoryName;
  final String titleName;

  const _DuaCard({
    required this.dua,
    required this.segmentName,
    required this.categoryName,
    required this.titleName,
  });

  void _copyDua(BuildContext context) {
    final settings = DuaSettingsProvider.of(context, listen: false);
    final parts = <String>[dua.arabic ?? ''];
    if (settings.showTransliteration && dua.latin != null) {
      parts.add(dua.latin!);
    }
    if (settings.showTranslation && dua.translation != null) {
      parts.add(dua.translation!);
    }
    final text = parts.where((s) => s.isNotEmpty).join('\n\n');

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Dua copied'),
        backgroundColor: QuranTheme.of(context).emeraldDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only listen to settings for font/toggle changes
    final settings = DuaSettingsProvider.of(context, listen: true);
    final arabicSize = settings.arabicFontSize;
    final translationSize = settings.translationFontSize;
    final showTransliteration = settings.showTransliteration;
    final showTranslation = settings.showTranslation;
    // Listen to progress for favorite state
    final progress = DuaProgressProvider.of(context, listen: true);
    final isFav = progress.isFavorite(dua.id);
    final qt = QuranTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qt.borderGlass),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('#${dua.id}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: qt.emeraldDeep)),
                      ),
                      if (dua.repeat > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.replay_rounded,
                                  size: 11, color: qt.emeraldDeep),
                              const SizedBox(width: 3),
                              Text('${dua.repeat}x',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: qt.emeraldDeep)),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: () => progress.toggleFavorite(DuaFavorite(
                          duaId: dua.id,
                          segmentName: segmentName,
                          categoryName: categoryName,
                          titleName: titleName,
                          latin: dua.latin,
                          translation: dua.translation,
                        )),
                        child: Icon(
                          isFav
                              ? Icons.favorite
                              : Icons.favorite_outline_rounded,
                          color: isFav ? Colors.redAccent : qt.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _copyDua(context),
                        child: Icon(Icons.copy_rounded,
                            size: 18, color: qt.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Arabic — full width, right-aligned
                  if (dua.arabic != null && dua.arabic!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        dua.arabic!,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'IndopakN',
                          fontSize: arabicSize,
                          height: 1.7,
                          color: qt.textPrimary,
                        ),
                      ),
                    ),

                  // Latin (conditional)
                  if (showTransliteration &&
                      dua.latin != null &&
                      dua.latin!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        dua.latin!,
                        style: TextStyle(
                          fontSize: translationSize,
                          fontStyle: FontStyle.italic,
                          color: qt.brightness == Brightness.dark
                              ? qt.emeraldGlow
                              : qt.emeraldDeep.withOpacity(0.85),
                          height: 1.5,
                        ),
                      ),
                    ),

                  // Translation (conditional)
                  if (showTranslation &&
                      dua.translation != null &&
                      dua.translation!.isNotEmpty)
                    Text(
                      dua.translation!,
                      style: TextStyle(
                        fontSize: translationSize,
                        color: qt.textPrimary,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),

            // Bottom section: benefits + source — always visible
            if (dua.benefits != null || dua.source != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dua.benefits != null && dua.benefits!.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 12, color: qt.emeraldDeep),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(dua.benefits!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: qt.textMuted,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                      if (dua.source != null && dua.source!.isNotEmpty)
                        const SizedBox(height: 6),
                    ],
                    if (dua.source != null && dua.source!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 11, color: qt.textMuted.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(dua.source!,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: qt.textMuted.withOpacity(0.5))),
                          ),
                        ],
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
