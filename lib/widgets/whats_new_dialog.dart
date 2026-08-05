// lib/widgets/whats_new_dialog.dart
//
// Premium "What's New" bottom sheet shown after an app update.
// Highlights the new prayer notification feature and nudges the user
// to tap the Prayer nav item.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/quran_theme.dart';

/// Shows the "What's New" bottom sheet. Returns true if the user tapped
/// "Show Me" (navigate to Prayer tab), false otherwise.
Future<bool> showWhatsNewDialog(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) => const _WhatsNewSheet(),
  );
  return result ?? false;
}

class _WhatsNewSheet extends StatefulWidget {
  const _WhatsNewSheet();

  @override
  State<_WhatsNewSheet> createState() => _WhatsNewSheetState();
}

class _WhatsNewSheetState extends State<_WhatsNewSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // ── "What's New" label ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withOpacity(0.08),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              "WHAT'S NEW",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: qt.emeraldDeep,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Animated bell icon ──
          ScaleTransition(
            scale: _bounceAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: qt.emeraldDeep.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 38,
                color: qt.emeraldDeep,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Prayer Time Notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: qt.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Description ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'You can now get reminded the moment each prayer time starts. '
              'Enable notifications for any prayer and never miss a prayer again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: qt.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Feature highlights ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04),
                ),
              ),
              child: Column(
                children: [
                  _featureRow(
                    qt,
                    icon: Icons.schedule_rounded,
                    text: 'Get notified exactly when each prayer begins',
                  ),
                  const SizedBox(height: 12),
                  _featureRow(
                    qt,
                    icon: Icons.touch_app_rounded,
                    text: 'Tap the bell icon next to any prayer to enable',
                  ),
                  const SizedBox(height: 12),
                  _featureRow(
                    qt,
                    icon: Icons.check_circle_outline_rounded,
                    text: 'Mark prayers as prayed right from the notification',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Maybe Later
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(false);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: qt.borderGlass),
                        foregroundColor: qt.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Show Me
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: qt.emeraldDeep,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Show Me',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow(QuranTheme qt,
      {required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: qt.emeraldDeep.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: qt.emeraldDeep),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: qt.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
