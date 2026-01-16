import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver Victory Conditions', () {
    late NightResolver resolver;
    
    setUp(() {
      resolver = NightResolver();
    });
    
    test('Dealers win at parity (equal numbers)', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill role',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Passive role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
      
      // 2 Dealers vs 2 Party Animals = parity
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      
      final players = [dealer1, dealer2, pa1, pa2];
      
      final result = resolver.checkVictory(players);
      
      expect(result, 'dealers', reason: 'Dealers should win at parity');
    });
    
    test('Dealers win when outnumbering party animals', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill role',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Passive role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
      
      // 3 Dealers vs 2 Party Animals
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole);
      final dealer3 = Player(id: 'd3', name: 'Dealer3', role: dealerRole);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      
      final players = [dealer1, dealer2, dealer3, pa1, pa2];
      
      final result = resolver.checkVictory(players);
      
      expect(result, 'dealers', reason: 'Dealers should win when outnumbering');
    });
    
    test('Party Animals win when all Dealers are dead', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill role',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Passive role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
      
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole, isAlive: false);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      
      final players = [dealer1, pa1, pa2];
      
      final result = resolver.checkVictory(players);
      
      expect(result, 'party_animals', reason: 'Party Animals should win when no Dealers alive');
    });
    
    test('No winner when Dealers outnumbered', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill role',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Passive role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
      
      // 1 Dealer vs 3 Party Animals
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      final pa3 = Player(id: 'pa3', name: 'PA3', role: partyAnimalRole);
      
      final players = [dealer1, pa1, pa2, pa3];
      
      final result = resolver.checkVictory(players);
      
      expect(result, null, reason: 'Game should continue when Dealers are outnumbered');
    });
    
    test('Whore counts toward Dealer victory', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill role',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      
      final whoreRole = Role(
        id: 'whore',
        name: 'The Whore',
        alliance: 'The Dealers',
        type: 'defensive',
        description: 'Support role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#008080',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Passive role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
      
      // 1 Dealer + 1 Whore vs 2 Party Animals = parity
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final whore = Player(id: 'w1', name: 'Whore1', role: whoreRole);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      
      final players = [dealer1, whore, pa1, pa2];
      
      final result = resolver.checkVictory(players);
      
      expect(result, 'dealers', reason: 'Whore should count toward Dealer parity');
    });
    
    test('Victory check ignores dead players', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill role',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Passive role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFDAB9',
      );
      
      // 2 Dealers (1 dead) vs 3 Party Animals (1 dead) = 1v2, no parity
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole, isAlive: false);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      final pa3 = Player(id: 'pa3', name: 'PA3', role: partyAnimalRole, isAlive: false);
      
      final players = [dealer1, dealer2, pa1, pa2, pa3];
      
      final result = resolver.checkVictory(players);
      
      expect(result, null, reason: 'Should only count alive players for victory');
    });
  });
}
