import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pad_widget.dart';
import '../widgets/pad_settings_sheet.dart';

/// Full-screen, landscape-first live performance interface.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key, required this.state});
  final AppState state;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    // Force landscape for the stage.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (state.settings.keepScreenOn) {
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _confirmPanic() async {
    if (!state.settings.confirmPanic) {
      await state.panic();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kill all sound?'),
        content: const Text('This stops every pad instantly.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StageColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('KILL ALL'),
          ),
        ],
      ),
    );
    if (ok == true) await state.panic();
  }

  Future<void> _renameGroup() async {
    final group = state.currentGroup!;
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: StageColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
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
    if (name != null) state.renameGroup(name);
  }

  @override
  Widget build(BuildContext context) {
    final accent = state.settings.accent;
    final group = state.currentGroup;
    if (group == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: StageColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _bankRail(accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _topBar(accent, group),
                    const SizedBox(height: 12),
                    Expanded(child: _padGrid(group)),
                    const SizedBox(height: 12),
                    _transportBar(accent),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _groupRail(accent),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Bank rail (left) ----
  Widget _bankRail(Color accent) {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: StageColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StageColors.stroke),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('BANK',
              style: TextStyle(
                  color: StageColors.textSecondary,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: state.currentSet!.banks.length,
              itemBuilder: (_, i) {
                final selected = i == state.bankIndex;
                final letter = state.currentSet!.banks[i].letter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: GestureDetector(
                    onTap: () => state.selectBank(i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withOpacity(0.18)
                            : StageColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected ? accent : StageColors.stroke,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Text(letter,
                          style: TextStyle(
                            color: selected ? accent : StageColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Group rail (right) ----
  Widget _groupRail(Color accent) {
    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: StageColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StageColors.stroke),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('GRP',
              style: TextStyle(
                  color: StageColors.textSecondary,
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: state.currentBank!.groups.length,
              itemBuilder: (_, i) {
                final selected = i == state.groupIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: GestureDetector(
                    onTap: () => state.selectGroup(i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withOpacity(0.18)
                            : StageColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected ? accent : StageColors.stroke,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                            color: selected ? accent : StageColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Top bar ----
  Widget _topBar(Color accent, GroupConfig group) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: StageColors.textSecondary),
          onPressed: () async {
            await state.closeSet();
            if (mounted) Navigator.pop(context);
          },
        ),
        GestureDetector(
          onTap: _renameGroup,
          child: Row(
            children: [
              Text(state.currentSet!.name.toUpperCase(),
                  style: const TextStyle(
                      color: StageColors.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.5)),
              const SizedBox(width: 10),
              Text('·', style: TextStyle(color: StageColors.textSecondary)),
              const SizedBox(width: 10),
              Text(group.name.toUpperCase(),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 13, color: StageColors.textSecondary),
            ],
          ),
        ),
        const Spacer(),
        // Master volume.
        const Icon(Icons.volume_up, size: 18, color: StageColors.textSecondary),
        SizedBox(
          width: 160,
          child: Slider(
            value: state.masterVolume,
            onChanged: state.setMasterVolume,
          ),
        ),
        Text('${(state.masterVolume * 100).round()}%',
            style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ---- Pad grid (4x2) ----
  Widget _padGrid(GroupConfig group) {
    final solo = state.soloPadId;
    return LayoutBuilder(
      builder: (context, c) {
        const cols = 4, rows = 2, gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        final h = (c.maxHeight - gap * (rows - 1)) / rows;
        final ratio = w / h;
        return GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: ratio,
          physics: const NeverScrollableScrollPhysics(),
          children: group.pads.map((pad) {
            final active = state.isPadActive(pad);
            return PadWidget(
              pad: pad,
              active: active,
              soloed: solo == pad.id,
              dimmedBySolo: solo != null && solo != pad.id && active,
              onTap: () => state.tapPad(pad),
              onLongPress: () =>
                  showPadSettings(context, state: state, pad: pad),
            );
          }).toList(),
        );
      },
    );
  }

  // ---- Transport / performance controls ----
  Widget _transportBar(Color accent) {
    final muted = state.muted;
    final soloActive = state.soloPadId != null || state.soloArmed;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: StageColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StageColors.stroke),
      ),
      child: Row(
        children: [
          _transportButton(
            label: 'MUTE',
            icon: muted ? Icons.volume_off : Icons.volume_mute,
            color: muted ? StageColors.warn : StageColors.textSecondary,
            highlighted: muted,
            onTap: state.toggleMute,
          ),
          _transportButton(
            label: state.soloArmed ? 'TAP PAD' : 'SOLO',
            icon: Icons.hearing,
            color: soloActive ? StageColors.warn : StageColors.textSecondary,
            highlighted: soloActive,
            onTap: state.toggleSoloArm,
          ),
          const _Divider(),
          _transportButton(
            label: 'FADE OUT',
            icon: Icons.south,
            color: accent,
            onTap: state.fadeOutAll,
          ),
          _transportButton(
            label: 'STOP ALL',
            icon: Icons.stop,
            color: StageColors.textPrimary,
            onTap: state.stopAll,
          ),
          const _Divider(),
          // Panic — widest, hardest to miss.
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _confirmPanic,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: StageColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: StageColors.danger, width: 1.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new,
                        color: StageColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('PANIC',
                        style: TextStyle(
                          color: StageColors.danger,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: highlighted
                ? color.withOpacity(0.15)
                : StageColors.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: highlighted ? color : StageColors.stroke,
                width: highlighted ? 1.4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: StageColors.stroke,
      );
}
