import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// All persistence for the app:
/// * Worship sets (full bank/group/pad configuration) -> SharedPreferences JSON
/// * App settings -> SharedPreferences JSON
/// * Audio library -> files copied into the app documents directory
/// * Backup / restore + set import/export -> JSON files via the system picker
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _kSetsKey = 'worship_pad.sets.v1';
  static const _kSettingsKey = 'worship_pad.settings.v1';
  static const _kRecentsKey = 'worship_pad.recents.v1';

  late SharedPreferences _prefs;
  late Directory _audioDir;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final docs = await getApplicationDocumentsDirectory();
    _audioDir = Directory('${docs.path}/audio_library');
    if (!await _audioDir.exists()) {
      await _audioDir.create(recursive: true);
    }
  }

  Directory get audioLibraryDir => _audioDir;

  // ---- Worship sets ---------------------------------------------------

  List<WorshipSet> loadSets() {
    final raw = _prefs.getStringList(_kSetsKey) ?? [];
    final sets = <WorshipSet>[];
    for (final s in raw) {
      try {
        sets.add(WorshipSet.decode(s));
      } catch (_) {/* skip corrupt entries */}
    }
    return sets;
  }

  Future<void> saveSets(List<WorshipSet> sets) async {
    await _prefs.setStringList(
        _kSetsKey, sets.map((s) => s.encode()).toList());
  }

  Future<void> saveSet(WorshipSet set) async {
    final sets = loadSets();
    final idx = sets.indexWhere((s) => s.id == set.id);
    set.updatedAt = DateTime.now();
    if (idx >= 0) {
      sets[idx] = set;
    } else {
      sets.add(set);
    }
    await saveSets(sets);
  }

  Future<void> deleteSet(String id) async {
    final sets = loadSets()..removeWhere((s) => s.id == id);
    await saveSets(sets);
    final recents = recentSetIds()..remove(id);
    await _prefs.setStringList(_kRecentsKey, recents);
  }

  List<String> recentSetIds() => _prefs.getStringList(_kRecentsKey) ?? [];

  Future<void> touchRecent(String id) async {
    final recents = recentSetIds()
      ..remove(id)
      ..insert(0, id);
    await _prefs.setStringList(_kRecentsKey, recents.take(10).toList());
  }

  // ---- Settings -------------------------------------------------------

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettingsKey);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setString(_kSettingsKey, jsonEncode(s.toJson()));
  }

  // ---- Audio library --------------------------------------------------

  static const supportedExtensions = [
    'wav', 'mp3', 'flac', 'aiff', 'aif', 'ogg', 'm4a', 'aac'
  ];

  /// Pick one or more audio files and copy them into the app library.
  /// Returns the absolute paths of the imported copies.
  Future<List<String>> importAudioFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      allowMultiple: true,
    );
    if (result == null) return [];

    final imported = <String>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final src = File(f.path!);
      var name = f.name;
      var dest = File('${_audioDir.path}/$name');
      var n = 1;
      while (await dest.exists()) {
        final dot = name.lastIndexOf('.');
        final base = dot > 0 ? name.substring(0, dot) : name;
        final ext = dot > 0 ? name.substring(dot) : '';
        dest = File('${_audioDir.path}/$base ($n)$ext');
        n++;
      }
      await src.copy(dest.path);
      imported.add(dest.path);
    }
    return imported;
  }

  Future<List<File>> listLibraryFiles() async {
    final entries = await _audioDir.list().toList();
    final files = entries.whereType<File>().where((f) {
      final ext = f.path.split('.').last.toLowerCase();
      return supportedExtensions.contains(ext);
    }).toList()
      ..sort((a, b) =>
          a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  Future<void> deleteLibraryFile(File f) async {
    if (await f.exists()) await f.delete();
  }

  Future<String?> renameLibraryFile(File f, String newBaseName) async {
    final ext = f.path.split('.').last;
    final dest = '${_audioDir.path}/$newBaseName.$ext';
    if (await File(dest).exists()) return null;
    final renamed = await f.rename(dest);
    return renamed.path;
  }

  // ---- Export / import / backup ---------------------------------------

  /// Export a single worship set as a shareable JSON file.
  Future<String?> exportSet(WorshipSet set) async {
    final bytes =
        Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ')
            .convert(set.toJson())));
    return FilePicker.platform.saveFile(
      dialogTitle: 'Export worship set',
      fileName:
          '${set.name.replaceAll(RegExp(r"[^\w\- ]"), "_")}.worshipset.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  /// Import a worship set from a JSON file. Returns the imported set.
  Future<WorshipSet?> importSet() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    try {
      final raw = await File(path).readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Re-id so an import never collides with an existing set.
      json.remove('id');
      final set = WorshipSet.fromJson(json);
      await saveSet(set);
      return set;
    } catch (_) {
      return null;
    }
  }

  /// Full backup: every set + settings in one JSON file.
  Future<String?> exportFullBackup() async {
    final payload = {
      'app': 'worship_pad',
      'backupVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': loadSettings().toJson(),
      'sets': loadSets().map((s) => s.toJson()).toList(),
    };
    final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
    final stamp = DateTime.now().toIso8601String().split('T').first;
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save full backup',
      fileName: 'worship_pad_backup_$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
  }

  /// Restore a full backup. Returns the number of sets restored, or null on
  /// failure. Existing sets with the same id are overwritten.
  Future<int?> restoreFullBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    try {
      final raw = await File(path).readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['app'] != 'worship_pad') return null;

      final restored = ((json['sets'] as List?) ?? [])
          .map((s) => WorshipSet.fromJson(s as Map<String, dynamic>))
          .toList();
      final existing = loadSets();
      for (final r in restored) {
        final idx = existing.indexWhere((s) => s.id == r.id);
        if (idx >= 0) {
          existing[idx] = r;
        } else {
          existing.add(r);
        }
      }
      await saveSets(existing);

      if (json['settings'] is Map<String, dynamic>) {
        await saveSettings(
            AppSettings.fromJson(json['settings'] as Map<String, dynamic>));
      }
      return restored.length;
    } catch (_) {
      return null;
    }
  }
}
