// lib/widgets/prayer_setup_dialog.dart
//
// Refined premium onboarding setup wizard with responsive glassmorphism styles.

import 'package:flutter/material.dart';
import '../services/prayer_service.dart';
import '../constants/locations.dart';
import '../constants/quran_theme.dart';

Future<bool> showPrayerSetupDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _PrayerSetupWizard(),
  );
  return result ?? false;
}

class _PrayerSetupWizard extends StatefulWidget {
  const _PrayerSetupWizard();

  @override
  State<_PrayerSetupWizard> createState() => _PrayerSetupWizardState();
}

class _PrayerSetupWizardState extends State<_PrayerSetupWizard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPage > 0) {
          _navigateToPage(0);
        }
      },
      child: Dialog(
        backgroundColor: qt.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          // Using SingleChildScrollView on the whole dialog content ensures safety across device sizes
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepIndicator(qt),
                const SizedBox(height: 20),

                // Fixed: Replaced rigid SizedBox with a flexible, scroll-safe container
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight:
                        460, // Give it enough breathing room for Page 2 text wrapping
                  ),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    children: [
                      _buildWelcomePage(qt, isDark),
                      _buildSettingsPage(qt, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(QuranTheme qt) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 5,
          width: isActive ? 20 : 5,
          decoration: BoxDecoration(
            color: isActive ? qt.emeraldDeep : qt.borderGlass.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PAGE 1: WELCOME
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildWelcomePage(QuranTheme qt, bool isDark) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: qt.emeraldDeep.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: qt.emeraldDeep.withOpacity(0.15), width: 1.5),
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/app_icon.png',
                width: 44,
                height: 44,
                errorBuilder: (_, __, ___) => Icon(Icons.menu_book_rounded,
                    color: qt.emeraldDeep, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to Kitably',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: qt.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'To calculate accurate prayer times, let\'s customize your local region parameters.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: qt.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_rounded,
                    color: qt.emeraldDeep, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% Offline & Private',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: qt.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Location services are requested once to determine coordinates. Calculations happen entirely on-device.',
                        style: TextStyle(
                            fontSize: 12, color: qt.textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Fixed: Added padding after location info, using explicit spacing instead of Spacer() inside bounded boxes
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _navigateToPage(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: qt.emeraldDeep,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Get Started',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: qt.textMuted),
            child: const Text('Skip Setup',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  PAGE 2: SETTINGS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSettingsPage(QuranTheme qt, bool isDark) {
    final hasLocation = PrayerService.instance.currentCity != null;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Prayer Settings',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: qt.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Customize regional preferences for local prayer schedules.',
            style: TextStyle(fontSize: 13, color: qt.textMuted),
          ),
          const SizedBox(height: 16),

          _buildListTile(
            qt,
            icon: Icons.location_on_rounded,
            title: 'Calculation Location',
            subtitle: hasLocation
                ? '${PrayerService.instance.currentCity}, ${PrayerService.instance.currentCountry}'
                : 'Tap to configure location settings',
            isConfigured: hasLocation,
            onTap: () => _showLocationSheet(qt),
          ),
          const SizedBox(height: 10),

          _buildListTile(
            qt,
            icon: Icons.timelapse_rounded,
            title: 'Asr Calculation Juristic Method',
            subtitle: PrayerService.instance.asrMethod == 0
                ? 'Standard (Shafi\'i, Maliki, Hanbali)'
                : 'Hanafi School Rules',
            isConfigured: true,
            onTap: () => _showAsrSheet(qt),
          ),
          const SizedBox(height: 10),

          _buildListTile(
            qt,
            icon: Icons.calendar_today_rounded,
            title: 'Hijri Adjustment Correction',
            subtitle: _hijriLabel(),
            isConfigured: PrayerService.instance.hijriAdjustment != 0,
            onTap: () => _showHijriSheet(qt),
          ),

          // Fixed: Explicit padding layout structure before action buttons instead of Spacer()
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _navigateToPage(0),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: qt.borderGlass),
                      foregroundColor: qt.textPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await PrayerService.instance.setSetupCompleted();
                      if (mounted) Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: qt.emeraldDeep,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Finish Setup',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildListTile(
    QuranTheme qt, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isConfigured,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConfigured
                ? qt.emeraldDeep.withOpacity(0.08)
                : qt.textMuted.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isConfigured ? qt.emeraldDeep : qt.textMuted, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: qt.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(
            subtitle,
            style: TextStyle(
                fontSize: 12,
                color: isConfigured ? qt.textSecondary : qt.textMuted),
          ),
        ),
        trailing:
            Icon(Icons.chevron_right_rounded, size: 18, color: qt.textMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }

  String _hijriLabel() {
    final adj = PrayerService.instance.hijriAdjustment;
    if (adj == 0) return 'Standard (No local calculation offset)';
    return 'Shifted ${adj >= 0 ? '+' : ''}$adj day${adj.abs() == 1 ? '' : 's'} based on sightings';
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  MODAL DRAWERS INTERACTIVE SHEETS
  // ═══════════════════════════════════════════════════════════════════════

  void _showLocationSheet(QuranTheme qt) {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = POPULAR_LOCATIONS.where((loc) {
            return '${loc['city']} ${loc['country']}'
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.65,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: qt.borderGlass,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) =>
                              setModalState(() => searchQuery = v),
                          style: TextStyle(color: qt.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search your city...',
                            hintStyle:
                                TextStyle(color: qt.textMuted, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: qt.textMuted, size: 20),
                            filled: true,
                            fillColor: qt.cardBg,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: qt.borderGlass),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: qt.borderGlass.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: qt.emeraldDeep.withOpacity(0.15)),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.my_location_rounded,
                              color: qt.emeraldDeep, size: 20),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await PrayerService.instance.fetchDeviceLocation();
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount:
                          filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(
                          color: qt.borderGlass.withOpacity(0.3), height: 1),
                      itemBuilder: (ctx, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            leading: Icon(Icons.public_rounded,
                                color: qt.emeraldDeep),
                            title: Text('Custom entry: "$searchQuery"',
                                style: TextStyle(
                                    color: qt.emeraldDeep,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await PrayerService.instance
                                  .setLocation(searchQuery, '');
                              setState(() {});
                            },
                          );
                        }
                        final i = searchQuery.isNotEmpty ? index - 1 : index;
                        final loc = filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.location_on_outlined,
                              color: qt.textMuted, size: 20),
                          title: Text(loc['city']!,
                              style: TextStyle(
                                  color: qt.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: Text(loc['country']!,
                              style:
                                  TextStyle(color: qt.textMuted, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await PrayerService.instance
                                .setLocation(loc['city']!, loc['country']!);
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAsrSheet(QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final current = PrayerService.instance.asrMethod;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: qt.borderGlass,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Asr Calculation Method',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: qt.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'Different juristic schools define the afternoon prayer timestamp differently based on shadow length calculations.',
                style:
                    TextStyle(fontSize: 13, color: qt.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              _asrOption(
                  qt,
                  'Standard Method',
                  'Shafi\'i, Maliki, Hanbali — Earlier shadow point',
                  0,
                  current,
                  ctx),
              const SizedBox(height: 10),
              _asrOption(
                  qt,
                  'Hanafi Method',
                  'Double shadow length rule — Later calculation point',
                  1,
                  current,
                  ctx),
            ],
          ),
        );
      },
    );
  }

  Widget _asrOption(QuranTheme qt, String title, String subtitle, int value,
      int current, BuildContext ctx) {
    final isSelected = value == current;
    return InkWell(
      onTap: () async {
        Navigator.pop(ctx);
        await PrayerService.instance.setAsrMethod(value);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? qt.emeraldDeep.withOpacity(0.05) : qt.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? qt.emeraldDeep : qt.borderGlass.withOpacity(0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: qt.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: qt.textMuted)),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? qt.emeraldDeep : qt.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showHijriSheet(QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final adj = PrayerService.instance.hijriAdjustment;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: qt.borderGlass,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Hijri Correction Adjustment',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: qt.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  'Fine-tune the lunar cycle display match by adding or subtracting calendar days manually.',
                  style:
                      TextStyle(fontSize: 13, color: qt.textMuted, height: 1.4),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _adjBtn(qt, Icons.remove_rounded, adj > -2, () async {
                        await PrayerService.instance
                            .setHijriAdjustment(adj - 1);
                        setModalState(() {});
                        setState(() {});
                      }),
                      Container(
                        constraints: const BoxConstraints(minWidth: 90),
                        alignment: Alignment.center,
                        child: Text(
                          '${adj >= 0 ? '+' : ''}$adj',
                          style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: qt.textPrimary,
                              fontFamily: 'monospace'),
                        ),
                      ),
                      _adjBtn(qt, Icons.add_rounded, adj < 2, () async {
                        await PrayerService.instance
                            .setHijriAdjustment(adj + 1);
                        setModalState(() {});
                        setState(() {});
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _adjBtn(
      QuranTheme qt, IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled
          ? qt.emeraldDeep.withOpacity(0.08)
          : qt.borderGlass.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon,
              color: enabled ? qt.emeraldDeep : qt.textMuted, size: 24),
        ),
      ),
    );
  }
}
