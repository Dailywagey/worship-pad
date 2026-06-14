import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState? _state;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Buffer-size options with the resulting callback latency at 48 kHz.
  static const _bufferOptions = <int, String>{
    64: '64 · ~1.3 ms',
    128: '128 · ~2.7 ms',
    256: '256 · ~5.3 ms',
    512: '512 · ~10.7 ms',
  };

  static const _accentOptions = <String>[
    '#00E5FF', '#1DE9B6', '#69F0AE', '#FFD740',
    '#FF6E40', '#FF4081', '#B388FF', '#448AFF',
  ];

  @override
  Widget build(BuildContext context) {
    _state ??= AppScope.of(context);
    final s = _state!;

    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final accent = s.settings.accent;
        return Scaffold(
          backgroundColor: StageColors.bg,
          appBar: AppBar(title: const Text('SETTINGS')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sectionHeader('AUDIO', Icons.tune),
              _card([
                const _RowLabel(
                  title: 'Audio buffer size',
                  subtitle:
                      'Lower buffer = lower latency. Decrease until you hear glitches, then step up one. Triggering is gapless because samples are preloaded in RAM.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bufferOptions.entries.map((e) {
                    final selected = s.settings.bufferSize == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      backgroundColor: StageColors.surfaceRaised,
                      selectedColor: accent.withOpacity(0.22),
                      side: BorderSide(
                          color: selected ? accent : StageColors.stroke),
                      labelStyle: TextStyle(
                          color: selected ? accent : StageColors.textSecondary,
                          fontSize: 12),
                      onSelected: (_) {
                        s.updateSettings((st) => st.bufferSize = e.key,
                            reinitAudio: true);
                        _toast(context, 'Audio engine reinitialized');
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 28, color: StageColors.stroke),
                const _RowLabel(
                    title: 'Sample rate',
                    subtitle: 'Match your audio interface for best fidelity.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [44100, 48000, 96000].map((sr) {
                    final selected = s.settings.sampleRate == sr;
                    return ChoiceChip(
                      label: Text('${(sr / 1000).toStringAsFixed(sr % 1000 == 0 ? 0 : 1)} kHz'),
                      selected: selected,
                      backgroundColor: StageColors.surfaceRaised,
                      selectedColor: accent.withOpacity(0.22),
                      side: BorderSide(
                          color: selected ? accent : StageColors.stroke),
                      labelStyle: TextStyle(
                          color: selected ? accent : StageColors.textSecondary,
                          fontSize: 12),
                      onSelected: (_) {
                        s.updateSettings((st) => st.sampleRate = sr,
                            reinitAudio: true);
                      },
                    );
                  }).toList(),
                ),
              ]),

              _sectionHeader('APPEARANCE', Icons.palette_outlined),
              _card([
                const _RowLabel(title: 'Accent color'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _accentOptions.map((hex) {
                    final c = colorFromHex(hex);
                    final selected = s.settings.accentHex == hex;
                    return GestureDetector(
                      onTap: () =>
                          s.updateSettings((st) => st.accentHex = hex),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: c.withOpacity(0.6),
                                blurRadius: selected ? 14 : 6)
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ]),

              _sectionHeader('PERFORMANCE', Icons.speed),
              _card([
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.settings.hapticsEnabled,
                  title: const Text('Haptic feedback',
                      style: TextStyle(color: StageColors.textPrimary)),
                  subtitle: const Text('Vibrate on pad and transport taps',
                      style: TextStyle(
                          color: StageColors.textSecondary, fontSize: 12)),
                  onChanged: (v) =>
                      s.updateSettings((st) => st.hapticsEnabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.settings.keepScreenOn,
                  title: const Text('Keep screen on',
                      style: TextStyle(color: StageColors.textPrimary)),
                  subtitle: const Text('Prevent sleep during performance',
                      style: TextStyle(
                          color: StageColors.textSecondary, fontSize: 12)),
                  onChanged: (v) =>
                      s.updateSettings((st) => st.keepScreenOn = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.settings.confirmPanic,
                  title: const Text('Confirm panic button',
                      style: TextStyle(color: StageColors.textPrimary)),
                  subtitle: const Text('Require confirmation before kill-all',
                      style: TextStyle(
                          color: StageColors.textSecondary, fontSize: 12)),
                  onChanged: (v) =>
                      s.updateSettings((st) => st.confirmPanic = v),
                ),
              ]),

              _sectionHeader('BACKUP & RESTORE', Icons.backup_outlined),
              _card([
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.upload_file, color: accent),
                  title: const Text('Export full backup',
                      style: TextStyle(color: StageColors.textPrimary)),
                  subtitle: const Text('All sets and settings to a JSON file',
                      style: TextStyle(
                          color: StageColors.textSecondary, fontSize: 12)),
                  onTap: () async {
                    final path = await s.storageExportBackup();
                    if (path != null && context.mounted) {
                      _toast(context, 'Backup saved');
                    }
                  },
                ),
                const Divider(height: 1, color: StageColors.stroke),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.restore, color: accent),
                  title: const Text('Restore from backup',
                      style: TextStyle(color: StageColors.textPrimary)),
                  subtitle: const Text('Merge sets and settings from a backup',
                      style: TextStyle(
                          color: StageColors.textSecondary, fontSize: 12)),
                  onTap: () async {
                    final n = await s.storageRestoreBackup();
                    if (context.mounted) {
                      _toast(
                          context,
                          n == null
                              ? 'Could not read backup file'
                              : 'Restored $n set(s)');
                    }
                  },
                ),
              ]),

              const SizedBox(height: 20),
              Center(
                child: Text('Worship Pad · v1.0.0 · Noets Tech Solutions',
                    style: TextStyle(
                        color: StageColors.textSecondary.withOpacity(0.6),
                        fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: StageColors.textSecondary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: StageColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: StageColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: StageColors.stroke),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: StageColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: const TextStyle(
                  color: StageColors.textSecondary, fontSize: 12, height: 1.4)),
        ],
      ],
    );
  }
}
