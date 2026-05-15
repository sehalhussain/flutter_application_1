import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../services/hadith_service.dart';
import 'hadith_book_screen.dart';
import 'hadith_chapter_screen.dart';
import 'hadith_reader_screen.dart';

class HadithHomeScreen extends StatefulWidget {
  const HadithHomeScreen({super.key});

  @override
  State<HadithHomeScreen> createState() => _HadithHomeScreenState();
}

class _HadithHomeScreenState extends State<HadithHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Future<List<HadithBookInfo>> _booksFuture;
  Future<List<FavoriteHadithItem>>? _favoritesFuture;
  String _favoritesKey = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _booksFuture = HadithService.instance.loadHadithBooks();
    _favoritesFuture = _loadFavoriteHadiths();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<FavoriteHadithItem>> _loadFavoriteHadiths() async {
    final progress = HadithProgressProvider.of(context, listen: false);
    if (progress.favorites.isEmpty) return [];

    final groupedFavorites = <String, Set<String>>{};
    for (final favorite in progress.favorites) {
      groupedFavorites
          .putIfAbsent(favorite.assetPath, () => <String>{})
          .add(favorite.hadithUuid);
    }

    final favorites = <FavoriteHadithItem>[];
    for (final assetPath in groupedFavorites.keys) {
      final book = await HadithService.instance.loadHadithBook(assetPath);
      for (final chapter in book.allBooks) {
        for (final hadith in chapter.hadithList) {
          if (groupedFavorites[assetPath]!.contains(hadith.uuid)) {
            favorites.add(FavoriteHadithItem(
              hadith: hadith,
              bookTitle: book.name,
              chapterTitle: chapter.englishTitle,
            ));
          }
        }
      }
    }

    return favorites;
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final progress = HadithProgressProvider.of(context, listen: true);
    final currentKey = progress.favorites
        .map((favorite) => '${favorite.assetPath}|${favorite.hadithUuid}')
        .join(',');
    if (currentKey != _favoritesKey) {
      _favoritesKey = currentKey;
      _favoritesFuture = _loadFavoriteHadiths();
    }

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        centerTitle: true,
        title: Text('Hadith Library', style: TextStyle(color: qt.textPrimary)),
        iconTheme: IconThemeData(color: qt.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: qt.emeraldDeep,
          labelColor: qt.emeraldDeep,
          unselectedLabelColor: qt.textMuted,
          tabs: const [
            Tab(text: 'Books'),
            Tab(text: 'Liked'),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              if (progress.lastRead != null) ...[
                _buildLastReadBanner(progress.lastRead!, qt),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBooksTab(qt),
                    _buildFavoritesTab(qt),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBooksTab(QuranTheme qt) {
    return FutureBuilder<List<HadithBookInfo>>(
      future: _booksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(qt.emeraldLight)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text('Unable to load hadith books',
                style: TextStyle(color: qt.textMuted)),
          );
        }

        final books = snapshot.data!;
        if (books.isEmpty) {
          return Center(
            child: Text('No hadith books found',
                style: TextStyle(color: qt.textMuted)),
          );
        }

        return ListView.separated(
          itemCount: books.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final book = books[index];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => HadithBookScreen(book: book)));
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: qt.borderGlass),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: qt.emeraldDeep.withAlpha(31),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          color: qt.emeraldDeep, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(book.title,
                          style: TextStyle(
                              color: qt.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: qt.textMuted),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab(QuranTheme qt) {
    return FutureBuilder<List<FavoriteHadithItem>>(
      future: _favoritesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(qt.emeraldLight)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load favorites',
                style: TextStyle(color: qt.textMuted)),
          );
        }

        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) {
          return Center(
            child: Text('No liked hadiths yet',
                style: TextStyle(color: qt.textMuted)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final item = favorites[index];
            final progress = HadithProgressProvider.of(context, listen: false);
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HadithReaderScreen(
                    hadith: item.hadith,
                    bookTitle: item.bookTitle,
                    chapterTitle: item.chapterTitle,
                  ),
                ));
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: qt.borderGlass),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.hadith.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: qt.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            await progress.toggleFavorite(
                                item.hadith.bookAsset, item.hadith.uuid);
                            setState(() {
                              _favoritesFuture = _loadFavoriteHadiths();
                            });
                          },
                          child: const Icon(Icons.favorite,
                              color: Colors.redAccent, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(item.chapterTitle,
                        style: TextStyle(color: qt.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item.bookTitle,
                        style: TextStyle(
                            color: qt.emeraldDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Text(item.hadith.englishText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: qt.textSecondary,
                            fontSize: 13,
                            height: 1.5)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLastReadBanner(HadithLastReadPosition lastRead, QuranTheme qt) {
    return GestureDetector(
      onTap: () async {
        final book =
            await HadithService.instance.loadHadithBook(lastRead.assetPath);
        HadithChapter? foundChapter;
        for (final chapter in book.allBooks) {
          if (chapter.hadithList.any((h) => h.uuid == lastRead.hadithUuid)) {
            foundChapter = chapter;
            break;
          }
        }

        if (foundChapter != null && mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HadithChapterScreen(
              chapter: foundChapter!,
              bookAsset: lastRead.assetPath,
              bookName: lastRead.bookTitle,
            ),
          ));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: qt.emeraldDeep.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: qt.emeraldDeep.withAlpha((0.2 * 255).round())),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resume last read',
                style: TextStyle(
                    color: qt.emeraldDeep,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 6),
            Text(lastRead.hadithTitle,
                style: TextStyle(
                    color: qt.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${lastRead.chapterTitle} • ${lastRead.bookTitle}',
                style: TextStyle(color: qt.textMuted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class FavoriteHadithItem {
  final Hadith hadith;
  final String bookTitle;
  final String chapterTitle;

  FavoriteHadithItem({
    required this.hadith,
    required this.bookTitle,
    required this.chapterTitle,
  });
}
