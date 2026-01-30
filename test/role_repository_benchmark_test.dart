import 'dart:convert';
import 'package:club_blackout/data/role_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAssetBundle extends AssetBundle {
  final String content;
  MockAssetBundle(this.content);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('roles.json')) {
      return content;
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Benchmark RoleRepository getRoleById performance', () async {
    // 1. Generate 10,000 roles
    const count = 10000;
    // Note: The role names should be unique or sortable. RoleRepository sorts by name.
    // To ensure worst case for "firstWhere", we want the target to be at the end of the list *after* sorting.
    // If we name them "Role 0" ... "Role 9999", "Role 9999" comes after "Role 1000".
    // But sorting logic is: _roles.sort((a, b) => a.name.compareTo(b.name));

    // "Role 9999" vs "Role 0".
    // Alphabetical: Role 0, Role 1, Role 10, ... Role 2, ...

    // To be safe, we can use a target id but verify its position.

    final rolesList = List.generate(
        count,
        (i) => {
              'id': 'role_$i',
              'name':
                  'Role ${i.toString().padLeft(5, '0')}', // Role 00000, Role 00001... ensures sorted order matches index
              'alliance': 'town',
              'type': 'human',
              'description': 'Description $i',
              'night_priority': 0,
              'asset_path': 'assets/images/role.png',
              'color_hex': '#FFFFFF',
            });

    const targetId = 'role_${count - 1}'; // The last one

    final jsonContent = json.encode({'roles': rolesList});
    final mockBundle = MockAssetBundle(jsonContent);

    final repository = RoleRepository(bundle: mockBundle);
    await repository.loadRoles();

    expect(repository.roles.length, count);
    expect(repository.roles.last.id, targetId,
        reason: 'Target should be at the end for worst-case scenario');

    // 2. Measure Lookup
    final stopwatch = Stopwatch()..start();

    // Perform multiple lookups
    const iterations = 1000;
    for (var i = 0; i < iterations; i++) {
      final role = repository.getRoleById(targetId);
      if (role == null) fail('Role not found');
    }

    stopwatch.stop();
    // ignore: avoid_print
    print(
        'Benchmark Result: Looked up last item $iterations times in ${stopwatch.elapsedMilliseconds}ms');
    // ignore: avoid_print
    print(
        'Average per lookup: ${stopwatch.elapsedMicroseconds / iterations}us');
  });
}
