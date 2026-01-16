import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Roles Schema Validation', () {
    test('assets/data/roles.json exists', () {
      final file = File('assets/data/roles.json');
      expect(file.existsSync(), true, reason: 'roles.json must exist');
    });
    
    test('roles.json contains valid JSON', () {
      final file = File('assets/data/roles.json');
      final contents = file.readAsStringSync();
      
      expect(() => json.decode(contents), returnsNormally,
          reason: 'roles.json must be valid JSON');
    });
    
    test('roles.json has "roles" array', () {
      final file = File('assets/data/roles.json');
      final contents = file.readAsStringSync();
      final data = json.decode(contents) as Map<String, dynamic>;
      
      expect(data.containsKey('roles'), true,
          reason: 'JSON must have "roles" key');
      expect(data['roles'], isA<List>(),
          reason: 'roles must be an array');
    });
    
    test('each role has required fields: id, name, nightPriority', () {
      final file = File('assets/data/roles.json');
      final contents = file.readAsStringSync();
      final data = json.decode(contents) as Map<String, dynamic>;
      final roles = data['roles'] as List;
      
      expect(roles.isNotEmpty, true, reason: 'roles array should not be empty');
      
      for (var i = 0; i < roles.length; i++) {
        final role = roles[i] as Map<String, dynamic>;
        
        expect(role.containsKey('id'), true,
            reason: 'Role at index $i must have "id" field');
        expect(role['id'], isA<String>(),
            reason: 'Role id at index $i must be a string');
        
        expect(role.containsKey('name'), true,
            reason: 'Role at index $i must have "name" field');
        expect(role['name'], isA<String>(),
            reason: 'Role name at index $i must be a string');
        
        expect(role.containsKey('night_priority'), true,
            reason: 'Role at index $i (${role['id']}) must have "night_priority" field');
        expect(role['night_priority'], isA<int>(),
            reason: 'Role night_priority at index $i (${role['id']}) must be an integer');
      }
    });
    
    test('role ids are unique', () {
      final file = File('assets/data/roles.json');
      final contents = file.readAsStringSync();
      final data = json.decode(contents) as Map<String, dynamic>;
      final roles = data['roles'] as List;
      
      final ids = <String>{};
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
          reason: 'Role ids must be unique. Duplicates found: $duplicates');
    });
    
    test('nightPriority values are in valid range', () {
      final file = File('assets/data/roles.json');
      final contents = file.readAsStringSync();
      final data = json.decode(contents) as Map<String, dynamic>;
      final roles = data['roles'] as List;
      
      for (var role in roles) {
        final roleMap = role as Map<String, dynamic>;
        final priority = roleMap['night_priority'] as int;
        final id = roleMap['id'] as String;
        
        expect(priority >= 0, true,
            reason: 'Role $id night_priority must be >= 0, got $priority');
        expect(priority <= 10, true,
            reason: 'Role $id night_priority must be <= 10, got $priority');
      }
    });
  });
}
