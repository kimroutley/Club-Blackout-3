import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver', () {
    late NightResolver resolver;
    
    setUp(() {
      resolver = NightResolver();
    });
    
    test('Medic protection prevents Dealer kill', () {
      // Create minimal roles
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
      
      final medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Protect role',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#FF0000',
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
      
      // Create players
      final dealer = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final medic = Player(id: 'm1', name: 'Medic1', role: medicRole);
      final target = Player(id: 't1', name: 'Target1', role: partyAnimalRole);
      
      final players = [dealer, medic, target];
      
      // Create actions: Dealer kills target, Medic protects target
      final actions = [
        NightAction(
          actorId: dealer.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: target.id,
          priority: 5,
        ),
        NightAction(
          actorId: medic.id,
          roleId: 'medic',
          actionType: 'protect',
          targetId: target.id,
          priority: 1,
        ),
      ];
      
      // Resolve
      final deaths = resolver.resolve(players, actions);
      
      // Assertions
      expect(deaths.isEmpty, true, reason: 'No one should die when Medic protects the target');
      expect(target.isAlive, true, reason: 'Target should be alive');
    });
    
    test('Dealer kill succeeds when no protection', () {
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
      
      final dealer = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final target = Player(id: 't1', name: 'Target1', role: partyAnimalRole);
      
      final players = [dealer, target];
      
      final actions = [
        NightAction(
          actorId: dealer.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: target.id,
          priority: 5,
        ),
      ];
      
      final deaths = resolver.resolve(players, actions);
      
      expect(deaths.length, 1);
      expect(deaths.contains(target.id), true);
      expect(target.isAlive, false);
    });
    
    test('Most-targeted player is killed (consensus)', () {
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
      
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole);
      final target1 = Player(id: 't1', name: 'Target1', role: partyAnimalRole);
      final target2 = Player(id: 't2', name: 'Target2', role: partyAnimalRole);
      
      final players = [dealer1, dealer2, target1, target2];
      
      // Both dealers target t1
      final actions = [
        NightAction(
          actorId: dealer1.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: target1.id,
          priority: 5,
        ),
        NightAction(
          actorId: dealer2.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: target1.id,
          priority: 5,
        ),
      ];
      
      final deaths = resolver.resolve(players, actions);
      
      expect(deaths.length, 1);
      expect(deaths.contains(target1.id), true);
      expect(target1.isAlive, false);
      expect(target2.isAlive, true);
    });
    
    test('Tie-breaker uses lexicographic order', () {
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
      
      final dealer1 = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'd2', name: 'Dealer2', role: dealerRole);
      final targetB = Player(id: 'target_b', name: 'TargetB', role: partyAnimalRole);
      final targetA = Player(id: 'target_a', name: 'TargetA', role: partyAnimalRole);
      
      final players = [dealer1, dealer2, targetA, targetB];
      
      // Dealer1 targets target_b, Dealer2 targets target_a (tie)
      final actions = [
        NightAction(
          actorId: dealer1.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: targetB.id,
          priority: 5,
        ),
        NightAction(
          actorId: dealer2.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: targetA.id,
          priority: 5,
        ),
      ];
      
      final deaths = resolver.resolve(players, actions);
      
      expect(deaths.length, 1);
      // target_a comes before target_b lexicographically
      expect(deaths.contains(targetA.id), true);
      expect(targetA.isAlive, false);
      expect(targetB.isAlive, true);
    });
    
    test('Sober sends Dealer home cancels all dealer kills', () {
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
      
      final soberRole = Role(
        id: 'sober',
        name: 'The Sober',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Send home role',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#00FFFF',
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
      
      final dealer = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final sober = Player(id: 's1', name: 'Sober1', role: soberRole);
      final target = Player(id: 't1', name: 'Target1', role: partyAnimalRole);
      
      final players = [dealer, sober, target];
      
      final actions = [
        NightAction(
          actorId: sober.id,
          roleId: 'sober',
          actionType: 'send_home',
          targetId: dealer.id,
          priority: 1,
        ),
        NightAction(
          actorId: dealer.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: target.id,
          priority: 5,
        ),
      ];
      
      final deaths = resolver.resolve(players, actions);
      
      expect(deaths.isEmpty, true, reason: 'No deaths when Sober sends Dealer home');
      expect(target.isAlive, true);
      expect(dealer.isAlive, true); // Dealer is sent home, not killed
    });
    
    test('Minor cannot die unless IDd by Bouncer', () {
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
      
      final minorRole = Role(
        id: 'minor',
        name: 'The Minor',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Protected role',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFA500',
      );
      
      final dealer = Player(id: 'd1', name: 'Dealer1', role: dealerRole);
      final minor = Player(id: 'min1', name: 'Minor1', role: minorRole);
      
      final players = [dealer, minor];
      
      final actions = [
        NightAction(
          actorId: dealer.id,
          roleId: 'dealer',
          actionType: 'kill',
          targetId: minor.id,
          priority: 5,
        ),
      ];
      
      final deaths = resolver.resolve(players, actions);
      
      expect(deaths.isEmpty, true, reason: 'Minor should not die on first kill attempt');
      expect(minor.isAlive, true);
      expect(minor.minorHasBeenIDd, true, reason: 'Minor should be marked as IDd');
      
      // Second kill attempt should succeed
      minor.isAlive = true; // Reset for second attempt
      final deaths2 = resolver.resolve(players, actions);
      
      expect(deaths2.length, 1);
      expect(deaths2.contains(minor.id), true);
      expect(minor.isAlive, false);
    });
  });
}
