import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/game_engine.dart';
import '../../logic/player_status_resolver.dart';
import '../../models/player.dart';
import '../styles.dart';

class HostPlayerStatusCard extends StatefulWidget {
  final Player player;
  final GameEngine gameEngine;
  final bool showControls; // To optionally hide the switch if used elsewhere
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const HostPlayerStatusCard({
    super.key,
    required this.player,
    required this.gameEngine,
    this.showControls = true,
    this.isSelected = false,
    this.onTap,
    this.trailing,
  });

  @override
  State<HostPlayerStatusCard> createState() => _HostPlayerStatusCardState();
}

class _HostPlayerStatusCardState extends State<HostPlayerStatusCard> {
  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    // Material 3 Card Style applied
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: widget.isSelected ? 4 : 2,
      shadowColor: player.role.color.withOpacity(widget.isSelected ? 0.6 : 0.3),
      color: player.isEnabled
          ? (player.isAlive
                ? (widget.isSelected
                      ? player.role.color.withOpacity(0.15)
                      : const Color(0xFF1E1E1E))
                : Colors.black.withOpacity(0.6))
          : Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: player.isEnabled
              ? (widget.isSelected
                    ? player.role.color
                    : player.role.color.withOpacity(0.4))
              : Colors.white10,
          width: widget.isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: player.role.color.withOpacity(
                          player.isEnabled ? 1 : 0.3,
                        ),
                        width: 2,
                      ),
                      boxShadow: player.isEnabled || widget.isSelected
                          ? ClubBlackoutTheme.circleGlow(
                              player.role.color,
                              intensity: widget.isSelected ? 0.8 : 0.5,
                            )
                          : [],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        player.role.assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.person, color: player.role.color),
                      ),
                    ),
                  ),
                  if (!player.isAlive && player.isEnabled)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: ClubBlackoutTheme.neonRed,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: TextStyle(
                        color: player.isEnabled ? Colors.white : Colors.white38,
                        fontSize: 15, // Reduced from 16
                        fontWeight: FontWeight.w900,
                        decoration: (!player.isAlive && player.isEnabled)
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: ClubBlackoutTheme.neonRed,
                        decorationThickness: 2,
                      ),
                      maxLines: 1, // Ensure single line
                      overflow: TextOverflow.ellipsis, // Truncate if too long
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          // Allow shrinking
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, // Reduced from 8
                              vertical: 3, // Reduced from 4
                            ),
                            decoration: BoxDecoration(
                              color: player.role.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              player.role.name.toUpperCase(),
                              style: TextStyle(
                                color: player.role.color,
                                fontSize: 9, // Reduced from 10
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (player.lives > 1) ...[
                          const SizedBox(width: 4), // Reduced from 8
                          Icon(
                            Icons.favorite,
                            color: ClubBlackoutTheme.neonRed,
                            size: 10,
                          ),
                          const SizedBox(width: 2), // Reduced from 4
                          Text(
                            'x${player.lives}',
                            style: TextStyle(
                              color: ClubBlackoutTheme.neonOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_hasStatusEffects(player)) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _buildPlayerStatusChips(player),
                      ),
                    ],
                  ],
                ),
              ),

              // Controls
              if (widget.showControls)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 32,
                        child: Transform.scale(
                          scale: 0.8, // Scale down the switch
                          child: Switch(
                            value: player.isEnabled,
                            activeColor: ClubBlackoutTheme.neonGreen,
                            inactiveThumbColor: Colors.white24,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                player.isEnabled = value;
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        player.isEnabled ? 'ACTIVE' : 'DISABLED',
                        style: TextStyle(
                          fontSize: 7, // Reduced from 8
                          color: player.isEnabled
                              ? ClubBlackoutTheme.neonGreen
                              : Colors.white24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Trailing Widget (e.g. Vote Count)
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _hasStatusEffects(Player player) {
    // Check using resolver logic
    return PlayerStatusResolver.resolveStatus(
      player,
      widget.gameEngine,
    ).isNotEmpty;
  }

  List<Widget> _buildPlayerStatusChips(Player player) {
    // Use centralized resolver for consistent chips across the app
    final statuses = PlayerStatusResolver.resolveStatus(
      player,
      widget.gameEngine,
    );

    return statuses.map((status) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: status.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: status.color.withOpacity(0.5), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status.icon != null) ...[
              Icon(status.icon, size: 8, color: status.color),
              const SizedBox(width: 4),
            ],
            Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 9, // Small font for dense info
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
