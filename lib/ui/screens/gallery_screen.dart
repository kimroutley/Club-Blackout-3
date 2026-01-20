import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/role_repository.dart';
import '../../models/role.dart';
import '../styles.dart';
import '../widgets/role_tile_widget.dart';
import '../widgets/role_reveal_widget.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
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
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Opacity(
            opacity: 0.6,
            child: Image.asset(
              "Backgrounds/Club Blackout App Background.png",
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) => Container(color: Colors.black),
            ),
          ),
        ),

        // Blurred background effect
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Main Content
        SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Extra spacing for the overhead AppBar in MainScreen
              const SliverToBoxAdapter(child: SizedBox(height: 80)),

              // Gallery Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Center(
                    child: Text(
                      'CHARACTER GALLERY',
                      style: TextStyle(
                        fontFamily: 'Hyperwave',
                        fontSize: 32,
                        color: ClubBlackoutTheme.neonBlue,
                        shadows: ClubBlackoutTheme.textGlow(
                          ClubBlackoutTheme.neonBlue,
                        ),
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
      ],
    );
  }

  void _showRoleDialog(Role role) {
    showRoleReveal(context, role, role.name, subtitle: role.alliance);
  }
}
