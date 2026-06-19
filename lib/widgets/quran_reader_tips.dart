import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/quran_theme.dart';
import '../providers/quran_settings_provider.dart';

/// Lightweight sequential overlay for first-time Quran reader visitors.
/// Blurs the background with an elegant glassmorphism style and reveals tips cards.
/// When [showOnlyTranslationTip] is true, only the first translation tip is shown
/// (used for existing users who update the app).
class QuranReaderTips extends StatefulWidget {
  final Widget child;
  final bool showOnlyTranslationTip;

  const QuranReaderTips({
    super.key,
    required this.child,
    this.showOnlyTranslationTip = false,
  });

  @override
  State<QuranReaderTips> createState() => QuranReaderTipsState();
}

class QuranReaderTipsState extends State<QuranReaderTips>
    with SingleTickerProviderStateMixin {
  int? _currentTip;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  List<_TipData> get _tips {
    if (widget.showOnlyTranslationTip) {
      return [
        const _TipData(
          title: 'Listen with Translation',
          subtitle:
              'Tap the settings icon, switch to "Full Surah" mode, and choose a reciter with Urdu or English translation from the top of the list.',
          icon: Icons.translate_rounded,
        ),
      ];
    }
    return [
      const _TipData(
        title: 'Listen with Translation',
        subtitle:
            'Tap the settings icon, switch to "Full Surah" mode, and choose a reciter with Urdu or English translation from the top of the list.',
        icon: Icons.translate_rounded,
      ),
      const _TipData(
        title: 'Customize Your Reading View',
        subtitle:
            'Tap the settings icon to change font size, scripts, translations, or reciter.',
        icon: Icons.tune_rounded,
      ),
      const _TipData(
        title: 'Read Tafsir',
        subtitle:
            'Tap "Read Tafsir" on any ayah to explore in-depth explanations from Ibn Kathir and more.',
        icon: Icons.menu_book_rounded,
      ),
      const _TipData(
        title: 'Interactive Audio Bar',
        subtitle:
            'Control playback, change listening modes, or view surah highlights via the information icon.',
        icon: Icons.play_arrow_rounded,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOutCubic),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void startTips() {
    if (_currentTip != null) return;
    _showTip(0);
  }

  void _showTip(int index) {
    if (index >= _tips.length || index < 0 || !mounted) {
      _dismiss();
      return;
    }
    setState(() => _currentTip = index);
    _fadeCtrl.forward(from: 0);
  }

  void _dismiss() {
    _currentTip = null;
    final settings = QuranSettingsProvider.of(context, listen: false);
    if (widget.showOnlyTranslationTip) {
      settings.markTranslationReciterTipSeen();
    } else {
      settings.markQuranReaderTipsSeen();
    }
    if (mounted) setState(() {});
  }

  void _advance() {
    final next = (_currentTip ?? 0) + 1;
    _fadeCtrl.reverse().then((_) {
      if (mounted) _showTip(next);
    });
  }

  void _goBack() {
    final prev = (_currentTip ?? 0) - 1;
    _fadeCtrl.reverse().then((_) {
      if (mounted) _showTip(prev);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentTip != null) _buildTipOverlay(_currentTip!),
      ],
    );
  }

  Widget _buildTipOverlay(int index) {
    final tip = _tips[index];
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final isFirst = index == 0;
    final isLast = index == _tips.length - 1;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isLast ? _dismiss : _advance,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -50) {
              isLast ? _dismiss() : _advance();
            } else if (details.primaryVelocity! > 50) {
              isFirst ? _dismiss() : _goBack();
            }
          }
        },
        // Premium background blur treatment instead of basic black opacity tint
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: (isDark ? Colors.black38 : Colors.black26),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // AnimatedSize ensures that if page content lengths alter slightly, elements fluidly stretch
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: 326,
                              minWidth: 280,
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            decoration: BoxDecoration(
                              // Semi-translucent base for glassmorphic surface
                              color: (isDark
                                  ? const Color(0xFF14241C)
                                      .withValues(alpha: 0.88)
                                  : Colors.white.withValues(alpha: 0.94)),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark
                                    ? qt.emeraldDeep.withValues(alpha: 0.3)
                                    : qt.emeraldDeep.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.35 : 0.12),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Liquid Glass Ring container around Icon
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        qt.emeraldDeep,
                                        qt.emeraldDeep.withValues(alpha: 0.75)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: qt.emeraldDeep
                                            .withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    tip.icon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  tip.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: qt.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  tip.subtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: qt.textSecondary,
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Step Progress Bars
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_tips.length, (i) {
                                    final active = i == index;
                                    final done = i < index;
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      width: active ? 22 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? qt.emeraldDeep
                                            : (done
                                                ? qt.emeraldDeep
                                                    .withValues(alpha: 0.4)
                                                : qt.textMuted
                                                    .withValues(alpha: 0.2)),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  isLast
                                      ? 'Tap anywhere to complete'
                                      : 'Tap or swipe to proceed',
                                  style: TextStyle(
                                    color: qt.textMuted.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Enhanced Floating Close Button
                        Positioned(
                          top: -10,
                          right: -10,
                          child: Material(
                            color: Colors.transparent,
                            child: GestureDetector(
                              onTap: _dismiss,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1C3227)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        qt.emeraldDeep.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: qt.emeraldDeep,
                                  size: 16,
                                ),
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
          ),
        ),
      ),
    );
  }
}

class _TipData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TipData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
