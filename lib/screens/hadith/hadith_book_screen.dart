import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../services/hadith_service.dart';
import 'hadith_chapter_screen.dart';

class HadithBookScreen extends StatefulWidget {
  final HadithBookInfo book;

  const HadithBookScreen({required this.book, super.key});

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  late Future<HadithBook> _bookFuture;
  final TextEditingController _searchController = TextEditingController();
  List<HadithChapter> _filteredChapters = [];
  List<HadithChapter> _allChapters = [];

  @override
  void initState() {
    super.initState();
    _bookFuture = HadithService.instance.loadHadithBook(widget.book.assetPath);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChapters = _allChapters.where((chapter) {
        return chapter.englishTitle.toLowerCase().contains(query) ||
            chapter.arabicTitle.contains(query) ||
            chapter.num.contains(query) ||
            chapter.hadithList.any((h) =>
                h.englishText.toLowerCase().contains(query) ||
                h.arabicText.contains(query) ||
                h.title.toLowerCase().contains(query));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: qt.textPrimary),
        title: Text(widget.book.title, style: TextStyle(color: qt.textPrimary)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: FutureBuilder<HadithBook>(
            future: _bookFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(qt.emeraldLight)));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Text('Unable to load book',
                      style: TextStyle(color: qt.textMuted)),
                );
              }

              final book = snapshot.data!;
              if (book.allBooks.isEmpty) {
                return Center(
                  child: Text('No chapters found',
                      style: TextStyle(color: qt.textMuted)),
                );
              }

              if (_allChapters.isEmpty) {
                _allChapters = book.allBooks;
                _filteredChapters = _allChapters;
              }

              return Column(
                children: [
                  // Book info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: qt.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: qt.borderGlass),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.name,
                            style: TextStyle(
                                color: qt.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(book.arabicName,
                            style: TextStyle(
                                color: qt.textSecondary,
                                fontSize: 14,
                                fontFamily: 'QPC Hafs')),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${book.numBooks} Chapters',
                                style: TextStyle(
                                    color: qt.emeraldDeep,
                                    fontWeight: FontWeight.bold)),
                            Text('${book.numHadiths} Hadiths',
                                style: TextStyle(
                                    color: qt.emeraldDeep,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search chapters or hadiths...',
                      prefixIcon: Icon(Icons.search, color: qt.textMuted),
                      filled: true,
                      fillColor: qt.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: qt.borderGlass),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: qt.borderGlass),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: qt.emeraldDeep),
                      ),
                    ),
                    style: TextStyle(color: qt.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  // Chapters list
                  Expanded(
                    child: _filteredChapters.isEmpty
                        ? Center(
                            child: Text('No chapters found',
                                style: TextStyle(color: qt.textMuted)),
                          )
                        : ListView.separated(
                            itemCount: _filteredChapters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final chapter = _filteredChapters[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => HadithChapterScreen(
                                            chapter: chapter,
                                            bookAsset: widget.book.assetPath,
                                            bookName: book.name,
                                          )));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: qt.cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: qt.borderGlass),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: qt.emeraldDeep.withAlpha(31),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(chapter.num,
                                            style: TextStyle(
                                                color: qt.emeraldDeep,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(chapter.englishTitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: qt.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 6),
                                            Text(chapter.arabicTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: qt.textMuted,
                                                    fontSize: 12,
                                                    fontFamily: 'QPC Hafs')),
                                            const SizedBox(height: 6),
                                            Text(
                                                '${chapter.hadithList.length} hadith${chapter.hadithList.length != 1 ? 's' : ''}',
                                                style: TextStyle(
                                                    color: qt.emeraldLight,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: qt.textMuted),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
