import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import '../providers/quran_settings_provider.dart';
import '../services/prayer_service.dart';
import '../services/translation_download_service.dart';
import '../services/backup_service.dart';
import '../models/downloadable_translation.dart';
import '../constants/locations.dart';
import '../constants/quran_theme.dart';
import 'storage_management_screen.dart';
import '../main.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<QuranSettings>();
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: qt.bg,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: qt.textPrimary,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: qt.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _buildSectionHeader("Prayer Configuration"),
          const SizedBox(height: 10),

          // Combined Location & Auto-Calculation Info Card
          _buildPremiumTile(
            qt,
            icon: Icons.location_on_rounded,
            title: "Prayer Location",
            subtitle:
                "${PrayerService.instance.currentCity ?? 'Unknown'}, ${PrayerService.instance.currentCountry ?? ''}",
            additionalInfo:
                "Method: ${_getCalculationMethodLabel(shortOnly: true)} (Auto-detected)",
            isConfigured: PrayerService.instance.currentCity != null,
            onTap: () => _showLocationBottomSheet(context, qt),
          ),
          const SizedBox(height: 10),

          _buildPremiumTile(
            qt,
            icon: Icons.timelapse_rounded,
            title: "Asr Calculation Method",
            subtitle: PrayerService.instance.asrMethod == 0
                ? "Standard (Shafi'i, Maliki, Hanbali)"
                : "Hanafi School Rules",
            isConfigured: true,
            onTap: () => _showAsrMethodSheet(context, qt),
          ),
          const SizedBox(height: 10),

          _buildPremiumTile(
            qt,
            icon: Icons.calendar_today_rounded,
            title: "Hijri Calendar Correction",
            subtitle: _hijriLabel(),
            isConfigured: PrayerService.instance.hijriAdjustment != 0,
            onTap: () => _showHijriAdjustmentSheet(context, qt),
          ),

          const SizedBox(height: 30),
          _buildSectionHeader("Appearance"),
          const SizedBox(height: 10),
          _buildThemeSelector(context, settings, qt, isDark),
          const SizedBox(height: 10),
          _buildSwitchTile(
            qt: qt,
            isDark: isDark,
            icon: Icons.motion_photos_on_outlined,
            title: "Bismillah Splash Screen",
            subtitle: "Show Bismillah animation at launch",
            value: settings.showBismillahSplash,
            onChanged: (val) => settings.setShowBismillahSplash(val),
          ),

          const SizedBox(height: 30),
          _buildSectionHeader("Storage & Downloads"),
          const SizedBox(height: 10),

          _buildPremiumTile(
            qt,
            icon: Icons.audiotrack_rounded,
            title: "Manage Audio Downloads",
            subtitle: "View and delete cached Surah audio recitations",
            isConfigured: false,
            onTap: () {
              MainNavigation.pushOnShell(
                context,
                const StorageManagementScreen(),
              );
            },
          ),
          const SizedBox(height: 10),

          _buildTranslationManagement(context, qt, isDark),

          const SizedBox(height: 30),
          _buildSectionHeader("Backup & Restore"),
          const SizedBox(height: 10),
          _buildBackupRestoreSection(qt),
          const SizedBox(height: 30),
          _buildSectionHeader("About"),
          const SizedBox(height: 10),
          _buildAboutSection(qt),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.withOpacity(0.8),
            letterSpacing: 1.5,
          ),
        ));
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  UNIVERSAL PREMIUM LIST TILE STYLE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPremiumTile(
    QuranTheme qt, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? additionalInfo,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: isConfigured ? qt.textSecondary : qt.textMuted),
              ),
              if (additionalInfo != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: qt.emeraldDeep.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    additionalInfo,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: qt.emeraldDeep,
                    ),
                  ),
                ),
              ],
            ],
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

  String _getCalculationMethodLabel({bool shortOnly = false}) {
    const methods = PrayerService.calculationMethods;
    final currentId = PrayerService.instance.calculationMethod;
    final current = methods.firstWhere(
      (m) => m['id'] == currentId,
      orElse: () => methods.first,
    );
    if (shortOnly) {
      return current['short'] as String;
    }
    return "${current['name']} (${current['short']})";
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ASR METHOD SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showAsrMethodSheet(BuildContext context, QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final currentMethod = PrayerService.instance.asrMethod;
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Asr Calculation Method",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: qt.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Different juristic schools define the afternoon prayer timestamp differently based on shadow length calculations.",
                style:
                    TextStyle(fontSize: 13, color: qt.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              _buildAsrOptionCard(
                context,
                qt,
                title: "Standard Method",
                subtitle: "Shafi'i, Maliki, Hanbali — Earlier shadow point",
                value: 0,
                isSelected: currentMethod == 0,
                onTap: () async {
                  Navigator.pop(ctx);
                  await PrayerService.instance.setAsrMethod(0);
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _buildAsrOptionCard(
                context,
                qt,
                title: "Hanafi Method",
                subtitle: "Double shadow length rule — Later calculation point",
                value: 1,
                isSelected: currentMethod == 1,
                onTap: () async {
                  Navigator.pop(ctx);
                  await PrayerService.instance.setAsrMethod(1);
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAsrOptionCard(
    BuildContext context,
    QuranTheme qt, {
    required String title,
    required String subtitle,
    required int value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: qt.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: qt.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  HIJRI ADJUSTMENT SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showHijriAdjustmentSheet(BuildContext context, QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final adj = PrayerService.instance.hijriAdjustment;
          final adjustedDate = DateTime.now().add(Duration(days: adj));
          final hijri = HijriCalendar.fromDate(adjustedDate);
          final formattedHijriDate =
              "${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH";

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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Hijri Calendar Correction",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Fine-tune the lunar cycle display match by adding or subtracting calendar days manually based on actual regional moon sightings.",
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
                            fontFamily: 'monospace',
                          ),
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
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: qt.emeraldDeep.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_rounded,
                            color: qt.emeraldDeep, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Calculated Date: ",
                          style:
                              TextStyle(fontSize: 12, color: qt.textSecondary),
                        ),
                        Text(
                          formattedHijriDate,
                          style: TextStyle(
                              fontSize: 12,
                              color: qt.emeraldDeep,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  LOCATION SHEET
  // ═══════════════════════════════════════════════════════════════════════

  void _showLocationBottomSheet(BuildContext context, QuranTheme qt) {
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
            final text = "${loc['city']} ${loc['country']}".toLowerCase();
            return text.contains(searchQuery.toLowerCase());
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                          style: TextStyle(color: qt.textPrimary),
                          decoration: InputDecoration(
                            hintText: "Search your city...",
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
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount:
                          filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      separatorBuilder: (_, __) => Divider(
                          color: qt.borderGlass.withOpacity(0.3), height: 1),
                      itemBuilder: (context, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.public_rounded,
                                color: qt.emeraldDeep),
                            title: Text(
                              'Custom entry: "$searchQuery"',
                              style: TextStyle(
                                color: qt.emeraldDeep,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await PrayerService.instance
                                  .setLocation(searchQuery, '');
                              setState(() {});
                            },
                          );
                        }

                        final locIndex =
                            searchQuery.isNotEmpty ? index - 1 : index;
                        final loc = filtered[locIndex];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.location_on_outlined,
                              color: qt.textMuted, size: 20),
                          title: Text(
                            loc['city']!,
                            style: TextStyle(
                              color: qt.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            loc['country']!,
                            style: TextStyle(color: qt.textMuted, fontSize: 12),
                          ),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  THEME SELECTOR & SWITCHES
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildThemeSelector(BuildContext context, QuranSettings settings,
      QuranTheme qt, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          _buildThemeTile(context, "Light Mode", Icons.light_mode_outlined,
              ThemeMode.light, settings, qt),
          Divider(
              height: 1, color: qt.borderGlass.withOpacity(0.3), indent: 56),
          _buildThemeTile(context, "Dark Mode", Icons.dark_mode_outlined,
              ThemeMode.dark, settings, qt),
          Divider(
              height: 1, color: qt.borderGlass.withOpacity(0.3), indent: 56),
          _buildThemeTile(context, "System Default",
              Icons.settings_suggest_outlined, ThemeMode.system, settings, qt),
        ],
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    String title,
    IconData icon,
    ThemeMode mode,
    QuranSettings settings,
    QuranTheme qt,
  ) {
    final isSelected = settings.themeMode == mode;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? qt.emeraldDeep : qt.textMuted, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: qt.textPrimary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: qt.emeraldDeep, size: 20)
          : Icon(Icons.radio_button_off_rounded,
              color: qt.borderGlass, size: 20),
      onTap: () => settings.setThemeMode(mode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSwitchTile({
    required QuranTheme qt,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? qt.emeraldDeep.withOpacity(0.08)
                : qt.textMuted.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: value ? qt.emeraldDeep : qt.textMuted, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: qt.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: qt.textMuted),
        ),
        value: value,
        activeTrackColor: qt.emeraldDeep,
        activeColor: Colors.white,
        inactiveTrackColor: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TRANSLATIONS MANAGEMENT (Merged into Storage & Downloads)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTranslationManagement(
      BuildContext context, QuranTheme qt, bool isDark) {
    final downloadService = TranslationDownloadService.instance;
    return FutureBuilder<void>(
      future: downloadService.refreshDownloadedStatus(),
      builder: (ctx, _) {
        return ListenableBuilder(
          listenable: downloadService,
          builder: (ctx, _) {
            final translations = kDownloadableTranslations;
            final downloaded = translations
                .where((t) => downloadService.isDownloaded(t.id) == true)
                .toList();

            if (downloaded.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: qt.textMuted.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.translate_rounded,
                        color: qt.textMuted, size: 20),
                  ),
                  title: Text(
                    "Translation Downloads",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: qt.textPrimary),
                  ),
                  subtitle: Text(
                    "No custom translations downloaded. You can grab translations via the Quran reader view.",
                    style: TextStyle(fontSize: 12, color: qt.textMuted),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                  child: Text(
                    "DOWNLOADED TRANSLATIONS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: qt.textSecondary.withOpacity(0.8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                for (final t in downloaded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: qt.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: qt.borderGlass.withOpacity(0.4)),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: qt.emeraldDeep.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle_rounded,
                              color: qt.emeraldDeep, size: 20),
                        ),
                        title: Text(
                          t.displayName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: qt.textPrimary),
                        ),
                        subtitle: Text(
                          "Downloaded Translation",
                          style: TextStyle(color: qt.textMuted, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 22),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: qt.bg,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: Text("Delete Translation",
                                    style: TextStyle(
                                        color: qt.textPrimary,
                                        fontWeight: FontWeight.bold)),
                                content: Text(
                                    "Delete downloaded translation: ${t.displayName}?",
                                    style: TextStyle(color: qt.textSecondary)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text("Cancel",
                                        style: TextStyle(color: qt.textMuted)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Delete",
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await downloadService.deleteTranslation(t.id);
                              setState(() {});
                            }
                          },
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BACKUP & RESTORE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBackupRestoreSection(QuranTheme qt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: qt.emeraldDeep, size: 22),
              const SizedBox(width: 8),
              Text(
                "Backup & Restore",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: qt.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Export your bookmarks, duas, hadith favorites, prayer logs, and settings to move them securely to another device.",
            style: TextStyle(
              color: qt.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: qt.emeraldDeep,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text(
                      "Export",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => BackupService.exportBackup(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: qt.textPrimary,
                      side: BorderSide(color: qt.borderGlass),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      "Restore",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => BackupService.importBackup(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  ABOUT & CREDITS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAboutSection(QuranTheme qt) {
    return Container(
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline, color: qt.textMuted, size: 20),
            title: Text("App Version",
                style: TextStyle(
                    fontSize: 14,
                    color: qt.textPrimary,
                    fontWeight: FontWeight.w500)),
            trailing: const Text("1.1.8",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Divider(
              height: 1, color: qt.borderGlass.withOpacity(0.3), indent: 56),
          ListTile(
            leading: Icon(Icons.favorite_border, color: qt.textMuted, size: 20),
            title: Text("Credits",
                style: TextStyle(
                    fontSize: 14,
                    color: qt.textPrimary,
                    fontWeight: FontWeight.w500)),
            subtitle: Text("Built with passion by Sehal Hussain",
                style: TextStyle(color: qt.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
