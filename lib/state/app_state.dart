import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/audio_engine.dart';
import '../services/storage_service.dart';

/// Single source of truth wired into the widget tree with an
/// InheritedNotifier (see main.dart). Owns the open worship set, bank/group
/// navigation, pad triggering and auto-save.
class AppState extends ChangeNotifier {
  AppState() {
    _activeSub = AudioEngine.instance.activePads.listen((_) {
      notifyListeners();
    });
  }

  late StreamSubscription _activeSub;

  AppSettings settings = AppSettings();

  WorshipSet? currentSet;
  int bankIndex = 0;
  int groupIndex = 0;

  Timer? _saveDebounce;

  BankConfig? get currentBank =>
      currentSet == null ? null : currentSet!.banks[bankIndex];
  GroupConfig? get currentGroup =>
      currentBank == null ? null : currentBank!.groups[groupIndex];

  bool get muted => AudioEngine.instance.isMuted;
  String? get soloPadId => AudioEngine.instance.soloPadId;
  double get masterVolume => AudioEngine.instance.masterVolume;
  bool soloArmed = false;

  // ---- Lifecycle ------------------------------------------------------

  Future<void> bootstrap() async {
    await StorageService.instance.init();
    settings = StorageService.instance.loadSettings();
    await AudioEngine.instance.init(
      bufferSize: settings.bufferSize,
      sampleRate: settings.sampleRate,
    );
    notifyListeners();
  }

  // ---- Set management -------------------------------------------------

  List<WorshipSet> allSets() => StorageService.instance.loadSets();

  List<WorshipSet> recentSets() {
    final sets = allSets();
    final order = StorageService.instance.recentSetIds();
    sets.sort((a, b) {
      final ia = order.indexOf(a.id);
      final ib = order.indexOf(b.id);
      if (ia == -1 && ib == -1) return b.updatedAt.compareTo(a.updatedAt);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return sets;
  }

  Future<WorshipSet> createSet(String name) async {
    final set = WorshipSet(name: name.trim().isEmpty ? 'Untitled Set' : name.trim());
    await StorageService.instance.saveSet(set);
    return set;
  }

  Future<void> openSet(WorshipSet set) async {
    await AudioEngine.instance.stopAll();
    currentSet = set;
    bankIndex = 0;
    groupIndex = 0;
    soloArmed = false;
    await StorageService.instance.touchRecent(set.id);
    notifyListeners();
    _preloadGroup();
  }

  Future<void> closeSet() async {
    await AudioEngine.instance.stopAll();
    await flushSave();
    currentSet = null;
    notifyListeners();
  }

  Future<void> deleteSet(WorshipSet set) async {
    if (currentSet?.id == set.id) currentSet = null;
    await StorageService.instance.deleteSet(set.id);
    notifyListeners();
  }

  Future<void> renameSet(WorshipSet set, String name) async {
    set.name = name.trim().isEmpty ? set.name : name.trim();
    await StorageService.instance.saveSet(set);
    notifyListeners();
  }

  // ---- Import / export / backup wrappers ------------------------------

  Future<WorshipSet?> storageImportSet() async {
    final set = await StorageService.instance.importSet();
    if (set != null) notifyListeners();
    return set;
  }

  Future<String?> storageExportSet(WorshipSet set) =>
      StorageService.instance.exportSet(set);

  Future<String?> storageExportBackup() =>
      StorageService.instance.exportFullBackup();

  Future<int?> storageRestoreBackup() async {
    final n = await StorageService.instance.restoreFullBackup();
    if (n != null) {
      settings = StorageService.instance.loadSettings();
      notifyListeners();
    }
    return n;
  }

  void markDirty() {
    notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), flushSave);
  }

  Future<void> flushSave() async {
    _saveDebounce?.cancel();
    final set = currentSet;
    if (set != null) {
      await StorageService.instance.saveSet(set);
    }
  }

  // ---- Navigation -----------------------------------------------------

