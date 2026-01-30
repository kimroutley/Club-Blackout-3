import 'dart:convert';
import 'dart:io';

import 'package:club_blackout/data/role_repository.dart';
import 'package:club_blackout/models/role.dart';

/// Loads roles from disk for tests.
///
/// This avoids depending on Flutter asset bundling in the test runner.
class FileRoleRepository extends RoleRepository {
  final String rolesJsonPath;

  List<Role> _loadedRoles = [];

  FileRoleRepository({this.rolesJsonPath = 'assets/data/roles.json'});

  @override
  Future<void> loadRoles() async {
    final file = File(rolesJsonPath);
    if (!file.existsSync()) {
      throw StateError('roles.json not found at: $rolesJsonPath');
    }

    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> || decoded['roles'] is! List) {
      throw StateError(
        'Invalid roles.json structure. Expected { roles: [...] }',
      );
    }

    final rawRoles = decoded['roles'] as List;
    _loadedRoles = rawRoles
        .whereType<Map>()
        .map((m) => Role.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    _loadedRoles.sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  List<Role> get roles => _loadedRoles;

  @override
  Role? getRoleById(String id) {
    try {
      return _loadedRoles.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
