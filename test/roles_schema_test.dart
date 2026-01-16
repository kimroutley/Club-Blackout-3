import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roles Schema Validation', () {
    test('roles.json exists and has valid structure', () async {
      // Load the roles.json file
      final String rolesJson = await rootBundle.loadString('assets/data/roles.json');
      expect(rolesJson, isNotEmpty);

      // Parse JSON
      final Map<String, dynamic> data = jsonDecode(rolesJson);

      // Validate top-level structure
      expect(data, containsPair('roles', isA<List>()));

      final List<dynamic> roles = data['roles'];
      expect(roles, isNotEmpty);

      // Track unique IDs
      final Set<String> roleIds = {};

      for (var role in roles) {
        expect(role, isA<Map<String, dynamic>>());

        final Map<String, dynamic> roleData = role;

        // Validate required fields
        expect(roleData, containsPair('id', isA<String>()));
        expect(roleData, containsPair('name', isA<String>()));
        expect(roleData, containsPair('alliance', isA<String>()));
        expect(roleData, containsPair('type', isA<String>()));
        expect(roleData, containsPair('night_priority', isA<int>()));
        expect(roleData, containsPair('asset_path', isA<String>()));

        final String roleId = roleData['id'];

        // Validate unique IDs
        expect(roleIds.contains(roleId), isFalse,
            reason: 'Duplicate role ID found: $roleId');
        roleIds.add(roleId);

        // Validate ID format (no spaces, lowercase with underscores)
        expect(roleId, matches(r'^[a-z_]+$'),
            reason: 'Role ID "$roleId" should be lowercase with underscores only');

        // Validate name is not empty
        expect(roleData['name'], isNotEmpty);

        // Validate alliance is one of expected values
        final String alliance = roleData['alliance'];
        expect(
          ['The Dealers', 'The Party Animals', 'Neutral', 'VARIABLE', 'None'],
          contains(alliance),
          reason: 'Role $roleId has invalid alliance: $alliance',
        );

        // Validate night_priority is reasonable
        final int priority = roleData['night_priority'];
        expect(priority, greaterThanOrEqualTo(0));
        expect(priority, lessThanOrEqualTo(10));
      }

      // Validate specific critical roles exist
      expect(roleIds, contains('dealer'));
      expect(roleIds, contains('party_animal'));
      expect(roleIds, contains('medic'));
      expect(roleIds, contains('bouncer'));
    });

    test('roles.json optional fields are valid when present', () async {
      final String rolesJson = await rootBundle.loadString('assets/data/roles.json');
      final Map<String, dynamic> data = jsonDecode(rolesJson);
      final List<dynamic> roles = data['roles'];

      for (var role in roles) {
        final Map<String, dynamic> roleData = role;
        final String roleId = roleData['id'];

        // Validate optional fields if present
        if (roleData.containsKey('description')) {
          expect(roleData['description'], isA<String>());
        }

        if (roleData.containsKey('has_binary_choice_at_start')) {
          expect(roleData['has_binary_choice_at_start'], isA<bool>());
        }

        if (roleData.containsKey('choices')) {
          expect(roleData['choices'], isA<List>());
        }

        if (roleData.containsKey('ability')) {
          expect(roleData['ability'], isA<String>());
        }

        if (roleData.containsKey('start_alliance')) {
          expect(roleData['start_alliance'], isA<String>());
        }

        if (roleData.containsKey('death_alliance')) {
          expect(roleData['death_alliance'], isA<String>());
        }

        if (roleData.containsKey('color_hex')) {
          final String colorHex = roleData['color_hex'];
          expect(colorHex, matches(r'^#[0-9A-Fa-f]{6}$'),
              reason: 'Role $roleId has invalid color_hex: $colorHex');
        }
      }
    });
  });
}
