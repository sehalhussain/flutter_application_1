import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quran_settings_provider.dart';
import '../services/prayer_service.dart';
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
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Prayer Configuration"),
          const SizedBox(height: 10),
          _buildLocationTile(context),
          const SizedBox(height: 8),
          _buildAsrMethodTile(context),
          
          const SizedBox(height: 30),
          _buildSectionHeader("Appearance"),
          const SizedBox(height: 10),
          _buildThemeSelector(context, settings),
          
          const SizedBox(height: 30),
          _buildSectionHeader("Storage & Data"),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.storage, color: Color(0xFF26A69A)),
            title: const Text("Manage Downloads"),
            subtitle: const Text("Delete downloaded Surah audio files"),
            trailing: const Icon(Icons.chevron_right),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: colorScheme.surfaceVariant.withOpacity(0.3),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageManagementScreen()),
              );
            },
          ),
          
          const SizedBox(height: 30),
          _buildSectionHeader("About"),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("App Version"),
            trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text("Credits"),
            subtitle: const Text("Built with passion by Sehal Hussain"),
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

  Widget _buildLocationTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.location_on, color: Color(0xFF26A69A)),
      title: const Text("Prayer Location"),
      subtitle: Text("${PrayerService.instance.currentCity ?? 'Unknown'}, ${PrayerService.instance.currentCountry ?? ''}"),
      trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      onTap: () => _showLocationBottomSheet(context),
    );
  }

  Widget _buildAsrMethodTile(BuildContext context) {
    final method = PrayerService.instance.asrMethod;
    return ListTile(
      leading: const Icon(Icons.access_time, color: Color(0xFF26A69A)),
      title: const Text("Asr Calculation Method"),
      subtitle: Text(method == 0 ? "Standard (Shafi, Maliki, Hanbali)" : "Hanafi"),
      trailing: const Icon(Icons.swap_horiz, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Select Asr Method"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<int>(
                  title: const Text("Standard"),
                  subtitle: const Text("Shafi, Maliki, Hanbali"),
                  value: 0,
                  groupValue: method,
                  onChanged: (val) async {
                    Navigator.pop(ctx);
                    await PrayerService.instance.setAsrMethod(0);
                    setState(() {});
                  },
                ),
                RadioListTile<int>(
                  title: const Text("Hanafi"),
                  subtitle: const Text("Later time for Asr"),
                  value: 1,
                  groupValue: method,
                  onChanged: (val) async {
                    Navigator.pop(ctx);
                    await PrayerService.instance.setAsrMethod(1);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLocationBottomSheet(BuildContext context) {
    final qt = QuranTheme.of(context);
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: qt.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = POPULAR_LOCATIONS.where((loc) {
            final text = "${loc['city']} ${loc['country']}".toLowerCase();
            return text.contains(searchQuery.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setModalState(() => searchQuery = val),
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
                            setState(() {}); // refresh location tile
                          },
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length + (searchQuery.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (searchQuery.isNotEmpty && index == 0) {
                          return ListTile(
                            leading: Icon(Icons.public, color: qt.emeraldDeep),
                            title: Text('Search for "$searchQuery"', style: TextStyle(color: qt.emeraldDeep, fontWeight: FontWeight.bold)),
                            subtitle: Text('Worldwide search', style: TextStyle(color: qt.textMuted, fontSize: 12)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await PrayerService.instance.setLocation(searchQuery, '');
                              setState(() {});
                            },
                          );
                        }
                        
                        final locIndex = searchQuery.isNotEmpty ? index - 1 : index;
                        final loc = filtered[locIndex];
                        return ListTile(
                          leading: Icon(Icons.location_on_outlined, color: qt.textMuted),
                          title: Text(loc['city']!, style: TextStyle(color: qt.textPrimary, fontWeight: FontWeight.bold)),
                          subtitle: Text(loc['country']!, style: TextStyle(color: qt.textMuted, fontSize: 12)),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await PrayerService.instance.setLocation(loc['city']!, loc['country']!);
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
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF26A69A) : null),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF26A69A)) : null,
      onTap: () => settings.setThemeMode(mode),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
