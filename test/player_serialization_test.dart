import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Player serialization persists role state', () {
    final role = Role(
      id: 'roofi',
      name: 'The Roofi',
      alliance: 'DEALER',
      type: 'ROLE',
      description: 'test',
      nightPriority: 0,
      assetPath: 'assets/test.png',
      colorHex: '#FFFFFF',
    );

    final player = Player(id: 'p1', name: 'Alice', role: role)
      ..roofiAbilityRevoked = true
      ..bouncerAbilityRevoked = true
      ..bouncerHasRoofiAbility = true
      ..secondWindConverted = true
      ..secondWindPendingConversion = true
      ..secondWindRefusedConversion = true
      ..secondWindConversionNight = 2
      ..teaSpillerTargetId = 'p2'
      ..predatorTargetId = 'p3'
      ..dramaQueenTargetAId = 'p4'
      ..dramaQueenTargetBId = 'p5';

    final json = player.toJson();
    final restored = Player.fromJson(json, role);

    expect(restored.roofiAbilityRevoked, isTrue);
    expect(restored.bouncerAbilityRevoked, isTrue);
    expect(restored.bouncerHasRoofiAbility, isTrue);

    expect(restored.secondWindConverted, isTrue);
    expect(restored.secondWindPendingConversion, isTrue);
    expect(restored.secondWindRefusedConversion, isTrue);
    expect(restored.secondWindConversionNight, 2);

    expect(restored.teaSpillerTargetId, 'p2');
    expect(restored.predatorTargetId, 'p3');
    expect(restored.dramaQueenTargetAId, 'p4');
    expect(restored.dramaQueenTargetBId, 'p5');
  });
}
