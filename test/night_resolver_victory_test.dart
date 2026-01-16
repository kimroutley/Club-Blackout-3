import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/logic/night_resolver.dart';

void main() {
  group('NightResolver Victory Conditions', () {
    test('Dealers win when they reach parity with Party Animals', () {
      // Create roles
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill players',
        nightPriority: 5,
        assetPath: 'test/path',
        colorHex: '#FF00FF',
      );

      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Survive',
        nightPriority: 0,
        assetPath: 'test/path',
        colorHex: '#FFDAB9',
      );

      // Create scenario: 2 dealers, 2 party animals (parity)
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final dealer2 = Player(
        id: 'dealer2',
        name: 'Dealer Dee',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal1 = Player(
        id: 'pa1',
        name: 'Party Animal Pete',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal2 = Player(
        id: 'pa2',
        name: 'Party Animal Pat',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer1, dealer2, partyAnimal1, partyAnimal2];

      // Check victory condition
      final resolver = NightResolver();
      final dealersWin = resolver.checkDealerVictory(players);

      // Verify dealers win at parity
      expect(dealersWin, isTrue);
    });

    test('Dealers win when they outnumber Party Animals', () {
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

      // Create scenario: 3 dealers, 2 party animals (dealers have majority)
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final dealer2 = Player(
        id: 'dealer2',
        name: 'Dealer Dee',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final dealer3 = Player(
        id: 'dealer3',
        name: 'Dealer Dave',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal1 = Player(
        id: 'pa1',
        name: 'Party Animal Pete',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal2 = Player(
        id: 'pa2',
        name: 'Party Animal Pat',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer1, dealer2, dealer3, partyAnimal1, partyAnimal2];

      // Check victory condition
      final resolver = NightResolver();
      final dealersWin = resolver.checkDealerVictory(players);

      // Verify dealers win with majority
      expect(dealersWin, isTrue);
    });

    test('Party Animals win when all Dealers are dead', () {
      // Create roles
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill players',
        nightPriority: 5,
        assetPath: 'test/path',
        colorHex: '#FF00FF',
      );

      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Survive',
        nightPriority: 0,
        assetPath: 'test/path',
        colorHex: '#FFDAB9',
      );

      // Create scenario: 1 dead dealer, 3 alive party animals
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: false, // Dead
        isEnabled: true,
      );

      final partyAnimal1 = Player(
        id: 'pa1',
        name: 'Party Animal Pete',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal2 = Player(
        id: 'pa2',
        name: 'Party Animal Pat',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal3 = Player(
        id: 'pa3',
        name: 'Party Animal Pam',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer1, partyAnimal1, partyAnimal2, partyAnimal3];

      // Check victory condition
      final resolver = NightResolver();
      final partyAnimalsWin = resolver.checkPartyAnimalVictory(players);

      // Verify party animals win when all dealers are dead
      expect(partyAnimalsWin, isTrue);
    });

    test('Game continues when Party Animals outnumber Dealers', () {
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

      // Create scenario: 1 dealer, 4 party animals (game continues)
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal1 = Player(
        id: 'pa1',
        name: 'Party Animal Pete',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal2 = Player(
        id: 'pa2',
        name: 'Party Animal Pat',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal3 = Player(
        id: 'pa3',
        name: 'Party Animal Pam',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal4 = Player(
        id: 'pa4',
        name: 'Party Animal Paul',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer1, partyAnimal1, partyAnimal2, partyAnimal3, partyAnimal4];

      // Check victory conditions
      final resolver = NightResolver();
      final dealersWin = resolver.checkDealerVictory(players);
      final partyAnimalsWin = resolver.checkPartyAnimalVictory(players);

      // Verify neither side has won yet
      expect(dealersWin, isFalse);
      expect(partyAnimalsWin, isFalse);
    });

    test('Victory check handles disabled players correctly', () {
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

      // Create scenario: 2 dealers, 2 party animals, but 1 dealer is disabled
      final dealer1 = Player(
        id: 'dealer1',
        name: 'Dealer Dan',
        role: dealerRole,
        isAlive: true,
        isEnabled: true,
      );

      final dealer2 = Player(
        id: 'dealer2',
        name: 'Dealer Dee',
        role: dealerRole,
        isAlive: true,
        isEnabled: false, // Disabled
      );

      final partyAnimal1 = Player(
        id: 'pa1',
        name: 'Party Animal Pete',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final partyAnimal2 = Player(
        id: 'pa2',
        name: 'Party Animal Pat',
        role: partyAnimalRole,
        isAlive: true,
        isEnabled: true,
      );

      final players = [dealer1, dealer2, partyAnimal1, partyAnimal2];

      // Check victory conditions (should only count enabled players)
      final resolver = NightResolver();
      final dealersWin = resolver.checkDealerVictory(players);
      final partyAnimalsWin = resolver.checkPartyAnimalVictory(players);

      // Verify game continues (1 dealer vs 2 party animals)
      expect(dealersWin, isFalse);
      expect(partyAnimalsWin, isFalse);
    });
  });
}
