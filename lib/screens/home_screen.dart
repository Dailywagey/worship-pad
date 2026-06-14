import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'performance_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  AppState get state => _state!;
  AppState? _state;

  @override
  Widget build(BuildContext context) {
    _state ??= AppScope.of(context);
    final s = _state!;
    final accent = s.settings.accent;

    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final recents = s.recentSets();
        return Scaffold(
          backgroundColor: StageColors.bg,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(accent, s)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  sliver: SliverToBoxAdapter(child: _quickActions(accent, s)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('WORSHIP SETS',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text('${s.allSets().length} saved',
                            style: const TextStyle(
                                color: StageColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (recents.isEmpty)
                  SliverToBoxAdapter(child: _emptyState(accent, s))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: recents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _setCard(recents[i], accent, s),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color accent, AppState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 16)],
            ),
            child: const Icon(Icons.graphic_eq, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WORSHIP PAD',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium!
                      .copyWith(fontSize: 24)),
              const Text('Live ambient pad performance',
                  style: TextStyle(color: StageColors.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          _circleIcon(Icons.library_music, () => _go(const LibraryScreen())),
          const SizedBox(width: 8),
          _circleIcon(Icons.settings, () => _go(const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: StageColors.textSecondary),
        style: IconButton.styleFrom(
          backgroundColor: StageColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: StageColors.stroke),
          ),
        ),
      );

  Widget _quickActions(Color accent, AppState s) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _createSet(s),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.22), accent.withOpacity(0.06)],
                ),
                border: Border.all(color: accent.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_circle_outline, color: accent, size: 28),
                  const SizedBox(height: 8),
                  const Text('NEW SET',
                      style: TextStyle(
                          color: StageColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _importSet(s),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: StageColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StageColors.stroke),
              ),
              child: const Column(
                children: [
                  Icon(Icons.file_download_outlined,
                      color: StageColors.textSecondary, size: 28),
                  SizedBox(height: 8),
                  Text('IMPORT SET',
                      style: TextStyle(
                          color: StageColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(Color accent, AppState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Column(
        children: [
          Icon(Icons.queue_music, size: 56, color: StageColors.stroke),
          const SizedBox(height: 16),
          const Text('No worship sets yet',
              style: TextStyle(color: StageColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Create a set to start building your banks of pads.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StageColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _setCard(WorshipSet set, Color accent, AppState s) {
    final assigned = _countAssigned(set);
    return GestureDetector(
      onTap: () => _openSet(set, s),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StageColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: StageColors.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StageColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Icon(Icons.album, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(set.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: StageColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('$assigned pads assigned · ${_dateLabel(set.updatedAt)}',
                      style: const TextStyle(
                          color: StageColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: StageColors.surfaceRaised,
              icon: const Icon(Icons.more_vert, color: StageColors.textSecondary),
              onSelected: (v) => _onMenu(v, set, s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'export', child: Text('Export set')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Actions ----

  Future<void> _createSet(AppState s) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New worship set'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: StageColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Set name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null) return;
    final set = await s.createSet(name);
    await _openSet(set, s);
  }

  Future<void> _importSet(AppState s) async {
    final set = await s.storageImportSet();
    if (set != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${set.name}"')));
      setState(() {});
    }
  }

  Future<void> _openSet(WorshipSet set, AppState s) async {
    await s.openSet(set);
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => PerformanceScreen(state: s)));
    if (mounted) setState(() {});
  }

  Future<void> _onMenu(String v, WorshipSet set, AppState s) async {
    switch (v) {
      case 'rename':
        final controller = TextEditingController(text: set.name);
        final name = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Rename set'),
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
        if (name != null) {
          await s.renameSet(set, name);
          setState(() {});
        }
        break;
      case 'export':
        final path = await s.storageExportSet(set);
        if (path != null && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Set exported')));
        }
        break;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete set?'),
            content: Text('"${set.name}" will be permanently removed.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: StageColors.danger),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (ok == true) {
          await s.deleteSet(set);
          setState(() {});
        }
        break;
    }
  }

  void _go(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  int _countAssigned(WorshipSet set) {
    var n = 0;
    for (final b in set.banks) {
      for (final g in b.groups) {
        for (final p in g.pads) {
          if (p.isAssigned) n++;
        }
      }
    }
    return n;
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
