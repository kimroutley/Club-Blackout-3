import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import 'player_guide_screen.dart';
import 'role_cards_screen.dart';

class GuidesScreen extends StatelessWidget {
  final GameEngine? gameEngine;
  const GuidesScreen({super.key, this.gameEngine});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          title: const Text('Guides'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
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
            ),
          ],
        ),
      ),
    );
  }
}
