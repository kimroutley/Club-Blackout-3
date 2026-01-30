import 'package:club_blackout/logic/script_builder.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to create roles
  Role createRole(String id, String type, int priority) {
    return Role(
      id: id,
      name: id.toUpperCase(),
      description: 'Test Role $id',
      alliance: 'party_goer',
      type: type, // 'active', 'passive', 'setup'
      nightPriority: priority,
      assetPath: 'assets/test.png',
      colorHex: '0xFF00FF00',
    );
  }

  group('Sober Mechanics Script Generation', () {
    late Role soberRole;
    late Role medicRole;
    late Role dealerRole;
    late Role wallflowerRole;

    setUp(() {
      soberRole = createRole('sober', 'active', 10);
      medicRole = createRole('medic', 'active', 5);
      dealerRole = createRole('dealer', 'active', 8);
      wallflowerRole = createRole('wallflower', 'passive', 0);
    });

    test('Sent home player is excluded from script', () {
      final p1 = Player(id: '1', name: 'Sober', role: soberRole);
      final p2 = Player(id: '2', name: 'Medic', role: medicRole);
      
      // Case 1: Normal
      var steps = ScriptBuilder.buildNightScript([p1, p2], 1);
      // Expect medic step
      expect(steps.any((s) => s.roleId == 'medic'), isTrue);

      // Case 2: Medic sent home
      p2.soberSentHome = true;
      steps = ScriptBuilder.buildNightScript([p1, p2], 1);
      
      // Expect NO medic step
      expect(steps.any((s) => s.roleId == 'medic'), isFalse);
    });

    test('Dealer sent home triggers Blocked Kill message', () {
      final p1 = Player(id: '1', name: 'Sober', role: soberRole);
      final p2 = Player(id: '2', name: 'Dealer1', role: dealerRole);
      final p3 = Player(id: '3', name: 'Dealer2', role: dealerRole);
      
      // Case 1: Normal Dealers
      var steps = ScriptBuilder.buildNightScript([p1, p2, p3], 1);
      expect(steps.any((s) => s.id == 'dealer_act'), isTrue);
      expect(steps.any((s) => s.id == 'dealer_kill_blocked'), isFalse);

      // Case 2: One Dealer sent home
      p2.soberSentHome = true;
      steps = ScriptBuilder.buildNightScript([p1, p2, p3], 1);
      
      expect(steps.any((s) => s.id == 'dealer_act'), isFalse, reason: 'Kill action should be blocked');
      expect(steps.any((s) => s.id == 'dealer_kill_blocked'), isTrue, reason: 'Blocked message should appear');
      
      // Verify text contains "NO MURDERS"
      final blockedStep = steps.firstWhere((s) => s.id == 'dealer_kill_blocked');
      expect(blockedStep.readAloudText, contains('NO MURDERS'));
    });
    
    test('Wallflower is skipped if Dealer sent home', () {
      // Need Wallflower role (using setUp initialized role)
       
      final p1 = Player(id: '1', name: 'Sober', role: soberRole);
      final p2 = Player(id: '2', name: 'Dealer1', role: dealerRole);
      final p3 = Player(id: '3', name: 'Wallflower', role: wallflowerRole);
      final p4 = Player(id: '4', name: 'Dealer2', role: dealerRole); // Survivor
      
      // Note: Wallflower wakes WITH Dealers.
      
      // Case 1: Normal - Wallflower present
      var steps = ScriptBuilder.buildNightScript([p1, p2, p3, p4], 1);
      
      expect(steps.any((s) => s.id == 'dealer_act'), isTrue);
      expect(steps.any((s) => s.id == 'wallflower_act'), isTrue);
      
      // Case 2: Dealer block (One dealer sent home, one remains)
      p2.soberSentHome = true;
      steps = ScriptBuilder.buildNightScript([p1, p2, p3, p4], 1);
      
      expect(steps.any((s) => s.id == 'dealer_kill_blocked'), isTrue, reason: 'Kill blocked msg expected');
      expect(steps.any((s) => s.id == 'wallflower_act'), isFalse, reason: 'Wallflower should skip witnessing if no murder');
    });
  });
}