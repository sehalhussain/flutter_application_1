import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../models/quran_models.dart';
import '../../services/quran_service.dart';
import '../../constants/quran_theme.dart';
import 'quran_reader_screen.dart';

class SurahInfoScreen extends StatefulWidget {
  final int surahNumber;
  final List<SurahInfo> surahList;

  const SurahInfoScreen({
    super.key, 
    required this.surahNumber,
    required this.surahList,
  });

  @override
  State<SurahInfoScreen> createState() => _SurahInfoScreenState();
}

class _SurahInfoScreenState extends State<SurahInfoScreen> {
  late Future<SurahDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = QuranService.instance.getSurahDetail(widget.surahNumber);
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.bg,
        elevation: 0,
        title: Text('Surah Information', 
          style: TextStyle(color: qt.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: qt.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<SurahDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: qt.emeraldLight, strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error loading surah information: ${snapshot.error}', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: qt.textMuted)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No information available.', style: TextStyle(color: qt.textMuted)));
          }

          final detail = snapshot.data!;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.surahName,
                  style: TextStyle(
                    color: qt.emeraldLight,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                HtmlWidget(
                  detail.text,
                  textStyle: TextStyle(
                    color: qt.textPrimary.withOpacity(0.9),
                    fontSize: 16,
                    height: 1.7,
                  ),
                  onTapUrl: (url) {
                    _handleLink(url);
                    return true;
                  },
                  customStylesBuilder: (element) {
                    if (element.localName == 'h2') {
                      return {
                        'color': '#${qt.emeraldLight.value.toRadixString(16).substring(2)}',
                        'font-weight': '800',
                        'font-size': '22px',
                        'margin-top': '32px',
                        'margin-bottom': '12px',
                      };
                    }
                    if (element.localName == 'p') {
                      return {'margin-bottom': '16px'};
                    }
                    if (element.localName == 'a') {
                      return {
                        'color': '#${qt.emeraldLight.value.toRadixString(16).substring(2)}',
                        'text-decoration': 'none',
                        'font-weight': '700',
                      };
                    }
                    if (element.localName == 'em') {
                      return {'font-style': 'italic', 'color': '#${qt.emeraldGlow.value.toRadixString(16).substring(2)}'};
                    }
                    return null;
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleLink(String url) {
    // Example URLs: "/30/2" or "/31/12-19"
    final parts = url.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final surahNum = int.tryParse(parts[0]);
      final ayahPart = parts[1];
      int? ayahNum;
      if (ayahPart.contains('-')) {
        ayahNum = int.tryParse(ayahPart.split('-')[0]);
      } else {
        ayahNum = int.tryParse(ayahPart);
      }

      if (surahNum != null && ayahNum != null) {
        if (surahNum == widget.surahNumber) {
          // Same surah, just pop and scroll
          Navigator.of(context).pop({'ayah': ayahNum});
        } else {
          // Different surah, push replacement reader
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QuranReaderScreen(
                surahNumber: surahNum,
                initialAyah: ayahNum,
                surahList: widget.surahList,
              ),
            ),
          );
        }
      }
    }
  }
}
