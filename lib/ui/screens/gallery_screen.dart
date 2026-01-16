import 'dart:ui';
import 'package:flutter/material.dart';
import '../../data/role_repository.dart';
import '../../models/role.dart';
import '../styles.dart';
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
        CustomScrollView(
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
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final role = _roleRepo.roles[index];
                    return _RoleTile(
                      role: role,
                      onTap: () => _showRoleDialog(role),
                    );
                  }, childCount: _roleRepo.roles.length),
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ],
    );
  }

  void _showRoleDialog(Role role) {
    showRoleReveal(context, role, role.name, subtitle: role.alliance);
  }
}

class _RoleTile extends StatelessWidget {
  final Role role;
  final VoidCallback onTap;

  const _RoleTile({required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material 3 Filled Card style adapted for Neon Theme
    return Card(
      elevation: 4,
      shadowColor: role.color.withOpacity(0.4),
      color: Color.alphaBlend(
        role.color.withOpacity(0.05),
        const Color(0xFF1E1E1E),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: role.color.withOpacity(0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: role.color.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Circle
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: role.color.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.black,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors
                          .transparent, // Background handled by image or icon
                      child: ClipOval(
                        child: role.assetPath.isNotEmpty
                            ? Image.asset(
                                role.assetPath,
                                fit: BoxFit.cover,
                                width: 64,
                                height: 64,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person,
                                  color: role.color,
                                  size: 32,
                                ),
                              )
                            : Icon(Icons.person, color: role.color, size: 32),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Name (Maximized, no pill)
              Expanded(
                flex: 2,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      role.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                        shadows: [Shadow(color: role.color, blurRadius: 10)],
                      ),
                      maxLines: 4, // Allow multiple lines
                      overflow: TextOverflow
                          .visible, // Should fit due to grid ratio and flex
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
