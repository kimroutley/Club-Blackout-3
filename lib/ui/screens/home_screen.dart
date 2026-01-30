import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../styles.dart';
import '../widgets/glow_button.dart';

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
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Container(
          decoration: ClubBlackoutTheme.neonBottomSheetDecoration(
            ctx,
            accent: ClubBlackoutTheme.neonBlue,
          ),
          padding: ClubBlackoutTheme.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlowButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onNavigateToLobby();
                },
                glowColor: ClubBlackoutTheme.neonPurple,
                child: const Text('Start a games night'),
              ),
              ClubBlackoutTheme.gap12,
              GlowButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onNavigateToLobby();
                },
                glowColor: ClubBlackoutTheme.neonPink,
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
    // For 'Day/Lobby', we keep it bright/colorful (Neon theme), but using M3 structures.
    
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

    // Buttons
    // In Night mode, use standard scheme. In Day mode, use specific Neon accents.
    final btnStylePrimary = isNight 
        ? null // Default M3
        : FilledButton.styleFrom(
            backgroundColor: ClubBlackoutTheme.neonBlue, 
            foregroundColor: Colors.white,
          );
    
    final btnStyleSecondary = isNight
        ? null // Default M3 tonal
        : FilledButton.styleFrom(
            backgroundColor: ClubBlackoutTheme.neonOrange,
            foregroundColor: Colors.white,
          );

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
                      style: btnStylePrimary,
                    ),
                    ClubBlackoutTheme.gap24,
                    FilledButton.icon(
                      onPressed: onNavigateToGuides,
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Guides'),
                      style: btnStyleSecondary,
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
