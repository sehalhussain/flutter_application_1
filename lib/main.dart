import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'providers/quran_settings_provider.dart';
import 'providers/quran_progress_provider.dart';
import 'providers/hadith_progress_provider.dart';
import 'providers/hadith_reader_settings_provider.dart';
import 'providers/dua_settings_provider.dart';
import 'providers/dua_progress_provider.dart';
import 'providers/prayer_tracker_provider.dart';
import 'services/prayer_service.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/quran/quran_home_screen.dart';
import 'screens/prayer_screen.dart';
import 'constants/quran_theme.dart';
import 'widgets/prayer_setup_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PrayerService before app runs
  await PrayerService.instance.initLocation();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.kitably.app.channel.audio',
    androidNotificationChannelName: 'Kitably Quran Playback',
    androidNotificationOngoing: true,
  );

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
        ChangeNotifierProvider(create: (_) => DuaProgress()..load()),
        ChangeNotifierProvider(create: (_) => PrayerTracker()..load()),
        // Expose PrayerService as a ChangeNotifier so screens can react to changes
        ChangeNotifierProvider.value(value: PrayerService.instance),
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

// ---- Splash Wrapper ----
class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper();

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _splashRemoved = false;
  bool _setupChecked = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Only listen to the exact setting we need
      final showSplash = Provider.of<QuranSettings>(context, listen: false)
          .showBismillahSplash;
      if (!showSplash) {
        setState(() => _splashRemoved = true);
      } else {
        _controller.forward();
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (mounted && !_splashRemoved && !_isDismissing) {
            _dismissSplash();
          }
        });
      }
    });
  }

  /// Trigger the first-time setup wizard after the app is built.
  Future<void> _showSetupIfNeeded() async {
    // Wait a frame for the build to complete
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final prayerService = PrayerService.instance;
    if (!prayerService.hasCompletedSetup) {
      await showPrayerSetupDialog(context);
    }
  }

  void _dismissSplash() {
    if (_isDismissing || _splashRemoved) return;
    setState(() => _isDismissing = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The home screen (MainNavigation) is ALWAYS in the tree. While the
    // splash is up, it is laid out and doing its async data fetching in
    // the background, so by the time the splash is removed the home
    // screen is already populated and won't visibly refresh.
    //
    // The splash itself is shown on top with an opaque background that
    // matches the app's scaffold background. It does NOT fade out — it
    // is removed instantly so there is never a "fade to black".
    if (!_splashRemoved && !_setupChecked) {
      _setupChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupIfNeeded();
      });
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const MainNavigation(),
        if (!_splashRemoved)
          AnimatedOpacity(
            opacity: _isDismissing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            onEnd: () {
              if (mounted && _isDismissing) {
                setState(() {
                  _splashRemoved = true;
                  _isDismissing = false;
                });
              }
            },
            child: _SplashScreen(
              controller: _controller,
              onDismiss: _dismissSplash,
            ),
          ),
      ],
    );
  }
}

// ---- Splash screen widget: text fades in and scales up, but the splash
// itself is OPAQUE (no fade-out). When dismissed, it is removed instantly
// from the tree, so there is no "fade to black".
class _SplashScreen extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback onDismiss;

  const _SplashScreen({
    required this.controller,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.light
        ? const Color(0xFFFBFDFA)
        : const Color(0xFF0F1711);
    final mutedColor = brightness == Brightness.light
        ? const Color(0xFF78909C)
        : const Color(0xFF90A4AE);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Stack(
          children: [
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
                  ),
                ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: controller,
                    curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '\u{0628}\u{0650}\u{0633}\u{0652}\u{0645}\u{0650} '
                        '\u{0627}\u{0644}\u{0644}\u{0651}\u{064e}\u{0647}\u{0650} '
                        '\u{0627}\u{0644}\u{0631}\u{0651}\u{064e}\u{062d}\u{0652}\u{0645}\u{064e}\u{0646}\u{0650} '
                        '\u{0627}\u{0644}\u{0631}\u{0651}\u{064e}\u{062d}\u{0650}\u{064a}\u{0645}\u{0650}',
                        style: TextStyle(
                          fontSize: 28,
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
                          color: mutedColor,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Positioned skip text - moved higher, with settings hint
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Column(
                children: [
                  Text(
                    'Tap anywhere to skip',
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedColor.withValues(alpha: 0.7),
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You can turn this off in Settings',
                    style: TextStyle(
                      fontSize: 11,
                      color: mutedColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Main Navigation (unchanged) ----
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
        index: _index >= 2 ? _index - 1 : _index,
        children: screens,
      ),
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
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              activeIcon: Icon(Icons.home_filled),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              activeIcon: Icon(Icons.access_time),
              label: "Prayer",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              activeIcon: Icon(Icons.menu_book_rounded),
              label: "Quran",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: "Menu",
            ),
          ],
        ),
      ),
    );
  }
}
