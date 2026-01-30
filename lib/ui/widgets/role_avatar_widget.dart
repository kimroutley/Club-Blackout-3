import 'package:flutter/material.dart';
import '../../models/role.dart';
import 'player_icon.dart';

class RoleAvatarWidget extends StatelessWidget {
  final Role role;
  final double size;
  final bool showGlow;
  final double borderWidth;

  const RoleAvatarWidget({
    super.key,
    required this.role,
    this.size = 40,
    this.showGlow = false,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerIcon(
      assetPath: role.assetPath,
      glowColor: role.color,
      size: size,
      glowIntensity: showGlow ? 1.0 : 0.0,
      isAlive: true,
      isEnabled: true,
    );
  }
}
