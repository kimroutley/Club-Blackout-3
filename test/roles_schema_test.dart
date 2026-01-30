import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roles.json schema validation', () {
    late Map<String, dynamic> rolesData;

    setUpAll(() {
      // Read roles.json from the project root
      final file = File('assets/data/roles.json');
      expect(file.existsSync(), isTrue, reason: 'roles.json file must exist');

      final content = file.readAsStringSync();
      rolesData = jsonDecode(content) as Map<String, dynamic>;
    });

    test('roles.json has valid JSON structure', () {
      expect(rolesData, isNotNull);
      expect(rolesData, contains('roles'));
      expect(rolesData['roles'], isA<List>());
    });

    test('all roles have required fields', () {
      final roles = rolesData['roles'] as List;
      expect(
        roles,
        isNotEmpty,
        reason: 'roles.json must contain at least one role',
      );

      for (final role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final roleId = roleMap['id'] as String?;

        // Required fields
        expect(roleMap, contains('id'), reason: 'Role must have id field');
        expect(
          roleMap,
          contains('name'),
          reason: 'Role $roleId must have name field',
        );
        expect(
          roleMap,
          contains('alliance'),
          reason: 'Role $roleId must have alliance field',
        );
        expect(
          roleMap,
          contains('type'),
          reason: 'Role $roleId must have type field',
        );
        expect(
          roleMap,
          contains('description'),
          reason: 'Role $roleId must have description field',
        );
        expect(
          roleMap,
          contains('night_priority'),
          reason: 'Role $roleId must have night_priority field',
        );
        expect(
          roleMap,
          contains('asset_path'),
          reason: 'Role $roleId must have asset_path field',
        );
        expect(
          roleMap,
          contains('color_hex'),
          reason: 'Role $roleId must have color_hex field',
        );

        // Type validation
        expect(
          roleMap['id'],
          isA<String>(),
          reason: 'Role id must be a string',
        );
        expect(
          roleMap['name'],
          isA<String>(),
          reason: 'Role $roleId name must be a string',
        );
        expect(
          roleMap['alliance'],
          isA<String>(),
          reason: 'Role $roleId alliance must be a string',
        );
        expect(
          roleMap['type'],
          isA<String>(),
          reason: 'Role $roleId type must be a string',
        );
        expect(
          roleMap['description'],
          isA<String>(),
          reason: 'Role $roleId description must be a string',
        );
        expect(
          roleMap['night_priority'],
          isA<int>(),
          reason: 'Role $roleId night_priority must be an integer',
        );
        expect(
          roleMap['asset_path'],
          isA<String>(),
          reason: 'Role $roleId asset_path must be a string',
        );
        expect(
          roleMap['color_hex'],
          isA<String>(),
          reason: 'Role $roleId color_hex must be a string',
        );

        // Non-empty validation
        expect(roleMap['id'], isNotEmpty, reason: 'Role id must not be empty');
        expect(
          roleMap['name'],
          isNotEmpty,
          reason: 'Role $roleId name must not be empty',
        );
        expect(
          roleMap['alliance'],
          isNotEmpty,
          reason: 'Role $roleId alliance must not be empty',
        );
        expect(
          roleMap['type'],
          isNotEmpty,
          reason: 'Role $roleId type must not be empty',
        );
      }
    });

    test('all role IDs are unique', () {
      final roles = rolesData['roles'] as List;
      final ids = <String>[];

      for (final role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final id = roleMap['id'] as String;

        expect(
          ids,
          isNot(contains(id)),
          reason: 'Duplicate role ID found: $id',
        );
        ids.add(id);
      }
    });

    test('night_priority values are valid', () {
      final roles = rolesData['roles'] as List;

      for (final role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final roleId = roleMap['id'] as String;
        final priority = roleMap['night_priority'] as int;

        // Night priority should be between 0 and 10 (reasonable range)
        expect(
          priority,
          greaterThanOrEqualTo(0),
          reason: 'Role $roleId night_priority must be >= 0',
        );
        expect(
          priority,
          lessThanOrEqualTo(10),
          reason: 'Role $roleId night_priority should be <= 10',
        );
      }
    });

    test('color_hex values are valid hex colors', () {
      final roles = rolesData['roles'] as List;
      final hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

      for (final role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final roleId = roleMap['id'] as String;
        final colorHex = roleMap['color_hex'] as String;

        expect(
          hexColorPattern.hasMatch(colorHex),
          isTrue,
          reason:
              'Role $roleId color_hex must be valid hex color format (#RRGGBB)',
        );
      }
    });

    test('required roles exist (dealer, party_animal, medic, bouncer)', () {
      final roles = rolesData['roles'] as List;
      final roleIds =
          roles.map((r) => (r as Map<String, dynamic>)['id'] as String).toSet();

      expect(
        roleIds,
        contains('dealer'),
        reason: 'roles.json must include dealer role',
      );
      expect(
        roleIds,
        contains('party_animal'),
        reason: 'roles.json must include party_animal role',
      );
      expect(
        roleIds,
        contains('medic'),
        reason: 'roles.json must include medic role',
      );
      expect(
        roleIds,
        contains('bouncer'),
        reason: 'roles.json must include bouncer role',
      );
    });

    test('optional fields have correct types when present', () {
      final roles = rolesData['roles'] as List;

      for (final role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final roleId = roleMap['id'] as String;

        // Optional: has_binary_choice_at_start
        if (roleMap.containsKey('has_binary_choice_at_start')) {
          expect(
            roleMap['has_binary_choice_at_start'],
            isA<bool>(),
            reason: 'Role $roleId has_binary_choice_at_start must be a boolean',
          );
        }

        // Optional: choices
        if (roleMap.containsKey('choices')) {
          expect(
            roleMap['choices'],
            isA<List>(),
            reason: 'Role $roleId choices must be a list',
          );
          for (final choice in roleMap['choices'] as List) {
            expect(
              choice,
              isA<String>(),
              reason: 'Role $roleId choices must contain strings',
            );
          }
        }

        // Optional: ability
        if (roleMap.containsKey('ability')) {
          expect(
            roleMap['ability'],
            isA<String>(),
            reason: 'Role $roleId ability must be a string',
          );
        }

        // Optional: start_alliance
        if (roleMap.containsKey('start_alliance')) {
          expect(
            roleMap['start_alliance'],
            isA<String>(),
            reason: 'Role $roleId start_alliance must be a string',
          );
        }

        // Optional: death_alliance
        if (roleMap.containsKey('death_alliance')) {
          expect(
            roleMap['death_alliance'],
            isA<String>(),
            reason: 'Role $roleId death_alliance must be a string',
          );
        }
      }
    });

    test('roles with binary choice have choices array', () {
      final roles = rolesData['roles'] as List;

      for (final role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final roleId = roleMap['id'] as String;
        final hasBinaryChoice =
            roleMap['has_binary_choice_at_start'] as bool? ?? false;

        if (hasBinaryChoice) {
          expect(
            roleMap,
            contains('choices'),
            reason:
                'Role $roleId with has_binary_choice_at_start=true must have choices array',
          );
          expect(
            (roleMap['choices'] as List).length,
            greaterThanOrEqualTo(2),
            reason:
                'Role $roleId with binary choice must have at least 2 choices',
          );
        }
      }
    });
  });
}
