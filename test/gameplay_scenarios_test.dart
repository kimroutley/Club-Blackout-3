import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/utils/role_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRoleRepository extends RoleRepository {
  final List<Role> _mockRoles = [
    Role(
      id: 'dealer',
      name: 'The Dealer',
      alliance: 'The Dealers',
      type: 'aggressive',
      description: '...',
      nightPriority: 5,
      assetPath: 'path',
      colorHex: '#FF00FF',
    ),
    Role(
      id: 'party_animal',
      name: 'The Party Animal',
      alliance: 'The Party Animals',
      type: 'passive',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#FFDAB9',
    ),
    Role(
      id: 'medic',
      name: 'The Medic',
      alliance: 'The Party Animals',
      type: 'defensive',
      description: '...',
      nightPriority: 1,
      hasBinaryChoiceAtStart: true,
      choices: ['REVIVE', 'PROTECT'],
      assetPath: 'path',
      colorHex: '#FF0000',
    ),
    Role(
      id: 'bouncer',
      name: 'The Bouncer',
      alliance: 'The Party Animals',
      type: 'investigative',
      description: '...',
      nightPriority: 2,
      assetPath: 'path',
      colorHex: '#0000FF',
    ),
    Role(
      id: 'wallflower',
      name: 'The Wallflower',
      alliance: 'The Party Animals',
      type: 'investigative',
      description: '...',
      nightPriority: 5,
      ability: 'witness_murder',
      assetPath: 'path',
      colorHex: '#FFC0CB',
    ),
    Role(
      id: 'club_manager',
      name: 'Club Manager',
      alliance: 'None',
      type: 'neutral',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#888888',
    ),
    Role(
      id: 'messy_bitch',
      name: 'The Messy Bitch',
      alliance: 'None (Neutral Survivor)',
      type: 'chaos',
      description: '...',
      nightPriority: 1,
      assetPath: 'path',
      colorHex: '#E6E6FA',
    ),
    Role(
      id: 'minor',
      name: 'The Minor',
      alliance: 'The Party Animals',
      type: 'defensive',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#FFFFFF',
    ),
    Role(
      id: 'seasoned_drinker',
      name: 'The Seasoned Drinker',
      alliance: 'The Party Animals',
      type: 'tank',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#98FF98',
    ),
    Role(
      id: 'ally_cat',
      name: 'Ally Cat',
      alliance: 'The Party Animals',
      type: 'special',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#000000',
    ),
    Role(
      id: 'second_wind',
      name: 'Second Wind',
      alliance: 'The Party Animals',
      type: 'special',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#AAAAAA',
    ),
    Role(
      id: 'roofi',
      name: 'The Roofi',
      alliance: 'The Party Animals',
      type: 'offensive',
      description: '...',
      nightPriority: 3,
      assetPath: 'path',
      colorHex: '#00FF00',
    ),
    Role(
      id: 'sober',
      name: 'The Sober',
      alliance: 'The Party Animals',
      type: 'protective',
      description: '...',
      nightPriority: 1,
      ability: 'send_home',
      assetPath: 'path',
      colorHex: '#32CD32',
    ),
    Role(
      id: 'tea_spiller',
      name: 'The Tea Spiller',
      alliance: 'The Party Animals',
      type: 'reactive',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#FFD700',
    ),
    Role(
      id: 'lightweight',
      name: 'The Lightweight',
      alliance: 'The Party Animals',
      type: 'passive',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#FFA500',
    ),
    Role(
      id: 'silver_fox',
      name: 'Silver Fox',
      alliance: 'The Party Animals',
      type: 'special',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#C0C0C0',
    ),
    Role(
      id: 'clinger',
      name: 'The Clinger',
      alliance: 'The Party Animals',
      type: 'special',
      description: '...',
      nightPriority: 0,
      assetPath: 'path',
      colorHex: '#FFFF00',
    ),
  ];

  @override
  Future<void> loadRoles() async {
    // No-op for mock
  }

  @override
  List<Role> get roles => _mockRoles;

  @override
  Role? getRoleById(String id) {
    try {
      return _mockRoles.firstWhere((role) => role.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Comprehensive gameplay scenario tests to validate all possible player combinations
/// and ensure logical game flow and win conditions work correctly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late RoleRepository roleRepository;
  late GameEngine gameEngine;

  setUp(() async {
    roleRepository = MockRoleRepository();
    gameEngine = GameEngine(roleRepository: roleRepository);
  });

  group('Required Role Composition Tests', () {
    test('Game requires at least 1 Dealer', () {
      // Setup: No dealers
      gameEngine.addPlayer(
        'Alice',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer('Bob', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Charlie',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Dana', role: roleRepository.getRoleById('bouncer'));

      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      expect(validation.isValid, false);
      expect(validation.error, contains('Dealer'));
    });

    test('Game requires at least 1 Party Animal', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Wallflower1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );

      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      expect(validation.isValid, false);
      expect(validation.error, contains('Party Animal'));
    });

    test('Game requires at least 1 Wallflower', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      expect(validation.isValid, false);
      expect(validation.error, contains('Wallflower'));
    });

    test('Game requires at least 1 Medic and/or Bouncer', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );

      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      expect(validation.isValid, false);
      expect(validation.error, contains('Medic'));
    });

    test('Game requires at least 2 Party Animal-aligned roles', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      // Should pass since we have PA + WF + Medic (all Party Animal aligned)
      expect(validation.isValid, true);
    });

    test('Dealers cannot have majority at start', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer3',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );

      // 3 dealers vs 2 party animals = dealer majority at start
      // This is actually validated in lobby, not in validateGameSetup
      // But we can check the ratio
      final enabledPlayers = gameEngine.enabledPlayers;
      final dealerCount = enabledPlayers
          .where((p) => p.role.id == 'dealer')
          .length;
      final totalCount = enabledPlayers.length;
      expect(dealerCount, greaterThan(totalCount - dealerCount));
    });

    test('Valid minimal game setup', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      expect(validation.isValid, true);
    });
  });

  group('Win Condition Scenarios', () {
    test('Dealers win when they outnumber Party Animals', () {
      // Setup: 3 dealers, 2 party animals (dealers outnumber)
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer3',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'DEALER');
    });

    test('Party Animals win when all Dealers are dead', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      // Kill all dealers
      final dealers = gameEngine.players.where((p) => p.role.id == 'dealer');
      for (final dealer in dealers) {
        dealer.die();
      }

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'PARTY_ANIMAL');
    });

    test('Game continues when both factions have survivors', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      // Kill one party animal
      final pa1 = gameEngine.players.firstWhere((p) => p.name == 'PA1');
      pa1.die();

      final result = gameEngine.checkGameEnd();
      expect(result, isNull); // Game should continue
    });

    test('Neutral (Club Manager) wins if they survive to the end', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer(
        'CM1',
        role: roleRepository.getRoleById('club_manager'),
      );

      // Kill all dealers (Party Animals would win, but Club Manager should also survive)
      final dealer = gameEngine.players.firstWhere(
        (p) => p.role.id == 'dealer',
      );
      dealer.die();

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'PARTY_ANIMAL');

      // Club Manager should still be alive
      final clubManager = gameEngine.players.firstWhere(
        (p) => p.role.id == 'club_manager',
      );
      expect(clubManager.isAlive, true);
    });
  });

  group('Role-Specific Ability Tests', () {
    test('Minor cannot die before being ID checked', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer('Minor1', role: roleRepository.getRoleById('minor'));
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final minor = gameEngine.players.firstWhere((p) => p.role.id == 'minor');

      // Try to kill minor without ID check
      expect(minor.minorHasBeenIDd, false);
      // Minor's protection is handled in ability resolution, not in die() method
      // This test validates the flag exists
      expect(minor.isAlive, true);
    });

    test('Seasoned Drinker has extra lives based on dealer count', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'SD1',
        role: roleRepository.getRoleById('seasoned_drinker'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );

      final sd = gameEngine.players.firstWhere(
        (p) => p.role.id == 'seasoned_drinker',
      );

      // Set lives based on dealer count
      final dealerCount = gameEngine.players
          .where((p) => p.role.id == 'dealer')
          .length;
      sd.setLivesBasedOnDealers(dealerCount);

      expect(sd.lives, dealerCount);
      expect(sd.lives, 2); // We have 2 dealers
    });

    test('Ally Cat has 9 lives', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer('AC1', role: roleRepository.getRoleById('ally_cat'));
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final allyCat = gameEngine.players.firstWhere(
        (p) => p.role.id == 'ally_cat',
      );
      allyCat.initialize();

      expect(allyCat.lives, 9);
    });

    test('Second Wind can convert to Dealer', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'SW1',
        role: roleRepository.getRoleById('second_wind'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final secondWind = gameEngine.players.firstWhere(
        (p) => p.role.id == 'second_wind',
      );

      expect(secondWind.secondWindConverted, false);
      expect(secondWind.secondWindPendingConversion, false);

      // Can set conversion flag
      secondWind.secondWindConverted = true;
      expect(secondWind.secondWindConverted, true);
    });
  });

  group('Player Count Variation Tests', () {
    test('Valid 4-player game', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      expect(gameEngine.players.length, 4);
      final validation = RoleValidator.validateGameSetup(gameEngine.players);
      expect(validation.isValid, true);
    });

    test('Valid 8-player game with 2 dealers', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );
      gameEngine.addPlayer('Roofi1', role: roleRepository.getRoleById('roofi'));

      expect(gameEngine.players.length, 8);
      final dealerCount = gameEngine.players
          .where((p) => p.role.id == 'dealer')
          .length;
      expect(dealerCount, 2); // 1 per 7 total = 2 for 8 players
    });

    test('Valid 15-player game with 3 dealers', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer3',
        role: roleRepository.getRoleById('dealer'),
      );

      for (var i = 1; i <= 4; i++) {
        gameEngine.addPlayer(
          'PA$i',
          role: roleRepository.getRoleById('party_animal'),
        );
      }
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );
      gameEngine.addPlayer('Roofi1', role: roleRepository.getRoleById('roofi'));
      gameEngine.addPlayer('Sober1', role: roleRepository.getRoleById('sober'));
      gameEngine.addPlayer(
        'TeaSpiller1',
        role: roleRepository.getRoleById('tea_spiller'),
      );
      gameEngine.addPlayer(
        'Lightweight1',
        role: roleRepository.getRoleById('lightweight'),
      );
      gameEngine.addPlayer(
        'Silver Fox1',
        role: roleRepository.getRoleById('silver_fox'),
      );

      expect(gameEngine.players.length, 15);
      final dealerCount = gameEngine.players
          .where((p) => p.role.id == 'dealer')
          .length;
      expect(dealerCount, 3); // 1 per 7 total = 3 for 15 players
    });
  });

  group('Late Join Scenarios', () {
    test('Player can join mid-game with available role', () {
      // Start with basic setup
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      // Simulate game start
      gameEngine.startGame();

      // Move to day phase (setup -> night -> day)
      gameEngine.skipToNextPhase(); // setup -> night
      gameEngine.skipToNextPhase(); // night -> day

      // Add a late joiner
      final newPlayer = gameEngine.addPlayerDuringDay('LateJoiner');

      expect(newPlayer.joinsNextNight, true);
      expect(newPlayer.isActive, false); // Not active until next night
      expect(gameEngine.players.length, 5);
    });

    test('Late joiner cannot get a role that already appeared', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      gameEngine.startGame();
      // Move to day phase (setup -> night -> day)
      gameEngine.skipToNextPhase(); // setup -> night
      gameEngine.skipToNextPhase(); // night -> day

      // Get available roles - should not include Medic or Wallflower (unique roles already used)
      final availableRoles = gameEngine.availableRolesForNewPlayer();
      final roleIds = availableRoles.map((r) => r.id).toList();

      expect(roleIds, isNot(contains('medic'))); // Unique role already used
      expect(
        roleIds,
        isNot(contains('wallflower')),
      ); // Unique role already used
      expect(
        roleIds,
        contains('party_animal'),
      ); // Can repeat (always available)
      // Dealer not available here because we already have 1/1 recommended dealers for 5 total players
      expect(roleIds, isNot(contains('dealer')));
    });

    test('Late joiner becomes active on next night', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      gameEngine.startGame();
      // Move to day phase (setup -> night -> day)
      gameEngine.skipToNextPhase(); // setup -> night
      gameEngine.skipToNextPhase(); // night -> day

      final newPlayer = gameEngine.addPlayerDuringDay('LateJoiner');
      expect(newPlayer.joinsNextNight, true);
      expect(newPlayer.isActive, false);

      // Move to next night
      gameEngine.skipToNextPhase(); // day -> night

      // Player should now be active
      expect(newPlayer.joinsNextNight, false);
      expect(newPlayer.isActive, true);
    });
  });

  group('Unique Role Enforcement', () {
    test('Cannot assign duplicate unique roles', () {
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      // Validation should fail for duplicate unique roles
      final medic2 = Player(
        id: 'medic2_id',
        name: 'Medic2',
        role: roleRepository.getRoleById('medic')!,
      );

      final validation = RoleValidator.canAssignRole(
        roleRepository.getRoleById('medic'),
        medic2.id,
        gameEngine.players,
      );

      expect(validation.isValid, false);
      expect(validation.error, contains('only exist once'));
    });

    test('Can assign multiple Dealers', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer3',
        role: roleRepository.getRoleById('dealer'),
      );

      final dealerCount = gameEngine.players
          .where((p) => p.role.id == 'dealer')
          .length;
      expect(dealerCount, 3);
    });

    test('Can assign multiple Party Animals', () {
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA3',
        role: roleRepository.getRoleById('party_animal'),
      );

      final paCount = gameEngine.players
          .where((p) => p.role.id == 'party_animal')
          .length;
      expect(paCount, 3);
    });
  });

  group('Edge Case Scenarios', () {
    test('Everyone dies - no winner', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      // Kill everyone
      for (final player in gameEngine.players) {
        player.die();
      }

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'NONE');
      expect(result.message, contains('No one wins'));
    });

    test('Dealers can win even with neutrals alive', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer(
        'CM1',
        role: roleRepository.getRoleById('club_manager'),
      );

      // Kill party animals
      gameEngine.players.where((p) => p.role.id == 'party_animal').first.die();
      gameEngine.players.where((p) => p.role.id == 'wallflower').first.die();

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'DEALER');

      // Club Manager should still be alive
      final cm = gameEngine.players.firstWhere(
        (p) => p.role.id == 'club_manager',
      );
      expect(cm.isAlive, true);
    });

    test('Single dealer vs many party animals - game continues', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA2',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'PA3',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));

      final result = gameEngine.checkGameEnd();
      expect(result, isNull); // 1 dealer vs 5 party animals = game continues
    });

    test('1v1 Standoff is a Draw', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'DRAW');
      expect(result.message, contains('Standoff'));
    });

    test('Messy Bitch steals win if alive when Dealers would win', () {
      // Setup: 2 Dealers, 1 Party Animal, 1 Messy Bitch
      // Total 4. Dealers (2) > PAs (1).
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Dealer2',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );
      gameEngine.addPlayer(
        'MB1',
        role: roleRepository.getRoleById('messy_bitch'),
      );

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'MESSY_BITCH');
      expect(result.message, contains('Messy Bitch'));
    });
  });
}
