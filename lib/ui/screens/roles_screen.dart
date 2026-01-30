import 'package:flutter/material.dart';

import '../../data/role_repository.dart';
import '../../logic/game_engine.dart';
import '../../models/role.dart';
import '../widgets/role_reveal_widget.dart';
import '../widgets/role_tile_widget.dart';

class RolesScreen extends StatefulWidget {
  final bool accountForMainShellAppBar;
  final GameEngine? gameEngine;

  const RolesScreen({
    super.key,
    this.accountForMainShellAppBar = true,
    this.gameEngine,
  });

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final RoleRepository _roleRepo = RoleRepository();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _roleRepo.loadRoles();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _roleRepo.roles.length,
        itemBuilder: (context, index) {
          final role = _roleRepo.roles[index];
          return RoleTileWidget(
            role: role,
            variant: RoleTileVariant.card,
            onTap: () => _showRoleDialog(role),
          );
        },
      ),
    );
  }

  void _showRoleDialog(Role role) {
    showRoleReveal(context, role, role.name, subtitle: role.alliance);
  }
}
