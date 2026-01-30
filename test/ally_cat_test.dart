import 'package:club_blackout/data/role_repository.dart'; // Added
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock repository
class MockRoleRepository extends RoleRepository {
  @override
  Future<void> loadRoles() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sharedPrefsChannel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sharedPrefsChannel,
          (MethodCall methodCall) async {
    if (methodCall.method == 'getAll') {
      return <String, dynamic>{};
    }
    return null;
  });

  group('Ally Cat Mechanics', () {
    late GameEngine engine;
    late Role allyCatRole;

    Role createRole(String id, int priority) {
      return Role(
        id: id,
        name: id.toUpperCase(),
        description: 'Test Role $id',
        alliance: 'party_goer',
        type: 'active',
        nightPriority: priority,
        assetPath: 'assets/test.png',
        colorHex: '0xFF00FF00',
      );
    }

    setUp(() {
      allyCatRole = createRole('ally_cat', 5);

      engine = GameEngine(roleRepository: MockRoleRepository());
    });

    test('Ally Cat starts with 9 lives', () {
      final p1 = Player(id: '1', name: 'Cat', role: allyCatRole);
      p1.initialize();
      expect(p1.lives, equals(9));
    });

    test('Ally Cat loses a life but survives Night Kill', () {
      final p1 = Player(id: '1', name: 'Cat', role: allyCatRole);
      p1.initialize();

      engine.processDeath(p1, cause: 'night_kill');

      expect(p1.lives, equals(8));
      expect(p1.isAlive, isTrue);
    });

    test('Ally Cat loses a life but survives Vote', () {
      final p1 = Player(id: '1', name: 'Cat', role: allyCatRole);
      p1.initialize();

      engine.processDeath(p1, cause: 'vote');

      expect(p1.lives, equals(8));
      expect(p1.isAlive, isTrue);
    });

    test('Ally Cat dies after 9 hits', () {
      final p1 = Player(id: '1', name: 'Cat', role: allyCatRole);
      p1.initialize(); // lives = 9

      for (int i = 0; i < 9; i++) {
        expect(p1.isAlive, isTrue,
            reason: 'Should be alive before hit ${i + 1}');
        engine.processDeath(p1, cause: 'vote');
      }

      expect(p1.lives, equals(0));
      expect(p1.isAlive, isFalse, reason: 'Should be dead after 9th hit');
    });
  });
}
