import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences channel
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

  group('Minor Role Mechanics', () {
    late GameEngine engine;
    late Role minorRole;
    late Role dealerRole;
    late Role bouncerRole;

    setUp(() {
      // Mock or use real repository
      // Since it's a unit test, we can use a basic one or the real one if accessible
      // Assuming RoleRepository is available in logic/role_repository.dart
      final repo = RoleRepository();
      engine = GameEngine(roleRepository: repo);

      minorRole = Role(
        id: 'minor',
        name: 'The Minor',
        alliance: 'The Party Animals',
        type: 'defensive',
        description: 'Cannot die until IDd',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      );
      dealerRole = Role(
        id: 'dealer',
        name: 'The Dealer',
        alliance: 'The Dealers',
        type: 'aggressive',
        description: 'Kill',
        nightPriority: 5,
        assetPath: '',
        colorHex: '#FF00FF',
      );
      bouncerRole = Role(
        id: 'bouncer',
        name: 'The Bouncer',
        alliance: 'The Party Animals',
        type: 'investigative',
        description: 'Check ID',
        nightPriority: 2,
        assetPath: '',
        colorHex: '#0000FF',
      );

      // Manually inject roles to ensure repository has them if needed
      // (Assuming engine uses a singleton rep, but test isolation is good)
    });

    test('Minor survives dealer attack if not IDd', () {
      engine.createTestGame();
      // Clear auto-created players
      engine.players.clear();

      final minor = Player(id: 'm1', name: 'Minor', role: minorRole)
        ..initialize();
      final dealer = Player(id: 'd1', name: 'Dealer', role: dealerRole)
        ..initialize();

      engine.players.addAll([minor, dealer]);

      // Attempt to kill Minor
      engine.processDeath(minor, cause: 'dealer_kill');

      expect(minor.isAlive, isTrue,
          reason: 'Minor should survive dealer kill when not IDd');
      expect(engine.gameLog.first.description,
          contains('cannot be killed by the Dealers'));
    });

    test('Minor dies if attacked after being IDd by Bouncer', () {
      engine.createTestGame();
      engine.players.clear();

      final minor = Player(id: 'm1', name: 'Minor', role: minorRole)
        ..initialize();
      final bouncer = Player(id: 'b1', name: 'Bouncer', role: bouncerRole)
        ..initialize();
      final dealer = Player(id: 'd1', name: 'Dealer', role: dealerRole)
        ..initialize();

      engine.players.addAll([minor, bouncer, dealer]);

      final alertBefore = engine.hostAlertVersion;

      // Night 1: Bouncer checks ID
      const bouncerStep = ScriptStep(
          id: 'bouncer_act',
          title: 'Bouncer',
          readAloudText: 'Text',
          instructionText: 'Text',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'bouncer');

      engine.handleScriptAction(bouncerStep, [minor.id]);

      expect(minor.minorHasBeenIDd, isTrue,
          reason: 'Minor should be flagged as IDd');

      expect(engine.hostAlertVersion, alertBefore + 1);
      expect(engine.hostAlertTitle, isNotNull);
      expect(engine.hostAlertMessage, contains('no longer immune'));

      // Night 2 (or same night): Dealer attacks
      engine.processDeath(minor, cause: 'dealer_kill');

      expect(minor.isAlive, isFalse,
          reason: 'Minor should die to dealer kill after being IDd');
    });

    test('Minor dies to other causes (e.g. Vote) even if not IDd', () {
      engine.createTestGame();
      engine.players.clear();

      final minor = Player(id: 'm1', name: 'Minor', role: minorRole)
        ..initialize();
      engine.players.add(minor);

      // Attempt to vote out
      engine.processDeath(minor, cause: 'vote');

      expect(minor.isAlive, isFalse,
          reason: 'Minor should die to voting even if not IDd');
    });
  });
}
