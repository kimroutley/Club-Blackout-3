import 'package:club_blackout/logic/script_builder.dart';
import 'package:club_blackout/models/player.dart';
import 'package:club_blackout/models/script_step.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/file_role_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Night Script Audit', () {
    late FileRoleRepository repo;

    setUp(() async {
      repo = FileRoleRepository();
      await repo.loadRoles();
    });

    List<Player> makeAllRolesPlayers() {
      final roles = repo.roles
          .where((r) => r.id != 'host' && r.id != 'temp')
          .toList(growable: false);

      final players = <Player>[];
      var i = 1;
      for (final role in roles) {
        final p = Player(id: '$i', name: 'P$i-${role.id}', role: role);
        p.initialize();

        // Ensure optional/conditional night roles actually produce steps.
        if (role.id == 'clinger') {
          p.clingerFreedAsAttackDog = true;
          p.clingerAttackDogUsed = false;
        }

        // Keep Roofi + Bouncer in their normal state for script coverage.
        if (role.id == 'roofi') {
          p.roofiAbilityRevoked = false;
        }
        if (role.id == 'bouncer') {
          p.bouncerAbilityRevoked = false;
          p.bouncerHasRoofiAbility = false;
        }

        players.add(p);
        i++;
      }

      // Defensive: ScriptBuilder assumes at least one non-host player exists.
      expect(players.where((p) => p.role.id != 'host').isNotEmpty, isTrue);

      return players;
    }

    List<String> expandRoleList(String rawGroup) {
      // Strip parenthetical modifiers like "(and The Creep)".
      var g = rawGroup.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

      // Normalize whitespace.
      g = g.replaceAll(RegExp(r'\s+'), ' ');

      // Split on commas first, then on " and ".
      final commaParts = g
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      final names = <String>[];
      for (final part in commaParts) {
        final andParts = part
            .split(RegExp(r'\s+and\s+', caseSensitive: false))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        names.addAll(andParts);
      }

      return names;
    }

    List<String> parseOpenNames(String text) {
      final matches = RegExp(
        r"([A-Za-z][A-Za-z\s\-']*)\s*,\s*open your eyes",
        caseSensitive: false,
      ).allMatches(text);

      final opened = <String>[];
      for (final m in matches) {
        final group = (m.group(1) ?? '').trim();
        if (group.isEmpty) continue;
        opened.addAll(expandRoleList(group));
      }
      return opened;
    }

    List<String> parseCloseNames(String text) {
      final matches = RegExp(
        r"([A-Za-z][A-Za-z\s\-']*)\s*,\s*close your eyes",
        caseSensitive: false,
      ).allMatches(text);

      final closed = <String>[];
      for (final m in matches) {
        final name = (m.group(1) ?? '').trim();
        if (name.isEmpty) continue;
        closed.add(name);
      }
      return closed;
    }

    void assertNoOneLeftAwake(List<ScriptStep> steps) {
      final awake = <String>{};

      for (final step in steps) {
        final text = step.readAloudText;
        if (text.trim().isEmpty) continue;

        awake.addAll(parseOpenNames(text));

        final lower = text.toLowerCase();

        // "Now close your eyes" is our canonical "everybody sleeping" close.
        if (lower.contains('now close your eyes')) {
          awake.clear();
          continue;
        }

        // Otherwise, try role-addressed closes.
        final closeNames = parseCloseNames(text);
        awake.removeAll(closeNames);
      }

      expect(
        awake,
        isEmpty,
        reason:
            'Some roles were instructed to open their eyes, but were never clearly told to close them: ${awake.join(', ')}',
      );
    }

    test('Night 1+ always starts with the sleep ritual', () {
      final players = makeAllRolesPlayers();

      final night1 = ScriptBuilder.buildNightScript(players, 1);
      expect(night1.isNotEmpty, isTrue);
      expect(night1.first.id, 'night_start');
      expect(night1.first.readAloudText.toUpperCase(), contains('CLOSE YOUR EYES'));

      final night2 = ScriptBuilder.buildNightScript(players, 2);
      expect(night2.isNotEmpty, isTrue);
      expect(night2.first.id, 'night_start');
    });

    test('Night script never includes Second Wind conversion choice (engine-injected, host-only)', () {
      final players = makeAllRolesPlayers();
      final steps = ScriptBuilder.buildNightScript(players, 1);
      expect(steps.any((s) => s.id == 'second_wind_conversion_vote'), isFalse);
      expect(steps.any((s) => s.id == 'second_wind_conversion_choice'), isFalse);
    });

    test('Every "open your eyes" is eventually followed by a close instruction', () {
      final players = makeAllRolesPlayers();

      // Audit both Night 1 and Night 2 flows.
      assertNoOneLeftAwake(ScriptBuilder.buildNightScript(players, 1));
      assertNoOneLeftAwake(ScriptBuilder.buildNightScript(players, 2));
    });

    test('Silver Fox always goes last in the night phase', () {
      final roleIds = <String>[
        // Priority roles
        'sober',
        'dealer',
        'bouncer',
        'medic',

        // Other night-action roles
        'messy_bitch',

        // Must be last
        'silver_fox',

        // Include integrated roles so Dealer steps are expanded
        'whore',
        'wallflower',
      ];

      final players = <Player>[];
      var i = 1;
      for (final roleId in roleIds) {
        final role = repo.getRoleById(roleId);
        expect(role, isNotNull, reason: 'roles.json missing role: $roleId');

        final p = Player(id: '$i', name: 'P$i-$roleId', role: role!);
        p.initialize();

        // Ensure integrated/conditional steps appear.
        if (roleId == 'whore') {
          p.whoreDeflectionUsed = false;
        }
        if (roleId == 'wallflower') {
          // No special flags needed; presence is enough (unless Dealer is sent home).
        }
        if (roleId == 'bouncer') {
          p.bouncerAbilityRevoked = false;
          p.bouncerHasRoofiAbility = false;
        }
        if (roleId == 'roofi') {
          p.roofiAbilityRevoked = false;
        }
        if (roleId == 'medic') {
          // Explicitly set a stable choice so this test isn't sensitive to defaults.
          p.medicChoice = 'PROTECT_DAILY';
        }

        players.add(p);
        i++;
      }

      final steps = ScriptBuilder.buildNightScript(players, 1);
      final silverFoxIndex = steps.indexWhere((s) => s.id == 'silver_fox_act');
      expect(silverFoxIndex, isNot(-1), reason: 'Expected silver_fox_act to be present');

      final lastNonSilverRoleStepIndex = steps.lastIndexWhere(
        (s) => s.roleId != null && s.id != 'silver_fox_act',
      );
      expect(
        silverFoxIndex,
        greaterThan(lastNonSilverRoleStepIndex),
        reason: 'Silver Fox should act after all other night role steps',
      );
    });
  });
}
