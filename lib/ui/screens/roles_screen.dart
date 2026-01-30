import 'package:flutter/material.dart';

import '../../data/role_repository.dart';
import '../../logic/game_engine.dart';
import '../../models/role.dart';
import '../styles.dart';
import '../widgets/neon_background.dart';
import '../widgets/role_reveal_widget.dart';
import '../widgets/role_tile_widget.dart';

class RolesScreen extends StatefulWidget {
  /// When this screen is shown under the drawer shell (`MainScreen`), the
  /// shell uses `extendBodyBehindAppBar: true`, so content must be offset.
  ///
  /// Defaults to true since this screen was designed for the drawer shell.
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
    if (widget.gameEngine?.currentPhase == GamePhase.night) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Roles'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
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
                  // Use card variant for cleaner look, or maybe a simple list tile for night?
                  // Sticking to Grid for consistency, but using RoleTileWidget.
                  // Only issue: RoleTileWidget might have neon styles baked in.
                  // Let's check RoleTileWidget implementation or wrap it.
                  return RoleTileWidget(
                    role: role,
                    variant: RoleTileVariant.card,
                    onTap: () => _showRoleDialog(role),
                  );
                },
              ),
      );
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final topPadding = widget.accountForMainShellAppBar
        ? topInset + kToolbarHeight + 12
        : topInset;

    return NeonBackground(
      backgroundAsset: 'Backgrounds/Club Blackout V2 Game Background.png',
      accentColor: ClubBlackoutTheme.neonBlue,
      blurSigma: 5,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Roles Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Center(
                    child: Text(
                      'ROLES',
                      style: ClubBlackoutTheme.neonGlowTextStyle(
                        color: ClubBlackoutTheme.neonBlue,
                        fontSize: 32,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),

              // Character Grid
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ClubBlackoutTheme.neonBlue,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final role = _roleRepo.roles[index];
                      return RoleTileWidget(
                        role: role,
                        variant: RoleTileVariant.card,
                        onTap: () => _showRoleDialog(role),
                      );
                    }, childCount: _roleRepo.roles.length),
                  ),
                ),

              // Bottom spacing
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleDialog(Role role) {
    showRoleReveal(context, role, role.name, subtitle: role.alliance);
  }
}
