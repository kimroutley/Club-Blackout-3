import 'package:club_blackout/logic/game_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileRoleRepository roleRepository;
  late GameEngine gameEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    roleRepository = FileRoleRepository();
    await roleRepository.loadRoles();
    gameEngine = GameEngine(roleRepository: roleRepository);
  });

  group('The Whore Scenarios', () {
    test('Whore deflection saves a Dealer from being voted out', () async {
      // Setup: 1 Dealer, 1 Whore, 1 Party Animal, 1 Wallflower
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer('Whore1', role: roleRepository.getRoleById('whore'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));
      gameEngine.addPlayer('WF1',
          role: roleRepository.getRoleById('wallflower'));
      await gameEngine.startGame();

      final dealer = gameEngine.players.firstWhere((p) => p.name == 'Dealer1');
      final whore = gameEngine.players.firstWhere((p) => p.name == 'Whore1');
      final target = gameEngine.players.firstWhere((p) => p.name == 'WF1');

      // Night phase: Whore deflects to target
      whore.whoreDeflectionTargetId = target.id;

      // Day phase: Dealer is voted out
      gameEngine.voteOutPlayer(dealer.id);

      // Assertions
      expect(dealer.isAlive, isTrue); // Dealer should be alive
      expect(target.isAlive, isFalse); // Target should be dead
      expect(
        gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'),
        isTrue,
      );
    });

    test('Whore deflection saves the Whore from being voted out', () async {
      // Setup: 1 Dealer, 1 Whore, 1 Party Animal, 1 Wallflower
      gameEngine.addPlayer(
        'Dealer1',
        role: roleRepository.getRoleById('dealer'),
      );
      gameEngine.addPlayer('Whore1', role: roleRepository.getRoleById('whore'));
      gameEngine.addPlayer('PA1',
          role: roleRepository.getRoleById('party_animal'));
      gameEngine.addPlayer('WF1',
          role: roleRepository.getRoleById('wallflower'));
      await gameEngine.startGame();

      final whore = gameEngine.players.firstWhere((p) => p.name == 'Whore1');
      final target = gameEngine.players.firstWhere((p) => p.name == 'WF1');

      // Night phase: Whore deflects to target
      whore.whoreDeflectionTargetId = target.id;

      // Day phase: Whore is voted out
      gameEngine.voteOutPlayer(whore.id);

      // Assertions
      expect(whore.isAlive, isTrue); // Whore should be alive
      expect(target.isAlive, isFalse); // Target should be dead
      expect(
        gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'),
        isTrue,
      );
    });
  });
}
