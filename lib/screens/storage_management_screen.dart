import 'dart:io';
import 'package:flutter/material.dart';
import '../services/quran_service.dart';
import '../services/backup_service.dart';

class StorageManagementScreen extends StatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  State<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState extends State<StorageManagementScreen> {
  List<File> _audioFiles = [];
  List<File> _tafsirFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final audioFiles = await QuranService.instance.getDownloadedAudioFiles();
    final tafsirFiles = await QuranService.instance.getDownloadedTafsirs();
    setState(() {
      _audioFiles = audioFiles;
      _tafsirFiles = tafsirFiles;
      _isLoading = false;
    });
  }

  Future<void> _deleteAudioFile(File file) async {
    await QuranService.instance.deleteAudioFile(file);
    _loadFiles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Audio deleted successfully"),
            duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _deleteTafsirFile(File file) async {
    await QuranService.instance.deleteTafsirFile(file);
    _loadFiles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Tafsir deleted successfully"),
            duration: Duration(seconds: 2)),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes > 0)
        ? (bytes
            .toDouble()
            .toStringAsExponential(2)
            .split('e')[1]
            .replaceAll('+', ''))
        : '0';
    int idx = (int.parse(i) / 3).floor();
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            title: const Text("Manage Storage",
                style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Backup & Restore Section
              Container(
                padding: const EdgeInsets.all(20),
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Backup & Restore",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        "Export your reading progress, bookmarks, and settings to move to another device.",
                        style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF26A69A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.upload_file),
                            label: const Text("Export Data"),
                            onPressed: () =>
                                BackupService.exportBackup(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF26A69A),
                              side: const BorderSide(color: Color(0xFF26A69A)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.download),
                            label: const Text("Restore Data"),
                            onPressed: () =>
                                BackupService.importBackup(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              const TabBar(
                labelColor: Color(0xFF26A69A),
                indicatorColor: Color(0xFF26A69A),
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: "Audio Downloads"),
                  Tab(text: "Saved Tafsirs"),
                ],
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          // Audio Tab
                          _buildFileList(_audioFiles, Icons.audio_file,
                              "No downloaded audio files", theme, true),
                          // Tafsir Tab
                          _buildFileList(_tafsirFiles, Icons.text_snippet,
                              "No saved tafsirs", theme, false),
                        ],
                      ),
              ),
            ],
          ),
        ));
  }

  Widget _buildFileList(List<File> files, IconData emptyIcon, String emptyText,
      ThemeData theme, bool isAudio) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon,
                size: 64, color: theme.colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(emptyText,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = file.path.split('/').last.split('\\').last;
        final size = file.lengthSync();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF26A69A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, color: const Color(0xFF26A69A)),
            ),
            title: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(_formatBytes(size),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete File"),
                    content: Text("Are you sure you want to delete $name?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isAudio) {
                            _deleteAudioFile(file);
                          } else {
                            _deleteTafsirFile(file);
                          }
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
