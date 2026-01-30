// A standalone preview app to test the Scoreboard UI with fake data.
// Run this with: flutter run -t lib/scoreboard_preview.dart

import 'package:flutter/material.dart';

import 'data/role_repository.dart';
import 'logic/game_engine.dart';
import 'models/player.dart';
import 'models/role.dart';
import 'models/vote_cast.dart';
import 'ui/styles.dart';
import 'ui/widgets/game_scoreboard.dart';

// Minimal mock to satisfy GameEngine dependency
class MockRoleRepository extends RoleRepository {
  @override
  Future<void> loadRoles() async {}
}

void main() {
  runApp(const ScoreboardPreviewApp());
}

class ScoreboardPreviewApp extends StatelessWidget {
  const ScoreboardPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ClubBlackoutTheme.createTheme(
        const ColorScheme.dark(
          primary: ClubBlackoutTheme.neonPurple,
          secondary: ClubBlackoutTheme.neonPink,
        ),
      ),
      home: const ScoreboardPreviewScreen(),
    );
  }
}

class ScoreboardPreviewScreen extends StatefulWidget {
  const ScoreboardPreviewScreen({super.key});

  @override
  State<ScoreboardPreviewScreen> createState() =>
      _ScoreboardPreviewScreenState();
}

class _ScoreboardPreviewScreenState extends State<ScoreboardPreviewScreen> {
  late GameEngine engine;

  @override
  void initState() {
    super.initState();
    _setupFakeGame();
  }

  void _setupFakeGame() {
    engine = GameEngine(roleRepository: MockRoleRepository());

    // --- Create Roles ---
    final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'desc',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#FF00FF',
        choices: [],
        hasBinaryChoiceAtStart: false);
    final partyRole = Role(
        id: 'party_animal',
        name: 'Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'desc',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
        choices: [],
        hasBinaryChoiceAtStart: false);
    final medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'desc',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#FF0000',
        choices: ['PROTECT'],
        hasBinaryChoiceAtStart: true);

    // --- Create Players ---
    final p1 = Player(id: 'p1', name: 'Indecisive Ian', role: partyRole);
    final p2 = Player(id: 'p2', name: 'Target Tim', role: partyRole);
    final p3 = Player(id: 'p3', name: 'Judge Judy', role: dealerRole);
    final p4 = Player(id: 'p4', name: 'Victim Vince', role: partyRole);
    final p5 = Player(id: 'p5', name: 'Medic Mike', role: medicRole);

    // Add them to the engine (bypassing normal flow)
    engine.players.clear();
    engine.players.addAll([p1, p2, p3, p4, p5]);
    engine.dayCount = 2;

    // 1. "The Flip-Flopper": Ian changes vote 3 times on day 1
    engine.voteChanges.add(VoteCast(
        day: 1,
        voterId: 'p1',
        targetId: 'p2',
        timestamp: DateTime.now(),
        sequence: 0));
    engine.voteChanges.add(VoteCast(
        day: 1,
        voterId: 'p1',
        targetId: 'p3',
        timestamp: DateTime.now(),
        sequence: 1));
    engine.voteChanges.add(VoteCast(
        day: 1,
        voterId: 'p1',
        targetId: 'p4',
        timestamp: DateTime.now(),
        sequence: 2));

    // 2. "Public Enemy #1": Tim gets targeted at night
    engine.nightHistory
        .add({'kill': 'p2', 'protect': 'p2'}); // Targeted + Saved
    engine.nightHistory.add({'check_id': 'p2'}); // Checked
    engine.nightHistory.add({'silence': 'p2'}); // Silenced

    // 3. "The Guardian Angel": Medic Mike (p5) protected Tim (p2) when targeted
    // (Logic checks if 'protect' and 'kill' targets match in a night history entry)
    // The entry added above `{'kill': 'p2', 'protect': 'p2'}` should trigger this if tracker logic is correct.
    // NOTE: Tracker logic might need to identify WHO is the medic. It scans for Role 'medic'.
    // Medic Mike has 'medic' role.

    // 4. "The Executioner": Judy votes for the eliminated player (Vince)
    // We need votesByDay to compute 'p4' (Vince) as the loser of Day 1.
    engine.voteHistory.add(VoteCast(
        day: 1,
        voterId: 'p1',
        targetId: 'p4',
        timestamp: DateTime.now(),
        sequence: 10)); // Ian -> Vince
    engine.voteHistory.add(VoteCast(
        day: 1,
        voterId: 'p3',
        targetId: 'p4',
        timestamp: DateTime.now(),
        sequence: 11)); // Judy -> Vince
    engine.voteHistory.add(VoteCast(
        day: 1,
        voterId: 'p2',
        targetId: 'p4',
        timestamp: DateTime.now(),
        sequence: 12)); // Tim -> Vince
    // Vince -> Judy
    engine.voteHistory.add(VoteCast(
        day: 1,
        voterId: 'p4',
        targetId: 'p3',
        timestamp: DateTime.now(),
        sequence: 13));

    // 5. "Friendly Fire Champion": Ian (Party) voting for Tim (Party) initially?
    // engine.voteChanges tracks changes, but standard awards scan `votesByDay` (final vote).
    // Final vote for Ian on Day 1 is Vince (Party). So Ian voted for Party.
    // Vince is Party. So Ian gets a Friendly Fire point for Day 1.
    // We need 2 points for the award.
    // Day 2: Ian votes for Medic Mike (Party).
    engine.voteHistory.add(VoteCast(
        day: 2,
        voterId: 'p1',
        targetId: 'p5',
        timestamp: DateTime.now(),
        sequence: 20));

    // Note: GameEngine exposes `winner`/`winMessage` as getters; for this
    // preview we rely on the scoreboard fallback text.
    // Force a UI update just in case
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scoreboard Preview')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Press the button to simulate End of Game',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('SHOW SCOREBOARD'),
              style: ClubBlackoutTheme.neonButtonStyle(
                ClubBlackoutTheme.neonGreen,
                isPrimary: true,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => GameScoreboard(
                    gameEngine: engine,
                    onRestart: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restart clicked!')),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
