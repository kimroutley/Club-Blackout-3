import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('Victory Parity Checks', () {
    late Role dealerRole;
    late Role partyAnimalRole;

    setUp(() {
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

    /// Helper to check victory based on parity
    /// Mirrors the engine's victory check logic
    String? checkVictory(List<Player> players) {
      final alivePlayers = players.where((p) => p.isAlive).toList();

      if (alivePlayers.isEmpty) {
        return 'NONE';
      }

      final dealerCount = alivePlayers
          .where((p) => p.alliance == 'The Dealers')
          .length;
      final partyAnimalCount = alivePlayers
          .where((p) => p.alliance == 'The Party Animals')
          .length;

      // Party Animals win if all Dealers are dead
      if (dealerCount == 0 && partyAnimalCount > 0) {
        return 'PARTY_ANIMAL';
      }

      // Dealers win if they reach parity (equal or greater numbers)
      if (dealerCount >= partyAnimalCount && dealerCount > 0) {
        return 'DEALER';
      }

      return null; // Game continues
    }

    test('Party Animals win when all Dealers are eliminated', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: true),
        Player(id: '2', name: 'PA2', role: partyAnimalRole, isAlive: true),
        Player(id: '3', name: 'PA3', role: partyAnimalRole, isAlive: true),
        Player(id: '4', name: 'D1', role: dealerRole, isAlive: false),
      ];

      final winner = checkVictory(players);
      expect(winner, 'PARTY_ANIMAL');
    });

    test('Dealers win when they reach parity (2v2)', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: true),
        Player(id: '2', name: 'PA2', role: partyAnimalRole, isAlive: true),
        Player(id: '3', name: 'D1', role: dealerRole, isAlive: true),
        Player(id: '4', name: 'D2', role: dealerRole, isAlive: true),
      ];

      final winner = checkVictory(players);
      expect(winner, 'DEALER');
    });

    test('Dealers win when they outnumber Party Animals (3v2)', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: true),
        Player(id: '2', name: 'PA2', role: partyAnimalRole, isAlive: true),
        Player(id: '3', name: 'D1', role: dealerRole, isAlive: true),
        Player(id: '4', name: 'D2', role: dealerRole, isAlive: true),
        Player(id: '5', name: 'D3', role: dealerRole, isAlive: true),
      ];

      final winner = checkVictory(players);
      expect(winner, 'DEALER');
    });

    test('Game continues when Party Animals outnumber Dealers (4v1)', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: true),
        Player(id: '2', name: 'PA2', role: partyAnimalRole, isAlive: true),
        Player(id: '3', name: 'PA3', role: partyAnimalRole, isAlive: true),
        Player(id: '4', name: 'PA4', role: partyAnimalRole, isAlive: true),
        Player(id: '5', name: 'D1', role: dealerRole, isAlive: true),
      ];

      final winner = checkVictory(players);
      expect(winner, isNull);
    });

    test('No winner when everyone is dead', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: false),
        Player(id: '2', name: 'D1', role: dealerRole, isAlive: false),
      ];

      final winner = checkVictory(players);
      expect(winner, 'NONE');
    });

    test('Dealers win at exact parity (1v1)', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: true),
        Player(id: '2', name: 'D1', role: dealerRole, isAlive: true),
      ];

      final winner = checkVictory(players);
      expect(winner, 'DEALER');
    });

    test('Game continues when Party Animals have majority (3v1)', () {
      final players = [
        Player(id: '1', name: 'PA1', role: partyAnimalRole, isAlive: true),
        Player(id: '2', name: 'PA2', role: partyAnimalRole, isAlive: true),
        Player(id: '3', name: 'PA3', role: partyAnimalRole, isAlive: true),
        Player(id: '4', name: 'D1', role: dealerRole, isAlive: true),
      ];

      final winner = checkVictory(players);
      expect(winner, isNull);
    });
  });
}
