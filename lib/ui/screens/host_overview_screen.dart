import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/ai_exporter.dart';
import '../../logic/game_dashboard_stats.dart';
import '../../logic/game_engine.dart';
import '../../logic/game_odds.dart';
import '../../logic/games_night_service.dart';
import '../../logic/host_insights.dart';
import '../../logic/live_game_stats.dart';
import '../../logic/monte_carlo_simulator.dart';
import '../../logic/story_exporter.dart';
import '../../logic/voting_insights.dart';
import '../../models/game_log_entry.dart';
import '../../models/player.dart';
import '../screens/game_screen.dart';
import '../screens/games_night_screen.dart';
import '../styles.dart';
import '../utils/export_file_service.dart';
import '../widgets/club_alert_dialog.dart';
import '../widgets/drama_queen_swap_dialog.dart';
import '../widgets/game_drawer.dart';
import '../widgets/game_toast_listener.dart';
import '../widgets/host_alert_listener.dart';
import '../widgets/host_player_status_card.dart';

class HostOverviewScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const HostOverviewScreen({super.key, required this.gameEngine});

  @override
  State<HostOverviewScreen> createState() => _HostOverviewScreenState();
}

class _HostOverviewScreenState extends State<HostOverviewScreen> {
  GameEngine get gameEngine => widget.gameEngine;

  Timer? _oddsDebounce;
  int? _lastRequestedOddsSignature;
  int? _lastCompletedOddsSignature;
  bool _oddsSimRunning = false;
  GameOddsSnapshot? _simulatedOdds;
  DateTime? _simulatedOddsUpdatedAt;

  @override
  void initState() {
    super.initState();
    gameEngine.addListener(_onEngineChanged);
    // Kick off an initial compute shortly after first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleOddsUpdate());
  }

