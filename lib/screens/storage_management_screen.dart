import 'dart:io';
import 'package:flutter/material.dart';
import '../services/quran_service.dart';
import '../services/backup_service.dart';
import '../constants/quran_theme.dart';

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
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final qt = QuranTheme.of(context);
    final isDark = qt.brightness == Brightness.dark;

    return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: qt.bg,
          appBar: AppBar(
            title: Text(
              "Manage Storage",
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
          body: Column(
            children: [
              // Backup & Restore Section (Matching Menu Screen Premium Theme)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
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
                          Icon(Icons.cloud_sync_rounded,
                              color: qt.emeraldDeep, size: 22),
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
                        "Export your reading progress, bookmarks, and settings to move them securely to another device.",
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
                                icon: const Icon(Icons.upload_file_rounded,
                                    size: 18),
                                label: const Text(
                                  "Export",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                onPressed: () =>
                                    BackupService.exportBackup(context),
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
                                icon: const Icon(Icons.download_rounded,
                                    size: 18),
                                label: const Text(
                                  "Restore",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                onPressed: () =>
                                    BackupService.importBackup(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              TabBar(
                labelColor: qt.emeraldDeep,
                indicatorColor: qt.emeraldDeep,
                unselectedLabelColor: qt.textMuted,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: "Audio Downloads"),
                  Tab(text: "Saved Tafsirs"),
                ],
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: qt.emeraldDeep))
                    : TabBarView(
                        children: [
                          // Audio Tab
                          _buildFileList(_audioFiles, Icons.audiotrack_rounded,
                              "No downloaded audio files found", qt, true),
                          // Tafsir Tab
                          _buildFileList(
                              _tafsirFiles,
                              Icons.text_snippet_rounded,
                              "No saved tafsirs found",
                              qt,
                              false),
                        ],
                      ),
              ),
            ],
          ),
        ));
  }

  Widget _buildFileList(
    List<File> files,
    IconData emptyIcon,
    String emptyText,
    QuranTheme qt,
    bool isAudio,
  ) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: qt.textMuted.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon,
                  size: 48, color: qt.textMuted.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: TextStyle(
                  color: qt.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final name = file.path.split('/').last.split('\\').last;
        final size = file.lengthSync();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: qt.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: qt.borderGlass.withOpacity(0.4)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: qt.emeraldDeep.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  isAudio
                      ? Icons.music_note_rounded
                      : Icons.description_rounded,
                  color: qt.emeraldDeep,
                  size: 20),
            ),
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: qt.textPrimary),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                _formatBytes(size),
                style: TextStyle(color: qt.textMuted, fontSize: 12),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 22),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: qt.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text("Delete File",
                        style: TextStyle(
                            color: qt.textPrimary,
                            fontWeight: FontWeight.bold)),
                    content: Text(
                        "Are you sure you want to delete this downloaded item? ($name)",
                        style: TextStyle(color: qt.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cancel",
                            style: TextStyle(color: qt.textMuted)),
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
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
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
