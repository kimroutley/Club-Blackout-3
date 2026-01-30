import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/saved_game.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';

/// Material 3 save/load dialog.
class SaveLoadDialog extends StatefulWidget {
  final GameEngine engine;

  const SaveLoadDialog({super.key, required this.engine});

  @override
  State<SaveLoadDialog> createState() => _SaveLoadDialogState();
}

class _SaveLoadDialogState extends State<SaveLoadDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _loading = true;
  List<SavedGame> _saves = const [];
  String? _selectedSaveId;

  static const String _testSaveName = 'Test Game (All Roles)';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final saves = await widget.engine.getSavedGames();
    saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _loading = false;
      _selectedSaveId ??= _saves.isNotEmpty ? _saves.first.id : null;
    });
  }

  Future<void> _save({String? overwriteId}) async {
    final raw = _nameController.text.trim();
    final name = raw.isEmpty ? 'Save ${DateTime.now().toIso8601String()}' : raw;

    await widget.engine.saveGame(name, overwriteId: overwriteId);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    widget.engine.showToast(
      overwriteId == null ? 'Saved "$name"' : 'Overwrote "$name"',
    );
  }

  Future<void> _loadSelected() async {
    final id = _selectedSaveId;
    if (id == null) return;

    final ok = await widget.engine.loadGame(id);
    if (!mounted) return;

    if (!ok) {
      widget.engine.showToast('Load failed (corrupt or missing save).');
      await _refresh();
      return;
    }

    Navigator.of(context).pop(true);
    widget.engine.showToast('Game loaded.');
  }

  Future<void> _deleteSelected() async {
    final id = _selectedSaveId;
    if (id == null) return;

    final cs = Theme.of(context).colorScheme;
    final save = _saves.where((s) => s.id == id).firstOrNull;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return ClubAlertDialog(
          title: Text(
            'Delete save?',
            style: (tt.titleLarge ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Delete "${save?.name ?? 'this save'}"?\n\nThis cannot be undone.',
            style: (tt.bodyMedium ?? const TextStyle()).copyWith(
              color: cs.onSurface.withValues(alpha: 0.9),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.errorContainer,
                foregroundColor: cs.onErrorContainer,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await widget.engine.deleteSavedGame(id);
    if (!mounted) return;
    setState(() => _selectedSaveId = null);
    await _refresh();
    if (!mounted) return;
    widget.engine.showToast('Save deleted.');
  }

  Future<void> _loadTestGame() async {
    if (_loading) return;
    final navigator = Navigator.of(context);
    final cs = Theme.of(context).colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return ClubAlertDialog(
          title: Text(
            'Load test game?',
            style: (tt.titleLarge ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Creates (or overwrites) a test save with one of each role, then loads it.',
            style: (tt.bodyMedium ?? const TextStyle()).copyWith(
              color: cs.onSurface.withValues(alpha: 0.9),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Load'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return ClubAlertDialog(
          content: SizedBox(
            height: 72,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Preparing test game…',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final saves = await widget.engine.getSavedGames();
      final existing = saves.where((s) => s.name == _testSaveName).firstOrNull;

      await widget.engine.createTestGame(fullRoster: true);
      await widget.engine.startGame();
      await widget.engine.saveGame(
        _testSaveName,
        overwriteId: existing?.id,
      );

      String? saveId = existing?.id;
      if (saveId == null) {
        final saves2 = await widget.engine.getSavedGames();
        final created = saves2.where((s) => s.name == _testSaveName).toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
        saveId = created.firstOrNull?.id;
      }

      if (saveId != null) {
        await widget.engine.loadGame(saveId);
      }

      if (!mounted) return;
      navigator.pop();
      await _refresh();
      if (!mounted) return;
      setState(() => _selectedSaveId = saveId);
      navigator.pop(true);
      widget.engine.showToast('Test game loaded.');
    } catch (_) {
      if (!mounted) return;
      navigator.pop();
      widget.engine.showToast('Failed to load test game.');
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final selected = _saves.where((s) => s.id == _selectedSaveId).firstOrNull;

    return ClubAlertDialog(
      title: Row(
        children: [
          Icon(Icons.save_rounded, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Save / load',
              style: (tt.titleLarge ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: ClubBlackoutTheme.inset16,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create a new save or load an existing one.',
                      style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                        color: cs.onSurface.withValues(alpha: 0.9),
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: cs.tertiaryContainer.withValues(alpha: 0.55),
                      child: ListTile(
                        leading: Icon(Icons.science_rounded,
                            color: cs.onTertiaryContainer),
                        title: Text(
                          'Load test game (one of each role)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Creates or overwrites a full roster save.',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _loadTestGame,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Save name',
                        hintText: 'e.g., Night 2 – after vote',
                        prefixIcon: Icon(Icons.edit_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _save(),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Save new'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _selectedSaveId == null
                              ? null
                              : () => _save(overwriteId: _selectedSaveId),
                          icon: const Icon(Icons.save_as_rounded),
                          label: const Text('Overwrite selected'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 16,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved games',
                      style: (tt.titleSmall ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_saves.isEmpty)
                      Text(
                        'No saves yet.',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _saves.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = _saves[index];
                            final isSelected = s.id == _selectedSaveId;
                            return Card(
                              elevation: 0,
                              color: isSelected
                                  ? cs.secondaryContainer
                                      .withValues(alpha: 0.55)
                                  : cs.surfaceContainer,
                              child: ListTile(
                                onTap: () =>
                                    setState(() => _selectedSaveId = s.id),
                                leading: Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? cs.onSecondaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                                title: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  'Day ${s.dayCount} • ${s.alivePlayers}/${s.totalPlayers} alive • ${s.currentPhase}',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.chevron_right_rounded)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    if (selected != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Selected: ${selected.name}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed:
              (_loading || _selectedSaveId == null) ? null : _deleteSelected,
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: const Text('Delete'),
        ),
        FilledButton(
          onPressed:
              (_loading || _selectedSaveId == null) ? null : _loadSelected,
          child: const Text('Load'),
        ),
      ],
    );
  }
}

class _SaveLoadDialogState extends State<SaveLoadDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _loading = true;
  List<SavedGame> _saves = const [];
  String? _selectedSaveId;

  static const String _testSaveName = 'Test Game (All Roles)';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final saves = await widget.engine.getSavedGames();
    // Present newest first, but don’t change stored ordering.
    saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _loading = false;
      _selectedSaveId ??= _saves.isNotEmpty ? _saves.first.id : null;
    });
  }

  Future<void> _save({String? overwriteId}) async {
    final raw = _nameController.text.trim();
    final name = raw.isEmpty ? 'Save ${DateTime.now().toIso8601String()}' : raw;

    await widget.engine.saveGame(name, overwriteId: overwriteId);
    if (!mounted) return;
    await _refresh();

    if (!mounted) return;
    widget.engine.showToast(
      overwriteId == null ? 'Saved "$name"' : 'Overwrote "$name"',
    );
  }

  Future<void> _loadSelected() async {
    final id = _selectedSaveId;
    if (id == null) return;

    final ok = await widget.engine.loadGame(id);
    if (!mounted) return;

    if (!ok) {
      widget.engine.showToast('Load failed (corrupt or missing save).');
      await _refresh();
      return;
    }

    Navigator.of(context).pop(true);
    widget.engine.showToast('Game loaded.');
  }

  Future<void> _deleteSelected() async {
    final id = _selectedSaveId;
    if (id == null) return;

    final save = _saves.where((s) => s.id == id).firstOrNull;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        const accent = ClubBlackoutTheme.neonRed;
        return BulletinDialogShell(
          accent: accent,
          maxWidth: 520,
          title: Text(
            'DELETE SAVE?',
            style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
          ),
          content: Text(
            'Delete "${save?.name ?? 'this save'}"?\n\nThis cannot be undone.',
            style: ClubBlackoutTheme.bulletinBodyStyle(cs.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  foregroundColor: cs.onSurface.withValues(alpha: 0.7)),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ClubBlackoutTheme.neonButtonStyle(accent, isPrimary: true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await widget.engine.deleteSavedGame(id);
    if (!mounted) return;

    setState(() {
      _selectedSaveId = null;
    });
    await _refresh();

    if (!mounted) return;
    widget.engine.showToast('Save deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accent = ClubBlackoutTheme.neonBlue;

    return BulletinDialogShell(
      accent: accent,
      maxWidth: 560,
      maxHeight: 740,
      title: Text(
        'SAVE / LOAD',
        style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
      ),
      showCloseButton: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurface.withValues(alpha: 0.7),
          ),
          child: const Text('CLOSE'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed:
              (_loading || _selectedSaveId == null) ? null : _deleteSelected,
          style: TextButton.styleFrom(
            foregroundColor: ClubBlackoutTheme.neonRed,
          ),
          child: const Text('DELETE'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed:
              (_loading || _selectedSaveId == null) ? null : _loadSelected,
          style: ClubBlackoutTheme.neonButtonStyle(
            ClubBlackoutTheme.neonGreen,
            isPrimary: true,
          ),
          child: const Text('LOAD'),
        ),
      ],
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create a new save or load an existing one.',
                    style: ClubBlackoutTheme.bulletinBodyStyle(cs.onSurface),
                  ),
                  const SizedBox(height: 12),

                  // Always-visible entry: creates/overwrites and loads a named test save.
                  InkWell(
                    onTap: _loading
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);

                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                final cs = Theme.of(ctx).colorScheme;
                                const accent = ClubBlackoutTheme.neonGreen;
                                return BulletinDialogShell(
                                  accent: accent,
                                  maxWidth: 520,
                                  title: Text(
                                    'LOAD TEST GAME?',
                                    style:
                                        ClubBlackoutTheme.bulletinHeaderStyle(
                                            accent),
                                  ),
                                  content: Text(
                                    'Creates (or overwrites) a test save with one of each role, then loads it.',
                                    style: ClubBlackoutTheme.bulletinBodyStyle(
                                        cs.onSurface),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            cs.onSurface.withValues(alpha: 0.7),
                                      ),
                                      child: const Text('CANCEL'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ClubBlackoutTheme.neonButtonStyle(
                                          accent,
                                          isPrimary: true),
                                      child: const Text('LOAD'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm != true) return;
                            if (!context.mounted) return;

                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const BulletinDialogShell(
                                accent: ClubBlackoutTheme.neonBlue,
                                maxWidth: 360,
                                title: SizedBox.shrink(),
                                content: SizedBox(
                                  height: 72,
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ),
                            );

                            try {
                              final saves = await widget.engine.getSavedGames();
                              final existing = saves
                                  .where((s) => s.name == _testSaveName)
                                  .firstOrNull;

                              await widget.engine
                                  .createTestGame(fullRoster: true);
                              await widget.engine.startGame();
                              await widget.engine.saveGame(
                                _testSaveName,
                                overwriteId: existing?.id,
                              );

                              // Prefer the known id (if overwriting), else re-query.
                              String? saveId = existing?.id;
                              if (saveId == null) {
                                final saves2 =
                                    await widget.engine.getSavedGames();
                                final created = saves2
                                    .where((s) => s.name == _testSaveName)
                                    .toList()
                                  ..sort(
                                      (a, b) => b.savedAt.compareTo(a.savedAt));
                                saveId = created.firstOrNull?.id;
                              }

                              if (saveId != null) {
                                await widget.engine.loadGame(saveId);
                              }

                              if (!context.mounted) return;
                              navigator.pop(); // progress dialog
                              await _refresh();
                              if (!context.mounted) return;
                              setState(() => _selectedSaveId = saveId);
                              navigator.pop(true);
                              widget.engine.showToast('Test game loaded.');
                            } catch (_) {
                              if (!context.mounted) return;
                              navigator.pop(); // progress dialog
                              widget.engine
                                  .showToast('Failed to load test game.');
                              await _refresh();
                            }
                          },
                    child: DecoratedBox(
                      decoration: ClubBlackoutTheme.bulletinItemDecoration(
                        color: ClubBlackoutTheme.neonGreen,
                        opacity: 0.10,
                      ),
                      child: Padding(
                        padding: ClubBlackoutTheme.fieldPaddingLoose,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.science_rounded,
                              color: ClubBlackoutTheme.neonGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Load Test Game (one of each role)',
                                style: ClubBlackoutTheme.glowTextStyle(
                                  base: ClubBlackoutTheme.bulletinBodyStyle(
                                      cs.onSurface),
                                  color: ClubBlackoutTheme.neonGreen,
                                  fontWeight: FontWeight.w900,
                                  glowIntensity: 0.8,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: ClubBlackoutTheme.neonGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                    decoration: ClubBlackoutTheme.neonInputDecoration(
                      context,
                      hint: 'e.g., Night 2 – after vote',
                      color: accent,
                      icon: Icons.save_rounded,
                    ).copyWith(
                      labelText: 'Save name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: ClubBlackoutTheme.neonButtonStyle(accent,
                            isPrimary: true),
                        onPressed: () => _save(),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save New'),
                      ),
                      FilledButton.icon(
                        style: ClubBlackoutTheme.neonButtonStyle(
                          ClubBlackoutTheme.neonPurple,
                          isPrimary: false,
                        ),
                        onPressed: _selectedSaveId == null
                            ? null
                            : () => _save(overwriteId: _selectedSaveId),
                        icon: const Icon(Icons.save_as_rounded),
                        label: const Text('Overwrite Selected'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 16,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Saved games',
                    style: ClubBlackoutTheme.bulletinBodyStyle(cs.onSurface)
                        .copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_saves.isEmpty)
                    Text(
                      'No saves yet.',
                      style: ClubBlackoutTheme.bulletinBodyStyle(
                              cs.onSurfaceVariant)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _saves.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = _saves[index];
                          final selected = s.id == _selectedSaveId;

                          return InkWell(
                            onTap: () => setState(() => _selectedSaveId = s.id),
                            child: DecoratedBox(
                              decoration:
                                  ClubBlackoutTheme.bulletinItemDecoration(
                                color: accent,
                                opacity: selected ? 0.16 : 0.10,
                              ),
                              child: Padding(
                                padding: ClubBlackoutTheme.fieldPaddingLoose,
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: selected
                                          ? accent
                                          : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.name,
                                            style: ClubBlackoutTheme
                                                    .bulletinBodyStyle(
                                                        cs.onSurface)
                                                .copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Day ${s.dayCount} • ${s.alivePlayers}/${s.totalPlayers} alive • ${s.currentPhase}',
                                            style: ClubBlackoutTheme
                                                    .bulletinBodyStyle(
                                                        cs.onSurfaceVariant)
                                                .copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            s.savedAt.toLocal().toString(),
                                            style: ClubBlackoutTheme
                                                .bulletinBodyStyle(
                                              cs.onSurfaceVariant
                                                  .withValues(alpha: 0.9),
                                            ).copyWith(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: accent,
                                      ),
                                  ],
                                ),
                              ),
                            ),
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

extension _FirstOrNullX<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
