import 'package:club_blackout/logic/game_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

void main() {
  test('save/load persists Whore deflection target', () async {
    SharedPreferences.setMockInitialValues({});

    final roleRepo = FileRoleRepository();
    await roleRepo.loadRoles();

    final whoreRole = roleRepo.getRoleById('whore');
    final paRole = roleRepo.getRoleById('party_animal');

    final engine = GameEngine(roleRepository: roleRepo);

    engine.addPlayer('Whore1', role: whoreRole);
    engine.addPlayer('PA1', role: paRole);
    engine.addPlayer('PA2', role: paRole);
    engine.addPlayer('PA3', role: paRole);
    await engine.startGame();

    // Set the deflection target on the player object
    final whore = engine.players.firstWhere((p) => p.role.id == 'whore');
    final target =
        engine.players.firstWhere((p) => p.role.id == 'party_animal');
    whore.whoreDeflectionTargetId = target.id;

    // Save the game state
    await engine.saveGame('Whore Test');

    // Create a new engine and load the game
    final newEngine = GameEngine(roleRepository: roleRepo);
    final saves = await engine.getSavedGames();
    final saveId = saves.last.id;
    await newEngine.loadGame(saveId);

    // Verify the deflection target was restored
    final loadedWhore =
        newEngine.players.firstWhere((p) => p.role.id == 'whore');
    expect(loadedWhore.whoreDeflectionTargetId, target.id);
  });
}
