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
