import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import '../providers/quran_settings_provider.dart';
import '../services/prayer_service.dart';
import '../services/translation_download_service.dart';
import '../models/downloadable_translation.dart';
import '../constants/locations.dart';
import '../constants/quran_theme.dart';
import 'storage_management_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<QuranSettings>();
    final colorScheme = Theme.of(context).colorScheme;
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Prayer Configuration"),
          const SizedBox(height: 10),
          _buildLocationTile(context, qt),
          const SizedBox(height: 8),
          _buildAsrMethodTile(context, qt),
          const SizedBox(height: 8),
          _buildHijriAdjustmentTile(context, qt),
          const SizedBox(height: 30),
          _buildSectionHeader("Appearance"),
          const SizedBox(height: 10),
          _buildThemeSelector(context, settings),
          const SizedBox(height: 8),
          SwitchListTile(
            secondary:
                Icon(Icons.motion_photos_on_outlined, color: qt.emeraldDeep),
            title: const Text("Bismillah Splash Screen"),
            subtitle: const Text("Show Bismillah animation at launch"),
            value: settings.showBismillahSplash,
            activeTrackColor: qt.emeraldDeep,
            onChanged: (val) => settings.setShowBismillahSplash(val),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 30),
          _buildSectionHeader("Storage & Data"),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.storage, color: qt.emeraldDeep),
            title: const Text("Manage Downloads"),
            subtitle: const Text("Delete downloaded Surah audio files"),
            trailing: const Icon(Icons.chevron_right),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StorageManagementScreen()),
              );
            },
          ),
          const SizedBox(height: 30),
          _buildSectionHeader("Translations"),
          const SizedBox(height: 10),
          _buildTranslationManagement(context),
          const SizedBox(height: 30),
          _buildSectionHeader("About"),
          const SizedBox(height: 10),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("App Version"),
            trailing: Text("1.0.5", style: TextStyle(color: Colors.grey)),
          ),
          const ListTile(
            leading: Icon(Icons.favorite_border),
            title: Text("Credits"),
            subtitle: Text("Built with passion by Sehal Hussain"),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LOCATION TILE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLocationTile(BuildContext context, QuranTheme qt) {
    return ListTile(
      leading: Icon(Icons.location_on, color: qt.emeraldDeep),
      title: const Text("Prayer Location"),
      subtitle: Text(
          "${PrayerService.instance.currentCity ?? 'Unknown'}, ${PrayerService.instance.currentCountry ?? ''}"),
      trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      onTap: () => _showLocationBottomSheet(context, qt),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CALCULATION METHOD TILE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildCalculationMethodTile(BuildContext context, QuranTheme qt) {
    const methods = PrayerService.calculationMethods;
    final currentId = PrayerService.instance.calculationMethod;
    final current = methods.firstWhere(
      (m) => m['id'] == currentId,
      orElse: () => methods.first,
    );

    return ListTile(
      leading: Icon(Icons.calculate_outlined, color: qt.emeraldDeep),
      title: const Text("Calculation Method"),
      subtitle: Text("${current['name']} (${current['short']})"),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      onTap: () => _showCalculationMethodSheet(context, qt),
    );
  }

  void _showCalculationMethodSheet(BuildContext context, QuranTheme qt) {
    const methods = PrayerService.calculationMethods;
    final currentId = PrayerService.instance.calculationMethod;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: qt.borderGlass,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Calculation Method",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: qt.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Different regions and Islamic organizations use different astronomical conventions (angles of the sun) to calculate Fajr and Isha prayer times. Select the method recommended for your region to ensure accurate daily timings.",
                style:
                    TextStyle(fontSize: 13, color: qt.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: methods.length,
                  itemBuilder: (context, index) {
                    final method = methods[index];
                    final isSelected = method['id'] == currentId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: isSelected
                            ? qt.emeraldDeep.withValues(alpha: 0.08)
                            : qt.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await PrayerService.instance
                                .setCalculationMethod(method['id'] as int);
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? qt.emeraldDeep
                                    : qt.borderGlass,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    method['name'] as String,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: qt.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      color: qt.emeraldDeep)
                                else
                                  Icon(Icons.radio_button_off_rounded,
                                      color: qt.borderGlass),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  ASR METHOD TILE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAsrMethodTile(BuildContext context, QuranTheme qt) {
    final method = PrayerService.instance.asrMethod;
    return ListTile(
      leading: Icon(Icons.access_time_outlined, color: qt.emeraldDeep),
      title: const Text("Asr Calculation Method"),
      subtitle:
          Text(method == 0 ? "Standard (Shafi, Maliki, Hanbali)" : "Hanafi"),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      onTap: () => _showAsrMethodSheet(context, qt),
    );
  }

  void _showAsrMethodSheet(BuildContext context, QuranTheme qt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final currentMethod = PrayerService.instance.asrMethod;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: qt.borderGlass,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                "The major Islamic schools of jurisprudence calculate the start of Asr prayer differently. The Standard method (Shafi, Maliki, Hanbali) begins earlier, when the shadow of an object equals its height. The Hanafi method begins later, when the shadow is twice the object's height.",
                style:
                    TextStyle(fontSize: 13, color: qt.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              _buildAsrOptionCard(
                context,
                qt,
                title: "Standard Method",
                subtitle: "Shafi, Maliki, Hanbali schools (Earlier time)",
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
                subtitle:
                    "Hanafi school (Later time, when shadow is double object length)",
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
    return Material(
      color: isSelected ? qt.emeraldDeep.withValues(alpha: 0.08) : qt.cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? qt.emeraldDeep : qt.borderGlass,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? qt.emeraldDeep.withValues(alpha: 0.15)
                      : qt.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: isSelected ? qt.emeraldDeep : qt.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 15,
                        color: qt.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: qt.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: qt.emeraldDeep)
              else
                Icon(Icons.radio_button_off_rounded, color: qt.borderGlass),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HIJRI ADJUSTMENT TILE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHijriAdjustmentTile(BuildContext context, QuranTheme qt) {
    final adjustment = PrayerService.instance.hijriAdjustment;
    String label;
    if (adjustment == 0) {
      label = "No adjustment";
    } else if (adjustment > 0) {
      label = "+$adjustment day${adjustment == 1 ? '' : 's'}";
    } else {
      label = "$adjustment day${adjustment == -1 ? '' : 's'}";
    }

    return ListTile(
      leading: Icon(Icons.calendar_month_outlined, color: qt.emeraldDeep),
      title: const Text("Hijri Calendar Adjustment"),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.3),
      onTap: () => _showHijriAdjustmentSheet(context, qt),
    );
  }

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
          String label;
          if (adj == 0) {
            label = "No adjustment";
          } else if (adj > 0) {
            label = "+$adj day${adj == 1 ? '' : 's'}";
          } else {
            label = "$adj day${adj == -1 ? '' : 's'}";
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: qt.borderGlass,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Hijri Calendar Adjustment",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: qt.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Because the traditional Islamic calendar is based on actual sightings of the crescent moon, pre-calculated calendar dates may differ by 1 or 2 days from your local community's actual practice. Adjusting this shifts the calculated Hijri dates across the app.",
                  style:
                      TextStyle(fontSize: 13, color: qt.textMuted, height: 1.4),
                ),
                const SizedBox(height: 36),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: qt.cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: qt.borderGlass),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minus Button
                        Material(
                          color: adj > -2
                              ? qt.emeraldDeep.withValues(alpha: 0.1)
                              : qt.borderGlass.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: adj > -2
                                ? () async {
                                    await PrayerService.instance
                                        .setHijriAdjustment(adj - 1);
                                    setModalState(() {});
                                    setState(() {});
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.remove_rounded,
                                color: adj > -2 ? qt.emeraldDeep : qt.textMuted,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Display Value
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              adj >= 0 ? "+$adj" : "$adj",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: qt.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                color: qt.emeraldDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 32),
                        // Plus Button
                        Material(
                          color: adj < 2
                              ? qt.emeraldDeep.withValues(alpha: 0.1)
                              : qt.borderGlass.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: adj < 2
                                ? () async {
                                    await PrayerService.instance
                                        .setHijriAdjustment(adj + 1);
                                    setModalState(() {});
                                    setState(() {});
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.add_rounded,
                                color: adj < 2 ? qt.emeraldDeep : qt.textMuted,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: qt.emeraldDeep.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: qt.emeraldDeep.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_rounded,
                            color: qt.emeraldDeep, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Calculated Date: ",
                          style: TextStyle(
                            fontSize: 13,
                            color: qt.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          formattedHijriDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: qt.emeraldDeep,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  LOCATION BOTTOM SHEET
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
              top: 24,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) =>
                              setModalState(() => searchQuery = val),
                          style: TextStyle(color: qt.textPrimary),
                          decoration: InputDecoration(
                            hintText: "Search city...",
                            hintStyle: TextStyle(color: qt.textMuted),
                            prefixIcon: Icon(Icons.search, color: qt.textMuted),
                            filled: true,
                            fillColor: qt.cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: qt.emeraldDeep.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.my_location, color: qt.emeraldDeep),
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
                    child: ListView.builder(
                      itemCount:
                          filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            leading: Icon(Icons.public, color: qt.emeraldDeep),
                            title: Text('Search for "$searchQuery"',
                                style: TextStyle(
                                    color: qt.emeraldDeep,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('Worldwide search',
                                style: TextStyle(
                                    color: qt.textMuted, fontSize: 12)),
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
                          leading: Icon(Icons.location_on_outlined,
                              color: qt.textMuted),
                          title: Text(loc['city']!,
                              style: TextStyle(
                                  color: qt.textPrimary,
                                  fontWeight: FontWeight.bold)),
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

  // ═══════════════════════════════════════════════════════════════════════
  //  THEME SELECTOR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildThemeSelector(BuildContext context, QuranSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildThemeTile(
            context,
            "Light",
            Icons.light_mode_outlined,
            ThemeMode.light,
            settings,
          ),
          const Divider(height: 1, indent: 56),
          _buildThemeTile(
            context,
            "Dark",
            Icons.dark_mode_outlined,
            ThemeMode.dark,
            settings,
          ),
          const Divider(height: 1, indent: 56),
          _buildThemeTile(
            context,
            "System Default",
            Icons.settings_suggest_outlined,
            ThemeMode.system,
            settings,
          ),
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
  ) {
    final isSelected = settings.themeMode == mode;
    final qt = QuranTheme.of(context);
    return ListTile(
      leading: Icon(icon, color: isSelected ? qt.emeraldDeep : null),
      title: Text(title,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing:
          isSelected ? Icon(Icons.check_circle, color: qt.emeraldDeep) : null,
      onTap: () => settings.setThemeMode(mode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  TRANSLATIONS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTranslationManagement(BuildContext context) {
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
              return ListTile(
                leading: const Icon(Icons.translate, color: Color(0xFF26A69A)),
                title: const Text("Manage Translations"),
                subtitle: const Text(
                    "No downloaded translations. Tap download icon in Quran reader."),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                tileColor: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              );
            }

            return Column(
              children: [
                for (final t in downloaded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF26A69A).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF26A69A), size: 20),
                      ),
                      title: Text(t.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text("Downloaded",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Translation"),
                              content: Text(
                                  "Delete downloaded translation: ${t.displayName}?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red)),
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
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
