import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  const String nightPriorityField = 'night_priority';
  
  group('Roles Schema Validation', () {
    test('roles.json exists and loads successfully', () async {
      // Verify the file can be loaded
      expect(
        () async => await rootBundle.loadString('assets/data/roles.json'),
        returnsNormally,
      );
    });
    
    test('roles.json contains valid JSON with roles array', () async {
      final String response = await rootBundle.loadString('assets/data/roles.json');
      final data = json.decode(response);
      
      // Verify structure
      expect(data, isA<Map<String, dynamic>>());
      expect(data.containsKey('roles'), true);
      expect(data['roles'], isA<List>());
    });
    
    test('each role has required fields: id, name, nightPriority', () async {
      final String response = await rootBundle.loadString('assets/data/roles.json');
      final data = json.decode(response);
      final roles = data['roles'] as List;
      
      expect(roles.isNotEmpty, true, reason: 'Roles array should not be empty');
      
      for (var i = 0; i < roles.length; i++) {
        final role = roles[i] as Map<String, dynamic>;
        
        // Check for required fields
        expect(
          role.containsKey('id'),
          true,
          reason: 'Role at index $i missing "id" field',
        );
        expect(
          role.containsKey('name'),
          true,
          reason: 'Role at index $i missing "name" field',
        );
        expect(
          role.containsKey(nightPriorityField),
          true,
          reason: 'Role at index $i missing "$nightPriorityField" field',
        );
        
        // Validate field types
        expect(
          role['id'],
          isA<String>(),
          reason: 'Role at index $i has non-string id',
        );
        expect(
          role['name'],
          isA<String>(),
          reason: 'Role at index $i has non-string name',
        );
        expect(
          role[nightPriorityField],
          isA<int>(),
          reason: 'Role at index $i has non-integer $nightPriorityField',
        );
      }
    });
    
    test('role IDs are unique', () async {
      final String response = await rootBundle.loadString('assets/data/roles.json');
      final data = json.decode(response);
      final roles = data['roles'] as List;
      
      final ids = <String>[];
      final duplicates = <String>[];
      
      for (final role in roles) {
        final id = role['id'] as String;
        if (ids.contains(id)) {
          duplicates.add(id);
        } else {
          ids.add(id);
        }
      }
      
      expect(
        duplicates,
        isEmpty,
        reason: 'Duplicate role IDs found: ${duplicates.join(", ")}',
      );
    });
    
    test('role names are unique', () async {
      final String response = await rootBundle.loadString('assets/data/roles.json');
      final data = json.decode(response);
      final roles = data['roles'] as List;
      
      final names = <String>[];
      final duplicates = <String>[];
      
      for (final role in roles) {
        final name = role['name'] as String;
        if (names.contains(name)) {
          duplicates.add(name);
        } else {
          names.add(name);
        }
      }
      
      expect(
        duplicates,
        isEmpty,
        reason: 'Duplicate role names found: ${duplicates.join(", ")}',
      );
    });
    
    test('night_priority values are non-negative', () async {
      final String response = await rootBundle.loadString('assets/data/roles.json');
      final data = json.decode(response);
      final roles = data['roles'] as List;
      
      for (var i = 0; i < roles.length; i++) {
        final role = roles[i] as Map<String, dynamic>;
        final priority = role[nightPriorityField] as int;
        
        expect(
          priority >= 0,
          true,
          reason: 'Role "${role['name']}" has negative $nightPriorityField: $priority',
        );
      }
    });
  });
}
