import 'dart:ui';
import 'package:flutter/material.dart';
import '../../logic/game_engine.dart';
import '../styles.dart';
import '../utils/player_sort.dart';
import '../widgets/game_drawer.dart';

class RumourMillScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const RumourMillScreen({super.key, required this.gameEngine});

  @override
  State<RumourMillScreen> createState() => _RumourMillScreenState();
}

class _RumourMillScreenState extends State<RumourMillScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Identify Messy Bitch
    final messyBitch = widget.gameEngine.players
        .where((p) => p.role.id == 'messy_bitch')
        .firstOrNull;

    if (messyBitch == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        drawer: GameDrawer(selectedIndex: 0, onNavigate: (_) {}),
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Opacity(
                opacity: 0.6,
                child: Image.asset(
                  "Backgrounds/Club Blackout App Background.png",
                  fit: BoxFit.cover,
                  errorBuilder: (c, o, s) => Container(color: Colors.black),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
            ),

            // Content
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    centerTitle: true,
                    floating: true,
                    pinned: true,
                    flexibleSpace: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.black.withOpacity(0.5)),
                      ),
                    ),
                    title: Text(
                      "RUMOUR MILL",
                      style: TextStyle(
                        fontFamily: 'Hyperwave',
                        fontSize: 29,
                        color: const Color(0xFFE6E6FA),
                        shadows: ClubBlackoutTheme.textGlow(
                          const Color(0xFFE6E6FA),
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    child: Center(
                      child: ClubBlackoutTheme.centeredConstrained(
                        maxWidth: 720,
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(32),
                          decoration: ClubBlackoutTheme.cardDecoration(
                            glowColor: const Color(0xFFE6E6FA),
                            glowIntensity: 0.6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                size: 64,
                                color: const Color(0xFFE6E6FA).withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No Messy Bitch in this game.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
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

    // Determine who is counted for the win condition (Alive players other than Messy Bitch)
    final otherPlayers = sortedPlayersByDisplayName(
      widget.gameEngine.players.where((p) => p.id != messyBitch.id),
    );
    final aliveOtherPlayers = otherPlayers.where((p) => p.isActive).toList();

    final playersWithRumour = aliveOtherPlayers
        .where((p) => p.hasRumour)
        .length;
    final totalAliveTargets = aliveOtherPlayers.length;

    final isWinning =
        totalAliveTargets > 0 && playersWithRumour >= totalAliveTargets;
    final rumourColor = const Color(0xFFE6E6FA);

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: GameDrawer(selectedIndex: 0, onNavigate: (_) {}),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                "Backgrounds/Club Blackout App Background.png",
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(color: Colors.black),
              ),
            ),
          ),

          // Blurred background effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Main Content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                centerTitle: true,
                floating: true,
                pinned: true,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                ),
                title: Text(
                  "RUMOUR MILL",
                  style: TextStyle(
                    fontFamily: 'Hyperwave',
                    fontSize: 29,
                    color: rumourColor,
                    shadows: ClubBlackoutTheme.textGlow(rumourColor),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Latest Gossip Card
                    if (widget.gameEngine.messyBitchGossip != null) ...[
                      ClubBlackoutTheme.centeredConstrained(
                        maxWidth: 820,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: ClubBlackoutTheme.cardDecoration(
                            glowColor: ClubBlackoutTheme.neonPink,
                            glowIntensity: 0.8,
                            borderRadius: 20,
                          ),
                          child: Column(
                            children: [
                              Text(
                                "FRESH GOSSIP",
                                style: TextStyle(
                                  fontFamily: 'Hyperwave',
                                  color: ClubBlackoutTheme.neonPink,
                                  fontSize: 24,
                                  shadows: ClubBlackoutTheme.textGlow(
                                    ClubBlackoutTheme.neonPink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "\"${widget.gameEngine.messyBitchGossip}\"",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Win Condition Card
                    ClubBlackoutTheme.centeredConstrained(
                      maxWidth: 820,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.9 + (value * 0.1),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: ClubBlackoutTheme.cardDecoration(
                            glowColor: isWinning
                                ? ClubBlackoutTheme.neonGreen
                                : rumourColor,
                            glowIntensity: isWinning ? 1.5 : 0.8,
                            borderRadius: 20,
                          ),
                          child: Column(
                            children: [
                              // Icon with animation
                              if (isWinning)
                                AnimatedBuilder(
                                  animation: _shimmerController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale:
                                          1.0 +
                                          (0.1 *
                                              (1 -
                                                  (_shimmerController.value -
                                                              0.5)
                                                          .abs() *
                                                      2)),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 48,
                                        color: ClubBlackoutTheme.neonGreen,
                                        shadows: ClubBlackoutTheme.textGlow(
                                          ClubBlackoutTheme.neonGreen,
                                          intensity: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else
                                Icon(
                                  Icons.campaign,
                                  size: 48,
                                  color: rumourColor,
                                  shadows: ClubBlackoutTheme.textGlow(
                                    rumourColor,
                                  ),
                                ),
                              const SizedBox(height: 16),

                              Text(
                                isWinning
                                    ? "WIN CONDITION MET!"
                                    : "RUMOUR PROGRESS",
                                style: TextStyle(
                                  fontFamily: 'Hyperwave',
                                  color: isWinning
                                      ? ClubBlackoutTheme.neonGreen
                                      : rumourColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  letterSpacing: 1.5,
                                  shadows: isWinning
                                      ? ClubBlackoutTheme.textGlow(
                                          ClubBlackoutTheme.neonGreen,
                                          intensity: 1.2,
                                        )
                                      : ClubBlackoutTheme.textGlow(rumourColor),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Progress bar
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white10,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: totalAliveTargets > 0
                                        ? playersWithRumour / totalAliveTargets
                                        : 0,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation(
                                      isWinning
                                          ? ClubBlackoutTheme.neonGreen
                                          : rumourColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Text(
                                "$playersWithRumour / $totalAliveTargets Alive Players Infected",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section Header
                    ClubBlackoutTheme.centeredConstrained(
                      maxWidth: 820,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Text(
                          "PLAYER STATUS",
                          style: TextStyle(
                            fontFamily: 'Hyperwave',
                            color: Colors.white70,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ]),
                ),
              ),

              // Player List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final player = otherPlayers[index];

                    return ClubBlackoutTheme.centeredConstrained(
                      maxWidth: 820,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(player.id),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 50)),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(opacity: value, child: child),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: player.hasRumour ? 8 : 4,
                          color: Colors.transparent,
                          shadowColor: player.hasRumour
                              ? rumourColor.withOpacity(0.4)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: player.hasRumour
                                  ? rumourColor.withOpacity(0.6)
                                  : Colors.white12,
                              width: player.hasRumour ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            // Bolt: Removed nested BackdropFilter for performance
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: player.hasRumour
                                      ? [
                                          rumourColor.withOpacity(0.15),
                                          rumourColor.withOpacity(0.05),
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.05),
                                          Colors.white.withOpacity(0.02),
                                        ],
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        player.role.color.withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                    ),
                                    border: Border.all(
                                      color: player.isActive
                                          ? player.role.color
                                          : player.role.color.withOpacity(0.3),
                                      width: 2,
                                    ),
                                    boxShadow: player.isActive
                                        ? ClubBlackoutTheme.circleGlow(
                                            player.role.color,
                                            intensity: 0.9,
                                          )
                                        : null,
                                  ),
                                  child: Icon(
                                    player.isActive
                                        ? Icons.person
                                        : Icons.person_off,
                                    color: player.isActive
                                        ? player.role.color
                                        : Colors.white24,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  player.name,
                                  style: TextStyle(
                                    color: player.isActive
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    decoration: player.isActive
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    player.role.name,
                                    style: TextStyle(
                                      color: player.isActive
                                          ? player.role.color.withOpacity(0.8)
                                          : player.role.color.withOpacity(0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: player.hasRumour
                                        ? rumourColor.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: player.hasRumour
                                          ? rumourColor.withOpacity(0.5)
                                          : Colors.white12,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    player.hasRumour
                                        ? Icons.campaign
                                        : Icons.campaign_outlined,
                                    color: player.hasRumour
                                        ? rumourColor
                                        : Colors.white24,
                                    size: 24,
                                    shadows: player.hasRumour
                                        ? ClubBlackoutTheme.textGlow(
                                            rumourColor,
                                            intensity: 0.8,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: otherPlayers.length),
                ),
              ),

              // Bottom spacing
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ],
      ),
    );
  }
}
