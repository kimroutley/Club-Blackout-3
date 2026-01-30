import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/logic/shenanigans_tracker.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/models/vote_cast.dart'; // Added import
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock repository
class MockRoleRepository extends RoleRepository {
  @override
  Future<void> loadRoles() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sharedPrefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sharedPrefsChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getAll') {
      return <String, dynamic>{};
    }
    return null;
  });

  group('Shenanigans Tracker', () {
    late GameEngine engine;
    late Role villagerRole;

    Role createRole(String id) {
      return Role(
        id: id,
        name: id.toUpperCase(),
        description: 'Test Role $id',
        alliance: 'party_goer',
        type: 'active',
        nightPriority: 0,
        assetPath: 'assets/test.png', // Added
        colorHex: '0xFF00FF00', // Added
      );
    }

    setUp(() {
      villagerRole = createRole('villager');
      engine = GameEngine(roleRepository: MockRoleRepository());
    });

    test('Tracks Flip-Flopper', () {
      final p1 = Player(id: '1', name: 'Flipper', role: villagerRole);
      final p2 = Player(id: '2', name: 'Target', role: villagerRole);
      final p3 = Player(id: '3', name: 'Other', role: villagerRole);
      
      engine.players.addAll([p1, p2, p3]);
      engine.dayCount = 1;
      
      // Vote 1
      engine.recordVote(voterId: '1', targetId: '2');
      // Change to 3
      engine.recordVote(voterId: '1', targetId: '3');
      // Change back to 2
      engine.recordVote(voterId: '1', targetId: '2');
      
      final awards = ShenanigansTracker.generateAwards(engine);
      final flipper = awards.firstWhere((a) => a.title == 'The Flip-Flopper');
      
      expect(flipper.playerName, equals('Flipper'));
      expect(flipper.value, equals('2 times')); // 2 changes
    });
    
    test('Tracks Public Enemy #1', () {
       // Ideally we need to simulate night phases to populate nightHistory
       // But we can manually inject for unit testing the Tracker logic
       final p1 = Player(id: '1', name: 'Victim', role: villagerRole);
       engine.players.add(p1);
       
       engine.nightHistory.add({'kill': '1'});
       engine.nightHistory.add({'check_id': '1'});
       engine.nightHistory.add({'kill': '1'});
       
       final awards = ShenanigansTracker.generateAwards(engine);
       final enemy = awards.firstWhere((a) => a.title == 'Public Enemy #1');
       
       expect(enemy.playerName, equals('Victim'));
       expect(enemy.value, equals('3 visits'));
    });
    
    test('Tracks Nemesis Pair', () {
      final p1 = Player(id: '1', name: 'A', role: villagerRole);
      final p2 = Player(id: '2', name: 'B', role: villagerRole);
      engine.players.addAll([p1, p2]);
      
      // A votes B (3 times)
      engine.voteHistory.add(VoteCast(day: 1, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 1));
      engine.voteHistory.add(VoteCast(day: 2, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 2));
      engine.voteHistory.add(VoteCast(day: 3, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 3));
      
      // B votes A (1 time)
      engine.voteHistory.add(VoteCast(day: 2, voterId: '2', targetId: '1', timestamp: DateTime.now(), sequence: 4));
      
      final awards = ShenanigansTracker.generateAwards(engine);
      final nemesis = awards.firstWhere((a) => a.title == 'Nemesis Pair');
      
      expect(nemesis.value, equals('4 clashes'));
      expect(nemesis.playerName, contains('A'));
      expect(nemesis.playerName, contains('B'));
    });

    test('Tracks The Lone Wolf', () {
      final p1 = Player(id: '1', name: 'Wolf', role: villagerRole);
      final p2 = Player(id: '2', name: 'Other', role: villagerRole);
      final p3 = Player(id: '3', name: 'Target', role: villagerRole);
      final p4 = Player(id: '4', name: 'Popular', role: villagerRole);
      engine.players.addAll([p1, p2, p3, p4]);

      // Day 1: Wolf votes Target. Others vote Popular.
      engine.voteHistory.add(VoteCast(day: 1, voterId: '1', targetId: '3', timestamp: DateTime.now(), sequence: 1)); // Wolf -> Target (1 vote)
      engine.voteHistory.add(VoteCast(day: 1, voterId: '2', targetId: '4', timestamp: DateTime.now(), sequence: 2));
      engine.voteHistory.add(VoteCast(day: 1, voterId: '3', targetId: '4', timestamp: DateTime.now(), sequence: 3));

      // Day 2: Wolf votes Other. Others vote Popular.
      engine.voteHistory.add(VoteCast(day: 2, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 4)); // Wolf -> Other (1 vote)
      engine.voteHistory.add(VoteCast(day: 2, voterId: '3', targetId: '4', timestamp: DateTime.now(), sequence: 5));
      
      final awards = ShenanigansTracker.generateAwards(engine);
      final wolf = awards.firstWhere((a) => a.title == 'The Lone Wolf');
      expect(wolf.playerName, equals('Wolf'));
      expect(wolf.value, contains('2 times'));
    });

    test('Tracks The Detective', () {
      final partyRole = Role(
        id: 'party', name: 'Party', description: '', alliance: 'The Party Animals', type: 'a', nightPriority: 0, assetPath: '', colorHex: '000000', choices: const [], hasBinaryChoiceAtStart: false
      );
      final dealerRole = Role(
        id: 'dealer', name: 'Dealer', description: '', alliance: 'The Dealers', type: 'a', nightPriority: 0, assetPath: '', colorHex: '000000', choices: const [], hasBinaryChoiceAtStart: false
      );
      
      final p1 = Player(id: '1', name: 'Detective', role: partyRole); 
      // Need to force alliance update because Player copies from Role on init usually, 
      // or we just rely on p1.role.alliance if GameEngine isn't strictly running initialization logic in this Mock setup.
      // Wait, ShenanigansTracker uses p.alliance. Player.alliance is a field.
      // In this test setup, we just created Player(). alliance defaults?
      // Player constructor:
      // Player({required this.id, required this.name, required this.role}) : alliance = role.alliance;
      // Let's verify Player constructor.
      
      final d1 = Player(id: '2', name: 'BadGuy', role: dealerRole);
      
      engine.players.addAll([p1, d1]);
      
      engine.voteHistory.add(VoteCast(day: 1, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 1));
      engine.voteHistory.add(VoteCast(day: 2, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 2));
      
      final awards = ShenanigansTracker.generateAwards(engine);
      final detective = awards.firstWhere((a) => a.title == 'The Detective');
      expect(detective.playerName, equals('Detective'));
      expect(detective.value, contains('2 correct'));
    });

    test('Tracks The Executioner', () {
      final p1 = Player(id: '1', name: 'Exec', role: villagerRole);
      final p2 = Player(id: '2', name: 'Victim1', role: villagerRole);
      final p3 = Player(id: '3', name: 'Victim2', role: villagerRole);
      final p4 = Player(id: '4', name: 'Other', role: villagerRole);
      engine.players.addAll([p1, p2, p3, p4]);

      // Day 1: victim1 dies (3 votes)
      engine.voteHistory.add(VoteCast(day: 1, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 1)); // Exec -> V1
      engine.voteHistory.add(VoteCast(day: 1, voterId: '3', targetId: '2', timestamp: DateTime.now(), sequence: 2));
      engine.voteHistory.add(VoteCast(day: 1, voterId: '4', targetId: '2', timestamp: DateTime.now(), sequence: 3));
      
      // Day 2: victim2 dies (2 votes vs 1)
      engine.voteHistory.add(VoteCast(day: 2, voterId: '1', targetId: '3', timestamp: DateTime.now(), sequence: 4)); // Exec -> V2
      engine.voteHistory.add(VoteCast(day: 2, voterId: '2', targetId: '3', timestamp: DateTime.now(), sequence: 5)); // Victim1 (ghost?) -> V2
      engine.voteHistory.add(VoteCast(day: 2, voterId: '4', targetId: '1', timestamp: DateTime.now(), sequence: 6)); // Other -> Exec (wrong)
      
      final awards = ShenanigansTracker.generateAwards(engine);
      final exec = awards.firstWhere((a) => a.title == 'The Executioner');
      expect(exec.playerName, equals('Exec'));
      expect(exec.value, contains('2 kills'));
    });

    test('Tracks Friendly Fire Champion', () {
       // Party Animal targeting Party Animal
       final partyRole = Role(id: 'pa', name: 'PA', description: '', alliance: 'The Party Animals', type: 'a', nightPriority: 0, assetPath: '', colorHex: '', choices: const [], hasBinaryChoiceAtStart: false);
       final p1 = Player(id: '1', name: 'Traitor', role: partyRole);
       final p2 = Player(id: '2', name: 'Victim', role: partyRole);
       
       engine.players.addAll([p1, p2]);
       
       engine.voteHistory.add(VoteCast(day: 1, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 1));
       engine.voteHistory.add(VoteCast(day: 2, voterId: '1', targetId: '2', timestamp: DateTime.now(), sequence: 2));
       
       final awards = ShenanigansTracker.generateAwards(engine);
       final ff = awards.firstWhere((a) => a.title == 'Friendly Fire Champion');
       expect(ff.playerName, equals('Traitor')); 
    });
  });
}
