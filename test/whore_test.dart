import 'package:flutter_test/flutter_test.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/models/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late RoleRepository roleRepository;
  late GameEngine gameEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    roleRepository = RoleRepository();
    await roleRepository.loadRoles();
    gameEngine = GameEngine(roleRepository: roleRepository);
  });

  group('The Whore Scenarios', () {
    test('Whore deflection saves a Dealer from being voted out', () {
      // Setup: 1 Dealer, 1 Whore, 2 Party Animals
      final dealer = Player(id: 'd1', name: 'Dealer1', role: roleRepository.getRoleById('dealer')!);
      final whore = Player(id: 'w1', name: 'Whore1', role: roleRepository.getRoleById('whore')!);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: roleRepository.getRoleById('party_animal')!);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: roleRepository.getRoleById('party_animal')!);
      
      gameEngine.players = [dealer, whore, pa1, pa2];
      
      // Night phase: Whore deflects to PA2
      gameEngine.nightActions['whore_redirect_target'] = pa2.id;
      
      // Day phase: Dealer is voted out
      gameEngine.voteOutPlayer(dealer.id);
      
      // Assertions
      expect(dealer.isAlive, true); // Dealer should be alive
      expect(pa2.isAlive, false);  // PA2 should be dead
      expect(gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'), true);
    });

    test('Whore deflection saves the Whore from being voted out', () {
      // Setup: 1 Dealer, 1 Whore, 2 Party Animals
      final dealer = Player(id: 'd1', name: 'Dealer1', role: roleRepository.getRoleById('dealer')!);
      final whore = Player(id: 'w1', name: 'Whore1', role: roleRepository.getRoleById('whore')!);
      final pa1 = Player(id: 'pa1', name: 'PA1', role: roleRepository.getRoleById('party_animal')!);
      final pa2 = Player(id: 'pa2', name: 'PA2', role: roleRepository.getRoleById('party_animal')!);

      gameEngine.players = [dealer, whore, pa1, pa2];

      // Night phase: Whore deflects to PA2
      gameEngine.nightActions['whore_redirect_target'] = pa2.id;

      // Day phase: Whore is voted out
      gameEngine.voteOutPlayer(whore.id);

      // Assertions
      expect(whore.isAlive, true); // Whore should be alive
      expect(pa2.isAlive, false); // PA2 should be dead
      expect(gameEngine.gameLog.any((log) => log.title == 'Vote Deflection'), true);
    });
  });
}