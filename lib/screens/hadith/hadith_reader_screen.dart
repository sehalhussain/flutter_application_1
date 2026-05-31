import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../providers/hadith_reader_settings_provider.dart';

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
    progress.toggleFavorite(widget.hadith.bookAsset, widget.hadith.uuid);
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

  Widget _buildTopActionBadge(QuranTheme qt,
      {required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: qt.textPrimary, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildCircularBadgeAction(
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
        color: qt.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: qt.borderGlass.withOpacity(0.3)),
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
        progress.isFavorite(widget.hadith.bookAsset, widget.hadith.uuid);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: qt.textPrimary),
        title: Text(
          widget.hadith.title.isNotEmpty
              ? widget.hadith.title
              : 'Hadith Details',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: qt.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _buildTopActionBadge(
                qt,
                icon: Icons.tune_rounded,
                onTap: _openReaderSettings,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // Chapter Title Header Label
            Text(
              widget.chapterTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: qt.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Immersive Glassmorphic Main Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: qt.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hadith #${widget.hadith.localNum}',
                            style: TextStyle(
                              color: qt.emeraldLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (widget.hadith.grade.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: qt.emeraldDeep.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.hadith.grade,
                                style: TextStyle(
                                  color: qt.emeraldDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Shared Visual Card Control Panel
                      Row(
                        children: [
                          _buildCircularBadgeAction(
                            qt,
                            icon: Icons.share_outlined,
                            color: qt.textMuted,
                            onPressed: _shareHadith,
                            tooltip: 'Share Hadith',
                          ),
                          const SizedBox(width: 8),
                          _buildCircularBadgeAction(
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
                  const SizedBox(height: 16),

                  // Narrator block if present
                  if (widget.hadith.narrator.isNotEmpty) ...[
                    Text(
                      'Narrator: ${widget.hadith.narrator}',
                      style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Arabic Block Content with Clean Wrapper
                  if (widget.hadith.arabicText.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: qt.bg,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: qt.borderGlass.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.hadith.arabicText,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'indopak',
                          fontSize: settings.arabicFontSize,
                          color: qt.textPrimary,
                          height: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Divider
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: qt.borderGlass.withOpacity(0.3),
                  ),
                  const SizedBox(height: 20),

                  // English Translation Block - Formatted and Correctly Aligned
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
                    ),
                    textAlign: TextAlign.start,
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

class HadithReaderSettingsSheet extends StatelessWidget {
  const HadithReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
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
          // Drag handle
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

          // Arabic Font Size Adjustments
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

          // Translation Font Size Adjustments
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

          // Preview Card
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
