import 'package:flutter/material.dart';
import '../../logic/game_engine.dart';
import '../styles.dart';

class PlayerGuideScreen extends StatelessWidget {
  final GameEngine? gameEngine;

  const PlayerGuideScreen({super.key, this.gameEngine});

  @override
  Widget build(BuildContext context) {
    if (gameEngine?.currentPhase == GamePhase.night) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Player Guide'),
        ),
        body: const SafeArea(
          child: PlayerGuideBody(),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'Backgrounds/Club Blackout V2 Game Background.png',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: null,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight,
            ),
            child: const PlayerGuideBody(),
          ),
        ),
      ],
    );
  }
}

class PlayerGuideBody extends StatelessWidget {
  const PlayerGuideBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _buildSection(
          context,
          'Welcome to Club Blackout',
          'Where the music is loud, the drinks are strong, and the survival rate is... debatable. '
          'You are either a PARTY ANIMAL looking for a good time, or a DEALER looking for your next victim. '
          'Try not to get thrown out (or worse).',
          ClubBlackoutTheme.neonPink,
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'The vibe (flow)',
          null,
          ClubBlackoutTheme.neonBlue,
          content: Column(
            children: [
              _buildFlowStep(context, 'Pre-game', 'Lobby screen. Pick a name, grab a selfie, pray for a good role.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'NIGHT 0', 'Setup phase. No dying yet. Just awkward introductions.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Blackout', 'Night phase. Eyes shut. Killers creep. Chaos ensues.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Morning after', 'Host spills the tea on who died or got lucky.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Vote', 'Accuse your friends. Lie to your family. Throw someone out.'),
              ClubBlackoutTheme.gap8,
              _buildFlowStep(context, 'Repeat', 'Until the Dealers are gone or the Party is dead.'),
            ],
          ),
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'Eyes & ears',
          'When the Host says "Sleep", you sleep. No peeking, no twitching. '
          'If you cheat, you ruin the vibe, and nobody likes a buzzkill.',
          ClubBlackoutTheme.neonPurple,
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'The throw out',
          'During the day, figure out who the Dealers are. If you vote correctly, they get booted. '
          'If you vote wrong... well, sorry Dave, but you looked suspicious.',
          ClubBlackoutTheme.neonOrange,
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'House rules',
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _buildSection(
          context,
          'You are the DJ',
          'You run the Club. You control the chaos. You are the Host. '
          'Your job is to keep the energy high and the game moving. '
          'Think "Master of Ceremonies" meets "Grim Reaper".',
          ClubBlackoutTheme.neonBlue,
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'Your gig',
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
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'Setup night (Night 0)',
          'The soft opening. Special roles (Medic, Clinger) do their thing. '
          'Nobody dies tonight. It\'s just a vibe check.',
          ClubBlackoutTheme.neonGold,
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'Blackout phase',
          'Follow the app prompts. Call roles by name. If they snore, wake them up. '
          'If they peek, shame them publicly.',
          ClubBlackoutTheme.neonPurple,
        ),
        ClubBlackoutTheme.gap12,
        _buildSection(
          context,
          'Daylight drama',
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
  return Container(
    decoration: ClubBlackoutTheme.neonFrame(
      color: accentColor,
      opacity: 0.1,
      borderRadius: ClubBlackoutTheme.radiusLg,
      borderWidth: 1.5,
      showGlow: false,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              border: Border(
                bottom: BorderSide(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
            ),
            child: Text(
              title,
              style: ClubBlackoutTheme.headingStyle.copyWith(
                fontSize: 14,
                color: accentColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                shadows: null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null)
                  Text(
                    description,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                if (content != null) content,
              ],
            ),
          ),
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
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusSm),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.15)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: cs.onSurface.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            desc,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ),
    ],
  );
}
