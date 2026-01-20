import 'package:flutter/material.dart';
import '../../models/role.dart';

class RoleAvatarWidget extends StatelessWidget {
  final Role role;
  final double size;
  final bool showBorder;
  final bool showGlow;
  final double borderWidth;

  const RoleAvatarWidget({
    super.key,
    required this.role,
    this.size = 48,
    this.showBorder = true,
    this.showGlow = true,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: role.color, width: borderWidth)
            : null,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: role.color.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [],
        color: const Color(0xFF1E1E1E),
      ),
      child: ClipOval(
        child: role.assetPath.isNotEmpty
            ? Image.asset(
                role.assetPath,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) =>
                    _buildFallbackIcon(),
              )
            : _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Icon(Icons.person, color: role.color, size: size * 0.5);
  }
}
