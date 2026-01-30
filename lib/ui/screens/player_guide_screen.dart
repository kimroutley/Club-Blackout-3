import 'package:flutter/material.dart';
import '../../logic/game_engine.dart';
import '../styles.dart';

class PlayerGuideScreen extends StatelessWidget {
  final GameEngine? gameEngine;

  const PlayerGuideScreen({super.key, this.gameEngine});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Guide'),
        elevation: 0,
      ),
      body: const SafeArea(
        child: PlayerGuideBody(),
      ),
    );
  }
}

class PlayerGuideBody extends StatelessWidget {
  const PlayerGuideBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          context,
          'Welcome to Club Blackout',
          'Where the music is loud, the drinks are strong, and the survival rate is... debatable. '
          'You are either a PARTY ANIMAL looking for a good time, or a DEALER looking for your next victim. '
          'Try not to get thrown out (or worse).',
          ClubBlackoutTheme.neonPink,
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'The Vibe (Flow)',
          null,
          ClubBlackoutTheme.neonBlue,
          content: Column(
            children: [
              _buildFlowStep(context, 'Pre-game', 'Lobby screen. Pick a name, grab a selfie, pray for a good role.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Night 0', 'Setup phase. No dying yet. Just awkward introductions.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Blackout', 'Night phase. Eyes shut. Killers creep. Chaos ensues.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Morning After', 'Host spills the tea on who died or got lucky.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Vote', 'Accuse your friends. Lie to your family. Throw someone out.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Repeat', 'Until the Dealers are gone or the Party is dead.'),
            ],
          ),
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'Eyes & Ears',
          'When the Host says "Sleep", you sleep. No peeking, no twitching. '
          'If you cheat, you ruin the vibe, and nobody likes a buzzkill.',
          ClubBlackoutTheme.neonPurple,
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'The Throw Out',
          'During the day, figure out who the Dealers are. If you vote correctly, they get booted. '
          'If you vote wrong... well, sorry Dave, but you looked suspicious.',
          ClubBlackoutTheme.neonOrange,
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'House Rules',
          null,
          ClubBlackoutTheme.neonPurple,
          content: Column(
            children: [
              _buildFlowStep(context, 'Don\'t be that guy', 'Don\'t peek. Don\'t cheat. It\'s a party game, chill.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Play the role', 'Attack the character, not the player. Unless it\'s Steve. Steve knows what he did.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Dead men tell no tales', 'If you die, shut up. Ghosts can\'t talk, they just haunt.'),
            ],
          ),
        ),
      ],
    );
  }
}

class HostGuideBody extends StatelessWidget {
  const HostGuideBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          context,
          'You are the DJ',
          'You run the Club. You control the chaos. You are the Host. '
          'Your job is to keep the energy high and the game moving. '
          'Think "Master of Ceremonies" meets "Grim Reaper".',
          ClubBlackoutTheme.neonBlue,
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'Your Gig',
          null,
          ClubBlackoutTheme.neonPink,
          content: Column(
            children: [
              _buildFlowStep(context, 'Set the tone', 'Use your "spooky narrator voice". Make them nervous.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Keep tempo', 'Don\'t let them sleep all night. Wake \'em up, kill \'em off.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'God mode', 'The app tracks the logic. You bring the drama.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Pause button', 'Need a break? Send everyone to sleep. Power trip approved.'),
            ],
          ),
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'Setup Night (Night 0)',
          'The soft opening. Special roles (Medic, Clinger) do their thing. '
          'Nobody dies tonight. It\'s just a vibe check.',
          ClubBlackoutTheme.neonGold,
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'Blackout Phase',
          'Follow the app prompts. Call roles by name. If they snore, wake them up. '
          'If they peek, shame them publicly.',
          ClubBlackoutTheme.neonPurple,
        ),
        ClubBlackoutTheme.gap16,
        _buildSection(
          context,
          'Daylight Drama',
          null,
          ClubBlackoutTheme.neonOrange,
          content: Column(
            children: [
              _buildFlowStep(context, 'The reveal', 'Read the Morning Bulletin like it\'s breaking news.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'The showdown', 'Let them argue. Fuel the fire. Then call the vote.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'The flush', 'When someone gets voted out, take their badge. They\'re done.'),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildSection(
  BuildContext context,
  String title,
  String? description,
  Color accentColor, {
  Widget? content,
}) {
  final cs = Theme.of(context).colorScheme;
  return Card(
    elevation: 0,
    color: cs.surfaceContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (description != null)
            Text(
              description,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          if (content != null) ...[
            if (description != null) const SizedBox(height: 12),
            content,
          ],
        ],
      ),
    ),
  );
}

Widget _buildFlowStep(BuildContext context, String label, String desc) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          desc,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}
