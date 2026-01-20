import 'package:flutter/material.dart';
import '../../models/role.dart';
import 'role_avatar_widget.dart';

enum RoleTileVariant {
  /// A card-like tile with a prominent icon/image and name.
  /// Best for grids (e.g., Gallery).
  card,

  /// A minimal vertical stack with a circular avatar and text.
  /// Best for dense lists or smaller grids (e.g., Character Cards, Role Assignment).
  compact,
}

class RoleTileWidget extends StatelessWidget {
  final Role role;
  final VoidCallback? onTap;
  final RoleTileVariant variant;
  final bool showAllianceColor;

  const RoleTileWidget({
    super.key,
    required this.role,
    this.onTap,
    this.variant = RoleTileVariant.card,
    this.showAllianceColor = true,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == RoleTileVariant.compact) {
      return _buildCompact(context);
    }
    return _buildCard(context);
  }

  Widget _buildCompact(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ID Header Strip
              Container(
                height: 18,
                color: role.color,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACCESS',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(
                      Icons.nfc,
                      size: 10,
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // Photo Box
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: role.color.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (role.assetPath.isNotEmpty)
                            Image.asset(
                              role.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.person, color: role.color),
                            )
                          else
                            Icon(Icons.person, color: role.color),

                          // Simple sheen
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.3, 0.5, 0.7],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Name Label
                    Text(
                      role.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
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
                child: Center(
                  child: RoleAvatarWidget(role: role, size: 70, showGlow: true),
                ),
              ),

              const SizedBox(height: 12),

              // Name
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    role.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16, // Slightly reduced to prevent overflow
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                      shadows: [Shadow(color: role.color, blurRadius: 10)],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.visible,
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
