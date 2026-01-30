import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/game_engine.dart';
import '../../logic/hall_of_fame_service.dart';
import '../../models/player.dart';
import '../styles.dart';
import '../widgets/bulletin_dialog_shell.dart';
import '../widgets/game_toast_listener.dart';
// M3: Removed neon widgets
// import '../widgets/neon_background.dart';
// import '../widgets/neon_page_scaffold.dart';
// import '../widgets/neon_section_header.dart';
import '../widgets/player_tile.dart';
import '../widgets/role_assignment_dialog.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const LobbyScreen({super.key, required this.gameEngine});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TextEditingController _hostController;
  late final FocusNode _nameFocus;
  late final FocusNode _hostFocus;
  final GlobalKey _guestNameFieldKey = GlobalKey();
  OptionsViewOpenDirection _optionsDirection = OptionsViewOpenDirection.down;

  late final AnimationController _notificationController;
  late Animation<Offset> _notificationOffset;
  String? _notificationMessage;
  Color? _notificationColor;

  static const String _quickTestSaveName = 'Quick Test Game';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _hostController =
        TextEditingController(text: widget.gameEngine.hostName ?? '');
    _nameFocus = FocusNode();
    _hostFocus = FocusNode();
    _nameFocus.addListener(() {
      if (_nameFocus.hasFocus) {
        _recomputeAutocompleteDirection();
      }
    });
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _notificationOffset = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _notificationController,
      curve: Curves.elasticOut,
    ));
  }

  void _recomputeAutocompleteDirection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final renderObject =
          _guestNameFieldKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox) return;

      final media = MediaQuery.of(context);
      final screenHeight = media.size.height;
      final keyboard = media.viewInsets.bottom;

      final fieldOffset = renderObject.localToGlobal(Offset.zero);
      final fieldTop = fieldOffset.dy;
      final fieldBottom = fieldOffset.dy + renderObject.size.height;

      final availableDown = screenHeight - keyboard - fieldBottom - 12;
      final availableUp = fieldTop - media.padding.top - 12;

      final next = (availableDown < 180 && availableUp > availableDown)
          ? OptionsViewOpenDirection.up
          : OptionsViewOpenDirection.down;

      if (next != _optionsDirection) {
        setState(() => _optionsDirection = next);
      }
    });
  }

  double _maxAutocompleteOptionsHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    const desired = 260.0;

    final renderObject = _guestNameFieldKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return desired;

    final screenHeight = media.size.height;
    final keyboard = media.viewInsets.bottom;

    final fieldOffset = renderObject.localToGlobal(Offset.zero);
    final fieldTop = fieldOffset.dy;
    final fieldBottom = fieldOffset.dy + renderObject.size.height;

    final availableDown = screenHeight - keyboard - fieldBottom - 12;
    final availableUp = fieldTop - media.padding.top - 12;
    final available = _optionsDirection == OptionsViewOpenDirection.up
        ? availableUp
        : availableDown;

    // Keep it usable but never huge.
    return math.max(120.0, math.min(desired, available));
  }

  @override
  void dispose() {
    _controller.dispose();
    _hostController.dispose();
    _nameFocus.dispose();
    _hostFocus.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  void _showNotification(String msg, {Color? color}) {
    setState(() {
      _notificationMessage = msg;
      _notificationColor = color;
    });
    _notificationController.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _notificationController.reverse();
      }
    });
  }

  void _showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
    Color? accent,
  }) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.surface.withValues(alpha: 0.96),
        content: Text(
          message,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: accent ?? ClubBlackoutTheme.neonBlue,
          onPressed: onUndo,
        ),
      ),
    );
  }

  void _removeGuestWithUndo(GameEngine engine, Player player) {
    final existingIndex = engine.players.indexWhere((p) => p.id == player.id);
    final snapshot = Player.fromJson(player.toJson(), player.role);

    engine.removePlayer(player.id);
    _showUndoSnackBar(
      message: 'Removed "${snapshot.name}".',
      accent: ClubBlackoutTheme.neonRed,
      onUndo: () {
        final ok = engine.restorePlayer(snapshot, index: existingIndex);
        if (!ok) {
          _showNotification(
            'Undo failed: name is already taken.',
            color: ClubBlackoutTheme.neonRed,
          );
          return;
        }

        if (snapshot.role.id == 'host') {
          _hostController.text = engine.hostName ?? '';
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.gameEngine,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final engine = widget.gameEngine;
        final guests = engine.guests.toList();
        final host = engine.hostPlayer;

        // Strict M3 TabBar
        final tabBar = TabBar(
          tabs: const [
            Tab(text: 'Guests'),
            Tab(text: 'Setup'),
          ],
          labelStyle: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
          splashFactory: InkSparkle.splashFactory,
          dividerColor: Colors.transparent,
        );

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(
              title: const Text('Lobby'),
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 3,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: tabBar,
              ),
            ),
            body: SafeArea(
              top: false,
              child: Stack(
                children: [
                  // Main Content
                  TabBarView(
                    children: [
                      _buildGuestsTab(context, cs, engine, guests, host),
                      _buildGameSetupTab(context, cs, engine, guests),
                    ],
                  ),

                  // Overlays
                  GameToastListener(engine: engine),
                  _buildNotificationOverlay(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationOverlay(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (keyboardOpen) return const SizedBox.shrink();
    if (_notificationMessage == null) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _notificationOffset,
        child: Padding(
          padding: ClubBlackoutTheme.rowPadding,
          child: _buildNotificationCard(),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    if (_notificationMessage == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final color = _notificationColor ?? cs.primary;

    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _notificationMessage!,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestsTab(
    BuildContext context,
    ColorScheme cs,
    GameEngine engine,
    List<Player> guests,
    Player? host,
  ) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        if (engine.players.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Tip: press Enter/Done to add fast. You can also paste a list.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_sweep_rounded,
                      color: cs.error, size: 24),
                  onPressed: () => _showClearAllConfirm(context, engine),
                  tooltip: 'Clear guest list',
                ),
              ],
            ),
          ),
        Expanded(
          child: keyboardOpen
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _notificationMessage == null
                        ? Text(
                            'Guest list hidden while typing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.55),
                              letterSpacing: 1.1,
                            ),
                          )
                        : SlideTransition(
                            position: _notificationOffset,
                            child: _buildNotificationCard(),
                          ),
                  ),
                )
              : (guests.isEmpty && host == null)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined,
                              size: 64, color: cs.surfaceContainerHigh),
                          const SizedBox(height: 16),
                          Text(
                            'Add at least 4 guests to start.',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: guests.length + (host == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        final isHostRow = host != null && index == 0;
                        final guestOffset = host == null ? 0 : 1;

                        if (isHostRow) {
                          final player = host;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: ClubBlackoutTheme.neonFrame(
                              color: cs.primary,
                              opacity: 0.5,
                              borderRadius: 12,
                              borderWidth: 1.0,
                              showGlow: false,
                            ),
                            child: PlayerTile(
                              player: player,
                              gameEngine: engine,
                              isCompact: true,
                              subtitleOverride: 'Host',
                              showEffectChips: false,
                              wrapInCard: false,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 20),
                                    onPressed: () async {
                                      await _renameGuest(context, player);
                                      if (!mounted) return;
                                      _hostController.text =
                                          engine.hostName ?? '';
                                    },
                                    tooltip: 'Rename Host',
                                    color: cs.onSurfaceVariant,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 20),
                                    onPressed: () {
                                      final prev = engine.hostName;
                                      engine.setHostName('');
                                      _hostController.clear();
                                      if (prev != null && prev.isNotEmpty) {
                                        _showUndoSnackBar(
                                          message: 'Host cleared.',
                                          accent: cs.primary,
                                          onUndo: () {
                                            try {
                                              engine.setHostName(prev);
                                              _hostController.text =
                                                  engine.hostName ?? '';
                                            } catch (_) {
                                              _showNotification(
                                                'Undo failed: name is already taken.',
                                                color: cs.error,
                                              );
                                            }
                                          },
                                        );
                                      } else {
                                        _showNotification('Host cleared.',
                                            color: cs.primary);
                                      }
                                    },
                                    tooltip: 'Clear Host',
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final player = guests[index - guestOffset];

                        return Dismissible(
                          key: Key(player.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) =>
                              _removeGuestWithUndo(engine, player),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_rounded,
                              color: cs.onErrorContainer,
                            ),
                          ),
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerLow,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            child: PlayerTile(
                              player: player,
                              gameEngine: engine,
                              isCompact: true,
                              subtitleOverride: player.role.id == 'temp'
                                  ? 'Awaiting assignment'
                                  : player.role.name,
                              showEffectChips: false,
                              wrapInCard: false,
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                onPressed: () => _renameGuest(context, player),
                                tooltip: 'Rename Guest',
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // Input Area
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHostNameRow(context),
                const SizedBox(height: 16),
                _buildAddPlayerRow(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHostNameRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _hostController,
            focusNode: _hostFocus,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              labelText: 'Host Name',
              hintText: 'Enter name',
              prefixIcon: const Icon(Icons.person_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: cs.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (val) => _setHostName(context, val),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: () => _setHostName(context, _hostController.text),
          icon: const Icon(Icons.check),
          tooltip: 'Set host name',
        ),
      ],
    );
  }

  void _setHostName(BuildContext context, String raw) {
    try {
      final prev = widget.gameEngine.hostName;
      widget.gameEngine.setHostName(raw);
      final name = widget.gameEngine.hostName;
      _hostController.text = name ?? '';

      // Offer undo for set/clear changes.
      final changed = (prev ?? '') != (name ?? '');
      if (changed) {
        widget.gameEngine.showToast(
          name == null ? 'Host cleared.' : 'Host set to $name.',
          title: 'Host',
          actionLabel: 'UNDO',
          onAction: () {
            try {
              widget.gameEngine.setHostName(prev ?? '');
              _hostController.text = widget.gameEngine.hostName ?? '';
            } catch (_) {
              widget.gameEngine
                  .showToast('Undo failed: name is already taken.');
            }
          },
        );
      } else {
        widget.gameEngine.showToast(
          name == null ? 'Host cleared.' : 'Host set to $name.',
          title: 'Host',
        );
      }
      _hostFocus.unfocus();
    } catch (e) {
      var msg = e.toString();
      msg = msg.replaceFirst(RegExp(r'^.*Exception: '), '');
      msg = msg.replaceFirst(RegExp(r'^.*ArgumentError: '), '');
      widget.gameEngine.showToast(msg);
    }
  }

  Widget _buildGameSetupTab(
    BuildContext context,
    ColorScheme cs,
    GameEngine engine,
    List<Player> players,
  ) {
    const showTestTools = kDebugMode || bool.fromEnvironment('SHOW_TEST_GAME');

    return Column(
      children: [
        // Top Card: Main Action & Info
        Card(
          elevation: 2,
          color: cs.surfaceContainerHigh,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info from Setup Tab
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Minimum 4+ guests. ${players.length} added.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Button
                FilledButton.icon(
                  onPressed: players.length < 4
                      ? null
                      : () => _showRoleAssignment(context),
                  label: const Text('ASSIGN ROLES & START'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Middle: Player List (Expanded)
        Expanded(
          child: Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: players.isEmpty
                ? Center(
                    child: Text(
                      'Add guests first.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = players[index];
                      return Card(
                        elevation: 0,
                        color: cs.surface,
                        margin: EdgeInsets.zero,
                        child: PlayerTile(
                          player: p,
                          gameEngine: engine,
                          isCompact: true,
                          subtitleOverride: p.role.id == 'temp'
                              ? 'Awaiting assignment'
                              : p.role.name,
                          showEffectChips: false,
                          wrapInCard: false,
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Bottom: Test Tools (if enabled)
        if (showTestTools) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Text('DEBUG TOOLS',
                    style: TextStyle(color: cs.onSurface, fontSize: 10)),
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: () =>
                          _loadOrCreateQuickTestGame(context, recreate: false),
                      child: const Text('Load')),
                  TextButton(
                      onPressed: () =>
                          _loadOrCreateQuickTestGame(context, recreate: true),
                      child: const Text('Reset')),
                ])
              ]),
            ),
          ),
        ],

        SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
      ],
    );
  }

  Future<void> _renameGuest(BuildContext context, Player player) async {
    final controller = TextEditingController(text: player.name);
    final cs = Theme.of(context).colorScheme;
    final prevName = player.name;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        const accent = ClubBlackoutTheme.neonPink;
        return BulletinDialogShell(
          accent: accent,
          maxWidth: 520,
          title: Text(
            'RENAME GUEST',
            style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: cs.onSurface),
            decoration: ClubBlackoutTheme.neonInputDecoration(
              context,
              hint: 'Enter new name',
              color: accent,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.7),
              ),
              child: const Text('CANCEL'),
            ),
            ClubBlackoutTheme.hGap8,
            FilledButton(
              style: ClubBlackoutTheme.neonButtonStyle(
                accent,
                isPrimary: true,
              ),
              onPressed: () {
                try {
                  widget.gameEngine.renamePlayer(player.id, controller.text);
                  Navigator.pop(ctx);

                  final nextName = controller.text.trim();
                  if (nextName.isNotEmpty && nextName != prevName) {
                    _showUndoSnackBar(
                      message: 'Renamed "$prevName" to "$nextName".',
                      accent: accent,
                      onUndo: () {
                        try {
                          widget.gameEngine.renamePlayer(player.id, prevName);
                          if (player.role.id == 'host') {
                            _hostController.text =
                                widget.gameEngine.hostName ?? '';
                          }
                        } catch (_) {
                          _showNotification(
                            'Undo failed: name is already taken.',
                            color: ClubBlackoutTheme.neonRed,
                          );
                        }
                      },
                    );
                  } else {
                    _showNotification('Guest renamed to "$nextName"');
                  }
                } catch (e) {
                  _showNotification(
                    e
                        .toString()
                        .replaceFirst('Exception: ', '')
                        .replaceFirst('ArgumentError: ', ''),
                    color: ClubBlackoutTheme.neonRed,
                  );
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadOrCreateQuickTestGame(
    BuildContext context, {
    required bool recreate,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        const accent = ClubBlackoutTheme.neonOrange;
        return BulletinDialogShell(
          accent: accent,
          maxWidth: 560,
          title: Text(
            recreate ? 'RECREATE TEST' : 'LOAD TEST',
            style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
          ),
          content: Text(
            recreate
                ? 'This will overwrite the "$_quickTestSaveName" save with a fresh deterministic game and jump into gameplay.'
                : 'This will load the "$_quickTestSaveName" save (or create it if missing) and jump into gameplay.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.7),
              ),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: ClubBlackoutTheme.neonButtonStyle(accent, isPrimary: true),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('CONTINUE'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    bool ok = true;
    Object? error;

    await _runBlockingProgressDialog(context, () async {
      final engine = widget.gameEngine;
      final saves = await engine.getSavedGames();
      saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      final existing =
          saves.where((s) => s.name == _quickTestSaveName).firstOrNull;

      if (!recreate && existing != null) {
        ok = await engine.loadGame(existing.id);
        if (!ok) {
          throw StateError('Failed to load quick test save.');
        }
        return;
      }

      // Create a fresh deterministic game, start it, and persist it as a single slot.
      await engine.createTestGame(fullRoster: false);
      await engine.startGame();
      await engine.saveGame(_quickTestSaveName, overwriteId: existing?.id);
    }).catchError((e) {
      ok = false;
      error = e;
    });

    if (!context.mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
            content:
                Text('Could not load test game: ${error ?? 'Unknown error'}')),
      );
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(
          builder: (_) => GameScreen(gameEngine: widget.gameEngine)),
    );
  }

  Future<void> _runBlockingProgressDialog(
    BuildContext context,
    Future<void> Function() op,
  ) async {
    if (!context.mounted) return;

    final navigator = Navigator.of(context);

    // Show themed progress dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: ClubBlackoutTheme.neonFrame(
                color: ClubBlackoutTheme.neonPink,
                opacity: 0.9,
                showGlow: true,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      color: ClubBlackoutTheme.neonPink,
                      strokeWidth: 3,
                    ),
                  ),
                  ClubBlackoutTheme.gap24,
                  Text(
                    'Processing',
                    style: ClubBlackoutTheme.glowTextStyle(
                      base: ClubBlackoutTheme.headingStyle,
                      color: ClubBlackoutTheme.neonPink,
                      fontSize: 22,
                    ),
                  ),
                  ClubBlackoutTheme.gap8,
                  Text(
                    'Please wait',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 2,
                      fontSize: 12,
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
      await op();
    } finally {
      if (mounted) {
        navigator.pop();
      }
    }
  }

  Widget _buildAddPlayerRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Autocomplete<String>(
                optionsViewOpenDirection: _optionsDirection,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return HallOfFameService.instance.allProfiles
                      .map((p) => p.name)
                      .where((name) => name
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (String selection) {
                  _addGuestsFromText(context, selection);
                },
                optionsViewBuilder: (context, onSelected, options) {
                  _recomputeAutocompleteDirection();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      color: cs.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: _maxAutocompleteOptionsHeight(context),
                        ),
                        child: Container(
                          width: constraints.maxWidth,
                          margin: const EdgeInsets.only(top: 4),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                leading: Icon(Icons.history, color: cs.primary),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  controller.addListener(() {
                    if (_controller.text != controller.text) {
                      _controller.text = controller.text;
                    }
                  });
                  _controller.addListener(() {
                    if (controller.text != _controller.text) {
                      controller.text = _controller.text;
                    }
                  });

                  return TextField(
                    key: _guestNameFieldKey,
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(
                      color: cs.onSurface,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Add Guest',
                      hintText: 'Enter name',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      prefixIcon: const Icon(Icons.person_add),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () =>
                            _addGuestsFromText(context, controller.text),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (val) {
                      _addGuestsFromText(context, val);
                    },
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Add from History',
          onPressed: () => _showSavedPlayersPicker(context),
          icon: const Icon(Icons.history_edu_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: 'Paste list',
          icon: const Icon(Icons.content_paste_rounded),
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text ?? '';
            if (!context.mounted) return;
            _addGuestsFromText(context, text);
          },
        ),
      ],
    );
  }

  void _addGuestsFromText(BuildContext context, String raw) {
    final names = _parseGuestNames(raw);
    if (names.isEmpty) {
      _nameFocus.requestFocus();
      return;
    }

    var added = 0;
    var skipped = 0;
    String? lastError;

    for (final name in names) {
      try {
        widget.gameEngine.addPlayer(name);
        added++;
      } catch (e) {
        skipped++;
        lastError = e.toString();
        // Remove 'Exception: ' or 'ArgumentError: ' prefix if present
        lastError = lastError.replaceFirst(RegExp(r'^.*Exception: '), '');
        lastError = lastError.replaceFirst(RegExp(r'^.*ArgumentError: '), '');
      }
    }

    _controller.clear();
    _nameFocus.requestFocus();

    String msg;
    if (added > 0 && skipped == 0) {
      if (names.length == 1) {
        msg = 'Guest "${names.first}" added.';
      } else {
        msg = 'Added $added guests.';
      }
    } else if (added > 0 && skipped > 0) {
      msg = 'Added $added, skipped $skipped duplicates.';
    } else {
      msg = skipped == 1 && lastError != null ? lastError : 'No guests added.';
    }

    _showNotification(msg,
        color: skipped > 0
            ? ClubBlackoutTheme.neonRed
            : ClubBlackoutTheme.neonPink);
  }

  List<String> _parseGuestNames(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return const [];

    // If the user pasted (Name) (Name) (Name), treat parenthesis groups as items.
    final parenMatches = RegExp(r'\(([^)]+)\)')
        .allMatches(input)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parenMatches.length >= 2) return parenMatches;

    var normalized = input.replaceAll('\r\n', '\n');

    // Bullets / dot bullets
    normalized = normalized.replaceAll(RegExp(r'[•·\u2022\u00b7]+'), '\n');

    // Common separators
    normalized = normalized.replaceAll(RegExp(r'[,;|/]+'), '\n');

    // Brackets/parentheses as separators
    normalized = normalized.replaceAll(RegExp(r'[\[\](){}]'), '\n');

    // "dot form" like: John. Mary. Alex
    if (RegExp(r'\.[ \t]+').hasMatch(normalized)) {
      final segs = normalized.split(RegExp(r'\.[ \t]+'));
      if (segs.length >= 2) normalized = segs.join('\n');
    } else if (normalized.contains('.') &&
        !normalized.contains('\n') &&
        normalized.split('.').length >= 3) {
      // Also handle: John.Mary.Alex
      normalized = normalized.split('.').join('\n');
    }

    final parts = normalized.split('\n');
    final out = <String>[];
    for (var part in parts) {
      var s = part.trim();
      if (s.isEmpty) continue;

      // Strip common list prefixes: "- ", "* ", "1)", "1."
      s = s.replaceFirst(RegExp(r'^(?:[-*]+\s+|\d+[.)]\s*)'), '').trim();
      if (s.isEmpty) continue;

      out.add(s);
    }

    return out;
  }

  void _showSavedPlayersPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final selected = <String>{};
        final cs = Theme.of(ctx).colorScheme;

        return StatefulBuilder(builder: (ctx, setState) {
          return ListenableBuilder(
            listenable: Listenable.merge([
              HallOfFameService.instance,
              widget.gameEngine,
            ]),
            builder: (ctx, _) {
              final profiles = HallOfFameService.instance.allProfiles;
              final profileNameSet = profiles
                  .map((p) => p.name.trim().toLowerCase())
                  .where((n) => n.isNotEmpty)
                  .toSet();

              final recentNames = widget.gameEngine.nameHistory
                  .where((n) => n.trim().isNotEmpty)
                  .map((n) => n.trim())
                  .where((n) => !profileNameSet.contains(n.toLowerCase()))
                  .toList(growable: false)
                  .reversed
                  .take(50)
                  .toList(growable: false);

              return BulletinDialogShell(
                accent: ClubBlackoutTheme.neonBlue,
                maxWidth: 560,
                title: Text(
                  'INVITE LIST',
                  style: ClubBlackoutTheme.bulletinHeaderStyle(
                      ClubBlackoutTheme.neonBlue),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 400,
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 8, bottom: 8),
                        child: Text(
                          'HALL OF FAME',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (profiles.isEmpty)
                        Padding(
                          padding: ClubBlackoutTheme.rowPadding,
                          child: Text(
                            'No Hall of Fame entries yet.\nComplete a game to start building stats.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.54)),
                          ),
                        )
                      else
                        ...profiles.map((p) {
                          final normalizedName = p.name.trim().toLowerCase();
                          final alreadyIn = widget.gameEngine.players.any((x) =>
                              x.name.trim().toLowerCase() == normalizedName);
                          final isSelected = selected.contains(p.name);

                          return CheckboxListTile(
                            title: Text(
                              p.name,
                              style: TextStyle(
                                color: alreadyIn
                                    ? cs.onSurface.withValues(alpha: 0.3)
                                    : cs.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              '${p.totalGames} games • ${(p.winRate * 100).toStringAsFixed(0)}% wins',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                            value: isSelected || alreadyIn,
                            activeColor: ClubBlackoutTheme.neonBlue,
                            checkColor: cs.surface,
                            onChanged: alreadyIn
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        selected.add(p.name);
                                      } else {
                                        selected.remove(p.name);
                                      }
                                    });
                                  },
                          );
                        }),
                      Padding(
                        padding: ClubBlackoutTheme.rowPadding,
                        child: Divider(
                            color: cs.onSurface.withValues(alpha: 0.15)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 8),
                        child: Text(
                          'RECENT NAMES',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (recentNames.isEmpty)
                        Padding(
                          padding: ClubBlackoutTheme.rowPadding,
                          child: Text(
                            'No recent names yet.\nAdd guests to build a quick-pick list.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.54)),
                          ),
                        )
                      else
                        ...recentNames.map((name) {
                          final normalizedName = name.trim().toLowerCase();
                          final alreadyIn = widget.gameEngine.players.any((x) =>
                              x.name.trim().toLowerCase() == normalizedName);
                          final isSelected = selected.contains(name);

                          return CheckboxListTile(
                            title: Text(
                              name,
                              style: TextStyle(
                                color: alreadyIn
                                    ? cs.onSurface.withValues(alpha: 0.3)
                                    : cs.onSurface,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              'Recent',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                            value: isSelected || alreadyIn,
                            activeColor: ClubBlackoutTheme.neonBlue,
                            checkColor: cs.surface,
                            onChanged: alreadyIn
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        selected.add(name);
                                      } else {
                                        selected.remove(name);
                                      }
                                    });
                                  },
                          );
                        }),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: ClubBlackoutTheme.neonButtonStyle(
                      ClubBlackoutTheme.neonBlue,
                      isPrimary: true,
                    ),
                    onPressed: () {
                      for (final name in selected) {
                        widget.gameEngine.addPlayer(name);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text('ADD CHECKED (${selected.length})'),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  void _showClearAllConfirm(BuildContext context, GameEngine engine) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        const accent = ClubBlackoutTheme.neonRed;
        return BulletinDialogShell(
          accent: accent,
          maxWidth: 520,
          title: Text(
            'CLEAR GUESTS?',
            style: ClubBlackoutTheme.bulletinHeaderStyle(accent),
          ),
          content: Text(
            'This will remove everyone from the guest list. Are you sure?',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.7),
              ),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: ClubBlackoutTheme.neonButtonStyle(
                accent,
                isPrimary: true,
              ),
              onPressed: () {
                final snapshot = engine.players
                    .map((p) => Player.fromJson(p.toJson(), p.role))
                    .toList(growable: false);
                engine.clearAllPlayers();
                Navigator.pop(ctx);

                if (snapshot.isNotEmpty) {
                  _showUndoSnackBar(
                    message: 'Guest list cleared.',
                    accent: accent,
                    onUndo: () {
                      final ok = engine.restoreAllPlayers(snapshot);
                      if (!ok) {
                        _showNotification(
                          'Undo failed: roster has changed.',
                          color: ClubBlackoutTheme.neonRed,
                        );
                      } else {
                        _hostController.text = engine.hostName ?? '';
                      }
                    },
                  );
                }
              },
              child: const Text('CLEAR ALL'),
            ),
          ],
        );
      },
    );
  }

  void _showRoleAssignment(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => RoleAssignmentDialog(
        gameEngine: widget.gameEngine,
        players: widget.gameEngine.guests.toList(),
        onConfirm: () async {
          await widget.gameEngine.startGame();
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => GameScreen(gameEngine: widget.gameEngine)),
            );
          }
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}
