import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/ui/widgets/game_fab_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GameFabMenu renders regarding roles', (WidgetTester tester) async {
    final roleRepo = RoleRepository();
    final gameEngine = GameEngine(roleRepository: roleRepo);
    gameEngine.players.addAll([
      Player(
        id: 'p1',
        name: 'Messy Bitch Player',
        role: Role(
            id: 'messy_bitch',
            name: 'Messy Bitch',
            alliance: 'Neutral',
            type: 'chaos',
            description: 'Spread rumours',
            nightPriority: 1,
            assetPath: '',
            colorHex: '#000000'),
      ),
      Player(
        id: 'p2',
        name: 'Lightweight Player',
        role: Role(
            id: 'lightweight',
            name: 'Lightweight',
            alliance: 'Party',
            type: 'passive',
            description: 'Avoid taboo',
            nightPriority: 0,
            assetPath: '',
            colorHex: '#FFFFFF'),
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton: GameFabMenu(gameEngine: gameEngine),
      ),
    ));

    // Verify FAB is present via Key
    expect(find.byKey(const Key('game_fab_menu_main_btn')), findsOneWidget);

    // Initial state: menu items hidden
    expect(find.text('RUMOUR MILL'), findsNothing);
    expect(find.text('TABOO LIST'), findsNothing);

    // Tap to open
    await tester.tap(find.byKey(const Key('game_fab_menu_main_btn')));
    await tester.pumpAndSettle();

    // Verify menu items visible based on roles
    expect(find.text('RUMOUR MILL'), findsOneWidget);
    expect(find.text('TABOO LIST'), findsOneWidget);
    expect(find.text('CLINGER OPS'),
        findsNothing); // No Clinger in this test setup

    // Tap again to close
    await tester.tap(find.byKey(const Key('game_fab_menu_main_btn')));
    await tester.pumpAndSettle();

    // Verify menu items hidden
    expect(find.text('RUMOUR MILL'), findsNothing);
  });

  testWidgets('GameFabMenu hides itself when no actions exist',
      (WidgetTester tester) async {
    final roleRepo = RoleRepository();
    final gameEngine = GameEngine(roleRepository: roleRepo);
    gameEngine.players.addAll([
      Player(
        id: 'p1',
        name: 'Just A Player',
        role: Role(
            id: 'medic',
            name: 'Medic',
            alliance: 'Party',
            type: 'support',
            description: 'Heals',
            nightPriority: 1,
            assetPath: '',
            colorHex: '#FFFFFF'),
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton: GameFabMenu(gameEngine: gameEngine),
      ),
    ));

    expect(find.byKey(const Key('game_fab_menu_main_btn')), findsNothing);
  });
}
