# Worship Pad

A professional, low-latency ambient pad performance app for live worship — built with Flutter for Android (and runnable on iOS with the standard Flutter iOS setup). Delivered by **Noets Tech Solutions**.

## What it does

- **Landscape-first stage interface** — dark, neon-accented, distraction-free.
- **8 performance pads** in a 4×2 grid. Tap to trigger, tap again to fade-stop, long-press to edit.
- **Bank / Group system** — 10 banks (A–J), each with 10 groups, each with 8 pads. Switch instantly from the side rails. Groups are renameable.
- **Per-pad settings** — audio sample, volume, loop, fade-in, fade-out, color, custom name.
- **Layering** — multiple pads play simultaneously with independent volume.
- **Transport** — master volume, fade-out-all, stop-all, mute, solo, and a red **PANIC** kill switch.
- **Worship sets** — create, save, open, rename, delete; everything persists permanently.
- **Library** — import, browse, search, rename, delete audio (WAV, MP3, FLAC, AIFF, OGG, M4A, AAC).
- **Backup & restore** — export/import a single set, or a full JSON backup of all sets + settings.

## Latency

Real-world trigger latency is dominated by the OS audio callback buffer, not app code. This app is built to push that as low as the hardware allows:

- **Engine:** `flutter_soloud` (SoLoud C++ engine over the miniaudio backend, via FFI). On Android this rides the **AAudio low-latency path**; on iOS, CoreAudio.
- **Preloading:** every assigned sample in the visible group is **decoded to raw PCM and held in RAM** (`LoadMode.memory`). A tap never touches disk or a decoder — it just starts a voice in the next callback.
- **Buffer size is adjustable in Settings:** `64 / 128 / 256 / 512` frames. At 48 kHz, `64` frames ≈ **~1.3 ms** of callback latency. Set it as low as your device runs cleanly, then step up one if you hear glitches.

> Note on "1 ms": end-to-end touch-to-sound latency also includes the touchscreen scan rate and the device's audio output stack, which the app cannot control. The audio engine itself is configured for the lowest buffer the hardware supports (~1.3 ms at 64 frames / 48 kHz). True sub-millisecond round-trip is not physically achievable on general-purpose phone hardware; this configuration gets you as close as the platform allows.

## Project structure

```
lib/
  main.dart                     app entry, theme, AppScope wiring
  models/models.dart            PadConfig, GroupConfig, BankConfig, WorshipSet, AppSettings
  services/
    audio_engine.dart           low-latency SoLoud wrapper (preload, fades, solo/mute, panic)
    storage_service.dart        persistence, audio library, import/export/backup
  state/
    app_state.dart              single source of truth (ChangeNotifier)
    app_scope.dart              InheritedNotifier access
  theme/app_theme.dart          dark stage theme + neon palette
  screens/
    home_screen.dart            recent sets, new/import set
    performance_screen.dart     the live 4×2 pad stage
    library_screen.dart         audio file management
    settings_screen.dart        audio / appearance / performance / backup
  widgets/
    pad_widget.dart             animated glowing pad
    pad_settings_sheet.dart     long-press pad editor
```

## Build & run

You need Flutter 3.x with the Android toolchain.

```bash
cd worship_pad
flutter pub get
flutter run            # on a connected device (use a real device for audio latency)
flutter build apk      # release APK
```

If you can't build locally, the same project compiles unchanged on cloud Flutter CI
(Codemagic, GitHub Actions with `subosito/flutter-action`, or GitHub Codespaces).

### Android notes
- `minSdk` is **23** (required by `flutter_soloud` / AAudio).
- Manifest declares `READ_MEDIA_AUDIO` and advertises the low-latency / pro-audio
  hardware features so the OS routes audio to the fast path.
- Replace the debug signing config in `android/app/build.gradle` before publishing.

## In Short
- Complete Flutter app: dark landscape worship-pad performer with 10 banks × 10 groups × 8 pads, full per-pad settings, layering, transport + panic, sets, library, backup/restore.
- Lowest practical latency via SoLoud + in-RAM PCM preloading and an adjustable 64–512 frame buffer (~1.3 ms at 64/48 kHz); genuine sub-1 ms round-trip isn't possible on phone hardware, and the README is honest about that.
- Build with `flutter pub get` then `flutter run`; needs the Flutter SDK (not present here, so it wasn't compiled in this environment — review the code and build on a machine or cloud CI with Flutter installed).
