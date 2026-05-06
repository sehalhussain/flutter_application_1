import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/quran_settings_provider.dart';
import 'providers/quran_progress_provider.dart';
import 'providers/hadith_progress_provider.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/quran/quran_home_screen.dart';
import 'screens/prayer_screen.dart';
import 'constants/quran_theme.dart';
import 'services/quran_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load metadata for performance
  await QuranService.instance.loadSurahList();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuranSettings()..load()),
        ChangeNotifierProvider(create: (_) => QuranProgress()..load()),
        ChangeNotifierProvider(create: (_) => HadithProgress()..load()),
      ],
      child: const AsSalahApp(),
    ),
  );
}

class AsSalahApp extends StatelessWidget {
  const AsSalahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<QuranSettings>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF26A69A),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFBFDFA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF26A69A),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF0F1711),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  final screens = [
    const HomeScreen(),
    const PrayerScreen(),
    const MenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: IndexedStack(
          index: _index >= 2 ? _index - 1 : _index, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: qt.borderGlass, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            if (i == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuranHomeScreen()),
              );
            } else {
              setState(() => _index = i);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: qt.cardBg,
          selectedItemColor: qt.emeraldDeep,
          unselectedItemColor: qt.textMuted,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                activeIcon: Icon(Icons.home_filled),
                label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.access_time),
                activeIcon: Icon(Icons.access_time),
                label: "Prayer"),
            BottomNavigationBarItem(
                icon: Icon(Icons.book),
                activeIcon: Icon(Icons.menu_book_rounded),
                label: "Quran"),
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                activeIcon: Icon(Icons.grid_view_rounded),
                label: "Menu"),
          ],
        ),
      ),
    );
  }
}
