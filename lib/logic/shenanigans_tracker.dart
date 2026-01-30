import 'package:flutter/material.dart';

import '../models/game_story_snapshot.dart'; // Added
import '../models/player.dart';
import '../models/vote_cast.dart';
import 'game_engine.dart';

@immutable
class ShenaniganAward {
  final String title;
  final String description;
  final String playerId;
  final String playerName;
  final dynamic value; // Count, percentage, etc.
  final IconData icon;
  final Color color;

  const ShenaniganAward({
    required this.title,
    required this.description,
    required this.playerId,
    required this.playerName,
    required this.value,
    this.icon = Icons.emoji_events_rounded,
    this.color = Colors.amber,
  });
}

class ShenanigansTracker {
  /// Generates a list of fun/in-depth stats awards based on the full game history.
  static List<ShenaniganAward> generateAwards(GameEngine engine) {
    if (engine.players.isEmpty) return [];

    final awards = <ShenaniganAward>[];
    final playersById = {for (var p in engine.guests) p.id: p};

    // --- Pre-calculation: Final Votes Per Day ---
    // voteHistory contains every vote event. We want the final state for each day.
    final votesByDay = <int, Map<String, String>>{};
    for (final vote in engine.voteHistory) {
      if (vote.targetId == null) continue; // Skip abstains for target tracking
      votesByDay.putIfAbsent(vote.day, () => {});
      // Since list is chronological, later votes overwrite earlier ones
      votesByDay[vote.day]![vote.voterId] = vote.targetId!;
    }

    // --- 1. "The Flip-Flopper" (Most vote changes) ---
    final changeCounts = <String, int>{};
    for (final change in engine.voteChanges) {
      changeCounts[change.voterId] = (changeCounts[change.voterId] ?? 0) + 1;
    }
    if (changeCounts.isNotEmpty) {
      final top =
          changeCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value > 1) {
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Flip-Flopper',
            description: 'Changed their vote the most times.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value} times',
            icon: Icons.swap_horiz_rounded,
            color: Colors.orange,
          ));
        }
      }
    }

    // --- 2. "Public Enemy #1" (Most Targeted by Night Actions) ---
    final nightTargetCounts = <String, int>{};
    for (final night in engine.nightHistory) {
      const keys = [
        'kill',
        'check_id',
        'silence',
        'sober_sent_home',
        'protect',
        'role_block'
      ];
      for (final key in keys) {
        final targetId = night[key];
        if (targetId is String) {
          nightTargetCounts[targetId] = (nightTargetCounts[targetId] ?? 0) + 1;
        }
      }
    }
    if (nightTargetCounts.isNotEmpty) {
      final top =
          nightTargetCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      final p = playersById[top.key];
      if (p != null) {
        awards.add(ShenaniganAward(
          title: 'Public Enemy #1',
          description: 'Most targeted player at night.',
          playerId: p.id,
          playerName: p.name,
          value: '${top.value} visits',
          icon: Icons.search_rounded,
          color: Colors.redAccent,
        ));
      }
    }

    // --- 3. "Nemesis Pair" ---
    final voteAdj = <String, Map<String, int>>{};
    for (final vote in engine.voteHistory) {
      if (vote.targetId == null) continue;
      voteAdj.putIfAbsent(vote.voterId, () => {});
      voteAdj[vote.voterId]![vote.targetId!] =
          (voteAdj[vote.voterId]![vote.targetId!] ?? 0) + 1;
    }

    String? p1, p2;
    int maxConflict = 0;

    for (final v1 in voteAdj.keys) {
      for (final t1 in voteAdj[v1]!.keys) {
        final int v1ot1 = voteAdj[v1]![t1]!;
        final int t1ov1 = voteAdj[t1]?[v1] ?? 0;
        final int conflict = v1ot1 + t1ov1;
        if (conflict > maxConflict && v1.compareTo(t1) < 0) {
          maxConflict = conflict;
          p1 = v1;
          p2 = t1;
        }
      }
    }

    if (p1 != null && p2 != null && maxConflict >= 3) {
      final name1 = playersById[p1]?.name ?? 'Unknown';
      final name2 = playersById[p2]?.name ?? 'Unknown';
      awards.add(ShenaniganAward(
        title: 'Nemesis Pair',
        description: 'These two couldn\'t leave each other alone.',
        playerId: '$p1-$p2',
        playerName: '$name1 & $name2',
        value: '$maxConflict clashes',
        icon: Icons.compare_arrows_rounded,
        color: Colors.purple,
      ));
    }

    // --- 4. "The Lone Wolf" (Voted alone often) ---
    final loneWolfCounts = <String, int>{};
    for (final dayVotes in votesByDay.values) {
      final counts = <String, int>{};
      for (final t in dayVotes.values) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
      for (final entry in dayVotes.entries) {
        final voter = entry.key;
        final target = entry.value;
        if (counts[target] == 1) {
          loneWolfCounts[voter] = (loneWolfCounts[voter] ?? 0) + 1;
        }
      }
    }

    if (loneWolfCounts.isNotEmpty) {
      final top =
          loneWolfCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value >= 2) {
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Lone Wolf',
            description: 'Voted for someone nobody else suspected.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value} times',
            icon: Icons.person_outline_rounded,
            color: Colors.blueGrey,
          ));
        }
      }
    }

    // --- 5. "The Scatterbrain" (Most unique targets) ---
    final uniqueTargets = <String, Set<String>>{};
    for (final dayVotes in votesByDay.values) {
      for (final entry in dayVotes.entries) {
        uniqueTargets.putIfAbsent(entry.key, () => {});
        uniqueTargets[entry.key]!.add(entry.value);
      }
    }

    if (uniqueTargets.isNotEmpty) {
      final top = uniqueTargets.entries
          .reduce((a, b) => a.value.length > b.value.length ? a : b);
      if (top.value.length >= 3) {
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Scatterbrain',
            description: 'Suspected the widest variety of people.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value.length} suspects',
            icon: Icons.call_split_rounded,
            color: Colors.teal,
          ));
        }
      }
    }

    // --- 6. "The Detective" (Party Animal finding Dealers) ---
    final detectiveScores = <String, int>{};
    for (final dayVotes in votesByDay.values) {
      for (final entry in dayVotes.entries) {
        final voter = playersById[entry.key];
        final target = playersById[entry.value];
        // Note: Using current alliance.
        if (voter != null &&
            target != null &&
            voter.alliance.toLowerCase().contains('party') &&
            target.alliance.toLowerCase().contains('dealer')) {
          detectiveScores[entry.key] = (detectiveScores[entry.key] ?? 0) + 1;
        }
      }
    }

    if (detectiveScores.isNotEmpty) {
      final top =
          detectiveScores.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value >= 2) {
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Detective',
            description: 'Correctly voted for Dealers most often.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value} correct',
            icon: Icons.policy_rounded,
            color: Colors.blue,
          ));
        }
      }
    }

    // --- 7. "The Shadow" (Dealer with fewest votes received) ---
    if (engine.dayCount >= 2) {
      final votesReceived = <String, int>{};
      for (final p in engine.guests) {
        votesReceived[p.id] = 0;
      }

      for (final dayVotes in votesByDay.values) {
        for (final targetId in dayVotes.values) {
          votesReceived[targetId] = (votesReceived[targetId] ?? 0) + 1;
        }
      }

      String? bestShadow;
      int minVotes = 999;

      for (final entry in votesReceived.entries) {
        final p = playersById[entry.key];
        if (p != null && p.alliance.toLowerCase().contains('dealer')) {
          if (entry.value < minVotes) {
            minVotes = entry.value;
            bestShadow = entry.key;
          }
        }
      }

      if (bestShadow != null && minVotes <= 2) {
        final p = playersById[bestShadow];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Shadow',
            description: 'Dealer who avoided suspicion.',
            playerId: p.id,
            playerName: p.name,
            value: '$minVotes votes',
            icon: Icons.visibility_off_rounded,
            color: Colors.blueGrey,
          ));
        }
      }
    }

    // --- 8. "The Guardian Angel" (Medic saving lives) ---
    // Requires correlating 'kill' and 'protect' targets in night history
    int successfulSaves = 0;
    for (final night in engine.nightHistory) {
      final killTarget = night['kill'];
      final protectTarget = night['protect'];
      if (killTarget != null &&
          protectTarget != null &&
          killTarget == protectTarget) {
        successfulSaves++;
      }
    }

    if (successfulSaves > 0) {
      // Find the Medic (assuming single medic for simplicity)
      final medic = playersById.values.cast<Player?>().firstWhere(
            (p) => p?.role.id == 'medic',
            orElse: () => null,
          );

      if (medic != null) {
        awards.add(ShenaniganAward(
          title: 'The Guardian Angel',
          description: 'Protected a victim from certain death.',
          playerId: medic.id,
          playerName: medic.name,
          value: '$successfulSaves lives saved',
          icon: Icons.health_and_safety_rounded,
          color: Colors.red,
        ));
      }
    }

    // --- 9. "The Executioner" (Most votes for the eliminated player) ---
    // --- 10. "The Instigator" (First to vote for the eliminated player) ---

    final executionerCounts = <String, int>{};
    final instigatorCounts = <String, int>{};

    for (final entry in votesByDay.entries) {
      final day = entry.key;
      final dayVotes = entry.value; // voterId -> targetId

      final counts = <String, int>{};
      for (final t in dayVotes.values) {
        counts[t] = (counts[t] ?? 0) + 1;
      }

      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.isEmpty) continue;
      final eliminatedId = sorted.first.key;
      // Ensure it wasn't a tie (skip ties for stats simplicity)
      if (sorted.length > 1 && sorted[1].value == sorted.first.value) continue;

      // Executioner
      final votersForEliminated = <String>[];
      for (final v in dayVotes.entries) {
        if (v.value == eliminatedId) {
          executionerCounts[v.key] = (executionerCounts[v.key] ?? 0) + 1;
          votersForEliminated.add(v.key);
        }
      }

      // Instigator
      VoteCast? firstVote;
      for (final v in engine.voteHistory) {
        if (v.day == day &&
            v.targetId == eliminatedId &&
            votersForEliminated.contains(v.voterId)) {
          if (firstVote == null || v.sequence < firstVote.sequence) {
            firstVote = v;
          }
        }
      }
      if (firstVote != null) {
        instigatorCounts[firstVote.voterId] =
            (instigatorCounts[firstVote.voterId] ?? 0) + 1;
      }
    }

    if (executionerCounts.isNotEmpty) {
      final top =
          executionerCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value >= 2) {
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Executioner',
            description: 'Voted for the eliminated player most often.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value} kills',
            icon: Icons.gavel_rounded,
            color: Colors.brown,
          ));
        }
      }
    }

    if (instigatorCounts.isNotEmpty) {
      final top =
          instigatorCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value >= 1) {
        // Even once is notable if they led the charge
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'The Instigator',
            description: 'Started the mob mentality.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value} mobs started',
            icon: Icons.campaign_rounded, // bullhorn
            color: Colors.deepOrange,
          ));
        }
      }
    }

    // --- 11. "Friendly Fire Champion" (Party voting Party) ---
    final ffCounts = <String, int>{};
    for (final dayVotes in votesByDay.values) {
      for (final entry in dayVotes.entries) {
        final voter = playersById[entry.key];
        final target = playersById[entry.value];
        if (voter != null &&
            target != null &&
            voter.alliance.toLowerCase().contains('party') &&
            target.alliance.toLowerCase().contains('party')) {
          ffCounts[entry.key] = (ffCounts[entry.key] ?? 0) + 1;
        }
      }
    }

    if (ffCounts.isNotEmpty) {
      final top = ffCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value >= 2) {
        final p = playersById[top.key];
        if (p != null) {
          awards.add(ShenaniganAward(
            title: 'Friendly Fire Champion',
            description: 'Voted for their own teammates the most.',
            playerId: p.id,
            playerName: p.name,
            value: '${top.value} betrayals',
            icon: Icons.error_outline_rounded,
            color: Colors.red.shade900,
          ));
        }
      }
    }

    return awards;
  }

  /// Generates awards based on a list of game snapshots (Multi-Game Session).
  static List<ShenaniganAward> generateSessionAwards(
      List<GameStorySnapshot> games) {
    if (games.isEmpty) return [];

    // Aggregators (Key = Player Name)
    final flipFlopCounts = <String, int>{};
    final nightTargetCounts = <String, int>{};
    final executionerCounts = <String, int>{};
    final instigatorCounts = <String, int>{};
    final detectiveCounts = <String, int>{};
    final friendlyFireCounts = <String, int>{};
    final totalGamesPlayed = <String, int>{};

    for (final game in games) {
      // Map ID -> Snapshot for this game
      final playersById = {for (var p in game.players) p.id: p};
      for (var p in game.players) {
        totalGamesPlayed[p.name] = (totalGamesPlayed[p.name] ?? 0) + 1;
      }

      // 1. Flip-Flopper
      for (final change in game.voteChanges) {
        final p = playersById[change.voterId];
        if (p != null) {
          flipFlopCounts[p.name] = (flipFlopCounts[p.name] ?? 0) + 1;
        }
      }

      // 2. Public Enemy
      for (final night in game.nightHistory) {
        const keys = [
          'kill',
          'check_id',
          'silence',
          'sober_sent_home',
          'protect',
          'role_block'
        ];
        for (final key in keys) {
          final targetId = night[key];
          if (targetId is String) {
            final p = playersById[targetId];
            if (p != null) {
              nightTargetCounts[p.name] = (nightTargetCounts[p.name] ?? 0) + 1;
            }
          }
        }
      }

      // Build Votes By Day
      final votesByDay = <int, Map<String, String>>{};
      for (final vote in game.voteHistory) {
        if (vote.targetId == null) continue;
        votesByDay.putIfAbsent(vote.day, () => {});
        votesByDay[vote.day]![vote.voterId] = vote.targetId!;
      }

      // Day Loop
      for (final entry in votesByDay.entries) {
        final day = entry.key;
        final dayVotes = entry.value;

        // Tally targets for elimination
        final counts = <String, int>{};
        for (final t in dayVotes.values) {
          counts[t] = (counts[t] ?? 0) + 1;
        }

        // Find eliminated (max votes)
        final sorted = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        String? eliminatedId;
        if (sorted.isNotEmpty) {
          // Simple max heuristic
          if (sorted.length == 1 || sorted[0].value > sorted[1].value) {
            eliminatedId = sorted[0].key;
          }
        }

        final votersForEliminated = <String>[];

        for (final voteEntry in dayVotes.entries) {
          final voterId = voteEntry.key;
          final targetId = voteEntry.value;
          final voter = playersById[voterId];
          final target = playersById[targetId];

          if (voter == null || target == null) continue;

          // Detective (Party -> Dealer)
          if (voter.alliance.toLowerCase().contains('party') &&
              target.alliance.toLowerCase().contains('dealer')) {
            detectiveCounts[voter.name] =
                (detectiveCounts[voter.name] ?? 0) + 1;
          }

          // Friendly Fire (Party -> Party)
          if (voter.alliance.toLowerCase().contains('party') &&
              target.alliance.toLowerCase().contains('party')) {
            friendlyFireCounts[voter.name] =
                (friendlyFireCounts[voter.name] ?? 0) + 1;
          }

          // Executioner
          if (eliminatedId != null && targetId == eliminatedId) {
            executionerCounts[voter.name] =
                (executionerCounts[voter.name] ?? 0) + 1;
            votersForEliminated.add(voterId);
          }
        }

        // Instigator
        if (eliminatedId != null) {
          VoteCast? firstVote;
          for (final v in game.voteHistory) {
            if (v.day == day &&
                v.targetId == eliminatedId &&
                votersForEliminated.contains(v.voterId)) {
              if (firstVote == null || v.sequence < firstVote.sequence) {
                firstVote = v;
              }
            }
          }
          if (firstVote != null) {
            final p = playersById[firstVote.voterId];
            if (p != null) {
              instigatorCounts[p.name] = (instigatorCounts[p.name] ?? 0) + 1;
            }
          }
        }
      }
    }

    // Convert Aggregates to Awards
    final awards = <ShenaniganAward>[];

    void addAward(Map<String, int> counts, String title, String desc,
        IconData icon, Color color, String suffix,
        {int min = 1}) {
      if (counts.isEmpty) return;
      final top = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (top.value >= min) {
        awards.add(ShenaniganAward(
          title: title,
          description: desc,
          playerId: 'session_${top.key}', // Virtual ID
          playerName: top.key,
          value: '${top.value} $suffix',
          icon: icon,
          color: color,
        ));
      }
    }

    addAward(
        flipFlopCounts,
        'Legacy of Indecision',
        'Changed their vote the most across all games.',
        Icons.swap_horiz_rounded,
        Colors.orange,
        'flips',
        min: 3);
    addAward(
        nightTargetCounts,
        'Target Practice',
        'Most targeted player of the night.',
        Icons.search_rounded,
        Colors.redAccent,
        'visits',
        min: 3);
    addAward(
        executionerCounts,
        'The Grim Reaper',
        'Voted for eliminated players most often.',
        Icons.gavel_rounded,
        Colors.brown,
        'executions',
        min: 3);
    addAward(instigatorCounts, 'Mob Boss', 'Started the most elimination mobs.',
        Icons.campaign_rounded, Colors.deepOrange, 'mobs',
        min: 2);
    addAward(
        detectiveCounts,
        'Sherlock Holmes',
        'Most correct votes against Dealers.',
        Icons.policy_rounded,
        Colors.blue,
        'caught',
        min: 3);
    addAward(
        friendlyFireCounts,
        'The Saboteur',
        'Voted for teammates most often.',
        Icons.error_outline_rounded,
        Colors.red.shade900,
        'betrayals',
        min: 3);

    return awards;
  }
}