  @override
  void didUpdateWidget(covariant HostOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameEngine != widget.gameEngine) {
      oldWidget.gameEngine.removeListener(_onEngineChanged);
      widget.gameEngine.addListener(_onEngineChanged);
      _lastRequestedOddsSignature = null;
      _lastCompletedOddsSignature = null;
      _simulatedOdds = null;
      _simulatedOddsUpdatedAt = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleOddsUpdate());
    }
  }

  @override
  void dispose() {
    _oddsDebounce?.cancel();
    gameEngine.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    _scheduleOddsUpdate();
  }

  void _scheduleOddsUpdate() {
    if (!mounted) return;
    _oddsDebounce?.cancel();
    _oddsDebounce = Timer(const Duration(milliseconds: 650), _maybeRunOddsSimulation);
  }

  int _engineOddsSignature(GameEngine engine) {
    final players = engine.players
        .where((p) => p.isEnabled && p.role.id != 'host')
        .map((p) => Object.hash(
              p.id,
              p.role.id,
              p.isAlive,
              p.soberSentHome,
              p.silencedDay,
              p.alibiDay,
              p.hasRumour,
            ))
        .toList(growable: false);

    // Votes are high-signal for odds; include the tallied map defensively.
    final votes = engine.eligibleDayVotesByTarget.entries
        .map((e) => Object.hash(e.key, Object.hashAll(e.value)))
        .toList(growable: false);

    return Object.hash(
      engine.dayCount,
      engine.currentPhase.index,
      engine.currentScriptIndex,
      engine.scriptQueue.length,
      Object.hashAll(players),
      Object.hashAll(votes),
    );
  }

  Future<void> _maybeRunOddsSimulation() async {
    if (!mounted) return;

    // If the game is already over, simulated odds are trivial.
    final end = gameEngine.checkGameEnd();
    if (end != null) {
      setState(() {
        _oddsSimRunning = false;
        _lastRequestedOddsSignature = null;
        _lastCompletedOddsSignature = null;
        _simulatedOddsUpdatedAt = DateTime.now();
        _simulatedOdds = GameOddsSnapshot(
          odds: {end.winner: 1.0},
          note: 'Game is already over.',
        );
      });
      return;
    }

    final signature = _engineOddsSignature(gameEngine);
    _lastRequestedOddsSignature = signature;

    // Avoid rerunning if we already have results for the current state.
    if (_lastCompletedOddsSignature == signature) return;
    if (_oddsSimRunning) return;

    setState(() {
      _oddsSimRunning = true;
    });

    try {
      final res = await MonteCarloSimulator.simulateWinOdds(
        gameEngine,
        runs: 100,
        seed: signature,
        // Keep this high enough to finish typical games, low enough to avoid stalls.
        maxStepsPerRun: 20000,
      );

      if (!mounted) return;

      final completed = res.completed;
      final odds = res.odds;

      setState(() {
        _lastCompletedOddsSignature = signature;
        _simulatedOddsUpdatedAt = DateTime.now();
        _simulatedOdds = GameOddsSnapshot(
          odds: odds,
          note: completed <= 0
              ? 'Simulated odds unavailable (0 completed runs).'
              : 'Simulated odds from 100 runs (completed $completed). Auto-updates as the game changes.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _oddsSimRunning = false;
        });

        // If the engine changed while we were simulating, immediately queue another run.
        final latestSignature = _engineOddsSignature(gameEngine);
        if (_lastRequestedOddsSignature != null &&
            latestSignature != _lastCompletedOddsSignature) {
          _scheduleOddsUpdate();
        }
      }
    }
  }

  void _handleDrawerNavigation(int index) {
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GamesNightScreen(gameEngine: gameEngine)),
      );
      return;
    }

    // For other navigation (Home, Lobby, Guides), we need to confirm quitting the game.
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        const accent = ClubBlackoutTheme.neonRed;

        return ClubAlertDialog(
          title: const Text('Quit game?'),
          content: Text(
            'Navigating away will end the current game session. Progress will be lost unless saved.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: FilledButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.18),
                foregroundColor: cs.onSurface,
              ),
              child: const Text('Quit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gameEngine, GamesNightService.instance]),
      builder: (context, _) {
        final insights = HostInsightsSnapshot.fromEngine(gameEngine);
        final stats = insights.stats;
        final dashboard = insights.dashboard;

        return _buildNightM3Scaffold(
          context: context,
          engine: gameEngine,
          stats: stats,
          dashboard: dashboard,
        );
      },
    );
  }

  Widget _buildNightM3Scaffold({
    required BuildContext context,
    required GameEngine engine,
    required LiveGameStats stats,
    required dynamic dashboard,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      drawer: GameDrawer(
        gameEngine: engine,
        onContinueGameTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameScreen(gameEngine: engine),
            ),
          );
        },
        onNavigate: _handleDrawerNavigation,
        selectedIndex: -1,
      ),
      appBar: AppBar(
        title: const Text('Host Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Copy Story Snapshot JSON',
            onPressed: () => _copyStorySnapshotJson(context),
            icon: const Icon(Icons.content_copy_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _buildHostTabs(context),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOverviewTab(context, engine, stats, dashboard),
                      _buildStatsTab(context, engine, dashboard),
                      _buildPlayersTab(context, engine),
                    ],
                  ),
                ),
              ],
            ),
          ),
          HostAlertListener(engine: engine),
          GameToastListener(engine: engine),
        ],
      ),
    );
  }

  Widget _buildHostTabs(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainer,
      child: const TabBar(
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Stats'),
          Tab(text: 'Players'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    GameEngine engine,
    dynamic stats,
    dynamic dashboard,
  ) {
    final baseOdds = dashboard.odds as GameOddsSnapshot;
    final odds = _simulatedOdds ?? baseOdds;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDashboardIntroCard(context),
        const SizedBox(height: 16),
        _buildSummaryGrid(context, stats),
        const SizedBox(height: 16),
        Text('Win odds & predictability',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildPredictabilityCard(context, odds),
        const SizedBox(height: 8),
        _buildOddsCard(context, odds, isUpdating: _oddsSimRunning, updatedAt: _simulatedOddsUpdatedAt),
        const SizedBox(height: 16),
        Text('Recent events', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildRecentEventsCard(context, engine.gameLog),
        const SizedBox(height: 16),
        Text('Morning summary', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              (engine.lastNightHostRecap.isNotEmpty
                      ? engine.lastNightHostRecap
                      : engine.lastNightSummary)
                  .trim(),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(BuildContext context, GameEngine engine, dynamic dashboard) {
    final voting = dashboard.voting as VotingInsights;
    return _HostStatsTab(
      engine: engine,
      dashboard: dashboard,
      voting: voting,
      buildVotingHighlightsCard: _buildVotingHighlightsCard,
      buildVotingCard: _buildVotingCard,
      buildRoleChipsCard: (ctx) => _buildRoleChipsCard(ctx, dashboard),
      buildHostToolsCard: (ctx) => _buildHostToolsCard(ctx, engine),
      buildAiExportCard: (ctx) => _buildAiExportCard(ctx, engine),
    );
  }

  Widget _buildPlayersTab(BuildContext context, GameEngine engine) {
    return _HostPlayersTab(engine: engine);
  }

  Widget _buildSummaryGrid(BuildContext context, dynamic stats) {
    final s = stats as LiveGameStats;
    final cs = Theme.of(context).colorScheme;

    Widget tile(String label, String value, Color color) {
      return Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.25,
      children: [
        tile('PLAYERS', s.totalPlayers.toString(), cs.primary),
        tile('ALIVE', s.aliveCount.toString(), ClubBlackoutTheme.neonGreen),
        tile('DEAD', s.deadCount.toString(), ClubBlackoutTheme.neonRed),
        tile('DEALERS', s.dealerAliveCount.toString(), ClubBlackoutTheme.neonRed),
        tile('PARTY', s.partyAliveCount.toString(), ClubBlackoutTheme.neonBlue),
        tile('NEUTRAL', s.neutralAliveCount.toString(), ClubBlackoutTheme.neonPurple),
      ],
    );
  }

  Widget _buildRecentEventsCard(BuildContext context, List<GameLogEntry> entries) {
    final rows = entries
        .where((e) => e.type != GameLogType.script)
        .take(5)
        .toList(growable: false);

    if (rows.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No events yet.')));
    }

    return Card(
      child: Column(
        children: rows.map((e) => ListTile(
          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          dense: true,
        )).toList(),
      ),
    );
  }

  Widget _buildVotingCard(BuildContext context, VotingInsights voting) {
    final cs = Theme.of(context).colorScheme;
    final breakdown = voting.currentBreakdown;

    if (breakdown.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No votes recorded.')));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current votes', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            for (final row in breakdown) ...[
              Row(
                children: [
                  Expanded(child: Text(row.targetName, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Text(row.voteCount.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (row.voterNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    row.voterNames.join(' · '),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChipsCard(BuildContext context, dynamic dashboard) {
    final chips = (dashboard as GameDashboardStats).roleChips;

    if (chips.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in chips)
              Chip(
                label: Text('${c.roleName} (${c.aliveCount})'),
                backgroundColor: c.color.withValues(alpha: 0.1),
                side: BorderSide(color: c.color.withValues(alpha: 0.3)),
                labelStyle: TextStyle(color: c.color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiExportCard(BuildContext context, GameEngine engine) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('AI Export', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            const Text('Export game state for analysis or commentary generation.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _copyAiGameStatsJson(context, engine),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Stats JSON'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _copyAiStoryExportJson(context, engine),
                  icon: const Icon(Icons.auto_stories),
                  label: const Text('Copy Story JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAiStoryExportJson(BuildContext context, GameEngine engine) async {
    final export = buildAiStoryExport(engine, minWords: 250, maxWords: 450);
    final jsonText = const JsonEncoder.withIndent('  ').convert(export);
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!context.mounted) return;
    gameEngine.showToast('Copied AI Recap Export JSON', title: 'Success');
  }

  Future<void> _copyStorySnapshotJson(BuildContext context) async {
    final snapshot = gameEngine.exportStorySnapshot();
    final jsonText = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!context.mounted) return;
    gameEngine.showToast('Copied story snapshot JSON', title: 'Success');
  }

  Future<AiCommentaryStyle?> _pickAiStyle(
    BuildContext context, {
    AiCommentaryStyle initial = AiCommentaryStyle.pg,
    String title = 'Select Commentary Style',
  }) async {
    return showDialog<AiCommentaryStyle>(
      context: context,
      builder: (ctx) {
        AiCommentaryStyle selected = initial;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return ClubAlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: AiCommentaryStyle.values.map((s) {
                  return RadioListTile<AiCommentaryStyle>(
                    title: Text(s.label),
                    value: s,
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v!),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _copyAiGameStatsJson(BuildContext context, GameEngine engine) async {
    final export = buildAiGameStatsExport(engine);
    final jsonText = const JsonEncoder.withIndent('  ').convert(export);
    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!context.mounted) return;
    gameEngine.showToast('Copied AI Game Stats JSON', title: 'Success');
  }

  Future<void> _openExportsFolder(BuildContext context, GameEngine engine) async {
    try {
      await ExportFileService.openExportsFolder();
      if (!context.mounted) return;
      engine.showToast('Opened exports folder.');
    } catch (_) {
      if (!context.mounted) return;
      engine.showToast('Unable to open exports folder on this platform.');
    }
  }

  
}

typedef _SimpleContextWidgetBuilder = Widget Function(BuildContext context);

class _HostStatsTab extends StatelessWidget {
  final GameEngine engine;
  final dynamic dashboard;
  final VotingInsights voting;

  final Widget Function(BuildContext context, VotingInsights voting) buildVotingHighlightsCard;
  final Widget Function(BuildContext context, VotingInsights voting) buildVotingCard;
  final _SimpleContextWidgetBuilder buildRoleChipsCard;
  final _SimpleContextWidgetBuilder buildHostToolsCard;
  final _SimpleContextWidgetBuilder buildAiExportCard;

  const _HostStatsTab({
    required this.engine,
    required this.dashboard,
    required this.voting,
    required this.buildVotingHighlightsCard,
    required this.buildVotingCard,
    required this.buildRoleChipsCard,
    required this.buildHostToolsCard,
    required this.buildAiExportCard,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        buildVotingHighlightsCard(context, voting),
        const SizedBox(height: 16),
        buildVotingCard(context, voting),
        const SizedBox(height: 16),
        buildRoleChipsCard(context),
        const SizedBox(height: 16),
        buildHostToolsCard(context),
        const SizedBox(height: 16),
        buildAiExportCard(context),
      ],
    );
  }
}


class _DramaQueenSwapPanel extends StatelessWidget {
  final GameEngine gameEngine;
  const _DramaQueenSwapPanel({required this.gameEngine});

  void _showSwapDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DramaQueenSwapDialog(
        gameEngine: gameEngine,
        onConfirm: (a, b) {
          gameEngine.completeDramaQueenSwap(a, b);
          gameEngine.showToast('Swap completed.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Drama Queen Swap Pending', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 8),
            const Text('The Drama Queen has died and must swap two players\' roles.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.swap_calls),
              label: const Text('Select Players'),
              onPressed: () => _showSwapDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredatorRetaliationPanel extends StatefulWidget {
  final GameEngine gameEngine;
  const _PredatorRetaliationPanel({required this.gameEngine});

  @override
  State<_PredatorRetaliationPanel> createState() =>
      _PredatorRetaliationPanelState();
}

class _PredatorRetaliationPanelState extends State<_PredatorRetaliationPanel> {
  String? _target;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final engine = widget.gameEngine;
    final alive = engine.guests.where((p) => p.isAlive && p.isEnabled).toList();

    final predatorId = engine.pendingPredatorId;
    final baseCandidates = predatorId == null
      ? alive
      : alive.where((p) => p.id != predatorId).toList();

    final eligibleVoters = engine.pendingPredatorEligibleVoterIds.toSet();
    final preferredId = engine.pendingPredatorPreferredTargetId;

    final candidates = eligibleVoters.isNotEmpty
      ? baseCandidates
        .where((p) => eligibleVoters.contains(p.id) || p.id == preferredId)
        .toList()
      : baseCandidates;

    final items = candidates
        .map(
          (p) => DropdownMenuItem<String>(
            value: p.id,
            child: Text(p.name),
          ),
        )
        .toList();

    _target ??= (engine.pendingPredatorPreferredTargetId != null &&
            candidates
                .any((p) => p.id == engine.pendingPredatorPreferredTargetId))
        ? engine.pendingPredatorPreferredTargetId
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Predator Retaliation', style: TextStyle(fontWeight: FontWeight.bold, color: cs.error)),
            const SizedBox(height: 8),
            const Text('Choose who dies with the Predator:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_target),
              initialValue: _target,
              decoration: const InputDecoration(labelText: 'Select Target', filled: true),
              items: items,
              onChanged: (v) => setState(() => _target = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: _target == null
                  ? null
                  : () {
                      final ok = engine.completePredatorRetaliation(_target!);
                      if (!ok) {
                        widget.gameEngine.showToast('Retaliation failed.');
                        return;
                      }
                      setState(() => _target = null);
                      widget.gameEngine.showToast('Retaliation applied.');
                    },
              child: const Text('Retaliate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeaSpillerRevealPanel extends StatefulWidget {
  final GameEngine gameEngine;
  const _TeaSpillerRevealPanel({required this.gameEngine});

  @override
  State<_TeaSpillerRevealPanel> createState() => _TeaSpillerRevealPanelState();
}

class _TeaSpillerRevealPanelState extends State<_TeaSpillerRevealPanel> {
  String? _target;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engine = widget.gameEngine;

    final teaId = engine.pendingTeaSpillerId;
    final teaName = teaId == null
        ? 'Tea Spiller'
        : (engine.players.where((p) => p.id == teaId).firstOrNull?.name ??
            'Tea Spiller');

    final alive = engine.guests.where((p) => p.isAlive && p.isEnabled).toList();
    final candidates = teaId == null
      ? const <Player>[]
      : alive
        .where((p) => engine.pendingTeaSpillerEligibleVoterIds.contains(p.id))
        .toList(growable: false);

    final items = candidates
        .map(
          (p) => DropdownMenuItem<String>(
            value: p.id,
            child: Text(p.name),
          ),
        )
        .toList(growable: false);

    if (_target != null && !candidates.any((p) => p.id == _target)) {
      _target = null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tea Spiller Reveal', style: TextStyle(fontWeight: FontWeight.bold, color: cs.tertiary)),
            const SizedBox(height: 8),
            Text('$teaName was eliminated. Choose a voter to expose:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(_target),
              initialValue: _target,
              decoration: const InputDecoration(labelText: 'Select Target', filled: true),
              items: items,
              onChanged: (v) => setState(() => _target = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.tertiary),
              onPressed: _target == null
                  ? null
                  : () {
                      final ok = engine.completeTeaSpillerReveal(_target!);
                      if (!ok) {
                        widget.gameEngine.showToast('Reveal failed.');
                        return;
                      }
                      setState(() => _target = null);
                      widget.gameEngine.showToast('Tea spilled.');
                    },
              child: const Text('Reveal'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RosterStatusFilter { all, alive, dead }

class _HostPlayersTab extends StatefulWidget {
  final GameEngine engine;

  const _HostPlayersTab({required this.engine});

  @override
  State<_HostPlayersTab> createState() => _HostPlayersTabState();
}

class _HostPlayersTabState extends State<_HostPlayersTab> {
  final TextEditingController _searchController = TextEditingController();
  _RosterStatusFilter _statusFilter = _RosterStatusFilter.all;
  bool _onlyEnabled = false;
  String? _selectedPlayerId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engine = widget.engine;
    final q = _searchController.text.trim().toLowerCase();

    bool matchesSearch(Player p) {
      if (q.isEmpty) return true;
      final name = p.name.toLowerCase();
      final roleName = p.role.name.toLowerCase();
      return name.contains(q) || roleName.contains(q);
    }

    bool matchesFilter(Player p) {
      if (_onlyEnabled && !p.isEnabled) return false;

      switch (_statusFilter) {
        case _RosterStatusFilter.all:
          return true;
        case _RosterStatusFilter.alive:
          return p.isAlive;
        case _RosterStatusFilter.dead:
          return !p.isAlive;
      }
    }

    final filtered =
        engine.guests.where((p) => matchesFilter(p) && matchesSearch(p)).toList();
    filtered.sort((a, b) {
      final aliveCmp = (b.isAlive ? 1 : 0).compareTo(a.isAlive ? 1 : 0);
      if (aliveCmp != 0) return aliveCmp;
      final enabledCmp = (b.isEnabled ? 1 : 0).compareTo(a.isEnabled ? 1 : 0);
      if (enabledCmp != 0) return enabledCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final alive = filtered.where((p) => p.isAlive).toList();
    final dead = filtered.where((p) => !p.isAlive).toList();

    Widget buildPlayerCard(Player p) {
      return HostPlayerStatusCard(
        player: p,
        gameEngine: engine,
        showControls: true,
        isSelected: _selectedPlayerId == p.id,
        onTap: () => setState(() => _selectedPlayerId = p.id),
        trailing: (p.role.id == 'clinger' &&
                p.isActive &&
                !p.clingerFreedAsAttackDog &&
                p.clingerPartnerId != null)
            ? IconButton(
                tooltip: 'Mark freed',
                icon: const Icon(Icons.link_off),
                onPressed: () {
                  final ok = engine.freeClingerFromObsession(p.id);
                  engine.showToast(ok ? 'Clinger unleashed.' : 'Action failed.');
                },
              )
            : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search players',
            prefixIcon: Icon(Icons.search),
            filled: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _statusFilter == _RosterStatusFilter.all,
              onSelected: (_) => setState(() => _statusFilter = _RosterStatusFilter.all),
            ),
            ChoiceChip(
              label: const Text('Alive'),
              selected: _statusFilter == _RosterStatusFilter.alive,
              onSelected: (_) => setState(() => _statusFilter = _RosterStatusFilter.alive),
            ),
            ChoiceChip(
              label: const Text('Dead'),
              selected: _statusFilter == _RosterStatusFilter.dead,
              onSelected: (_) => setState(() => _statusFilter = _RosterStatusFilter.dead),
            ),
            FilterChip(
              label: const Text('Only enabled'),
              selected: _onlyEnabled,
              onSelected: (v) => setState(() => _onlyEnabled = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Center(child: Text('No players found.'))
        else ...[
          if (_statusFilter != _RosterStatusFilter.dead && alive.isNotEmpty) ...[
            Text('Alive (${alive.length})', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...alive.map(buildPlayerCard),
            const SizedBox(height: 16),
          ],
          if (_statusFilter != _RosterStatusFilter.alive && dead.isNotEmpty) ...[
            Text('Dead (${dead.length})', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...dead.map(buildPlayerCard),
          ],
        ],
      ],
    );
  }
}

Widget _buildDashboardIntroCard(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Card(
    elevation: 0,
    color: cs.surfaceContainerHighest,
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live game summary',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Monitor win odds, voting patterns, and recent events in real-time.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

Widget _buildPredictabilityCard(BuildContext context, GameOddsSnapshot odds) {
  final rows = odds.sortedDesc;
  if (rows.isEmpty) {
    return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No odds available.')));
  }

  final top = rows.first;
  final confidence = top.value.clamp(0.0, 1.0);

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Predictability: ${(confidence * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: confidence, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          Text('Leader: ${top.key}'),
        ],
      ),
    ),
  );
}

Widget _buildOddsCard(BuildContext context, GameOddsSnapshot odds, {required bool isUpdating, DateTime? updatedAt}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Win Odds', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isUpdating) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in odds.sortedDesc)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(e.key)),
                  Expanded(
                    flex: 5,
                    child: LinearProgressIndicator(value: e.value.clamp(0.0, 1.0)),
                  ),
                  const SizedBox(width: 8),
                  Text('${(e.value * 100).round()}%'),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildVotingHighlightsCard(BuildContext context, VotingInsights voting) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Total Votes Today: ${voting.votesCastToday}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (voting.currentBreakdown.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Most Targeted: ${voting.currentBreakdown.first.targetName} (${voting.currentBreakdown.first.voteCount})'),
          ],
        ],
      ),
    ),
  );
}

Widget _buildHostToolsCard(BuildContext context, GameEngine engine) {
  final cs = Theme.of(context).colorScheme;
  final hasPending = engine.dramaQueenSwapPending ||
      engine.hasPendingPredatorRetaliation ||
      engine.hasPendingTeaSpillerReveal;

  return Card(
    color: hasPending ? cs.tertiaryContainer : null,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pending Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          if (!hasPending)
            const Text('None.')
          else ...[
            if (engine.dramaQueenSwapPending) const Text('• Drama Queen Swap'),
            if (engine.hasPendingPredatorRetaliation) const Text('• Predator Retaliation'),
            if (engine.hasPendingTeaSpillerReveal) const Text('• Tea Spiller Reveal'),
          ],
        ],
      ),
    ),
  );
}
