import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver Victory Parity Tests', () {
    late Role dealerRole;
    late Role partyAnimalRole;

    setUp(() {
      dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Killer',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );

      partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Citizen',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
    });

    test('Dealers reach parity - should be checked by caller', () {
      // Setup: 2 dealers, 2 party animals
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'dealer2', name: 'Dealer2', role: dealerRole);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final victim2 = Player(id: 'victim2', name: 'Victim2', role: partyAnimalRole);

      final players = [dealer1, dealer2, victim1, victim2];

      // Dealers kill one victim
      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
        NightAction(playerId: 'dealer2', actionType: 'dealer_kill', targetId: 'victim1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      expect(dead.contains('victim1'), true);
      expect(victim1.isAlive, false);

      // Count alive dealers vs party animals
      final aliveDealers = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Party Animals').length;

      // After this kill: 2 dealers vs 1 party animal
      expect(aliveDealers, 2);
      expect(alivePartyAnimals, 1);

      // Dealers have majority - victory condition
      // Note: NightResolver doesn't check victory, caller (GameEngine) does
      expect(aliveDealers >= alivePartyAnimals, true);
    });

    test('Dealers exact parity (equal numbers)', () {
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final victim2 = Player(id: 'victim2', name: 'Victim2', role: partyAnimalRole);

      final players = [dealer1, victim1, victim2];

      // Kill one victim to reach parity (1 dealer vs 1 party animal)
      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      expect(dead.contains('victim1'), true);

      final aliveDealers = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Party Animals').length;

      expect(aliveDealers, 1);
      expect(alivePartyAnimals, 1);

      // Parity reached - dealers win
      expect(aliveDealers >= alivePartyAnimals, true);
    });

    test('All dealers eliminated - party animals win', () {
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole, isAlive: false);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final victim2 = Player(id: 'victim2', name: 'Victim2', role: partyAnimalRole);

      final players = [dealer1, victim1, victim2];

      // No night actions - just check status
      final dead = NightResolver.resolve(players, []);

      final aliveDealers = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Party Animals').length;

      expect(aliveDealers, 0);
      expect(alivePartyAnimals, 2);

      // Party animals win
      expect(aliveDealers, 0);
    });

    test('Multiple kills in one night affects parity', () {
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'dealer2', name: 'Dealer2', role: dealerRole);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final victim2 = Player(id: 'victim2', name: 'Victim2', role: partyAnimalRole);
      final victim3 = Player(id: 'victim3', name: 'Victim3', role: partyAnimalRole);

      final players = [dealer1, dealer2, victim1, victim2, victim3];

      // Dealers vote for victim1
      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
        NightAction(playerId: 'dealer2', actionType: 'dealer_kill', targetId: 'victim1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      expect(dead.length, 1);
      expect(dead.contains('victim1'), true);

      final aliveDealers = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Party Animals').length;

      expect(aliveDealers, 2);
      expect(alivePartyAnimals, 2);

      // Exact parity - dealers win
      expect(aliveDealers >= alivePartyAnimals, true);
    });

    test('Parity calculation excludes dead players', () {
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'dealer2', name: 'Dealer2', role: dealerRole, isAlive: false);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final victim2 = Player(id: 'victim2', name: 'Victim2', role: partyAnimalRole);
      final victim3 = Player(id: 'victim3', name: 'Victim3', role: partyAnimalRole, isAlive: false);

      final players = [dealer1, dealer2, victim1, victim2, victim3];

      // One dealer alive, two party animals alive
      final aliveDealers = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Party Animals').length;

      expect(aliveDealers, 1);
      expect(alivePartyAnimals, 2);

      // Party animals still have majority
      expect(aliveDealers >= alivePartyAnimals, false);
    });

    test('Victory parity with neutral roles excluded', () {
      final neutralRole = Role(
        id: 'neutral',
        name: 'Neutral',
        alliance: 'Neutral',
        type: 'neutral',
        description: 'Neutral',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#CCCCCC',
      );

      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final neutral1 = Player(id: 'neutral1', name: 'Neutral1', role: neutralRole);

      final players = [dealer1, victim1, neutral1];

      // Count only dealers vs party animals (exclude neutrals)
      final aliveDealers = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => 
          p.isAlive && p.role.alliance == 'The Party Animals').length;

      expect(aliveDealers, 1);
      expect(alivePartyAnimals, 1);

      // Parity reached despite neutral being alive
      expect(aliveDealers >= alivePartyAnimals, true);
    });
  });
}