  void selectBank(int i) {
    if (currentSet == null || i == bankIndex) return;
    bankIndex = i.clamp(0, 9);
    groupIndex = 0;
    notifyListeners();
    _preloadGroup();
  }

  void selectGroup(int i) {
    if (currentSet == null || i == groupIndex) return;
    groupIndex = i.clamp(0, 9);
    notifyListeners();
    _preloadGroup();
  }

  Future<void> renameGroup(String name) async {
    final g = currentGroup;
    if (g == null) return;
    g.name = name.trim().isEmpty ? g.name : name.trim();
    markDirty();
  }

  /// Decode every assigned sample in the visible group (and keep already
  /// cached ones) so taps are instant.
  void _preloadGroup() {
    final g = currentGroup;
    if (g == null) return;
    for (final pad in g.pads) {
      if (pad.isAssigned) {
        AudioEngine.instance.preload(pad.audioPath!);
      }
    }
  }

  // ---- Pad actions ----------------------------------------------------

  Future<void> tapPad(PadConfig pad) async {
    if (!pad.isAssigned) return;

    if (soloArmed) {
      AudioEngine.instance.setSolo(pad.id);
      soloArmed = false;
      if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
      notifyListeners();
      return;
    }

    if (settings.hapticsEnabled) HapticFeedback.lightImpact();
    await AudioEngine.instance.toggle(
      padId: pad.id,
      path: pad.audioPath!,
      volume: pad.volume,
      loop: pad.loop,
      fadeInMs: pad.fadeInMs,
      fadeOutMs: pad.fadeOutMs,
    );
    notifyListeners();
  }

  bool isPadActive(PadConfig pad) => AudioEngine.instance.isPadActive(pad.id);

  Future<void> assignAudio(PadConfig pad, String path) async {
    pad.audioPath = path;
    await AudioEngine.instance.preload(path);
    markDirty();
  }

  Future<void> removeAudio(PadConfig pad) async {
    await AudioEngine.instance.stopPad(pad.id);
    pad.audioPath = null;
    pad.name = '';
    markDirty();
  }

  void updatePadVolume(PadConfig pad, double v) {
    pad.volume = v;
    AudioEngine.instance.setPadVolume(pad.id, v);
    markDirty();
  }

  // ---- Global performance controls -------------------------------------

  void setMasterVolume(double v) {
    AudioEngine.instance.setMasterVolume(v);
    notifyListeners();
  }

  void toggleMute() {
    AudioEngine.instance.setMuted(!muted);
    if (settings.hapticsEnabled) HapticFeedback.selectionClick();
    notifyListeners();
  }

  void toggleSoloArm() {
    if (soloPadId != null) {
      // Solo active -> clear it.
      AudioEngine.instance.setSolo(null);
      soloArmed = false;
    } else {
      soloArmed = !soloArmed;
    }
    if (settings.hapticsEnabled) HapticFeedback.selectionClick();
    notifyListeners();
  }

  Future<void> fadeOutAll() async {
    if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
    await AudioEngine.instance.fadeOutAll(fadeOutMs: 3000);
    soloArmed = false;
    notifyListeners();
  }

  Future<void> stopAll() async {
    if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
    await AudioEngine.instance.stopAll();
    soloArmed = false;
    notifyListeners();
  }

  Future<void> panic() async {
    if (settings.hapticsEnabled) HapticFeedback.heavyImpact();
    await AudioEngine.instance.panic();
    soloArmed = false;
    notifyListeners();
  }

  // ---- Settings -------------------------------------------------------

  Future<void> updateSettings(void Function(AppSettings) apply,
      {bool reinitAudio = false}) async {
    apply(settings);
    await StorageService.instance.saveSettings(settings);
    if (reinitAudio) {
      await AudioEngine.instance.reinit(
        bufferSize: settings.bufferSize,
        sampleRate: settings.sampleRate,
      );
      _preloadGroup();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _activeSub.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }
}
