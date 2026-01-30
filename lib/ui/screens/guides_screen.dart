import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';
import '../widgets/neon_background.dart';
import 'player_guide_screen.dart';
import 'role_cards_screen.dart';

class GuidesScreen extends StatelessWidget {
  final GameEngine? gameEngine;
  const GuidesScreen({super.key, this.gameEngine});

  @override
  Widget build(BuildContext context) {
    final isNight = gameEngine?.currentPhase == GamePhase.night;

    // Unified M3 Structure with Theming
    return Stack(
      children: [
        if (!isNight)
          const Positioned.fill(
            child: NeonBackground(
              accentColor: ClubBlackoutTheme.neonOrange,
              backgroundAsset:
                  'Backgrounds/Club Blackout V2 Game Background.png',
              blurSigma: 12.0,
              showOverlay: true,
              child: SizedBox.expand(),
            ),
          ),
        DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: isNight ? null : Colors.transparent,
            appBar: AppBar(
              backgroundColor: isNight ? null : Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(
                  color: Colors.white), // Always readable on bg
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              title:
                  const Text('Guides', style: TextStyle(color: Colors.white)),
              centerTitle: true,
              bottom: TabBar(
                labelColor: isNight ? null : ClubBlackoutTheme.neonOrange,
                unselectedLabelColor: Colors.white60,
                indicatorColor: isNight ? null : ClubBlackoutTheme.neonOrange,
                tabs: const [
                  Tab(text: 'HOST'),
                  Tab(text: 'PLAYER'),
                  Tab(text: 'ROLES'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                const HostGuideBody(),
                const PlayerGuideBody(),
                RoleCardsScreen(
                  roles: gameEngine?.roleRepository.roles ?? const [],
                  embedded: true,
                  isNight: isNight, // Pass context so cards render cleanly
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
