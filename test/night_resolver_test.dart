import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/logic/night_resolver.dart';

void main() {
  group('NightResolver', () {
    test('Dealer kills target when no protection exists', () {
      // Create roles
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill players',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );

      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Survive',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );

      // Create players
      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final victim = Player(
        id: 'victim1',
        name: 'Victim Val',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer, victim];

      // Create night actions
      final actions = [
        NightAction(
          roleId: 'dealer',
          targetId: 'victim1',
          actionType: 'kill',
        ),
      ];

      // Resolve night
      final resolver = NightResolver();
      final result = resolver.resolve(players, actions);

      // Verify victim was killed
      expect(result.killedPlayerIds, contains('victim1'));
      expect(result.protectedPlayerIds, isEmpty);
      expect(result.messages['victim1'], contains('Killed'));
    });

    test('Medic protects target from Dealer kill', () {
      // Create roles
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill players',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );

      final medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Protect players',
        nightPriority: 2,
        assetPath: '',
        colorHex: '#FF0000',
      );

      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Survive',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );

      // Create players
      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final medic = Player(
        id: 'medic1',
        name: 'Medic Mary',
        role: medicRole,
        isAlive: true,
        isEnabled: true,
        medicChoice: 'PROTECT_DAILY',
      );

      final target = Player(
        id: 'target1',
        name: 'Target Tom',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer, medic, target];

      // Create night actions: Medic protects target, Dealer tries to kill target
      final actions = [
        NightAction(
          roleId: 'medic',
          targetId: 'target1',
          actionType: 'protect',
        ),
        NightAction(
          roleId: 'dealer',
          targetId: 'target1',
          actionType: 'kill',
        ),
      ];

      // Resolve night
      final resolver = NightResolver();
      final result = resolver.resolve(players, actions);

      // Verify target was protected and NOT killed
      expect(result.killedPlayerIds, isEmpty);
      expect(result.protectedPlayerIds, contains('target1'));
      expect(result.messages['target1'], contains('protected') | contains('blocked'));
    });

    test('Sober sends Dealer home and blocks all kills', () {
      // Create roles
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill players',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );

      final soberRole = Role(
        id: 'sober',
        name: 'The Sober',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Send someone home',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#00FF00',
      );

      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Survive',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );

      // Create players
      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final sober = Player(
        id: 'sober1',
        name: 'Sober Sam',
        role: soberRole,
        isAlive: true,
        isEnabled: true,
      );

      final victim = Player(
        id: 'victim1',
        name: 'Victim Val',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer, sober, victim];

      // Create night actions: Sober sends dealer home, Dealer tries to kill victim
      final actions = [
        NightAction(
          roleId: 'sober',
          targetId: 'dealer1',
          actionType: 'send_home',
        ),
        NightAction(
          roleId: 'dealer',
          targetId: 'victim1',
          actionType: 'kill',
        ),
      ];

      // Resolve night
      final resolver = NightResolver();
      final result = resolver.resolve(players, actions);

      // Verify NO kills happened (dealer was sent home)
      expect(result.killedPlayerIds, isEmpty);
      expect(result.protectedPlayerIds, contains('dealer1'));
      expect(result.messages['victim1'], contains('blocked') | contains('Dealer sent home'));
    });

    test('Minor immunity blocks Dealer kill until ID checked', () {
      // Create roles
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill players',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );

      final minorRole = Role(
        id: 'minor',
        name: 'The Minor',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Immune until ID checked',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFF00',
      );

      // Create players
      final dealer = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final minor = Player(
        id: 'minor1',
        name: 'Minor Mindy',
        role: minorRole,
        isAlive: true,
        isEnabled: true,
        minorHasBeenIDd: false, // Not yet ID'd
      );

      final players = [dealer, minor];

      // Create night actions: Dealer tries to kill Minor
      final actions = [
        NightAction(
          roleId: 'dealer',
          targetId: 'minor1',
          actionType: 'kill',
        ),
      ];

      // Resolve night
      final resolver = NightResolver();
      final result = resolver.resolve(players, actions);

      // Verify Minor was NOT killed (immunity)
      expect(result.killedPlayerIds, isEmpty);
      expect(result.messages['minor1'], contains('Minor immunity') | contains('blocked'));
    });
  });
}
