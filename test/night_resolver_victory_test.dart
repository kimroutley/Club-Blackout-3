import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver Victory Parity', () {
    test('Dealers achieve parity when killing last extra Party Animal', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Test dealer',
        nightPriority: 5,
        assetPath: 'test/path',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Test party animal',
        nightPriority: 0,
        assetPath: 'test/path',
        colorHex: '#FFDAB9',
      );
      
      // Setup: 2 Dealers, 3 Party Animals (Dealers need to kill 1 to reach parity)
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: partyAnimalRole);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: partyAnimalRole);
      final pa3 = Player(id: 'pa3', name: 'PA3', role: partyAnimalRole);
      
      final players = [dealer1, dealer2, pa1, pa2, pa3];
      
      // Both dealers vote to kill PA1
      final actions = [
        NightAction(playerId: dealer1.id, actionType: 'kill', targetId: pa1.id),
        NightAction(playerId: dealer2.id, actionType: 'kill', targetId: pa1.id),
      ];
      
      final resolver = NightResolver();
      final deaths = resolver.resolve(players, actions);
      
      // Verify: PA1 dies
      expect(deaths.length, 1);
      expect(deaths.contains(pa1.id), true);
      expect(pa1.isAlive, false);
      
      // Check parity: count alive players by alliance
      final aliveDealers = players.where((p) => p.isAlive && p.role.alliance == 'The Dealers').length;
      final alivePartyAnimals = players.where((p) => p.isAlive && p.role.alliance == 'The Party Animals').length;
      
      // After kill: 2 Dealers alive, 2 Party Animals alive = parity achieved
      expect(aliveDealers, 2);
      expect(alivePartyAnimals, 2);
      expect(aliveDealers, alivePartyAnimals);
    });
    
    test('Dealer kill vote uses lexicographic tie-breaking', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Test dealer',
        nightPriority: 5,
        assetPath: 'test/path',
        colorHex: '#FF00FF',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Test party animal',
        nightPriority: 0,
        assetPath: 'test/path',
        colorHex: '#FFDAB9',
      );
      
      // Setup: 2 Dealers, 3 Party Animals with specific names for tie-breaking
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole);
      final zebra = Player(id: 'z1', name: 'Zebra', role: partyAnimalRole); // Last alphabetically
      final apple = Player(id: 'a1', name: 'Apple', role: partyAnimalRole); // First alphabetically
      final mango = Player(id: 'm1', name: 'Mango', role: partyAnimalRole); // Middle
      
      final players = [dealer1, dealer2, zebra, apple, mango];
      
      // Dealers split vote (1 vote each for Zebra and Apple)
      final actions = [
        NightAction(playerId: dealer1.id, actionType: 'kill', targetId: zebra.id),
        NightAction(playerId: dealer2.id, actionType: 'kill', targetId: apple.id),
      ];
      
      final resolver = NightResolver();
      final deaths = resolver.resolve(players, actions);
      
      // Verify: Apple dies (comes first alphabetically in tie)
      expect(deaths.length, 1);
      expect(deaths.contains(apple.id), true);
      expect(apple.isAlive, false);
      expect(zebra.isAlive, true);
      expect(mango.isAlive, true);
    });
    
    test('Sober sending Dealer home prevents all kills', () {
      final dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Test dealer',
        nightPriority: 5,
        assetPath: 'test/path',
        colorHex: '#FF00FF',
      );
      
      final soberRole = Role(
        id: 'sober',
        name: 'The Sober',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Test sober',
        nightPriority: 1,
        assetPath: 'test/path',
        colorHex: '#00FF00',
      );
      
      final partyAnimalRole = Role(
        id: 'party_animal',
        name: 'The Party Animal',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Test party animal',
        nightPriority: 0,
        assetPath: 'test/path',
        colorHex: '#FFDAB9',
      );
      
      // Setup
      final dealer = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final sober = Player(id: 's1', name: 'Sober1', role: soberRole);
      final victim = Player(id: 'v1', name: 'Victim1', role: partyAnimalRole);
      
      final players = [dealer, sober, victim];
      
      // Actions: Dealer tries to kill victim, Sober sends dealer home
      final actions = [
        NightAction(playerId: dealer.id, actionType: 'kill', targetId: victim.id),
        NightAction(playerId: sober.id, actionType: 'send_home', targetId: dealer.id),
      ];
      
      final resolver = NightResolver();
      final deaths = resolver.resolve(players, actions);
      
      // Verify: No deaths because Sober sent a Dealer home
      expect(deaths.isEmpty, true);
      expect(victim.isAlive, true);
      expect(dealer.isAlive, true);
    });
  });
}
