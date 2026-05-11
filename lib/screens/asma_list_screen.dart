import 'package:flutter/material.dart';
import '../models/name_model.dart';
import '../services/data_service.dart';
import '../constants/quran_theme.dart';

class AsmaListScreen extends StatefulWidget {
  const AsmaListScreen({super.key});

  @override
  State<AsmaListScreen> createState() => _AsmaListScreenState();
}

class _AsmaListScreenState extends State<AsmaListScreen> {
  List<AsmaName> allNames = [];
  List<AsmaName> filteredNames = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final names = await DataService.loadNames();
    if (!mounted) return;
    setState(() {
      allNames = names;
      filteredNames = names;
    });
  }

  void _filterNames(String query) {
    setState(() {
      searchQuery = query;
      filteredNames = allNames
          .where((n) =>
              n.transliteration.toLowerCase().contains(query.toLowerCase()) ||
              n.meaning.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);

    return Scaffold(
      backgroundColor: qt.bg,
      body: Column(
        children: [
          // --- HEADER SECTION ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [qt.emeraldDeep, qt.emeraldMid],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text("Asma ul Husna",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Text("THE 99 NAMES OF ALLAH",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 10),
                const Text(
                  "\"And to Allah belong the best names, so invoke Him by them.\"",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 5),
                const Text("Surah Al-A'raf (7:180)",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),

          // --- FLOATING SEARCH BAR ---
          Transform.translate(
            offset: const Offset(0, -25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: qt.cardBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: qt.borderGlass),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: TextField(
                  onChanged: _filterNames,
                  style: TextStyle(color: qt.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Search name, meaning...",
                    hintStyle: TextStyle(color: qt.textMuted),
                    prefixIcon: Icon(Icons.search, color: qt.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
          ),

          // --- LIST OF NAMES ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: filteredNames.length,
              itemBuilder: (context, index) {
                final name = filteredNames[index];
                return _buildNameCard(name, qt);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard(AsmaName name, QuranTheme qt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: qt.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: qt.borderGlass),
      ),
      child: Row(
        children: [
          // Index Number
          Text("${name.number}",
              style: TextStyle(
                  color: qt.emeraldDeep,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(width: 20),
          // Meaning and Transliteration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.transliteration,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: qt.textPrimary)),
                Text(name.meaning,
                    style: TextStyle(fontSize: 13, color: qt.textMuted)),
              ],
            ),
          ),
          // Arabic Name
          Text(name.name,
              style: TextStyle(
                  fontSize: 28,
                  color: qt.emeraldDeep,
                  fontFamily: 'QPC Hafs',
                  fontWeight: FontWeight.normal)),
        ],
      ),
    );
  }
}
