import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/ui/screens/lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Role tempRole() => Role(
        id: 'temp',
        name: 'Temp',
        alliance: 'None',
        type: 'meta',
        description: 'Temporary role used in lobby.',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      );

  testWidgets('Lobby: swipe-to-delete guest can be undone', (tester) async {
    // LobbyScreen touches HallOfFameService, which boots SharedPreferences.
    SharedPreferences.setMockInitialValues({});

    final engine = GameEngine(roleRepository: RoleRepository());
    engine.players.addAll([
      Player(id: 'p1', name: 'Alice', role: tempRole()),
      Player(id: 'p2', name: 'Bob', role: tempRole()),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: LobbyScreen(gameEngine: engine),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // Swipe Alice away (DismissDirection.endToStart).
    await tester.drag(find.byKey(const Key('p1')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // Order should be preserved (Alice remains above Bob).
    final aliceY = tester.getTopLeft(find.text('Alice')).dy;
    final bobY = tester.getTopLeft(find.text('Bob')).dy;
    expect(aliceY, lessThan(bobY));
  });
}
