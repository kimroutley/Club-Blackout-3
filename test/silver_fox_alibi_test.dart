import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/logic/game_engine.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/role.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences channel (some engine code paths touch it).
  const sharedPrefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sharedPrefsChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getAll') {
      return <String, dynamic>{};
    }
    return null;
  });

  group('Silver Fox - Alibi (Vote Immunity)', () {
    late GameEngine engine;
    late Role silverFoxRole;
    late Role partyRole;

    setUp(() {
      engine = GameEngine(roleRepository: RoleRepository());

      silverFoxRole = Role(
        id: 'silver_fox',
        name: 'The Silver Fox',
        alliance: 'The Dealers',
        type: 'disruptive',
        description: 'Nightly alibi',
        nightPriority: 1,
        assetPath: '',
        colorHex: '#808000',
      );

      partyRole = Role(
        id: 'party_animal',
        name: 'Party Animal',
        alliance: 'The Party Animals',
        type: 'basic',
        description: 'Just vibing',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      );

      engine.players.clear();
      engine.clearDayVotes();
      engine.nightActions.clear();
      engine.dayCount = 2; // Use an in-day value (see engine dayCount semantics)
    });

    test('handleScriptAction assigns alibi for following day', () {
      final fox = Player(id: 'sf', name: 'SilverFox', role: silverFoxRole)
        ..initialize();
      final target = Player(id: 't1', name: 'Target', role: partyRole)
        ..initialize();

      engine.players.addAll([fox, target]);

      const step = ScriptStep(
        id: 'silver_fox_act',
        title: 'Alibi',
        readAloudText: 'Text',
        instructionText: 'Text',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'silver_fox',
      );

      engine.handleScriptAction(step, [target.id]);

      expect(engine.nightActions['silver_fox_alibi'], target.id);
      expect(target.alibiDay, engine.dayCount + 1);
    });

    test('recordVote ignores votes against an alibied target', () {
      final voter = Player(id: 'v1', name: 'Voter', role: partyRole)
        ..initialize();
      final immune = Player(id: 't1', name: 'Immune', role: partyRole)
        ..initialize();
      immune.alibiDay = engine.dayCount;

      engine.players.addAll([voter, immune]);

      engine.recordVote(voterId: voter.id, targetId: immune.id);

      expect(engine.currentDayVotesByVoter[voter.id], isNull);
      expect(engine.currentDayVotesByTarget.containsKey(immune.id), isFalse);
      expect(engine.eligibleDayVotesByTarget.containsKey(immune.id), isFalse);
    });

    test('voteOutPlayer refuses to eliminate an alibied target', () {
      final immune = Player(id: 't1', name: 'Immune', role: partyRole)
        ..initialize();
      immune.alibiDay = engine.dayCount;

      engine.players.add(immune);

      final result = engine.voteOutPlayer(immune.id);

      expect(result, isFalse);
      expect(immune.isAlive, isTrue);
    });

    test('alibi expires when the day ends', () {
      final immune = Player(id: 't1', name: 'Immune', role: partyRole)
        ..initialize();
      immune.alibiDay = engine.dayCount;

      engine.players.add(immune);
      engine.currentPhase = GamePhase.day;

      engine.skipToNextPhase();

      expect(engine.currentPhase, GamePhase.night);
      expect(immune.alibiDay, isNull);
    });
  });
}
