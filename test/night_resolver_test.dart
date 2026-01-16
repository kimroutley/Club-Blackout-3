import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver', () {
    late Role dealerRole;
    late Role medicRole;
    late Role partyAnimalRole;

    setUp(() {
      // Create minimal role objects for testing
      dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'Killer',
        description: 'Kill one Party Animal each night',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF0000',
      );

      medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'Protector',
        description: 'Protect players from death',
        nightPriority: 2,
        assetPath: '',
        colorHex: '#00FF00',
      );

      partyAnimalRole = Role(
        id: 'party_animal',
        name: 'Party Animal',
        alliance: 'The Party Animals',
        type: 'Villager',
        description: 'No special abilities',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#0000FF',
      );
    });

    test('Medic protection prevents Dealer kill', () {
      // Create test players
      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer One',
        role: dealerRole,
        isAlive: true,
      );

      final medic = Player(
        id: 'medic1',
        name: 'Medic One',
        role: medicRole,
        isAlive: true,
        medicChoice: 'PROTECT_DAILY',
      );

      final target = Player(
        id: 'target1',
        name: 'Target One',
        role: partyAnimalRole,
        isAlive: true,
      );

      final players = [dealer, medic, target];

      // Create night actions: Medic protects target, Dealer kills target
      final actions = [
        NightAction(
          roleId: 'medic',
          sourcePlayerId: medic.id,
          targetPlayerId: target.id,
          actionType: 'protect',
          priority: 3,
        ),
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer.id,
          targetPlayerId: target.id,
          actionType: 'kill',
          priority: 5,
        ),
      ];

      // Resolve night
      final result = NightResolver.resolve(players, actions);

      // Target should not die (protected by medic)
      expect(result.deadPlayerIds, isEmpty);
      expect(result.metadata['protected_${target.id}'], 'true');
      expect(result.metadata['kill_target'], target.id);
    });

    test('Dealer kill succeeds when target is not protected', () {
      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer One',
        role: dealerRole,
        isAlive: true,
      );

      final target = Player(
        id: 'target1',
        name: 'Target One',
        role: partyAnimalRole,
        isAlive: true,
      );

      final players = [dealer, target];

      final actions = [
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer.id,
          targetPlayerId: target.id,
          actionType: 'kill',
          priority: 5,
        ),
      ];

      final result = NightResolver.resolve(players, actions);

      // Target should die (not protected)
      expect(result.deadPlayerIds, contains(target.id));
      expect(result.metadata['kill_target'], target.id);
    });

    test('Sober sending Dealer home cancels all kills', () {
      final soberRole = Role(
        id: 'sober',
        name: 'The Sober',
        alliance: 'The Party Animals',
        type: 'Protector',
        description: 'Send one player home',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#FFFF00',
      );

      final sober = Player(
        id: 'sober1',
        name: 'Sober One',
        role: soberRole,
        isAlive: true,
      );

      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer One',
        role: dealerRole,
        isAlive: true,
      );

      final target = Player(
        id: 'target1',
        name: 'Target One',
        role: partyAnimalRole,
        isAlive: true,
      );

      final players = [sober, dealer, target];

      final actions = [
        NightAction(
          roleId: 'sober',
          sourcePlayerId: sober.id,
          targetPlayerId: dealer.id,
          actionType: 'send_home',
          priority: 1,
        ),
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer.id,
          targetPlayerId: target.id,
          actionType: 'kill',
          priority: 5,
        ),
      ];

      final result = NightResolver.resolve(players, actions);

      // No one should die (dealer was sent home, cancelling kill)
      expect(result.deadPlayerIds, isEmpty);
      expect(result.metadata['dealer_sent_home'], 'true');
      expect(result.metadata['dealer_kill_cancelled'], 'true');
    });

    test('Multiple dealers vote for same target deterministically', () {
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer One',
        role: dealerRole,
        isAlive: true,
      );

      final dealer2 = Player(
        id: 'dealer2',
        name: 'Dealer Two',
        role: dealerRole,
        isAlive: true,
      );

      final target = Player(
        id: 'target1',
        name: 'Target One',
        role: partyAnimalRole,
        isAlive: true,
      );

      final players = [dealer1, dealer2, target];

      final actions = [
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer1.id,
          targetPlayerId: target.id,
          actionType: 'kill',
          priority: 5,
        ),
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer2.id,
          targetPlayerId: target.id,
          actionType: 'kill',
          priority: 5,
        ),
      ];

      final result = NightResolver.resolve(players, actions);

      // Target should die (both dealers voted for same target)
      expect(result.deadPlayerIds, contains(target.id));
      expect(result.metadata['kill_target'], target.id);
    });

    test('Tie-breaking is lexical when dealers vote for different targets', () {
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer One',
        role: dealerRole,
        isAlive: true,
      );

      final dealer2 = Player(
        id: 'dealer2',
        name: 'Dealer Two',
        role: dealerRole,
        isAlive: true,
      );

      final targetA = Player(
        id: 'zzz_target',
        name: 'Target ZZZ',
        role: partyAnimalRole,
        isAlive: true,
      );

      final targetB = Player(
        id: 'aaa_target',
        name: 'Target AAA',
        role: partyAnimalRole,
        isAlive: true,
      );

      final players = [dealer1, dealer2, targetA, targetB];

      final actions = [
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer1.id,
          targetPlayerId: targetA.id,
          actionType: 'kill',
          priority: 5,
        ),
        NightAction(
          roleId: 'dealer',
          sourcePlayerId: dealer2.id,
          targetPlayerId: targetB.id,
          actionType: 'kill',
          priority: 5,
        ),
      ];

      final result = NightResolver.resolve(players, actions);

      // Should choose lexically first target (aaa_target)
      expect(result.deadPlayerIds, contains(targetB.id));
      expect(result.deadPlayerIds, isNot(contains(targetA.id)));
      expect(result.metadata['kill_target'], targetB.id);
    });
  });
}
