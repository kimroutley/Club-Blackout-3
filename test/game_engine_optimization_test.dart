import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  const sharedPrefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sharedPrefsChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getAll') {
      return <String, dynamic>{};
    }
    return null;
  });

  group('GameEngine Optimization - eligibleDayVotesByTarget', () {
    late GameEngine engine;
    late Role partyRole;

    setUp(() {
      engine = GameEngine(roleRepository: RoleRepository());
      partyRole = Role(
        id: 'party_animal',
        name: 'Party Animal',
        alliance: 'The Party Animals',
        type: 'basic',
        description: 'Just vibing',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      );
      engine.players.clear();
      engine.clearDayVotes();
    });

    test('correctly filters votes', () {
      final p1 = Player(id: 'p1', name: 'Player 1', role: partyRole)..initialize();
      final p2 = Player(id: 'p2', name: 'Player 2', role: partyRole)..initialize();
      final p3 = Player(id: 'p3', name: 'Player 3', role: partyRole)..initialize();

      // p4 is sent home (ineligible voter)
      final p4 = Player(id: 'p4', name: 'Player 4', role: partyRole)..initialize();
      p4.soberSentHome = true;

      engine.players.addAll([p1, p2, p3, p4]);

      // p1 votes for p2
      engine.currentDayVotesByVoter[p1.id] = p2.id;
      engine.currentDayVotesByTarget[p2.id] = [p1.id];

      // p4 votes for p2 (should be ignored in eligible)
      engine.currentDayVotesByVoter[p4.id] = p2.id;
      engine.currentDayVotesByTarget[p2.id]!.add(p4.id);

      // p2 votes for p3
      engine.currentDayVotesByVoter[p2.id] = p3.id;
      engine.currentDayVotesByTarget[p3.id] = [p2.id];

      final eligible = engine.eligibleDayVotesByTarget;

      // Check p2 votes
      expect(eligible.containsKey(p2.id), isTrue);
      expect(eligible[p2.id]!.contains(p1.id), isTrue);
      expect(eligible[p2.id]!.contains(p4.id), isFalse); // p4 sent home

      // Check p3 votes
      expect(eligible.containsKey(p3.id), isTrue);
      expect(eligible[p3.id]!.contains(p2.id), isTrue);
    });

    test('ignores targets with alibi', () {
      final p1 = Player(id: 'p1', name: 'Player 1', role: partyRole)..initialize();
      final p2 = Player(id: 'p2', name: 'Player 2', role: partyRole)..initialize();

      // p2 has alibi
      p2.alibiDay = engine.dayCount;

      engine.players.addAll([p1, p2]);

      // p1 votes for p2
      engine.currentDayVotesByVoter[p1.id] = p2.id;
      engine.currentDayVotesByTarget[p2.id] = [p1.id];

      final eligible = engine.eligibleDayVotesByTarget;

      // p2 should not be in the result because of alibi
      expect(eligible.containsKey(p2.id), isFalse);
    });
  });
}
