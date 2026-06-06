import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../services/hadith_service.dart';
import 'hadith_chapter_screen.dart';
import 'hadith_reader_screen.dart';
import 'hadith_search_screen.dart';

class HadithBookScreen extends StatefulWidget {
  final HadithBookInfo book;

  const HadithBookScreen({required this.book, super.key});

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  late Future<HadithBook> _bookFuture;

  @override
  void initState() {
    super.initState();
    _bookFuture = HadithService.instance.loadHadithBook(
      widget.book.assetPath,
      preloadAll: false,
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 24),
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
                        widget.book.title,
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
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Search Bar → Unified search ──
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HadithSearchScreen(
                          preSelectedBookTitle: widget.book.title,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Search chapters or hadiths...',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FutureBuilder<HadithBook>(
                future: _bookFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(qt.emeraldLight)));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Text('Unable to load book data',
                          style: TextStyle(
                              color: qt.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    );
                  }

                  final book = snapshot.data!;
                  if (book.allBooks.isEmpty) {
                    return Center(
                      child: Text('No chapters found',
                          style: TextStyle(
                              color: qt.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    );
                  }

                  return _buildChapterList(qt, book, book.allBooks);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookStatsCard(QuranTheme qt, HadithBook book) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: qt.emeraldDeep.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    '${book.numBooks}',
                    style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text('Chapters',
                      style: TextStyle(color: qt.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: qt.emeraldDeep.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    '${book.numHadiths}',
                    style: TextStyle(
                        color: qt.emeraldDeep,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text('Hadiths',
                      style: TextStyle(color: qt.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList(
      QuranTheme qt, HadithBook book, List<HadithChapter> chapters) {
    if (chapters.isEmpty) {
      return Center(
        child: Text('No chapters found',
            style: TextStyle(
                color: qt.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: chapters.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildBookStatsCard(qt, book);
        }
        final chapter = chapters[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildChapterCard(qt, chapter),
        );
      },
    );
  }

  Widget _buildChapterCard(QuranTheme qt, HadithChapter chapter) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithChapterScreen(
                  chapter: chapter,
                  bookAsset: widget.book.assetPath,
                  bookName: widget.book.title,
                )));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chapter.num,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chapter.englishTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chapter.arabicTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 12,
                        fontFamily: 'QPC Hafs'),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${chapter.hadithCount > 0 ? chapter.hadithCount : chapter.hadithList.length} hadith${(chapter.hadithCount > 0 ? chapter.hadithCount : chapter.hadithList.length) != 1 ? 's' : ''}',
                      style: TextStyle(
                          color: qt.emeraldDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: qt.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
