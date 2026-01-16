import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/night_resolver.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';

void main() {
  group('NightResolver', () {
    late Role dealerRole;
    late Role medicRole;
    late Role partyAnimalRole;
    late Role soberRole;
    late Role roofiRole;
    late Role minorRole;

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

      medicRole = Role(
        id: 'medic',
        name: 'The Medic',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Healer',
        nightPriority: 2,
        assetPath: '',
        colorHex: '#FF0000',
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

      soberRole = Role(
        id: 'sober',
        name: 'The Sober',
        alliance: 'The Party Animals',
        type: 'protective',
        description: 'Protector',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#00FF00',
      );

      roofiRole = Role(
        id: 'roofi',
        name: 'The Roofi',
        alliance: 'The Dealers',
        type: 'disruptive',
        description: 'Silencer',
        nightPriority: 4,
        assetPath: '',
        colorHex: '#800080',
      );

      minorRole = Role(
        id: 'minor',
        name: 'The Minor',
        alliance: 'The Party Animals',
        type: 'passive',
        description: 'Protected',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#888888',
      );
    });

    test('Medic protect prevents Dealer kill', () {
      // Setup players
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final medic = Player(id: 'medic1', name: 'Medic1', role: medicRole);
      final victim = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      medic.medicChoice = 'PROTECT_DAILY';

      final players = [dealer, medic, victim];

      // Setup actions
      final actions = [
        NightAction(
          playerId: 'dealer1',
          actionType: 'dealer_kill',
          targetId: 'victim1',
        ),
        NightAction(
          playerId: 'medic1',
          actionType: 'medic',
          targetId: 'victim1',
          metadata: {'medicChoice': 'PROTECT_DAILY'},
        ),
      ];

      // Resolve
      final dead = NightResolver.resolve(players, actions);

      // Verify: victim should be alive (protected)
      expect(victim.isAlive, true);
      expect(dead.isEmpty, true);
    });

    test('Dealer kill succeeds when not protected', () {
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final victim = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);

      final players = [dealer, victim];

      final actions = [
        NightAction(
          playerId: 'dealer1',
          actionType: 'dealer_kill',
          targetId: 'victim1',
        ),
      ];

      final dead = NightResolver.resolve(players, actions);

      expect(victim.isAlive, false);
      expect(dead.contains('victim1'), true);
    });

    test('Multiple dealer votes - most votes wins', () {
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'dealer2', name: 'Dealer2', role: dealerRole);
      final victim1 = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);
      final victim2 = Player(id: 'victim2', name: 'Victim2', role: partyAnimalRole);

      final players = [dealer1, dealer2, victim1, victim2];

      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
        NightAction(playerId: 'dealer2', actionType: 'dealer_kill', targetId: 'victim1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      expect(victim1.isAlive, false);
      expect(victim2.isAlive, true);
      expect(dead.contains('victim1'), true);
    });

    test('Dealer kill tie-break by lexicographic order', () {
      final dealer1 = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final dealer2 = Player(id: 'dealer2', name: 'Dealer2', role: dealerRole);
      final victimA = Player(id: 'victim_a', name: 'VictimA', role: partyAnimalRole);
      final victimZ = Player(id: 'victim_z', name: 'VictimZ', role: partyAnimalRole);

      final players = [dealer1, dealer2, victimA, victimZ];

      // Tie: one vote each
      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim_z'),
        NightAction(playerId: 'dealer2', actionType: 'dealer_kill', targetId: 'victim_a'),
      ];

      final dead = NightResolver.resolve(players, actions);

      // Should kill victim_a (lexicographically first)
      expect(victimA.isAlive, false);
      expect(victimZ.isAlive, true);
      expect(dead.contains('victim_a'), true);
    });

    test('Sober send home prevents death', () {
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final sober = Player(id: 'sober1', name: 'Sober1', role: soberRole);
      final victim = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);

      final players = [dealer, sober, victim];

      final actions = [
        NightAction(playerId: 'sober1', actionType: 'send_home', targetId: 'victim1'),
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      expect(victim.isAlive, true);
      expect(dead.isEmpty, true);
    });

    test('Sober sends Dealer home - no kills happen', () {
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final sober = Player(id: 'sober1', name: 'Sober1', role: soberRole);
      final victim = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);

      final players = [dealer, sober, victim];

      final actions = [
        NightAction(playerId: 'sober1', actionType: 'send_home', targetId: 'dealer1'),
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      // No kills should happen when dealer sent home
      expect(victim.isAlive, true);
      expect(dealer.isAlive, true);
      expect(dead.isEmpty, true);
    });

    test('Roofi silences player', () {
      final roofi = Player(id: 'roofi1', name: 'Roofi1', role: roofiRole);
      final victim = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);

      final players = [roofi, victim];

      final actions = [
        NightAction(
          playerId: 'roofi1',
          actionType: 'roofi',
          targetId: 'victim1',
          metadata: {'currentDay': 1},
        ),
      ];

      NightResolver.resolve(players, actions);

      expect(victim.silencedDay, 1);
    });

    test('Minor protection - first attack fails', () {
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final minor = Player(id: 'minor1', name: 'Minor1', role: minorRole);

      final players = [dealer, minor];

      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'minor1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      // Minor should survive first attack but be marked as ID'd
      expect(minor.isAlive, true);
      expect(minor.minorHasBeenIDd, true);
      expect(dead.isEmpty, true);
    });

    test('Minor - second attack kills', () {
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final minor = Player(id: 'minor1', name: 'Minor1', role: minorRole);
      minor.minorHasBeenIDd = true; // Already ID'd

      final players = [dealer, minor];

      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'minor1'),
      ];

      final dead = NightResolver.resolve(players, actions);

      // Minor should die on second attack
      expect(minor.isAlive, false);
      expect(dead.contains('minor1'), true);
    });

    test('Deterministic ordering - actions resolved in correct priority', () {
      final dealer = Player(id: 'dealer1', name: 'Dealer1', role: dealerRole);
      final medic = Player(id: 'medic1', name: 'Medic1', role: medicRole);
      final sober = Player(id: 'sober1', name: 'Sober1', role: soberRole);
      final victim = Player(id: 'victim1', name: 'Victim1', role: partyAnimalRole);

      final players = [dealer, medic, sober, victim];

      // Actions in random order - should be sorted by priority
      final actions = [
        NightAction(playerId: 'dealer1', actionType: 'dealer_kill', targetId: 'victim1'),
        NightAction(
          playerId: 'medic1',
          actionType: 'medic',
          targetId: 'victim1',
          metadata: {'medicChoice': 'PROTECT_DAILY'},
        ),
        // Sober action (priority 1) should execute first
      ];

      final dead = NightResolver.resolve(players, actions);

      // Medic protection should prevent kill
      expect(victim.isAlive, true);
      expect(dead.isEmpty, true);
    });
  });
}
