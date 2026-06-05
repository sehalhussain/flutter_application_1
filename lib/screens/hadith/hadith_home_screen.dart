import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../models/hadith_models.dart';
import '../../providers/hadith_progress_provider.dart';
import '../../services/hadith_service.dart';
import '../../main.dart';
import 'hadith_book_screen.dart';
import 'hadith_chapter_screen.dart';
import 'hadith_reader_screen.dart';
import 'hadith_search_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// HADITH HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════

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

  String _getBookDescription(String title) {
    final t = title.toLowerCase();
    if (t.contains('bukhari')) {
      return 'The most authentic compilation of Hadith, focusing on sound chains of narration.';
    } else if (t.contains('muslim')) {
      return 'Highly authentic compilation, praised for its meticulous thematic arrangement.';
    } else if (t.contains('dawud') || t.contains('davud')) {
      return 'An authoritative collection of Hadith focusing primarily on legal rulings (Ahkam).';
    } else if (t.contains('tirmidhi')) {
      return 'Famous for discussing legal opinions and categorizing Hadith grades.';
    } else if (t.contains('nasai') || t.contains("nasa'i")) {
      return 'Renowned for its rigorous criteria in selecting narrations and minor legal points.';
    } else if (t.contains('majah')) {
      return 'One of the six canonical books, covering a wide range of legal and theological topics.';
    } else if (t.contains('riyad') || t.contains('salihin')) {
      return 'A beautiful curation of verses and Hadiths on moral conduct and character development.';
    } else if (t.contains('adab') && t.contains('mufrad')) {
      return 'An invaluable guide focusing entirely on manners, social ethics, and family relationships.';
    } else if (t.contains('nawawi') ||
        t.contains('forty') ||
        t.contains('40')) {
      return 'A foundational collection of pivotal Hadiths summarizing the core principles of Islam.';
    } else if (t.contains('mishkat')) {
      return 'A comprehensive expansion of foundational Hadith sources organized by topic.';
    } else if (t.contains('shamail') || t.contains('shama\'il')) {
      return 'A beautiful collection detailing the physical traits and daily life of the Prophet ﷺ.';
    }
    return 'Explore authentic narrations and moral guidance from the Prophetic traditions.';
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final progress = HadithProgressProvider.of(context, listen: true);
    final topPadding = MediaQuery.of(context).padding.top;

    final currentKey = progress.favorites
        .map((favorite) => '${favorite.assetPath}|${favorite.hadithUuid}')
        .join(',');
    if (currentKey != _favoritesKey) {
      _favoritesKey = currentKey;
      _favoritesFuture = _loadFavoriteHadiths();
    }

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // ── Immersive Premium Header ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 4, 16, 2),
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
                      child: MainNavigation.canPopShell(context)
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 22),
                              onPressed: () => MainNavigation.popShell(context),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const Expanded(
                      child: Text(
                        'Hadith Library',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
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
                        icon: const Icon(Icons.search_rounded,
                            color: Colors.white, size: 22),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HadithSearchScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"The best among you are those who learn the Quran \n and teach it. (Al-Bukhari 5027)"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // ── Tab Bar (Sleek integration) ──
          Container(
            color: qt.emeraldMid,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Books'),
                Tab(text: 'Liked'),
              ],
            ),
          ),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBooksTab(qt),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildFavoritesTab(qt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required QuranTheme qt,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: qt.emeraldLight,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: qt.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(HadithBookInfo book, QuranTheme qt) {
    final description = _getBookDescription(book.title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HadithBookScreen(book: book)));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(20),
            // THE CHANGE: Ultra-soft hidden glassmorphic borders
            border: Border.all(color: qt.borderGlass.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  qt.brightness == Brightness.dark ? 0.15 : 0.02,
                ),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Consistent uniform icon layout representing equal value & importance
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: qt.emeraldDeep.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: qt.emeraldDeep, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        color: qt.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: qt.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right_rounded,
                    color: qt.textMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBooksTab(QuranTheme qt) {
    final progress = HadithProgressProvider.of(context, listen: true);
    final showLastRead = progress.lastRead != null;

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
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          );
        }

        final books = snapshot.data!;
        if (books.isEmpty) {
          return Center(
            child: Text('No hadith books found',
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          );
        }

        // Dynamically split books into categories based on canonical identifiers
        final kutubAlSittah = <HadithBookInfo>[];
        final selections = <HadithBookInfo>[];

        for (final book in books) {
          final titleLower = book.title.toLowerCase();
          // Including Sunan an-Nasa'i properly inside Kutub Al-Sittah
          if (titleLower.contains('bukhari') ||
              titleLower.contains('muslim') ||
              titleLower.contains('dawud') ||
              titleLower.contains('davud') ||
              titleLower.contains('tirmidhi') ||
              titleLower.contains('nasa\'i') ||
              titleLower.contains('majah')) {
            kutubAlSittah.add(book);
          } else {
            selections.add(book);
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          physics: const BouncingScrollPhysics(),
          children: [
            if (showLastRead) ...[
              _buildLastReadBanner(progress.lastRead!, qt),
              const SizedBox(height: 8),
            ],

            // ── Section 1: Kutub Al Sittah (The 6 Books) ──
            if (kutubAlSittah.isNotEmpty) ...[
              _buildSectionHeader(
                title: "Kutub al-Sittah / The 6 Hadith",
                subtitle:
                    "The six canonical, authoritative books forming the foundation of Prophetic tradition.",
                qt: qt,
              ),
              ...kutubAlSittah.map((book) => _buildBookCard(book, qt)).toList(),
            ],

            // ── Section 2: Selections & Compilations ──
            if (selections.isNotEmpty) ...[
              _buildSectionHeader(
                title: "Selections & Compilations",
                subtitle:
                    "Curated collections compiled for general guidance, moral wisdom, and easier daily reading.",
                qt: qt,
              ),
              ...selections.map((book) => _buildBookCard(book, qt)).toList(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFavoritesTab(QuranTheme qt) {
    final progress = HadithProgressProvider.of(context, listen: true);
    final showLastRead = progress.lastRead != null;

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
                style: TextStyle(
                    color: qt.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          );
        }

        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) {
          if (showLastRead) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildLastReadBanner(progress.lastRead!, qt),
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: qt.textMuted.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.favorite_border_rounded,
                            size: 48, color: qt.textMuted.withOpacity(0.4)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No liked hadiths yet',
                        style: TextStyle(
                            color: qt.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: qt.textMuted.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite_border_rounded,
                      size: 48, color: qt.textMuted.withOpacity(0.4)),
                ),
                const SizedBox(height: 16),
                Text(
                  'No liked hadiths yet',
                  style: TextStyle(
                      color: qt.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: favorites.length + (showLastRead ? 1 : 0),
          itemBuilder: (context, index) {
            if (showLastRead && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLastReadBanner(progress.lastRead!, qt),
              );
            }

            final itemIndex = showLastRead ? index - 1 : index;
            final item = favorites[itemIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: qt.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    // THE CHANGE: Switched to soft visual borders using Opacity
                    border: Border.all(color: qt.borderGlass.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          qt.brightness == Brightness.dark ? 0.15 : 0.02,
                        ),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.hadith.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: qt.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
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
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded,
                                  color: Colors.redAccent, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.chapterTitle,
                        style: TextStyle(color: qt.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.bookTitle,
                          style: TextStyle(
                              color: qt.emeraldDeep,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.hadith.englishText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: qt.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
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
        final book = await HadithService.instance.loadHadithBook(
          lastRead.assetPath,
          preloadAll: true,
        );
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: qt.emeraldDeep.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: qt.emeraldDeep.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: qt.emeraldDeep.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark_added_rounded,
                    color: qt.emeraldDeep, size: 18),
                const SizedBox(width: 6),
                Text(
                  'RESUME LAST READ',
                  style: TextStyle(
                    color: qt.emeraldDeep,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lastRead.hadithTitle,
              style: TextStyle(
                  color: qt.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${lastRead.chapterTitle} • ${lastRead.bookTitle}',
              style: TextStyle(color: qt.textMuted, fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER CLASS DEFINITION
// ═══════════════════════════════════════════════════════════════════════════

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
