import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Low-latency audio engine for live pad performance.
///
/// Design goals:
/// * Every assigned sample is decoded to raw PCM and held in RAM
///   (LoadMode.memory) so a trigger never touches disk or a decoder.
/// * Small audio callback buffer (default 256 frames @ 48 kHz ≈ 5.3 ms)
///   riding Android's AAudio / iOS's CoreAudio low-latency path.
/// * Trigger path is synchronous after preload: tap → voice start in the
///   next audio callback. Perceived latency is effectively instant.
class AudioEngine {
  AudioEngine._();
  static final AudioEngine instance = AudioEngine._();

  final SoLoud _soloud = SoLoud.instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Decoded sample cache: absolute file path -> in-memory audio source.
  final Map<String, AudioSource> _sources = {};

  /// Currently sounding voices: pad id -> handle.
  final Map<String, SoundHandle> _voices = {};

  /// Pad volumes for active voices (needed to restore after solo/mute).
  final Map<String, double> _voiceVolumes = {};

  double _masterVolume = 1.0;
  bool _muted = false;
  String? _soloPadId;

  /// Notifies the UI when the set of active pads changes.
  final StreamController<Set<String>> _activeController =
      StreamController.broadcast();
  Stream<Set<String>> get activePads => _activeController.stream;

  Set<String> get currentlyActive => _voices.keys.toSet();
  bool isPadActive(String padId) => _voices.containsKey(padId);
  String? get soloPadId => _soloPadId;
  bool get isMuted => _muted;
  double get masterVolume => _masterVolume;

  Future<void> init({int bufferSize = 256, int sampleRate = 48000}) async {
    if (_initialized) return;
    await _soloud.init(
      bufferSize: bufferSize,
      sampleRate: sampleRate,
      channels: Channels.stereo,
    );
    _soloud.setGlobalVolume(_masterVolume);
    _initialized = true;
  }

  /// Reinitialize with new audio settings (used from the Settings screen).
  Future<void> reinit({required int bufferSize, required int sampleRate}) async {
    await panic();
    for (final src in _sources.values) {
      await _soloud.disposeSource(src);
    }
    _sources.clear();
    _soloud.deinit();
    _initialized = false;
    await init(bufferSize: bufferSize, sampleRate: sampleRate);
  }

  /// Decode a file into RAM ahead of time so triggering is instant.
  Future<bool> preload(String path) async {
    if (!_initialized) return false;
    if (_sources.containsKey(path)) return true;
    try {
      _sources[path] = await _soloud.loadFile(path, mode: LoadMode.memory);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> unload(String path) async {
    final src = _sources.remove(path);
    if (src != null) {
      await _soloud.disposeSource(src);
    }
  }

  /// Trigger a pad. If the pad is already sounding it is faded out and
  /// stopped (toggle behaviour, the standard for worship pads).
  ///
  /// Returns true if the pad is now playing, false if it stopped/failed.
  Future<bool> toggle({
    required String padId,
    required String path,
    required double volume,
    required bool loop,
    required int fadeInMs,
    required int fadeOutMs,
  }) async {
    if (!_initialized) return false;

    // Already playing -> fade out and stop.
    if (_voices.containsKey(padId)) {
      await stopPad(padId, fadeOutMs: fadeOutMs);
      return false;
    }

    // Hot path: source should already be preloaded; fall back to load.
    var src = _sources[path];
    if (src == null) {
      final ok = await preload(path);
      if (!ok) return false;
      src = _sources[path];
    }

    final effectiveVolume = _effectiveVolumeFor(padId, volume);
    final handle = await _soloud.play(
      src!,
      volume: fadeInMs > 0 ? 0.0 : effectiveVolume,
      looping: loop,
    );
    if (fadeInMs > 0) {
      _soloud.fadeVolume(
          handle, effectiveVolume, Duration(milliseconds: fadeInMs));
    }

    _voices[padId] = handle;
    _voiceVolumes[padId] = volume;
    _notify();

    // For one-shot (non-loop) pads, clear state when playback finishes.
    if (!loop) {
      _watchOneShot(padId, handle);
    }
    return true;
  }

  void _watchOneShot(String padId, SoundHandle handle) {
    Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (_voices[padId] != handle) {
        t.cancel();
        return;
      }
      if (!_soloud.getIsValidVoiceHandle(handle)) {
        _voices.remove(padId);
        _voiceVolumes.remove(padId);
        if (_soloPadId == padId) _soloPadId = null;
        _notify();
        t.cancel();
      }
    });
  }

  Future<void> stopPad(String padId, {int fadeOutMs = 0}) async {
    final handle = _voices.remove(padId);
    _voiceVolumes.remove(padId);
    if (_soloPadId == padId) {
      _soloPadId = null;
      _reapplyVoiceVolumes();
    }
    if (handle == null) return;
    if (fadeOutMs > 0) {
      _soloud.fadeVolume(handle, 0.0, Duration(milliseconds: fadeOutMs));
      _soloud.scheduleStop(handle, Duration(milliseconds: fadeOutMs + 60));
    } else {
      await _soloud.stop(handle);
    }
    _notify();
  }

  /// Live volume change for an already-sounding pad.
  void setPadVolume(String padId, double volume) {
    _voiceVolumes[padId] = volume;
    final handle = _voices[padId];
    if (handle != null) {
      _soloud.setVolume(handle, _effectiveVolumeFor(padId, volume));
    }
  }

  // ---- Global controls -----------------------------------------------

  void setMasterVolume(double v) {
    _masterVolume = v.clamp(0.0, 1.0);
    if (!_muted) _soloud.setGlobalVolume(_masterVolume);
  }

  void setMuted(bool muted) {
    _muted = muted;
    _soloud.setGlobalVolume(muted ? 0.0 : _masterVolume);
    _notify();
  }

  /// Solo a pad: every other active voice is silenced (volume 0) but keeps
  /// running so un-solo restores the full layered bed seamlessly.
  void setSolo(String? padId) {
    _soloPadId = padId;
    _reapplyVoiceVolumes();
    _notify();
  }

  double _effectiveVolumeFor(String padId, double padVolume) {
    if (_soloPadId != null && _soloPadId != padId) return 0.0;
    return padVolume;
  }

  void _reapplyVoiceVolumes() {
    for (final entry in _voices.entries) {
      final v = _voiceVolumes[entry.key] ?? 1.0;
      _soloud.setVolume(entry.value, _effectiveVolumeFor(entry.key, v));
    }
  }

  /// Musical fade-out of everything currently sounding.
  Future<void> fadeOutAll({int fadeOutMs = 3000}) async {
    final ids = _voices.keys.toList();
    for (final id in ids) {
      final handle = _voices[id];
      if (handle != null) {
        _soloud.fadeVolume(handle, 0.0, Duration(milliseconds: fadeOutMs));
        _soloud.scheduleStop(handle, Duration(milliseconds: fadeOutMs + 60));
      }
    }
    _voices.clear();
    _voiceVolumes.clear();
    _soloPadId = null;
    _notify();
  }

  /// Stop everything with a short safety fade (no click).
  Future<void> stopAll() => fadeOutAll(fadeOutMs: 120);

  /// PANIC: kill every voice immediately.
  Future<void> panic() async {
    final handles = _voices.values.toList();
    _voices.clear();
    _voiceVolumes.clear();
    _soloPadId = null;
    for (final h in handles) {
      await _soloud.stop(h);
    }
    _notify();
  }

  void _notify() {
    if (!_activeController.isClosed) {
      _activeController.add(currentlyActive);
    }
  }

  void dispose() {
    _activeController.close();
    _soloud.deinit();
    _initialized = false;
  }
}
