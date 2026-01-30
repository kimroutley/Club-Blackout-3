import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../styles.dart';
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
    final isDark = theme.brightness == Brightness.dark;
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
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/Backgrounds/background.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: players.isEmpty
            ? const Center(
                child: Text(
                  'No rumours yet...',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return _buildRumourCard(context, player, isDark);
                },
              ),
      ),
    );
  }

  Widget _buildRumourCard(BuildContext context, Player player, bool isDark) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? ClubBlackoutTheme.rumourLavender.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: player.isAlive ? Colors.transparent : Colors.red.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
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
            color: isDark ? Colors.white : Colors.black87,
            decoration: player.isAlive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          player.isAlive ? 'Active in the community' : 'Deceased',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        trailing: player.isAlive
            ? const Icon(Icons.mark_chat_unread_outlined, color: Colors.amber)
            : const Icon(Icons.cancel, color: Colors.red),
      ),
    );
  }
}
