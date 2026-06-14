import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<File> _files = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final files = await StorageService.instance.listLibraryFiles();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _import() async {
    final imported = await StorageService.instance.importAudioFiles();
    if (imported.isNotEmpty) await _refresh();
  }

  Future<void> _rename(File f) async {
    final current = f.path.split('/').last;
    final dot = current.lastIndexOf('.');
    final controller =
        TextEditingController(text: dot > 0 ? current.substring(0, dot) : current);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: StageColors.textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await StorageService.instance.renameLibraryFile(f, name.trim());
      await _refresh();
    }
  }

  Future<void> _delete(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
            '${f.path.split('/').last} will be removed from the library. Pads using it will lose their sample.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: StageColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.instance.deleteLibraryFile(f);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _files
        .where((f) =>
            f.path.split('/').last.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: StageColors.bg,
      appBar: AppBar(
        title: const Text('LIBRARY'),
        actions: [
          IconButton(
            onPressed: _import,
            icon: const Icon(Icons.add),
            tooltip: 'Import audio',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              style: const TextStyle(color: StageColors.textPrimary),
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.search, color: StageColors.textSecondary),
                hintText: 'Search audio files',
                hintStyle: const TextStyle(color: StageColors.textSecondary),
                filled: true,
                fillColor: StageColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StageColors.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StageColors.stroke),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _fileTile(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audio_file, size: 56, color: StageColors.stroke),
            const SizedBox(height: 14),
            Text(_query.isEmpty ? 'No audio imported yet' : 'No matches',
                style: const TextStyle(color: StageColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('WAV, MP3, FLAC, AIFF, OGG, M4A, AAC supported',
                style: TextStyle(color: StageColors.textSecondary, fontSize: 12)),
          ],
        ),
      );

  Widget _fileTile(File f) {
    final name = f.path.split('/').last;
    final ext = name.split('.').last.toUpperCase();
    final sizeKb = f.lengthSync() / 1024;
    final sizeLabel = sizeKb > 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '${sizeKb.toStringAsFixed(0)} KB';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StageColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StageColors.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: StageColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(ext,
                style: const TextStyle(
                    color: StageColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: StageColors.textPrimary)),
                const SizedBox(height: 2),
                Text(sizeLabel,
                    style: const TextStyle(
                        color: StageColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: StageColors.surfaceRaised,
            icon: const Icon(Icons.more_vert, color: StageColors.textSecondary),
            onSelected: (v) {
              if (v == 'rename') _rename(f);
              if (v == 'delete') _delete(f);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
