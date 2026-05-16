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
  void _toggleFavorite(HadithProgress progress) {
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
    final text = 'Hadith: ${widget.hadith.title}\n\n'
        '${widget.hadith.narrator}\n\n'
        '${widget.hadith.arabicText}\n\n'
        '${widget.hadith.englishText}\n\n'
        '— ${widget.bookTitle}, ${widget.chapterTitle}';
    Share.share(text);
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
    final progress = HadithProgressProvider.of(context, listen: true);
    final settings = HadithReaderSettingsProvider.of(context, listen: true);
    final isFavorite =
        progress.isFavorite(widget.hadith.bookAsset, widget.hadith.uuid);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: qt.textPrimary),
        title: Text(widget.hadith.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: qt.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _openReaderSettings,
              child: Center(
                child: _glassBtn(
                    Icon(Icons.tune_rounded, color: qt.textPrimary, size: 18),
                    qt),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(widget.chapterTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: qt.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: qt.cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: qt.borderGlass),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
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
                          Text('Hadith #${widget.hadith.localNum}',
                              style: TextStyle(
                                  color: qt.emeraldLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          if (widget.hadith.grade.isNotEmpty)
                            Text(widget.hadith.grade,
                                style: TextStyle(
                                    color: qt.textMuted, fontSize: 10)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _shareHadith,
                            icon: Icon(Icons.share_outlined,
                                color: qt.textMuted, size: 20),
                          ),
                          IconButton(
                            onPressed: () => _toggleFavorite(progress),
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  isFavorite ? Colors.redAccent : qt.textMuted,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.hadith.narrator.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(widget.hadith.narrator,
                          style: TextStyle(
                              color: qt.textMuted,
                              fontSize: 12,
                              fontStyle: FontStyle.italic)),
                    ),
                  Text(widget.hadith.arabicText,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontFamily: 'indopak',
                          fontSize: settings.arabicFontSize,
                          color: qt.textPrimary,
                          height: 1.9),
                      softWrap: true),
                  const SizedBox(height: 24),
                  Container(
                    width: 40,
                    height: 1,
                    color: qt.borderGlass,
                  ),
                  const SizedBox(height: 24),
                  Text(
                      widget.hadith.englishText
                          .split('\n\n')
                          .map((p) => p.replaceAll('\n', ' '))
                          .join('\n\n'),
                      style: TextStyle(
                          color: qt.textSecondary,
                          fontSize: settings.translationFontSize,
                          height: 1.75),
                      textAlign: TextAlign.justify,
                      softWrap: true),
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
    final settings = HadithReaderSettingsProvider.of(context);
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
          Text('Reader Settings',
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
            min: 14,
            max: 28,
            divisions: 14,
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
                Text('مثال الحديث',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontFamily: 'QPC Hafs',
                        fontSize: settings.arabicFontSize,
                        height: 1.8,
                        color: qt.textPrimary)),
                const SizedBox(height: 12),
                Text(
                    'The translation font size will apply to all Hadith screens.',
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
