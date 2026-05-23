import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart'; // 1. ADD THIS IMPORT
import 'providers/quran_settings_provider.dart';
import 'providers/quran_progress_provider.dart';
import 'providers/hadith_progress_provider.dart';
import 'providers/hadith_reader_settings_provider.dart';
import 'providers/dua_settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/quran/quran_home_screen.dart';
import 'screens/prayer_screen.dart';
import 'constants/quran_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. INITIALIZE JUST AUDIO BACKGROUND
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.kitably.app.channel.audio',
    androidNotificationChannelName: 'Kitably Quran Playback',
    androidNotificationOngoing: true,
  );

  // Enable edge-to-edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuranSettings()..load()),
        ChangeNotifierProvider(create: (_) => QuranProgress()..load()),
        ChangeNotifierProvider(create: (_) => HadithProgress()..load()),
        ChangeNotifierProvider(create: (_) => HadithReaderSettings()..load()),
        ChangeNotifierProvider(create: (_) => DuaSettings()..load()),
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
      home: const _SplashWrapper(),
    );
  }
}

class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper();

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  double _splashOpacity = 1.0;
  bool _splashRemoved = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = Provider.of<QuranSettings>(context, listen: false);
      if (!settings.showBismillahSplash) {
        setState(() {
          _splashRemoved = true;
        });
      } else {
        _controller.forward();
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (mounted && _splashOpacity > 0.0) {
            setState(() {
              _splashOpacity = 0.0;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<QuranSettings>();
    if (!settings.showBismillahSplash) {
      return const MainNavigation();
    }

    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.light
        ? const Color(0xFFFBFDFA)
        : const Color(0xFF0F1711);
    final fg = brightness == Brightness.light
        ? const Color(0xFF004D40)
        : const Color(0xFF80CBC4);
    final muted = brightness == Brightness.light
        ? const Color(0xFF78909C)
        : const Color(0xFF90A4AE);

    return Stack(
      children: [
        const MainNavigation(),
        if (!_splashRemoved)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _splashOpacity,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              onEnd: () {
                if (_splashOpacity == 0.0) {
                  setState(() {
                    _splashRemoved = true;
                  });
                }
              },
              child: Scaffold(
                backgroundColor: bg,
                body: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_splashOpacity > 0.0) {
                      setState(() {
                        _splashOpacity = 0.0;
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      Center(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _fadeAnimation.value,
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\u{0628}\u{0650}\u{0633}\u{0652}\u{0645}\u{0650} '
                                '\u{0627}\u{0644}\u{0644}\u{0651}\u{064e}\u{0647}\u{0650} '
                                '\u{0627}\u{0644}\u{0631}\u{0651}\u{064e}\u{062d}\u{0652}\u{0645}\u{064e}\u{0646}\u{0650} '
                                '\u{0627}\u{0644}\u{0631}\u{0651}\u{064e}\u{062d}\u{0650}\u{064a}\u{0645}\u{0650}',
                                style: TextStyle(
                                  fontSize: 28,
                                  color: fg,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'QPC Hafs',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'In the name of Allah,\nthe Most Gracious, the Most Merciful',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: muted,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'Tap anywhere to skip',
                            style: TextStyle(
                              fontSize: 12,
                              color: muted.withOpacity(0.6),
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _index = 0;

  void goToTab(int tab) {
    setState(() => _index = tab);
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    final screens = [
      const HomeScreen(),
      PrayerScreen(onBackToHome: () => goToTab(0)),
      const MenuScreen(),
    ];

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
