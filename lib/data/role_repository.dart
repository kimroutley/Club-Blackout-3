import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/role.dart';

class RoleRepository {
  List<Role> _roles = [];

  Future<void> loadRoles() async {
    final String response = await rootBundle.loadString(
      'assets/data/roles.json',
    );
    final data = await json.decode(response);
    _roles = (data['roles'] as List).map((i) => Role.fromJson(i)).toList();
    _roles.sort((a, b) => a.name.compareTo(b.name));
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
