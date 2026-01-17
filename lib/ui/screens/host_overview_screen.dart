import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
import '../utils/player_sort.dart';

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
    final players =
      sortedPlayersByDisplayName(widget.gameEngine.guests.toList());
    final enabledPlayers = players.where((p) => p.isEnabled).length;
    final alivePlayers = players.where((p) => p.isActive).length;
    final deadPlayers = enabledPlayers - alivePlayers;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'HOST OVERVIEW',
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
            tooltip: 'About',
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
                    'HOST OVERVIEW',
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
                    'This screen provides:\n\n'
                    '• Quick reference of all players and their roles\n'
                    '• Special status tracking (lives, obsessions, mimics)\n'
                    '• Player management (toggle on/off)\n'
                    '• Game customization controls\n\n'
                    'Keep this tab private from players!',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    FilledButton(
                      style: ClubBlackoutTheme.neonButtonStyle(
                        ClubBlackoutTheme.neonGreen,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('GOT IT'),
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
                // Game Stats
                _buildGameStats(alivePlayers, deadPlayers),
                const SizedBox(height: 16),

                // Special Status Section
                _buildSpecialStatusSection(),
                const SizedBox(height: 16),

                // Players Table
                _buildPlayersTable(players),
                const SizedBox(height: 16),

                // Game Controls
                _buildGameControls(),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlayerStatusChips(Player player) {
    final chips = <Widget>[];

    Widget buildChip(String label, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9, // Small font for dense info
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Role-specific states
    if (player.hasRumour) {
      chips.add(buildChip('RUMOUR', ClubBlackoutTheme.neonPurple));
    }
    if (player.soberSentHome) {
      chips.add(buildChip('SENT HOME', ClubBlackoutTheme.neonBlue));
    }
    if (player.clingerPartnerId != null) {
      final target = widget.gameEngine.players
          .firstWhere((p) => p.id == player.clingerPartnerId, orElse: () => player);
      chips.add(buildChip('OBSESSED: ${target.name}', ClubBlackoutTheme.neonPink));
    }
    if (player.creepTargetId != null) {
      final target = widget.gameEngine.players
          .firstWhere((p) => p.id == player.creepTargetId, orElse: () => player);
      chips.add(buildChip('CREEPING: ${target.name}', ClubBlackoutTheme.neonGreen));
    }
    if (player.clingerFreedAsAttackDog) {
      chips.add(buildChip('UNLEASHED', ClubBlackoutTheme.neonRed));
    }
    if (player.medicChoice != null) {
      chips.add(buildChip(
        player.medicChoice == 'PROTECT_DAILY' ? 'MEDIC: PROTECT' : 'MEDIC: REVIVE',
        ClubBlackoutTheme.neonBlue,
      ));
    }
    if (player.idCheckedByBouncer) {
      chips.add(buildChip('CHECKED', Colors.grey));
    }
    if (player.silencedDay == widget.gameEngine.dayCount) {
      chips.add(buildChip('SILENCED', Colors.white));
    }
    if (player.minorHasBeenIDd) {
      chips.add(buildChip('MINOR ID\'D', ClubBlackoutTheme.neonOrange));
    }
    if (player.secondWindConverted) {
      chips.add(buildChip('CONVERTED', ClubBlackoutTheme.neonOrange));
    } else if (player.secondWindPendingConversion) {
      chips.add(buildChip('PENDING CONV', ClubBlackoutTheme.neonOrange));
    }
    if (player.joinsNextNight) {
      chips.add(buildChip('LATE JOIN', ClubBlackoutTheme.neonGreen));
    }

    return chips;
  }

  Widget _buildGameStats(int alive, int dead) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: Colors.black,
        borderColor: ClubBlackoutTheme.neonGreen.withOpacity(0.4),
        opacity: 0.6,
        borderRadius: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.nightlight_round,
            'Night ${widget.gameEngine.dayCount}',
            ClubBlackoutTheme.neonPurple,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            Icons.favorite,
            '$alive Alive',
            ClubBlackoutTheme.neonGreen,
          ),
          _buildVerticalDivider(),
          _buildStatItem(Icons.close, '$dead Dead', ClubBlackoutTheme.neonRed),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.white12);
  }

  Widget _buildStatItem(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: ClubBlackoutTheme.circleGlow(color, intensity: 0.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
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
              p.silencedDay == widget.gameEngine.dayCount ||
              p.blockedKillNight == widget.gameEngine.dayCount,
        )
        .toList();
    final sentHome = widget.gameEngine.players
        .where((p) => p.soberSentHome)
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

    final lastNightLog = widget.gameEngine.gameLog
        .where((e) => e.turn >= widget.gameEngine.dayCount - 1)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ClubBlackoutTheme.glassmorphism(
        color: ClubBlackoutTheme.neonOrange,
        borderColor: ClubBlackoutTheme.neonOrange.withOpacity(0.6),
        opacity: 0.1,
        borderRadius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility,
                color: ClubBlackoutTheme.neonBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'LIVE GAME STATE',
                style: TextStyle(
                  fontFamily: 'Hyperwave',
                  fontSize: 20,
                  color: ClubBlackoutTheme.neonBlue,
                  shadows: ClubBlackoutTheme.textGlow(
                    ClubBlackoutTheme.neonBlue,
                  ),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Permanent Roles
          _buildClingerRow(clinger),
          if (creep != null) _buildCreepStatus(creep),
          if (allyCat != null) _buildMultiLifeStatus(allyCat),
          if (seasonedDrinker != null) _buildMultiLifeStatus(seasonedDrinker),
          if (dramaPending || lastDramaSwap != null)
            _buildDramaQueenStatus(
              pending: dramaPending,
              lastSwap: lastDramaSwap,
            ),

          const Divider(color: Colors.white24, height: 24),

          // 2. LIVE NIGHT ACTIONS (Pending Resolution)
          if (dealerTarget != null || roofiTarget != null || bouncerTarget != null || protected != null || sentHome.isNotEmpty) ...[
             const Text(
              "PENDING NIGHT ACTIONS (Live)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (dealerTarget != null)
              _buildStatItem(Icons.dangerous, "Dealers Hunting: ${dealerTarget.name}", ClubBlackoutTheme.neonRed),
            if (roofiTarget != null)
              _buildStatItem(Icons.block, "Roofi Targeting: ${roofiTarget.name}", Colors.grey),
            if (bouncerTarget != null)
              _buildStatItem(Icons.verified_user, "Bouncer ID'ing: ${bouncerTarget.name}", ClubBlackoutTheme.neonBlue),
            if (protected != null)
               _buildStatItem(Icons.medical_services, "Medic Protecting: ${protected.name}", Colors.green),
            if (sentHome.isNotEmpty)
              ...sentHome.map((p) => _buildStatItem(Icons.no_drinks, "Sober Sent Home: ${p.name}", Colors.blue)),
             const SizedBox(height: 16),
          ],

          // 3. Active Temporary Effects (Resolved Previous Night)
          if (silenced.isNotEmpty) ...[
            const Text(
              "SILENCED (Roofi - Active)",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            ...silenced.map(
              (p) => Text(
                "• ${p.name} (${p.role.name})",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (sentHome.isNotEmpty) ...[
            const Text(
              "SENT HOME (Sober - Active)",
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            ...sentHome.map(
              (p) => Text(
                "• ${p.name} (${p.role.name})",
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],

          const Divider(color: Colors.white24, height: 24),

          // 4. Recent Action Log (Last Night + Today)
          const Text(
            "RECENT ACTIONS",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (lastNightLog.isEmpty)
            const Text(
              "No actions yet...",
              style: TextStyle(
                color: Colors.white30,
                fontStyle: FontStyle.italic,
              ),
            ),
          ...lastNightLog
              .take(5)
              .map(
                (log) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "• ",
                        style: TextStyle(color: ClubBlackoutTheme.neonOrange),
                      ),
                      Expanded(
                        child: Text(
                          log.details,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ), // Smaller text for log
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildClingerRow(Player? clinger) {
    String? partnerId = clinger?.clingerPartnerId;
    if (partnerId == null && widget.gameEngine.nightActions.containsKey('clinger_obsession')) {
       partnerId = widget.gameEngine.nightActions['clinger_obsession'];
    }

    final partner = partnerId != null
        ? widget.gameEngine.players
            .where((p) => p.id == partnerId)
            .firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (clinger?.role.color ?? Colors.grey).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (clinger?.role.color ?? Colors.grey).withOpacity(0.5)),
            ),
            child: Text(
              'CLINGER',
              style: TextStyle(
                color: clinger?.role.color ?? Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: clinger != null
                ? Text(
                    partner != null
                        ? '${clinger.name} → Obsessed with ${partner.name} (${partner.role.name})'
                        : '${clinger.name} → No obsession selected yet',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  )
                : const Text(
                    '(Not in this game)',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
          ),
          if (clinger != null && clinger.clingerFreedAsAttackDog)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ClubBlackoutTheme.neonRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ClubBlackoutTheme.neonRed),
              ),
              child: Text(
                'ATTACK DOG',
                style: TextStyle(
                  color: ClubBlackoutTheme.neonRed,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreepStatus(Player creep) {
    String? targetId = creep.creepTargetId;
    if (targetId == null && widget.gameEngine.nightActions.containsKey('creep_target')) {
       targetId = widget.gameEngine.nightActions['creep_target'];
    }

    final target = targetId != null
        ? widget.gameEngine.players
              .where((p) => p.id == targetId)
              .firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: creep.role.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: creep.role.color.withOpacity(0.5)),
            ),
            child: Text(
              'CREEP',
              style: TextStyle(
                color: creep.role.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              target != null
                  ? '${creep.name} → Mimicking ${target.name} (${target.role.name})'
                  : '${creep.name} → No target selected yet',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiLifeStatus(Player player) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: player.role.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: player.role.color.withOpacity(0.5)),
            ),
            child: Text(
              player.role.name.toUpperCase(),
              style: TextStyle(
                color: player.role.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.favorite, color: ClubBlackoutTheme.neonRed, size: 16),
          const SizedBox(width: 4),
          Text(
            '${player.lives} ${player.lives == 1 ? 'Life' : 'Lives'} Remaining',
            style: TextStyle(
              color: player.lives > 1
                  ? ClubBlackoutTheme.neonGreen
                  : ClubBlackoutTheme.neonOrange,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDramaQueenStatus({
    required bool pending,
    required DramaQueenSwapRecord? lastSwap,
  }) {
    Player? resolve(String? id) {
      if (id == null) return null;
      return widget.gameEngine.players.where((p) => p.id == id).firstOrNull;
    }

    final markedA = resolve(widget.gameEngine.dramaQueenMarkedAId);
    final markedB = resolve(widget.gameEngine.dramaQueenMarkedBId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClubBlackoutTheme.neonBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClubBlackoutTheme.neonBlue.withOpacity(0.5)),
        boxShadow: ClubBlackoutTheme.circleGlow(
          ClubBlackoutTheme.neonBlue,
          intensity: 0.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high,
                color: ClubBlackoutTheme.neonBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'DRAMA QUEEN',
                style: TextStyle(
                  color: ClubBlackoutTheme.neonBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              if (pending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ClubBlackoutTheme.neonPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PENDING SWAP',
                    style: TextStyle(
                      color: ClubBlackoutTheme.neonPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (pending)
            Text(
              markedA != null && markedB != null
                  ? 'Awaiting swap: ${markedA.name} ↔ ${markedB.name}.'
                  : 'Awaiting swap: no marked pair; host chooses any two players.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          if (lastSwap != null) ...[
            if (pending) const SizedBox(height: 4),
            Text(
              'Last swap: ${lastSwap.playerAName} (${lastSwap.fromRoleA} → ${lastSwap.toRoleA}) with ${lastSwap.playerBName} (${lastSwap.fromRoleB} → ${lastSwap.toRoleB}).',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayersTable(List<Player> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.people, color: ClubBlackoutTheme.neonPink, size: 20),
              const SizedBox(width: 8),
              Text(
                'PLAYER ROSTER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ClubBlackoutTheme.neonPink,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        ...players.map((player) => _buildPlayerCard(player)),
      ],
    );
  }

  Widget _buildPlayerCard(Player player) {
    // Material 3 Card Style
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: player.role.color.withOpacity(0.3),
      color: player.isEnabled
          ? (player.isAlive
                ? const Color(0xFF1E1E1E)
                : Colors.black.withOpacity(0.6))
          : Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: player.isEnabled
              ? player.role.color.withOpacity(0.4)
              : Colors.white10,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: player.role.color.withOpacity(
                        player.isEnabled ? 1 : 0.3,
                      ),
                      width: 2,
                    ),
                    boxShadow: player.isEnabled
                        ? ClubBlackoutTheme.circleGlow(
                            player.role.color,
                            intensity: 0.5,
                          )
                        : [],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      player.role.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.person, color: player.role.color),
                    ),
                  ),
                ),
                if (!player.isAlive && player.isEnabled)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: ClubBlackoutTheme.neonRed,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      color: player.isEnabled ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      decoration: (!player.isAlive && player.isEnabled)
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: ClubBlackoutTheme.neonRed,
                      decorationThickness: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                      if (player.lives > 1) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.favorite,
                          color: ClubBlackoutTheme.neonRed,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'x${player.lives}',
                          style: TextStyle(
                            color: ClubBlackoutTheme.neonOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (player.statusEffects.isNotEmpty ||
                      player.hasRumour ||
                      player.soberSentHome ||
                      player.clingerPartnerId != null ||
                      player.creepTargetId != null ||
                      player.clingerFreedAsAttackDog ||
                      player.medicChoice != null ||
                      player.idCheckedByBouncer ||
                      player.silencedDay == widget.gameEngine.dayCount ||
                      player.minorHasBeenIDd ||
                      player.secondWindConverted ||
                      player.secondWindPendingConversion) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _buildPlayerStatusChips(player),
                    ),
                  ],
                ],
              ),
            ),

            // Controls
            Column(
              children: [
                Switch(
                  value: player.isEnabled,
                  activeColor: ClubBlackoutTheme.neonGreen,
                  inactiveThumbColor: Colors.white24,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      player.isEnabled = value;
                    });
                  },
                ),
                Text(
                  player.isEnabled ? 'ACTIVE' : 'DISABLED',
                  style: TextStyle(
                    fontSize: 8,
                    color: player.isEnabled
                        ? ClubBlackoutTheme.neonGreen
                        : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClubBlackoutTheme.neonPurple.withOpacity(0.2),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ClubBlackoutTheme.neonPurple.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: ClubBlackoutTheme.neonPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'GAME CONTROLS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ClubBlackoutTheme.neonPurple,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  icon: Icons.refresh,
                  label: 'Revive All',
                  color: ClubBlackoutTheme.neonGreen,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: ClubBlackoutTheme.neonGreen.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        title: Text(
                          'REVIVE ALL PLAYERS?',
                          style: TextStyle(color: ClubBlackoutTheme.neonGreen),
                          textAlign: TextAlign.center,
                        ),
                        content: const Text(
                          'This will mark all players as alive and reset their lives.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                for (var player in widget.gameEngine.players) {
                                  player.isAlive = true;
                                  player.initialize();
                                }
                              });
                              Navigator.pop(context);
                              HapticFeedback.mediumImpact();
                            },
                            child: const Text('REVIVE ALL'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildControlButton(
                  icon: Icons.warning,
                  label: 'Kill All',
                  color: ClubBlackoutTheme.neonRed,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: ClubBlackoutTheme.neonRed.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        title: Text(
                          'KILL ALL PLAYERS?',
                          style: TextStyle(color: ClubBlackoutTheme.neonRed),
                          textAlign: TextAlign.center,
                        ),
                        content: const Text(
                          'This will mark all players as dead.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                for (var player in widget.gameEngine.players) {
                                  player.isAlive = false;
                                }
                              });
                              Navigator.pop(context);
                              HapticFeedback.heavyImpact();
                            },
                            child: const Text('KILL ALL'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
