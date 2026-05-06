import 'package:flutter/material.dart';
import '../../constants/quran_theme.dart';
import '../../services/hadith_service.dart';
import '../../models/hadith_models.dart';
import 'hadith_book_screen.dart';

class HadithHomeScreen extends StatefulWidget {
  const HadithHomeScreen({super.key});

  @override
  State<HadithHomeScreen> createState() => _HadithHomeScreenState();
}

class _HadithHomeScreenState extends State<HadithHomeScreen> {
  late Future<List<HadithBookInfo>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = HadithService.instance.loadHadithBooks();
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        backgroundColor: qt.cardBg,
        elevation: 0,
        centerTitle: true,
        title:
            Text('Hadith Collection', style: TextStyle(color: qt.textPrimary)),
        iconTheme: IconThemeData(color: qt.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a hadith book to begin',
                  style: TextStyle(color: qt.textMuted, fontSize: 14)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<HadithBookInfo>>(
                  future: _booksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(qt.emeraldLight)),
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(book.title,
                                          style: TextStyle(
                                              color: qt.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
