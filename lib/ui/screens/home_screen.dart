import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';

class HomeScreen extends StatelessWidget {
  final GameEngine gameEngine;
  final VoidCallback onNavigateToLobby;
  final VoidCallback onNavigateToGuides;

  const HomeScreen({
    super.key,
    required this.gameEngine,
    required this.onNavigateToLobby,
    required this.onNavigateToGuides,
  });

  void _showStartOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onNavigateToLobby();
                },
                child: const Text('Start a games night'),
              ),
              ClubBlackoutTheme.gap12,
              FilledButton.tonal(
                onPressed: () {
                  Navigator.pop(ctx);
                  onNavigateToLobby();
                },
                child: const Text('Normal game'),
              ),
              ClubBlackoutTheme.gap12,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Phase-aware styling
    final isNight = gameEngine.currentPhase == GamePhase.night;

    // Background
    Widget background;
    if (isNight) {
      background = Container(color: Theme.of(context).colorScheme.surface);
    } else {
      background = Image.asset(
        'Backgrounds/Club Blackout V2 Home Menu.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: background),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Club Blackout'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showStartOptions(context),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Let's get started"),
                    ),
                    ClubBlackoutTheme.gap24,
                    FilledButton.tonalIcon(
                      onPressed: onNavigateToGuides,
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Guides'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
