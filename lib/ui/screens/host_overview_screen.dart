import 'package:flutter/material.dart';
import 'dart:ui';
import '../../logic/game_engine.dart';
import '../../logic/game_state.dart';
import '../../logic/live_game_stats.dart';
import '../../logic/game_commentator.dart';
import '../../models/player.dart';
import '../../models/game_log_entry.dart';
import '../styles.dart';
import '../utils/player_sort.dart';

import '../widgets/player_tile.dart';

class HostOverviewScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const HostOverviewScreen({super.key, required this.gameEngine});

  @override
  State<HostOverviewScreen> createState() => _HostOverviewScreenState();
}

class _HostOverviewScreenState extends State<HostOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Rebuild UI whenever game state changes
    widget.gameEngine.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.gameEngine.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Live Stats
    final stats = LiveGameStats.fromEngine(widget.gameEngine);

    // Player list for table
    final players = sortedPlayersByDisplayName(
      widget.gameEngine.guests.toList(),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'HOST DASHBOARD',
          style: TextStyle(
            fontFamily: 'Hyperwave',
            fontSize: 28,
            color: ClubBlackoutTheme.neonGreen,
            shadows: ClubBlackoutTheme.textGlow(ClubBlackoutTheme.neonGreen),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            tooltip: 'Dashboard Help',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: ClubBlackoutTheme.neonGreen,
                      width: 2,
                    ),
                  ),
                  title: Text(
                    'HOST DASHBOARD',
                    style: TextStyle(
                      fontFamily: 'Hyperwave',
                      fontSize: 24,
                      color: ClubBlackoutTheme.neonGreen,
                      shadows: ClubBlackoutTheme.textGlow(
                        ClubBlackoutTheme.neonGreen,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  content: const Text(
                    'The Host Dashboard is your command center:\n\n'
                    '• Real-time stats on all factions\n'
                    '• Detailed log of everything that happened last night\n'
                    '• Live tracking of pending actions for the current night\n'
                    '• Quick access to player roles and status management\n\n'
                    'Hide this screen from players at all times.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    FilledButton(
                      style: ClubBlackoutTheme.neonButtonStyle(
                        ClubBlackoutTheme.neonGreen,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('UNDERSTOOD'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              "Backgrounds/Club Blackout App Background.png",
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),

          // Content
          SafeArea(
            child: ClubBlackoutTheme.centeredConstrained(
              maxWidth: 820,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 90, 16, 40),
                children: [
                  // 1. Core Game Stats & Phase
                  _buildGameStats(stats),
                  const SizedBox(height: 24),

                  // 2. LIVE GAME TRACKER (Cumulative Data)
                  _buildLiveGameTracker(stats),
                  const SizedBox(height: 24),

                  // 3. LAST NIGHT'S LOG (Detailed)
                  if (widget.gameEngine.lastNightHostRecap.isNotEmpty) ...[
                    _buildLastNightLogCard(),
                    const SizedBox(height: 24),
                  ],

                  // 4. LIVE FEED & PENDING ACTIONS
                  _buildSpecialStatusSection(),
                  const SizedBox(height: 24),

                  // 5. ROLE POPULATION (ALIVE)
                  _buildSectionHeader("ROLE POPULATION", Icons.badge_outlined),
                  _buildRolePopulationGrid(stats),
                  const SizedBox(height: 24),

                  // 6. PLAYER ROSTER
                  _buildSectionHeader("ACTIVE GUESTS", Icons.people_outline),
                  _buildPlayersTable(players),
                  const SizedBox(height: 24),

                  // 7. CONTROL PANEL
                  _buildSectionHeader("HOST CONTROLS", Icons.settings_outlined),
                  _buildGameControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveGameTracker(LiveGameStats stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: Colors.black,
        borderColor: ClubBlackoutTheme.neonBlue.withOpacity(0.3),
        opacity: 0.5,
        borderRadius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE GAME TRACKER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
              _buildStatBadge(
                Icons.analytics_outlined,
                'REAL-TIME DATA',
                ClubBlackoutTheme.neonBlue,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLargeStat('TOTAL', '${stats.totalPlayers}', Colors.white70),
              _buildLargeStat(
                'ALIVE',
                '${stats.aliveCount}',
                ClubBlackoutTheme.neonGreen,
              ),
              _buildLargeStat(
                'DEAD',
                '${stats.deadCount}',
                ClubBlackoutTheme.neonRed,
                onTap: _showDeadPlayersDialog,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white10),
          ),
          const Text(
            "FACTION SPREAD (ALIVE)",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFactionStat(
                'DEALERS',
                stats.dealerAliveCount,
                ClubBlackoutTheme.neonRed,
              ),
              const SizedBox(width: 12),
              _buildFactionStat(
                'INNOCENTS',
                stats.partyAliveCount,
                ClubBlackoutTheme.neonBlue,
              ),
              const SizedBox(width: 12),
              _buildFactionStat(
                'NEUTRALS',
                stats.neutralAliveCount,
                ClubBlackoutTheme.neonPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStat(
    String label,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: ClubBlackoutTheme.textGlow(color, intensity: 0.5),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionStat(String name, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              name,
              style: TextStyle(
                fontSize: 8,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastNightLogCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: Colors.black,
        borderColor: ClubBlackoutTheme.neonPurple.withOpacity(0.3),
        opacity: 0.5,
        borderRadius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, color: ClubBlackoutTheme.neonPurple),
              const SizedBox(width: 12),
              const Text(
                "LAST NIGHT'S LOG",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              widget.gameEngine.lastNightHostRecap,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStats(LiveGameStats stats) {
    final commentary = GameCommentator.generateCommentary(
      stats,
      widget.gameEngine.dayCount,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: ClubBlackoutTheme.neonPurple,
        borderColor: ClubBlackoutTheme.neonPurple.withOpacity(0.4),
        opacity: 0.15,
        borderRadius: 24,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ClubBlackoutTheme.neonPurple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ClubBlackoutTheme.neonPurple.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  widget.gameEngine.currentPhase == GamePhase.night
                      ? 'PHASE: NIGHT ${widget.gameEngine.dayCount}'
                      : 'PHASE: DAY ${widget.gameEngine.dayCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
              _buildStatBadge(
                widget.gameEngine.currentPhase == GamePhase.night
                    ? Icons.dark_mode
                    : Icons.light_mode,
                widget.gameEngine.currentPhase.name.toUpperCase(),
                widget.gameEngine.currentPhase == GamePhase.night
                    ? ClubBlackoutTheme.neonPurple
                    : ClubBlackoutTheme.neonOrange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: ClubBlackoutTheme.neonPink,
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"$commentary"',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeadPlayersDialog() {
    final deadPlayers = widget.gameEngine.players
        .where((p) => !p.isAlive)
        .toList();

    // Sort by death day (descending - most recent first)
    deadPlayers.sort((a, b) => (b.deathDay ?? 0).compareTo(a.deathDay ?? 0));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Icon(
                    Icons.sentiment_very_dissatisfied,
                    color: ClubBlackoutTheme.neonRed,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THE GRAVEYARD',
                        style: TextStyle(
                          fontFamily: 'Hyperwave', // Use branding font
                          fontSize: 28,
                          color: ClubBlackoutTheme.neonRed,
                          shadows: ClubBlackoutTheme.textGlow(
                            ClubBlackoutTheme.neonRed,
                          ),
                        ),
                      ),
                      Text(
                        '${deadPlayers.length} CASUALTIES',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: deadPlayers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.white10,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No casualties yet...",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: deadPlayers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final player = deadPlayers[index];
                        return _buildDeadPlayerTile(player);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadPlayerTile(Player player) {
    final reason = _formatDeathReason(player.deathReason);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
            image: DecorationImage(
              image: AssetImage(player.role.assetPath),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5), // Desaturate/dim dead players
                BlendMode.darken,
              ),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.close,
              color: ClubBlackoutTheme.neonRed.withOpacity(0.8),
              size: 28,
            ),
          ),
        ),
        title: Text(
          player.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.white38,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: player.role.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    player.role.name.toUpperCase(),
                    style: TextStyle(
                      color: player.role.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Died Day ${player.deathDay ?? "?"}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: TextStyle(color: Colors.red[200], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDeathReason(String? reason) {
    switch (reason) {
      case 'vote':
        return 'Voted out by the group';
      case 'night_kill':
        return 'Murdered by The Dealers';
      case 'dealer_kill':
        return 'Killed by a Dealer';
      case 'spoke_taboo_name':
        return 'Spoke a taboo name (Lightweight)';
      case 'vote_deflected':
        return 'Hit by deflected vote (Whore)';
      case 'predator_revenge':
        return 'Taken down by The Predator';
      case 'messy_bitch_rampage':
        return 'Killed in Messy Bitch\'s rampage';
      case 'messy_bitch_special_kill':
        return 'Killed by Messy Bitch (rampage)';
      case 'clinger_suicide':
        return 'Died of heartbreak (Clinger)';
      case 'attack_dog_kill':
        return 'Killed by Attack Dog (Clinger)';
      case 'bomb':
        return 'Caught in an explosion';
      case 'debug_kill_all':
        return 'Debug kill';
      default:
        // Handle ability-based deaths
        if (reason != null && reason.contains('ability_')) {
          return 'Killed by special ability';
        }
        return reason != null ? 'Cause: $reason' : 'Cause unknown';
    }
  }

  Widget _buildSpecialStatusSection() {
    final clinger = widget.gameEngine.players
        .where((p) => p.role.id == 'clinger')
        .firstOrNull;
    final creep = widget.gameEngine.players
        .where((p) => p.role.id == 'creep')
        .firstOrNull;
    final allyCat = widget.gameEngine.players
        .where((p) => p.role.id == 'ally_cat')
        .firstOrNull;
    final seasonedDrinker = widget.gameEngine.players
        .where((p) => p.role.id == 'seasoned_drinker')
        .firstOrNull;
    final lastDramaSwap = widget.gameEngine.lastDramaQueenSwap;
    final dramaPending = widget.gameEngine.dramaQueenSwapPending;

    // Build list of active night effects
    final silenced = widget.gameEngine.players
        .where(
          (p) =>
              p.isAlive &&
              (p.silencedDay == widget.gameEngine.dayCount ||
                  p.blockedKillNight == widget.gameEngine.dayCount),
        )
        .toList();
    final sentHome = widget.gameEngine.players
        .where((p) => p.isAlive && p.soberSentHome)
        .toList();

    // Pending/Active Night Actions
    final dealerTargetId = widget.gameEngine.nightActions['kill'];
    final roofiTargetId = widget.gameEngine.nightActions['roofi'];
    final bouncerTargetId = widget.gameEngine.nightActions['bouncer_check'];
    final medicTargetId = widget.gameEngine.nightActions['protect'];

    // Helper to get player by ID
    Player? getP(String? id) => id != null
        ? widget.gameEngine.players.where((p) => p.id == id).firstOrNull
        : null;

    final protected = getP(medicTargetId); // Medic target for tonight
    final dealerTarget = getP(dealerTargetId);
    final roofiTarget = getP(roofiTargetId);
    final bouncerTarget = getP(bouncerTargetId);

    final recentLogs = widget.gameEngine.gameLog
        .where((e) => e.type != GameLogType.script)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PENDING ACTIONS & LIVE EFFECTS
        Container(
          padding: const EdgeInsets.all(24),
          decoration: ClubBlackoutTheme.glassmorphism(
            color: Colors.black,
            borderColor: ClubBlackoutTheme.neonOrange.withOpacity(0.3),
            opacity: 0.5,
            borderRadius: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LIVE FEED & PENDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                  _buildStatBadge(
                    Icons.sensors,
                    'LIVE TRACKING',
                    ClubBlackoutTheme.neonOrange,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // LIVE ACTIONS (Only show if in Night phase or actions exist)
              if (dealerTarget != null ||
                  roofiTarget != null ||
                  bouncerTarget != null ||
                  protected != null) ...[
                const Text(
                  "ACTIVE TARGETS THIS NIGHT",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (dealerTarget != null)
                  _buildLiveActionRow(
                    Icons.dangerous,
                    "DEALERS HUNTING",
                    dealerTarget.name,
                    ClubBlackoutTheme.neonRed,
                  ),
                if (roofiTarget != null)
                  _buildLiveActionRow(
                    Icons.block,
                    "ROOFI PARALYZING",
                    roofiTarget.name,
                    Colors.grey,
                  ),
                if (bouncerTarget != null)
                  _buildLiveActionRow(
                    Icons.search,
                    "BOUNCER ID'ING",
                    bouncerTarget.name,
                    ClubBlackoutTheme.neonBlue,
                  ),
                if (protected != null)
                  _buildLiveActionRow(
                    Icons.security,
                    "MEDIC PROTECTING",
                    protected.name,
                    ClubBlackoutTheme.neonGreen,
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white10),
                ),
              ],

              // PERSISTENT STATUS EFFECTS
              if (silenced.isNotEmpty ||
                  sentHome.isNotEmpty ||
                  clinger != null ||
                  creep != null) ...[
                const Text(
                  "ACTIVE STATUS EFFECTS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (silenced.isNotEmpty)
                  _buildStatusEffectRow(
                    Icons.mic_off,
                    "SILENCED",
                    silenced.map((p) => p.name).join(", "),
                    Colors.grey,
                  ),
                if (sentHome.isNotEmpty)
                  _buildStatusEffectRow(
                    Icons.home,
                    "SENT HOME",
                    sentHome.map((p) => p.name).join(", "),
                    Colors.amber,
                  ),
                if (clinger != null) _buildClingerRow(clinger),
                if (creep != null) _buildCreepStatus(creep),
                if (allyCat != null) _buildMultiLifeStatus(allyCat),
                if (seasonedDrinker != null)
                  _buildMultiLifeStatus(seasonedDrinker),
                if (dramaPending || lastDramaSwap != null)
                  _buildDramaQueenStatus(
                    pending: dramaPending,
                    lastSwap: lastDramaSwap,
                  ),
              ] else if (dealerTarget == null &&
                  roofiTarget == null &&
                  bouncerTarget == null &&
                  protected == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "No active targets or effects found.",
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. RECENT ACTIVITY LOG
        Container(
          padding: const EdgeInsets.all(24),
          decoration: ClubBlackoutTheme.glassmorphism(
            color: Colors.black,
            borderColor: Colors.white10,
            opacity: 0.4,
            borderRadius: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RECENT ACTIVITY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              if (recentLogs.isEmpty)
                const Text(
                  "Waiting for drama...",
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...recentLogs.reversed
                    .take(6)
                    .map(
                      (log) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getLogColor(log.type),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.title.toUpperCase(),
                                    style: TextStyle(
                                      color: _getLogColor(
                                        log.type,
                                      ).withOpacity(0.8),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    log.details,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "D${log.turn}",
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getLogColor(GameLogType type) {
    switch (type) {
      case GameLogType.action:
        return ClubBlackoutTheme.neonBlue;
      case GameLogType.system:
        return ClubBlackoutTheme.neonRed;
      case GameLogType.script:
        return ClubBlackoutTheme.neonGreen;
    }
  }

  Widget _buildLiveActionRow(
    IconData icon,
    String label,
    String target,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            "$label:",
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            target,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusEffectRow(
    IconData icon,
    String label,
    String targets,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            "$label:",
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              targets,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePopulationGrid(LiveGameStats stats) {
    // Sort roles by count or importance
    final entries = stats.roleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: Colors.black,
        borderColor: Colors.white10,
        opacity: 0.3,
        borderRadius: 24,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: entries.map((entry) {
          final role = widget.gameEngine.roleRepository.getRoleById(entry.key);
          final color = role?.color ?? Colors.white;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.value}x',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  role?.name.toUpperCase() ?? entry.key.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClingerRow(Player clinger) {
    final partner = clinger.clingerPartnerId != null
        ? widget.gameEngine.players.firstWhere(
            (p) => p.id == clinger.clingerPartnerId,
            orElse: () => clinger,
          )
        : null;

    return _buildStatusEffectRow(
      Icons.favorite,
      "CLINGER",
      partner != null
          ? "${clinger.name} → ${partner.name}"
          : "${clinger.name} (No partner)",
      ClubBlackoutTheme.neonPink,
    );
  }

  Widget _buildCreepStatus(Player creep) {
    final target = creep.creepTargetId != null
        ? widget.gameEngine.players.firstWhere(
            (p) => p.id == creep.creepTargetId,
            orElse: () => creep,
          )
        : null;

    return _buildStatusEffectRow(
      Icons.masks,
      "CREEP",
      target != null
          ? "${creep.name} mimicking ${target.role.name}"
          : "${creep.name} (No target)",
      Colors.purple,
    );
  }

  Widget _buildMultiLifeStatus(Player player) {
    return _buildStatusEffectRow(
      Icons.health_and_safety,
      player.role.name.toUpperCase(),
      "${player.name} (${player.lives} lives remaining)",
      ClubBlackoutTheme.neonGreen,
    );
  }

  Widget _buildDramaQueenStatus({
    required bool pending,
    DramaQueenSwapRecord? lastSwap,
  }) {
    if (pending) {
      return _buildStatusEffectRow(
        Icons.swap_horiz,
        "DRAMA QUEEN",
        "Swap pending (host must select 2 players)",
        ClubBlackoutTheme.neonPurple,
      );
    } else if (lastSwap != null) {
      return _buildStatusEffectRow(
        Icons.swap_horiz,
        "DRAMA QUEEN",
        "Last swap: ${lastSwap.fromRoleA} ↔ ${lastSwap.toRoleA}",
        ClubBlackoutTheme.neonPurple,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPlayersTable(List<Player> players) {
    return Container(
      decoration: ClubBlackoutTheme.glassmorphism(
        color: Colors.black,
        borderColor: Colors.white10,
        opacity: 0.3,
        borderRadius: 24,
      ),
      child: Column(
        children: players.map<Widget>((player) {
          return PlayerTile(
            player: player,
            gameEngine: widget.gameEngine,
            isCompact: false,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: Colors.black,
        borderColor: Colors.white10,
        opacity: 0.3,
        borderRadius: 24,
      ),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('BACK TO GAME'),
            style: ClubBlackoutTheme.neonButtonStyle(
              ClubBlackoutTheme.neonGreen,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: ClubBlackoutTheme.neonRed,
                      width: 2,
                    ),
                  ),
                  title: Text(
                    'SAVE GAME?',
                    style: TextStyle(
                      color: ClubBlackoutTheme.neonRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: const Text(
                    'Save current game state to continue later?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await widget.gameEngine.saveGame('autosave');
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Game saved successfully!'),
                              backgroundColor: ClubBlackoutTheme.neonGreen,
                            ),
                          );
                        }
                      },
                      style: ClubBlackoutTheme.neonButtonStyle(
                        ClubBlackoutTheme.neonGreen,
                      ),
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('SAVE GAME'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}
