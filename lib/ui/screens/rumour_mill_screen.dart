import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../widgets/game_drawer.dart';
import 'game_screen.dart';

class RumourMillScreen extends StatelessWidget {
  final GameEngine gameEngine;

  const RumourMillScreen({
    super.key,
    required this.gameEngine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final players = gameEngine.players;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rumour Mill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Initial refresh logic if needed
            },
          ),
        ],
      ),
      drawer: GameDrawer(
        gameEngine: gameEngine,
        onContinueGameTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(gameEngine: gameEngine),
            ),
          );
        },
      ),
      body: players.isEmpty
          ? const Center(
              child: Text(
                'No rumours yet...',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return _buildRumourCard(context, player);
              },
            ),
    );
  }

  Widget _buildRumourCard(BuildContext context, Player player) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.surfaceContainer,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: player.isAlive ? Colors.green : Colors.grey,
          child: Icon(
            player.isAlive ? Icons.person : Icons.person_off,
            color: Colors.white,
          ),
        ),
        title: Text(
          player.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: player.isAlive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          player.isAlive ? 'Active in the community' : 'Deceased',
        ),
        trailing: player.isAlive
            ? const Icon(Icons.mark_chat_unread_outlined, color: Colors.amber)
            : const Icon(Icons.cancel, color: Colors.red),
      ),
    );
  }
}
