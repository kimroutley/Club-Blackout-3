import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/utils/death_causes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/file_role_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileRoleRepository repo;
  late GameEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = FileRoleRepository();
    await repo.loadRoles();
    engine = GameEngine(roleRepository: repo);

    engine.addPlayer('Dealer1', role: repo.getRoleById('dealer'));
    engine.addPlayer('LW1', role: repo.getRoleById('lightweight'));
    engine.addPlayer('PA1', role: repo.getRoleById('party_animal'));
    engine.addPlayer('Medic1', role: repo.getRoleById('medic'));

    await engine.startGame();
  });

  test('Lightweight taboo violation kills Lightweight immediately', () {
    final lw = engine.players.firstWhere((p) => p.role.id == 'lightweight');
    expect(lw.isAlive, isTrue);

    engine.markLightweightTabooViolation(tabooName: 'Dealer1');

    expect(lw.isAlive, isFalse);
    expect(lw.deathReason, DeathCause.spokeTabooName);
  });
}
