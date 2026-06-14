import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Long-press pad editor. Returns nothing — edits are applied to the [pad]
/// instance and persisted through [state] live.
Future<void> showPadSettings(
  BuildContext context, {
  required AppState state,
  required PadConfig pad,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: StageColors.surface,
    builder: (_) => _PadSettingsSheet(state: state, pad: pad),
  );
}

class _PadSettingsSheet extends StatefulWidget {
  const _PadSettingsSheet({required this.state, required this.pad});
  final AppState state;
  final PadConfig pad;

  @override
  State<_PadSettingsSheet> createState() => _PadSettingsSheetState();
}

class _PadSettingsSheetState extends State<_PadSettingsSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.pad.name);

  PadConfig get pad => widget.pad;
  AppState get state => widget.state;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _assignFromLibrary() async {
    final files = await StorageService.instance.listLibraryFiles();
    if (!mounted) return;
    final picked = await showModalBottomSheet<File>(
      context: context,
      backgroundColor: StageColors.surfaceRaised,
      isScrollControlled: true,
      builder: (_) => _LibraryPicker(files: files),
    );
    if (picked != null) {
      await state.assignAudio(pad, picked.path);
      setState(() {});
    }
  }

  Future<void> _importNew() async {
    final imported = await StorageService.instance.importAudioFiles();
    if (imported.isNotEmpty) {
      await state.assignAudio(pad, imported.first);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = state.settings.accent;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) => Container(
          decoration: const BoxDecoration(
            color: StageColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: StageColors.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: pad.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: pad.color.withOpacity(0.6), blurRadius: 10)
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('PAD SETTINGS',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 20),

              // --- Audio assignment ---
              _sectionLabel('AUDIO SAMPLE'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: StageColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StageColors.stroke),
                ),
                child: Row(
                  children: [
                    Icon(
                      pad.isAssigned ? Icons.graphic_eq : Icons.music_off,
                      color: pad.isAssigned ? accent : StageColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pad.isAssigned
                            ? pad.audioPath!.split('/').last
                            : 'No sample assigned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: StageColors.textPrimary, fontSize: 13),
                      ),
                    ),
                    if (pad.isAssigned)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: StageColors.danger),
                        onPressed: () async {
                          await state.removeAudio(pad);
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _outlineButton(
                      icon: Icons.library_music,
                      label: 'From library',
                      accent: accent,
                      onTap: _assignFromLibrary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _outlineButton(
                      icon: Icons.add,
                      label: 'Import new',
                      accent: accent,
                      onTap: _importNew,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // --- Name ---
              _sectionLabel('PAD NAME'),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                style: const TextStyle(color: StageColors.textPrimary),
                decoration: _inputDecoration('e.g. Cinematic C / Worship A', accent),
                onChanged: (v) {
                  pad.name = v;
                  state.markDirty();
                },
              ),
              const SizedBox(height: 22),

              // --- Volume ---
              _sliderRow(
                label: 'VOLUME',
                value: pad.volume,
                min: 0,
                max: 1,
                display: '${(pad.volume * 100).round()}%',
                accent: accent,
                onChanged: (v) {
                  state.updatePadVolume(pad, v);
                  setState(() {});
                },
              ),

              // --- Loop ---
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Loop playback',
                    style: TextStyle(color: StageColors.textPrimary)),
                subtitle: const Text('Keep ambient pads sustaining',
                    style: TextStyle(color: StageColors.textSecondary, fontSize: 12)),
                value: pad.loop,
                onChanged: (v) {
                  setState(() => pad.loop = v);
                  state.markDirty();
                },
              ),

              // --- Fades ---
              _sliderRow(
                label: 'FADE IN',
                value: pad.fadeInMs.toDouble(),
                min: 0,
                max: 8000,
                display: '${(pad.fadeInMs / 1000).toStringAsFixed(1)}s',
                accent: accent,
                onChanged: (v) {
                  setState(() => pad.fadeInMs = v.round());
                  state.markDirty();
                },
              ),
              _sliderRow(
                label: 'FADE OUT',
                value: pad.fadeOutMs.toDouble(),
                min: 0,
                max: 10000,
                display: '${(pad.fadeOutMs / 1000).toStringAsFixed(1)}s',
                accent: accent,
                onChanged: (v) {
                  setState(() => pad.fadeOutMs = v.round());
                  state.markDirty();
                },
              ),
              const SizedBox(height: 16),

              // --- Color ---
              _sectionLabel('PAD COLOR'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: kPadPalette.map((c) {
                  final selected = pad.colorHex == hexFromColor(c);
                  return GestureDetector(
                    onTap: () {
                      setState(() => pad.colorHex = hexFromColor(c));
                      state.markDirty();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: c.withOpacity(0.6), blurRadius: selected ? 14 : 6)
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('DONE',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t,
        style: const TextStyle(
          color: StageColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required Color accent,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel(label),
            Text(display,
                style: TextStyle(
                    color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  InputDecoration _inputDecoration(String hint, Color accent) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: StageColors.textSecondary),
        filled: true,
        fillColor: StageColors.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StageColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StageColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent),
        ),
      );
}

/// In-app picker listing imported library files.
class _LibraryPicker extends StatelessWidget {
  const _LibraryPicker({required this.files});
  final List<File> files;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CHOOSE FROM LIBRARY',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text('No imported files yet. Use "Import new" instead.',
                    style: TextStyle(color: StageColors.textSecondary)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: StageColors.stroke),
                  itemBuilder: (_, i) {
                    final f = files[i];
                    return ListTile(
                      leading: const Icon(Icons.audiotrack,
                          color: StageColors.textSecondary),
                      title: Text(f.path.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: StageColors.textPrimary)),
                      onTap: () => Navigator.pop(context, f),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
