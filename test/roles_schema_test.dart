import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roles.json schema validation', () {
    late Map<String, dynamic> rolesData;

    setUpAll(() {
      // Load roles.json file
      final file = File('assets/data/roles.json');
      expect(file.existsSync(), true, reason: 'roles.json file must exist at assets/data/roles.json');

      final jsonString = file.readAsStringSync();
      rolesData = json.decode(jsonString) as Map<String, dynamic>;
    });

    test('roles.json has "roles" array', () {
      expect(rolesData.containsKey('roles'), true);
      expect(rolesData['roles'], isA<List>());
    });

    test('each role has required fields: id, name, nightPriority', () {
      final roles = rolesData['roles'] as List;
      expect(roles.isNotEmpty, true, reason: 'roles array should not be empty');

      for (var i = 0; i < roles.length; i++) {
        final role = roles[i] as Map<String, dynamic>;
        
        // Check for 'id' field
        expect(role.containsKey('id'), true, 
            reason: 'Role at index $i must have "id" field');
        expect(role['id'], isA<String>(), 
            reason: 'Role at index $i: "id" must be a string');
        expect((role['id'] as String).isNotEmpty, true, 
            reason: 'Role at index $i: "id" must not be empty');

        // Check for 'name' field
        expect(role.containsKey('name'), true, 
            reason: 'Role at index $i (${role['id']}) must have "name" field');
        expect(role['name'], isA<String>(), 
            reason: 'Role at index $i (${role['id']}): "name" must be a string');
        expect((role['name'] as String).isNotEmpty, true, 
            reason: 'Role at index $i (${role['id']}): "name" must not be empty');

        // Check for 'night_priority' field (note: using snake_case as per JSON convention)
        expect(role.containsKey('night_priority'), true, 
            reason: 'Role at index $i (${role['id']}) must have "night_priority" field');
        expect(role['night_priority'], isA<int>(), 
            reason: 'Role at index $i (${role['id']}): "night_priority" must be an integer');
      }
    });

    test('role IDs are unique', () {
      final roles = rolesData['roles'] as List;
      final ids = <String>[];
      final duplicates = <String>[];

      for (var role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final id = roleMap['id'] as String;
        
        if (ids.contains(id)) {
          duplicates.add(id);
        } else {
          ids.add(id);
        }
      }

      expect(duplicates.isEmpty, true, 
          reason: 'Duplicate role IDs found: ${duplicates.join(", ")}');
      expect(ids.length, roles.length, 
          reason: 'Number of unique IDs should match number of roles');
    });

    test('all roles have valid alliance values', () {
      final roles = rolesData['roles'] as List;
      final validAlliances = [
        'The Dealers',
        'The Party Animals',
        'Neutral',
        'None (Neutral Survivor)',
        'Variable',
      ];

      for (var i = 0; i < roles.length; i++) {
        final role = roles[i] as Map<String, dynamic>;
        
        if (role.containsKey('alliance')) {
          final alliance = role['alliance'] as String;
          expect(validAlliances.contains(alliance), true,
              reason: 'Role ${role['id']} has invalid alliance: $alliance');
        }
      }
    });

    test('night_priority values are non-negative integers', () {
      final roles = rolesData['roles'] as List;

      for (var role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final priority = roleMap['night_priority'] as int;
        
        expect(priority >= 0, true, 
            reason: 'Role ${roleMap['id']} has negative night_priority: $priority');
      }
    });

    test('roles have description field', () {
      final roles = rolesData['roles'] as List;

      for (var role in roles) {
        final roleMap = role as Map<String, dynamic>;
        
        expect(roleMap.containsKey('description'), true,
            reason: 'Role ${roleMap['id']} must have "description" field');
        expect(roleMap['description'], isA<String>(),
            reason: 'Role ${roleMap['id']}: "description" must be a string');
      }
    });

    test('roles with has_binary_choice_at_start have choices array', () {
      final roles = rolesData['roles'] as List;

      for (var role in roles) {
        final roleMap = role as Map<String, dynamic>;
        
        if (roleMap.containsKey('has_binary_choice_at_start') && 
            roleMap['has_binary_choice_at_start'] == true) {
          expect(roleMap.containsKey('choices'), true,
              reason: 'Role ${roleMap['id']} has has_binary_choice_at_start but no choices array');
          expect(roleMap['choices'], isA<List>(),
              reason: 'Role ${roleMap['id']}: "choices" must be an array');
          final choices = roleMap['choices'] as List;
          expect(choices.length, greaterThan(0),
              reason: 'Role ${roleMap['id']}: "choices" array must not be empty');
        }
      }
    });
  });
}
