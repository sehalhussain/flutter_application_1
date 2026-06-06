import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/quran_theme.dart';
import '../../main.dart';
import '../../models/hadith_models.dart';
import '../../providers/quran_settings_provider.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../providers/hadith_reader_settings_provider.dart';
import 'hadith_search_screen.dart';

class HadithReaderScreen extends StatefulWidget {
  final Hadith hadith;
  final String bookTitle;
  final String chapterTitle;

  const HadithReaderScreen({
    required this.hadith,
    required this.bookTitle,
    required this.chapterTitle,
    super.key,
  });

  @override
  State<HadithReaderScreen> createState() => _HadithReaderScreenState();
}

class _HadithReaderScreenState extends State<HadithReaderScreen> {
  void _toggleFavorite(HadithProgressProvider progress) {
    progress.toggleFavorite(widget.hadith.bookAsset, widget.hadith.srno);
  }

  void _openReaderSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const HadithReaderSettingsSheet(),
    );
  }

  void _shareHadith() {
    final text = '${widget.hadith.title}\n\n'
        '${widget.hadith.narrator}\n\n'
        '${widget.hadith.arabicText}\n\n'
        '${widget.hadith.englishText}\n\n'
        '— ${widget.bookTitle}, ${widget.chapterTitle}';
    Share.share(text);
  }

  Widget _buildBadgedAction(
    QuranTheme qt, {
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: qt.borderGlass.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final progress = HadithProgressProvider.of(context, listen: true);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
    final isFavorite =
        progress.isFavorite(widget.hadith.bookAsset, widget.hadith.srno);
    final canGoBack =
        Navigator.canPop(context) || MainNavigation.canPopShell(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Immersive Premium Header matching Chapter Screen Visuals ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
              boxShadow: [
                BoxShadow(
                  color: qt.emeraldDeep.withOpacity(0.15),
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
                      child: canGoBack
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 22),
                              onPressed: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else if (MainNavigation.canPopShell(
                                    context)) {
                                  MainNavigation.popShell(context);
                                }
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Text(
                        widget.bookTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 22),
                        onPressed: _openReaderSettings,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Chapter Sub-title tag (tappable → unified search with this book)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HadithSearchScreen(
                          preSelectedBookTitle: widget.bookTitle,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.chapterTitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.95),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  // Metadata Chapter/Item identifier row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'HADITH #${widget.hadith.localNum}',
                          style: TextStyle(
                            color: qt.emeraldDeep,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hadith Title text flow
                  if (widget.hadith.title.isNotEmpty) ...[
                    Text(
                      widget.hadith.title,
                      style: TextStyle(
                        color: qt.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                        height: 1.35,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Narrator attribution text
                  if (widget.hadith.narrator.isNotEmpty) ...[
                    Text(
                      'Narrated by ${widget.hadith.narrator}',
                      style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Arabic flow with unified translucent background plate
                  if (settings.showArabic &&
                      widget.hadith.arabicText.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: qt.brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.03)
                            : Colors.white.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: qt.borderGlass.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.hadith.arabicText,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'indopak',
                          fontSize: settings.arabicFontSize,
                          color: qt.textPrimary,
                          height: 1.85,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Translation paragraphs flow
                  if (settings.showEnglish &&
                      widget.hadith.englishText.trim().isNotEmpty)
                    Text(
                      widget.hadith.englishText
                          .trim()
                          .split('\n\n')
                          .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
                          .join('\n\n'),
                      style: TextStyle(
                        color: qt.textSecondary,
                        fontSize: settings.translationFontSize,
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                      textAlign: TextAlign.start,
                    ),

                  if (settings.showEnglish &&
                      widget.hadith.englishText.trim().isNotEmpty)
                    const SizedBox(height: 24),

                  // Editorial baseline separator
                  Divider(
                    color: qt.borderGlass.withOpacity(0.08),
                    height: 1,
                    thickness: 1,
                  ),
                  const SizedBox(height: 20),

                  // Action panel footer (Grade + Favorite/Share)
                  Row(
                    children: [
                      if (widget.hadith.grade.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: qt.emeraldDeep.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            widget.hadith.grade,
                            style: TextStyle(
                              color: qt.emeraldDeep,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      const Spacer(),

                      // Navigation reading utilities (Share + Favorite only)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBadgedAction(
                            qt,
                            icon: Icons.share_outlined,
                            color: qt.textMuted,
                            onPressed: _shareHadith,
                            tooltip: 'Share Hadith',
                          ),
                          const SizedBox(width: 8),
                          _buildBadgedAction(
                            qt,
                            icon: isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite ? Colors.redAccent : qt.textMuted,
                            onPressed: () => _toggleFavorite(
                                progress as HadithProgressProvider),
                            tooltip: 'Like Hadith',
                          ),
                        ],
                      ),
                    ],
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

class HadithReaderSettingsSheet extends StatelessWidget {
  const HadithReaderSettingsSheet({super.key});

  Widget _modeChip(
      String label, bool selected, VoidCallback onTap, QuranTheme qt) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? qt.emeraldDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : qt.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
    final appSettings = QuranSettingsProvider.of(context, listen: true);
    final qt = QuranTheme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: qt.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: qt.borderGlass.withOpacity(0.4))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: qt.borderGlass,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Reader Settings',
            style: TextStyle(
              color: qt.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Theme',
            style: TextStyle(
              color: qt.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: qt.borderGlass.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _modeChip(
                        'Auto',
                        appSettings.themeMode == ThemeMode.system,
                        () => appSettings.setThemeMode(ThemeMode.system),
                        qt)),
                Expanded(
                    child: _modeChip(
                        'Light',
                        appSettings.themeMode == ThemeMode.light,
                        () => appSettings.setThemeMode(ThemeMode.light),
                        qt)),
                Expanded(
                    child: _modeChip(
                        'Dark',
                        appSettings.themeMode == ThemeMode.dark,
                        () => appSettings.setThemeMode(ThemeMode.dark),
                        qt)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Display',
            style: TextStyle(
              color: qt.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Arabic'),
            subtitle: const Text('Toggle the Arabic narration text.'),
            value: settings.showArabic,
            onChanged: settings.setShowArabic,
          ),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Show English'),
            subtitle: const Text('Toggle the translation text.'),
            value: settings.showEnglish,
            onChanged: settings.setShowEnglish,
          ),
          const SizedBox(height: 16),

          // Arabic Font Size adjustments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arabic Font Size',
                style: TextStyle(
                    color: qt.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                '${settings.arabicFontSize.round()} px',
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: settings.arabicFontSize,
            min: 18,
            max: 42,
            divisions: 12,
            activeColor: qt.emeraldDeep,
            inactiveColor: qt.emeraldDeep.withOpacity(0.12),
            onChanged: settings.setArabicFontSize,
          ),
          const SizedBox(height: 8),

          // Translation Font Size adjustments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Translation Font Size',
                style: TextStyle(
                    color: qt.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                '${settings.translationFontSize.round()} px',
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: settings.translationFontSize,
            min: 14,
            max: 28,
            divisions: 14,
            activeColor: qt.emeraldDeep,
            inactiveColor: qt.emeraldDeep.withOpacity(0.12),
            onChanged: settings.setTranslationFontSize,
          ),
          const SizedBox(height: 16),

          // Dynamic Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: qt.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Live Preview',
                  style: TextStyle(
                    color: qt.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'مثال الحديث الشريف',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'indopak',
                    fontSize: settings.arabicFontSize,
                    height: 1.8,
                    color: qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The translation font size will scale smoothly across all Hadith reader views.',
                  style: TextStyle(
                    color: qt.textSecondary,
                    fontSize: settings.translationFontSize,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
