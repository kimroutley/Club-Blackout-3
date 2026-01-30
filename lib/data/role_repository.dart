import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/role.dart';
import '../utils/game_logger.dart';

class RoleRepository {
  List<Role> _roles = [];

  Future<void> loadRoles() async {
    final started = DateTime.now();
    const candidates = <String>[
      'assets/data/roles.json',
      // Common typo seen in logs/user reports; keep as fallback for robustness.
      'asset/data/roles.json',
    ];

    try {
      String? response;
      Object? lastError;

      for (final path in candidates) {
        try {
          GameLogger.info('Loading roles from $path',
              context: 'RoleRepository');
          response = await rootBundle.loadString(path);
          if (response.isNotEmpty) {
            break;
          }
        } catch (e) {
          lastError = e;
        }
      }

      if (response == null || response.isEmpty) {
        throw StateError(
          'Unable to load roles.json from any known asset path. '
          'Tried: ${candidates.join(', ')}. '
          'Last error: $lastError',
        );
      }

      final data = json.decode(response);
      _roles = (data['roles'] as List).map((i) => Role.fromJson(i)).toList();
      _roles.sort((a, b) => a.name.compareTo(b.name));
      GameLogger.performance(
          'Loaded ${_roles.length} roles', DateTime.now().difference(started));
    } catch (e, stackTrace) {
      GameLogger.error(
        'Failed to load roles',
        context: 'RoleRepository',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  List<Role> get roles => _roles;

  Role? getRoleById(String id) {
    try {
      return _roles.firstWhere((role) => role.id == id);
    } catch (e) {
      return null;
    }
  }
}
