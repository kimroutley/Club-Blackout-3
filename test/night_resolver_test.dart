import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver', () {
    test('Medic protect prevents Dealer kill', () {
      // Create minimal roles for testing
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
      
      final medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Test medic',
        nightPriority: 1,
        assetPath: 'test/path',
        colorHex: '#FF0000',
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
      
      // Setup: 1 Dealer, 1 Medic, 1 Party Animal
      final dealer = Player(
        id: 'd1',
        name: 'Dealer1',
        role: dealerRole,
      );
      
      final medic = Player(
        id: 'm1',
        name: 'Medic1',
        role: medicRole,
      );
      
      final victim = Player(
        id: 'v1',
        name: 'Victim1',
        role: partyAnimalRole,
      );
      
      final players = [dealer, medic, victim];
      
      // Actions: Dealer kills victim, Medic protects victim
      final actions = [
        NightAction(playerId: dealer.id, actionType: 'kill', targetId: victim.id),
        NightAction(playerId: medic.id, actionType: 'protect', targetId: victim.id),
      ];
      
      final resolver = NightResolver();
      final deaths = resolver.resolve(players, actions);
      
      // Verify: No deaths because Medic protected the victim
      expect(deaths.isEmpty, true);
      expect(victim.isAlive, true);
      expect(dealer.isAlive, true);
      expect(medic.isAlive, true);
    });
    
    test('Dealer kill succeeds when Medic protects different player', () {
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
      
      final medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Test medic',
        nightPriority: 1,
        assetPath: 'test/path',
        colorHex: '#FF0000',
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
      
      final dealer = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final medic = Player(id: 'm1', name: 'Medic1', role: medicRole);
      final victim = Player(id: 'v1', name: 'Victim1', role: partyAnimalRole);
      final otherPlayer = Player(id: 'o1', name: 'Other1', role: partyAnimalRole);
      
      final players = [dealer, medic, victim, otherPlayer];
      
      // Actions: Dealer kills victim, Medic protects other player
      final actions = [
        NightAction(playerId: dealer.id, actionType: 'kill', targetId: victim.id),
        NightAction(playerId: medic.id, actionType: 'protect', targetId: otherPlayer.id),
      ];
      
      final resolver = NightResolver();
      final deaths = resolver.resolve(players, actions);
      
      // Verify: Victim dies because Medic protected someone else
      expect(deaths.length, 1);
      expect(deaths.contains(victim.id), true);
      expect(victim.isAlive, false);
      expect(otherPlayer.isAlive, true);
    });
  });
}
