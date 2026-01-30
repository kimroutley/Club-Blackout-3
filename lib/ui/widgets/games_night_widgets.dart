import 'package:flutter/material.dart';
import '../../logic/games_night_service.dart';
import '../styles.dart';
import 'neon_page_scaffold.dart';

class GamesNightSummaryCard extends StatelessWidget {
  final GamesNightInsights insights;
  const GamesNightSummaryCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return NeonGlassCard(
      glowColor: ClubBlackoutTheme.neonPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Games recorded: ${insights.gamesRecorded}'),
          Text('Total vote actions: ${insights.voting.totalVoteActions}'),
          Text('Total log events: ${insights.actions.totalLogEntries}'),
        ],
      ),
    );
  }
}

class GamesNightVotingCard extends StatelessWidget {
  final GamesNightInsights insights;
  const GamesNightVotingCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final topVoters = insights.voting.topVoters;
    final mostTargeted = insights.voting.mostTargeted;

    return NeonGlassCard(
      glowColor: ClubBlackoutTheme.neonOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voting', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Top voters (activity)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (topVoters.isEmpty)
            const Text('—')
          else
            ...topVoters.map(
              (v) {
                final changes = v.changes > 0 ? ' (${v.changes} changes)' : '';
                return Text('${v.voterName}: ${v.voteActions} votes$changes');
              },
            ),
          const SizedBox(height: 16),
          const Text('Most targeted', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (mostTargeted.isEmpty)
            const Text('—')
          else
            ...mostTargeted.map((t) => Text('${t.name}: ${t.count}')),
        ],
      ),
    );
  }
}

class GamesNightRolesCard extends StatelessWidget {
  final GamesNightInsights insights;
  const GamesNightRolesCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final roles = insights.roles.entries.toList(growable: false);
    return NeonGlassCard(
      glowColor: ClubBlackoutTheme.neonBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Roles (enabled players)', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (roles.isEmpty)
            const Text('—')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roles
                  .map(
                    (e) => Chip(
                      label: Text('${e.key} (${e.value})'),
                      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class GamesNightActionsCard extends StatelessWidget {
  final GamesNightInsights insights;
  const GamesNightActionsCard({super.key, required this.insights});

  String _humanizeEnumName(String raw) {
    final withSpaces = raw
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(?<!^)([A-Z])'), (m) => ' ${m[1]}');
    final words = withSpaces.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words
        .map(
          (w) => w.length <= 1
              ? w.toUpperCase()
              : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final byType = insights.actions.byType;
    final topTitles = insights.actions.topTitles;

    String typeLine() {
      if (byType.isEmpty) return '—';
      final parts = byType.entries
          .map((e) => '${_humanizeEnumName(e.key.name)}: ${e.value}')
          .toList(growable: false);
      return parts.join('  •  ');
    }

    return NeonGlassCard(
      glowColor: ClubBlackoutTheme.neonPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actions (from log)', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Total events: ${insights.actions.totalLogEntries}'),
          const SizedBox(height: 8),
          Text(typeLine()),
          const SizedBox(height: 16),
          const Text('Most common titles', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (topTitles.isEmpty)
            const Text('—')
          else
            ...topTitles.map((t) => Text('${t.name}: ${t.count}')),
        ],
      ),
    );
  }
}

class GamesNightControlCard extends StatelessWidget {
  final bool isActive;
  final DateTime? startedAt;
  final int gamesRecorded;
  final int totalEvents;
  final ValueChanged<bool> onToggle;
  final VoidCallback onClear;
  final VoidCallback onCopyJson;
  final VoidCallback onShowHallOfFame;
  final VoidCallback onShowRecap;

  const GamesNightControlCard({
    super.key,
    required this.isActive,
    required this.startedAt,
    required this.gamesRecorded,
    required this.totalEvents,
    required this.onToggle,
    required this.onClear,
    required this.onCopyJson,
    required this.onShowHallOfFame,
    required this.onShowRecap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration =
        startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);

    return NeonGlassCard(
      glowColor: isActive ? ClubBlackoutTheme.neonGreen : ClubBlackoutTheme.neonRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.nights_stay_rounded,
                color: isActive ? ClubBlackoutTheme.neonGreen : ClubBlackoutTheme.neonRed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'GAMES NIGHT ACTIVE' : 'NO SESSION ACTIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isActive
                            ? ClubBlackoutTheme.neonGreen
                            : ClubBlackoutTheme.neonRed,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (isActive)
                      Text(
                        'Running for ${hours}h ${mins}m',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: onToggle,
                activeThumbColor: ClubBlackoutTheme.neonGreen,
                inactiveTrackColor: ClubBlackoutTheme.neonRed.withValues(alpha: 0.2),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            Wrap(
               spacing: 8,
               runSpacing: 8,
               children: [
                 Tooltip(
                   message: 'Hall of Fame',
                   child: FilledButton(
                      onPressed: onShowHallOfFame,
                      style: ClubBlackoutTheme.neonButtonStyle(ClubBlackoutTheme.neonGold, isPrimary: false).copyWith(
                        padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded),
                   ),
                 ),
                 Tooltip(
                   message: 'Session Recap',
                   child: FilledButton(
                      onPressed: onShowRecap,
                      style: ClubBlackoutTheme.neonButtonStyle(ClubBlackoutTheme.neonBlue, isPrimary: false).copyWith(
                        padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                      ),
                      child: const Icon(Icons.emoji_events_rounded),
                   ),
                 ),
                 Tooltip(
                   message: 'Copy Session JSON',
                   child: FilledButton(
                      onPressed: onCopyJson,
                      style: ClubBlackoutTheme.neonButtonStyle(ClubBlackoutTheme.neonPurple, isPrimary: false).copyWith(
                        padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                      ),
                      child: const Icon(Icons.content_copy_rounded),
                   ),
                 ),
               ],
            ),
            const SizedBox(height: 16),
            Divider(color: cs.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: ClubBlackoutTheme.neonRed,
                side: const BorderSide(color: ClubBlackoutTheme.neonRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
