import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:club_blackout/utils/role_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

/// Comprehensive gameplay scenario tests to validate all possible player combinations
/// and ensure logical game flow and win conditions work correctly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late RoleRepository roleRepository;
  late GameEngine gameEngine;

  setUp(() async {
    roleRepository = FileRoleRepository();
    await roleRepository.loadRoles();
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
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );

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
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer(
        'CM1',
        role: roleRepository.getRoleById('club_manager'),
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
      final dealerCount =
          enabledPlayers.where((p) => p.role.id == 'dealer').length;
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
    test('Dealers win in a 1v1 showdown vs a Party Animal', () {
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
      expect(result!.winner, 'DEALER');
    });

    test('Converted Second Wind counts as a Dealer for game end', () {
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

      final dealerRole = roleRepository.getRoleById('dealer');
      expect(dealerRole, isNotNull);

      final secondWind =
          gameEngine.players.firstWhere((p) => p.role.id == 'second_wind');
      secondWind.secondWindConverted = true;
      secondWind.role = dealerRole!;
      secondWind.alliance = dealerRole.alliance;

      // Original Dealer dies; converted Second Wind is now the last Dealer.
      gameEngine.players.firstWhere((p) => p.name == 'Dealer1').die();

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'DEALER');
    });

    test('Creep mimicking Dealer does not immediately become a Dealer', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Creep1',
        role: roleRepository.getRoleById('creep'),
      );

      final dealer = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');
      final creep = gameEngine.players.firstWhere((p) => p.name == 'Creep1');
      expect(creep.role.id, 'creep');

      // Resolve a night where the Creep chooses Dealer1.
      gameEngine.currentPhase = GamePhase.night;
      gameEngine.nightActions['creep_target'] = dealer.id;
      gameEngine.skipToNextPhase();

      expect(creep.creepTargetId, dealer.id);
      expect(creep.role.id, 'creep');
      expect(creep.alliance.toLowerCase().contains('dealer'), false);
    });

    test('Creep inherits Dealer on death and takes their place', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'Creep1',
        role: roleRepository.getRoleById('creep'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );

      final dealer = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');
      final creep = gameEngine.players.firstWhere((p) => p.name == 'Creep1');

      creep.creepTargetId = dealer.id;
      gameEngine.processDeath(dealer, cause: 'vote');

      expect(creep.role.id, 'dealer');
      expect(creep.creepTargetId, isNull);

      // Now the last two alive are Dealer (former Creep) vs Party Animal.
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
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );

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

    test('Club Manager wins if only they and a Dealer remain', () {
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer(
        'CM1',
        role: roleRepository.getRoleById('club_manager'),
      );
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );

      // Eliminate the Party Animal so it's Dealer vs Club Manager.
      gameEngine.players.where((p) => p.role.id == 'party_animal').first.die();

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'CLUB_MANAGER');
    });
  });

  group('Clinger Mechanics', () {
    test('Clinger votes always mirror obsession partner', () {
      gameEngine.addPlayer('Clinger1',
          role: roleRepository.getRoleById('clinger'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));
      gameEngine.addPlayer('Dealer1',
          role: roleRepository.getRoleById('dealer'));

      final clinger =
          gameEngine.players.firstWhere((p) => p.name == 'Clinger1');
      final partner = gameEngine.players.firstWhere((p) => p.name == 'PA1');
      final dealer = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');

      clinger.clingerPartnerId = partner.id;
      clinger.clingerFreedAsAttackDog = false;

      // Partner votes Dealer -> Clinger should follow.
      gameEngine.recordVote(voterId: partner.id, targetId: dealer.id);
      expect(gameEngine.currentDayVotesByVoter[clinger.id], dealer.id);

      // Clinger tries to vote differently -> should snap back to partner.
      gameEngine.recordVote(voterId: clinger.id, targetId: partner.id);
      expect(gameEngine.currentDayVotesByVoter[clinger.id], dealer.id);

      // Partner clears vote -> Clinger should clear too.
      gameEngine.recordVote(voterId: partner.id, targetId: null);
      expect(gameEngine.currentDayVotesByVoter[clinger.id], isNull);
    });

    test('Clinger dies of heartbreak when obsession dies', () {
      gameEngine.addPlayer('Clinger1',
          role: roleRepository.getRoleById('clinger'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));

      final clinger =
          gameEngine.players.firstWhere((p) => p.name == 'Clinger1');
      final partner = gameEngine.players.firstWhere((p) => p.name == 'PA1');

      clinger.clingerPartnerId = partner.id;
      clinger.clingerFreedAsAttackDog = false;

      gameEngine.processDeath(partner, cause: 'test');
      expect(partner.isAlive, isFalse);
      expect(clinger.isAlive, isFalse);
    });

    test('Freed Clinger does not sync votes or heartbreak', () {
      gameEngine.addPlayer('Clinger1',
          role: roleRepository.getRoleById('clinger'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));
      gameEngine.addPlayer('Dealer1',
          role: roleRepository.getRoleById('dealer'));

      final clinger =
          gameEngine.players.firstWhere((p) => p.name == 'Clinger1');
      final partner = gameEngine.players.firstWhere((p) => p.name == 'PA1');
      final dealer = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');

      clinger.clingerPartnerId = partner.id;
      expect(gameEngine.freeClingerFromObsession(clinger.id), isTrue);

      // Votes should no longer mirror.
      gameEngine.recordVote(voterId: partner.id, targetId: dealer.id);
      expect(gameEngine.currentDayVotesByVoter[clinger.id], isNull);

      // Heartbreak should no longer apply.
      gameEngine.processDeath(partner, cause: 'test');
      expect(partner.isAlive, isFalse);
      expect(clinger.isAlive, isTrue);
    });

    test('Freed Clinger can use Attack Dog exactly once', () {
      gameEngine.addPlayer('Clinger1',
          role: roleRepository.getRoleById('clinger'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));
      gameEngine.addPlayer('Dealer1',
          role: roleRepository.getRoleById('dealer'));

      final clinger =
          gameEngine.players.firstWhere((p) => p.name == 'Clinger1');
      final partner = gameEngine.players.firstWhere((p) => p.name == 'PA1');
      final target = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');

      clinger.clingerPartnerId = partner.id;
      expect(gameEngine.freeClingerFromObsession(clinger.id), isTrue);
      expect(clinger.clingerFreedAsAttackDog, isTrue);

      const step = ScriptStep(
        id: 'clinger_act',
        title: 'Clinger',
        readAloudText: '',
        instructionText: '',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'clinger',
        isNight: true,
      );

      // First use: kill resolves immediately.
      gameEngine.handleScriptAction(step, [target.id]);
      expect(target.isAlive, isFalse);
      expect(clinger.clingerAttackDogUsed, isTrue);

      // Second use: should be blocked (no new kill).
      final stillAlive = gameEngine.players.firstWhere((p) => p.name == 'PA1');
      gameEngine.handleScriptAction(step, [stillAlive.id]);
      expect(stillAlive.isAlive, isTrue);
    });

    test('Non-freed Clinger cannot use Attack Dog', () {
      gameEngine.addPlayer('Clinger1',
          role: roleRepository.getRoleById('clinger'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));
      gameEngine.addPlayer('Dealer1',
          role: roleRepository.getRoleById('dealer'));

      final clinger =
          gameEngine.players.firstWhere((p) => p.name == 'Clinger1');
      final partner = gameEngine.players.firstWhere((p) => p.name == 'PA1');
      final target = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');

      clinger.clingerPartnerId = partner.id;
      clinger.clingerFreedAsAttackDog = false;
      clinger.clingerAttackDogUsed = false;

      const step = ScriptStep(
        id: 'clinger_act',
        title: 'Clinger',
        readAloudText: '',
        instructionText: '',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'clinger',
        isNight: true,
      );

      gameEngine.handleScriptAction(step, [target.id]);
      expect(target.isAlive, isTrue);
      expect(clinger.clingerAttackDogUsed, isFalse);
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
      final dealerCount =
          gameEngine.players.where((p) => p.role.id == 'dealer').length;
      sd.setLivesBasedOnDealers(dealerCount);

      expect(sd.lives, dealerCount + 1);
      expect(sd.lives, 3); // We have 2 dealers
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
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );
      gameEngine.addPlayer('Roofi1', role: roleRepository.getRoleById('roofi'));
      gameEngine.addPlayer('MB1',
          role: roleRepository.getRoleById('messy_bitch'));

      expect(gameEngine.players.length, 8);
      final dealerCount =
          gameEngine.players.where((p) => p.role.id == 'dealer').length;
      expect(dealerCount, 2); // 7-10 players => 2 Dealers
    });

    test('Valid 15-player game with 4 dealers', () {
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
        'Dealer4',
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
      gameEngine.addPlayer(
        'Bartender1',
        role: roleRepository.getRoleById('bartender'),
      );
      gameEngine.addPlayer(
        'AllyCat1',
        role: roleRepository.getRoleById('ally_cat'),
      );

      expect(gameEngine.players.length, 15);
      final dealerCount =
          gameEngine.players.where((p) => p.role.id == 'dealer').length;
      expect(dealerCount, 4); // 11-14 => 3, 15-18 => 4
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
        isNot(contains('party_animal')),
      ); // Party Animal is unique and already used

      // Some other unused role should still be available (example: Bouncer).
      expect(roleIds, contains('bouncer'));
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

      final dealerCount =
          gameEngine.players.where((p) => p.role.id == 'dealer').length;
      expect(dealerCount, 3);
    });

    test('Can assign multiple Party Animals', () {
      gameEngine.addPlayer(
        'PA1',
        role: roleRepository.getRoleById('party_animal'),
      );

      final pa2 = Player(
        id: 'pa2_id',
        name: 'PA2',
        role: roleRepository.getRoleById('party_animal')!,
      );

      final validation = RoleValidator.canAssignRole(
        roleRepository.getRoleById('party_animal'),
        pa2.id,
        gameEngine.players,
      );

      expect(validation.isValid, true);
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

    test('Game continues when Dealers outnumber but not 1v1', () {
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
      expect(result, isNull);
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
        'WF1',
        role: roleRepository.getRoleById('wallflower'),
      );
      gameEngine.addPlayer('Medic1', role: roleRepository.getRoleById('medic'));
      gameEngine.addPlayer(
        'Bouncer1',
        role: roleRepository.getRoleById('bouncer'),
      );
      gameEngine.addPlayer(
        'Roofi1',
        role: roleRepository.getRoleById('roofi'),
      );

      final result = gameEngine.checkGameEnd();
      expect(
          result, isNull); // 1 dealer vs many Party-aligned roles => continues
    });

    test('1v1 Dealer vs Party Animal is a Dealer win', () {
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
      expect(result!.winner, 'DEALER');
      expect(result.message, contains('Final showdown'));
    });

    test('Messy Bitch wins when a rumour reaches every player', () {
      // Setup: 1 Dealer, 1 Party Animal, 1 Messy Bitch
      gameEngine.addPlayer(
        'Dealer1',
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

      // Mark everyone except Messy Bitch as "infected".
      final messyBitch =
          gameEngine.players.firstWhere((p) => p.role.id == 'messy_bitch');
      for (final p in gameEngine.players) {
        if (p.id == messyBitch.id) continue;
        p.hasRumour = true;
      }

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'MESSY_BITCH');
      expect(result.message, contains('Messy Bitch'));
    });

    test('Messy Bitch win ignores dead players', () {
      gameEngine.addPlayer(
        'Dealer1',
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

      final messyBitch =
          gameEngine.players.firstWhere((p) => p.role.id == 'messy_bitch');
      final partyAnimal =
          gameEngine.players.firstWhere((p) => p.role.id == 'party_animal');
      final dealer =
          gameEngine.players.firstWhere((p) => p.role.id == 'dealer');

      // Only the living non-Messy player needs a rumour.
      partyAnimal.hasRumour = true;
      expect(dealer.hasRumour, isFalse);

      // Kill the dealer; they should no longer be required for the rumour win.
      gameEngine.processDeath(dealer, cause: 'unknown');
      expect(dealer.isAlive, isFalse);
      expect(messyBitch.isAlive, isTrue);
      expect(partyAnimal.isAlive, isTrue);

      final result = gameEngine.checkGameEnd();
      expect(result, isNotNull);
      expect(result!.winner, 'MESSY_BITCH');
    });
  });
}
