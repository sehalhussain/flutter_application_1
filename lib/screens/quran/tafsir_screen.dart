import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/quran_models.dart';
import '../../services/quran_service.dart';
import '../../constants/quran_theme.dart';
import 'quran_reader_screen.dart';

class TafsirScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final String? initialAuthor;
  final List<SurahInfo> surahList;

  const TafsirScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    this.initialAuthor,
    required this.surahList,
  });

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  late Future<TafsirResponse> _tafsirFuture;
  String? _selectedAuthor;
  bool _isDownloaded = false;

  static bool _authorMatches(String selected, String fromApi) {
    // Normalize both strings: lowercase, remove apostrophes, hyphens, spaces
    String normalize(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"['\-\s]"), '');
    final normalizedSelected = normalize(selected);
    final normalizedApi = normalize(fromApi);
    return normalizedSelected == normalizedApi ||
        normalizedApi.contains(normalizedSelected) ||
        normalizedSelected.contains(normalizedApi);
  }

  @override
  void initState() {
    super.initState();
    _tafsirFuture =
        QuranService.instance.getTafsir(widget.surahNumber, widget.ayahNumber);
    _selectedAuthor = widget.initialAuthor;
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final offline = await QuranService.instance
        .getOfflineTafsir(widget.surahNumber, widget.ayahNumber);
    if (mounted) {
      setState(() {
        _isDownloaded = offline != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.bg,
        elevation: 0,
        title: Text('Tafsir',
            style: TextStyle(
                color: qt.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: qt.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          FutureBuilder<TafsirResponse>(
            future: _tafsirFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return IconButton(
                  icon: Icon(
                      _isDownloaded
                          ? Icons.download_done_rounded
                          : Icons.download_rounded,
                      color: qt.emeraldLight),
                  tooltip: _isDownloaded ? "Downloaded" : "Save Offline",
                  onPressed: _isDownloaded
                      ? null
                      : () async {
                          await QuranService.instance.saveTafsirOffline(
                            widget.surahNumber,
                            widget.ayahNumber,
                            snapshot.data!,
                          );
                          if (context.mounted) {
                            setState(() {
                              _isDownloaded = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Tafsir saved for offline reading!'),
                                backgroundColor: qt.emeraldDeep,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FutureBuilder<TafsirResponse>(
        future: _tafsirFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: qt.emeraldLight, strokeWidth: 2));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error loading tafsir: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: qt.textMuted)),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
                child: Text('No tafsir available.',
                    style: TextStyle(color: qt.textMuted)));
          }

          final response = snapshot.data!;
          final authors = response.tafsirs.map((t) => t.author).toList();

          // Default to first author if none selected or if selected not found
          if (_selectedAuthor == null ||
              !authors.any((a) => _authorMatches(_selectedAuthor!, a))) {
            _selectedAuthor = authors.isNotEmpty ? authors.first : null;
          }

          final selectedTafsir = response.tafsirs.firstWhere(
            (t) => _authorMatches(_selectedAuthor ?? '', t.author),
            orElse: () => response.tafsirs.first,
          );

          return Column(
            children: [
              if (authors.length > 1) _buildAuthorSelector(authors, qt),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${response.surahName} (${response.surahNo}:${response.ayahNo})',
                        style: TextStyle(
                          color: qt.emeraldLight,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tafsir by ${selectedTafsir.author}',
                        style: TextStyle(
                          color: qt.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      MarkdownBody(
                        data: selectedTafsir.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: qt.textPrimary.withOpacity(0.9),
                            fontSize: 16,
                            height: 1.7,
                          ),
                          h1: TextStyle(
                            color: qt.emeraldLight,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 2.0,
                          ),
                          h2: TextStyle(
                            color: qt.emeraldLight,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.8,
                          ),
                          h3: TextStyle(
                            color: qt.emeraldLight,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          listBullet: TextStyle(color: qt.emeraldLight),
                          blockquote: TextStyle(
                            color: qt.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                                left: BorderSide(
                                    color: qt.emeraldLight, width: 4)),
                            color: qt.glassWhite,
                          ),
                          code: TextStyle(
                            backgroundColor: qt.glassWhite,
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                        onTapLink: (text, href, title) {
                          if (href != null) _handleLink(href);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthorSelector(List<String> authors, QuranTheme qt) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: authors.length,
        itemBuilder: (context, index) {
          final author = authors[index];
          final isSelected = _authorMatches(author, _selectedAuthor ?? '');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(author),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedAuthor = author;
                  });
                }
              },
              selectedColor: qt.emeraldLight.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? qt.emeraldLight : qt.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? qt.emeraldLight : qt.borderGlass,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleLink(String url) {
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
