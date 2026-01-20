import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/logic/game_state.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:club_blackout/data/role_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ... Mocks and Data same as before ...

class MockRoleRepository implements RoleRepository {
  final List<Role> _roles;
  MockRoleRepository(this._roles);
  @override
  List<Role> get roles => _roles;
  @override
  Future<void> loadRoles() async {}
  @override
  Role? getRoleById(String id) {
    try {
      return _roles.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

final Role hostRole = Role(
  id: 'host',
  name: 'The Host',
  alliance: 'Neutral',
  type: 'Game Master',
  description: 'Host',
  nightPriority: 999,
  assetPath: '',
  colorHex: '#FFA500',
);
final Role dealerRole = Role(
  id: 'dealer',
  name: 'The Dealer',
  alliance: 'The Dealers',
  type: 'Aggressive',
  description: 'Killer',
  nightPriority: 1,
  assetPath: '',
  colorHex: '#FF00FF',
);
final Role medicRole = Role(
  id: 'medic',
  name: 'The Medic',
  alliance: 'The Party Animals',
  type: 'Defensive',
  description: 'Healer',
  nightPriority: 3,
  assetPath: '',
  colorHex: '#FF0000',
  hasBinaryChoiceAtStart: true,
  choices: ['PROTECT', 'REVIVE'],
);
final Role partyAnimalRole = Role(
  id: 'party_animal',
  name: 'The Party Animal',
  alliance: 'The Party Animals',
  type: 'Passive',
  description: 'Citizen',
  nightPriority: 0,
  assetPath: '',
  colorHex: '#FFDAB9',
);
final Role clingerRole = Role(
  id: 'clinger',
  name: 'The Clinger',
  alliance: 'Variable',
  type: 'Passive',
  description: 'Obsessed',
  nightPriority: 0,
  assetPath: '',
  colorHex: '#FFFF00',
);
final Role bouncerRole = Role(
  id: 'bouncer',
  name: 'The Bouncer',
  alliance: 'The Party Animals',
  type: 'Investigative',
  description: 'Checker',
  nightPriority: 2,
  assetPath: '',
  colorHex: '#0000FF',
);
final Role messyBitchRole = Role(
  id: 'messy_bitch',
  name: 'The Messy Bitch',
  alliance: 'Neutral',
  type: 'Chaos',
  description: 'Rumour',
  nightPriority: 6,
  assetPath: '',
  colorHex: '#E6E6FA',
);
final Role minorRole = Role(
  id: 'minor',
  name: 'The Minor',
  alliance: 'The Party Animals',
  type: 'Passive',
  description: 'Protected',
  nightPriority: 0,
  assetPath: '',
  colorHex: '#888888',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameEngine gameEngine;
  late MockRoleRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = MockRoleRepository([
      hostRole,
      dealerRole,
      medicRole,
      partyAnimalRole,
      clingerRole,
      bouncerRole,
      messyBitchRole,
      minorRole,
    ]);
    gameEngine = GameEngine(roleRepository: repo);
  });

  void executeScriptStep(String roleIdFilter, List<String> targetIds) {
    bool found = false;
    int maxSteps = 100;
    while (gameEngine.currentScriptIndex < gameEngine.scriptQueue.length &&
        maxSteps > 0) {
      final currentStep = gameEngine.scriptQueue[gameEngine.currentScriptIndex];
      // Debug print
      // print('Step: ${currentStep.id} Role: ${currentStep.roleId} Action: ${currentStep.actionType}');

      if (currentStep.roleId == roleIdFilter &&
          currentStep.actionType == ScriptActionType.selectPlayer) {
        gameEngine.handleScriptAction(currentStep, targetIds);
        found = true;
      }

      gameEngine.advanceScript();
      maxSteps--;

      if (found) return;
    }
    if (!found) {
      throw Exception(
        "Script step for $roleIdFilter not found in queue of length ${gameEngine.scriptQueue.length}. Queue dump: ${gameEngine.scriptQueue.map((s) => s.roleId).toList()}",
      );
    }
  }

  void fastForwardScript() {
    int safety = 0;
    int initialPhaseDay = gameEngine.dayCount;
    GamePhase initialPhase = gameEngine.currentPhase;

    while (gameEngine.currentScriptIndex < gameEngine.scriptQueue.length &&
        safety < 100) {
      gameEngine.advanceScript();
      safety++;
      if (gameEngine.currentPhase != initialPhase ||
          gameEngine.dayCount != initialPhaseDay) {
        break;
      }
    }
  }

  test('Scenario 1: Dealer kills Party Animal', () async {
    gameEngine.addPlayer('Host', role: hostRole);
    gameEngine.addPlayer('Dealer', role: dealerRole);
    gameEngine.addPlayer('Medic', role: medicRole);
    gameEngine.addPlayer('Victim', role: partyAnimalRole);
    gameEngine.addPlayer('Extra', role: partyAnimalRole);

    await gameEngine.startGame();
    final medic = gameEngine.players.firstWhere((p) => p.role.id == 'medic');
    final victimId = gameEngine.players
        .firstWhere((p) => p.name == 'Victim')
        .id;
    medic.medicChoice = 'PROTECT_DAILY';

    fastForwardScript(); // End Setup -> Night 1

    executeScriptStep('dealer', [victimId]);
    executeScriptStep('medic', [medic.id]);

    fastForwardScript(); // End Night 1 -> Day

    expect(gameEngine.deadPlayerIds, contains(victimId));
  });

  test('Scenario 3: Clinger dies with Partner', () async {
    gameEngine.addPlayer('Host', role: hostRole);
    gameEngine.addPlayer('Dealer', role: dealerRole);
    gameEngine.addPlayer('Clinger', role: clingerRole);
    gameEngine.addPlayer('Partner', role: partyAnimalRole);
    gameEngine.addPlayer('Extra', role: partyAnimalRole);

    await gameEngine.startGame();
    final partnerId = gameEngine.players
        .firstWhere((p) => p.name == 'Partner')
        .id;
    final clingerId = gameEngine.players
        .firstWhere((p) => p.name == 'Clinger')
        .id;
    executeScriptStep('clinger', [partnerId]);
    fastForwardScript(); // End Setup -> Night 1

    executeScriptStep('dealer', [partnerId]);
    fastForwardScript(); // End Night 1

    expect(gameEngine.deadPlayerIds, contains(partnerId));
    expect(gameEngine.deadPlayerIds, contains(clingerId));
  });

  test('Scenario 2: Medic Saves', () async {
    gameEngine.addPlayer('Host', role: hostRole);
    gameEngine.addPlayer('Dealer', role: dealerRole);
    gameEngine.addPlayer('Medic', role: medicRole);
    gameEngine.addPlayer('Victim', role: partyAnimalRole);
    gameEngine.addPlayer('Extra', role: partyAnimalRole);

    await gameEngine.startGame();
    final medic = gameEngine.players.firstWhere((p) => p.role.id == 'medic');
    final victimId = gameEngine.players
        .firstWhere((p) => p.name == 'Victim')
        .id;
    medic.medicChoice = 'PROTECT_DAILY';
    fastForwardScript();
    executeScriptStep('dealer', [victimId]);
    executeScriptStep('medic', [victimId]);
    fastForwardScript();
    expect(gameEngine.deadPlayerIds, isEmpty);
  });

  test('Scenario 5: Messy Bitch', () async {
    gameEngine.addPlayer('Host', role: hostRole);
    gameEngine.addPlayer('Messy', role: messyBitchRole);
    gameEngine.addPlayer('P1', role: partyAnimalRole);
    gameEngine.addPlayer('P2', role: minorRole);
    gameEngine.addPlayer('Extra', role: partyAnimalRole);

    await gameEngine.startGame();
    final p1Id = gameEngine.players.firstWhere((p) => p.name == 'P1').id;
    final p2Id = gameEngine.players.firstWhere((p) => p.name == 'P2').id;
    fastForwardScript();
    executeScriptStep('messy_bitch', [p1Id]);
    fastForwardScript(); // to day
    fastForwardScript(); // to night 2
    executeScriptStep('messy_bitch', [p2Id]);
    fastForwardScript();
  });
}
