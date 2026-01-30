import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../styles.dart';
import '../widgets/neon_page_scaffold.dart';
import '../widgets/player_icon.dart';
import '../widgets/role_card_widget.dart';
import '../widgets/role_tile_widget.dart';

class RoleCardsScreen extends StatelessWidget {
  final List<Role> roles;
  final bool embedded;
  final bool isNight;

  const RoleCardsScreen({
    super.key,
    required this.roles,
    this.embedded = false,
    this.isNight = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sort roles by alliance
    final dealerTeam =
        roles.where((r) => r.alliance.contains('Dealer')).toList();
    final partyAnimals =
        roles.where((r) => r.alliance.contains('Party Animal')).toList();
    final neutrals = roles
        .where(
          (r) =>
              !r.alliance.contains('Dealer') &&
              !r.alliance.contains('Party Animal'),
        )
        .toList();

    final list = ListView(
      padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      children: [
        _buildAllianceGraph(context),
        const SizedBox(height: 24),
        _buildRoleGrid(
          'Dealers',
          dealerTeam,
          ClubBlackoutTheme.neonRed,
          context,
        ),
        const SizedBox(height: 24),
        _buildRoleGrid(
          'Party Animals',
          partyAnimals,
          ClubBlackoutTheme.neonBlue,
          context,
        ),
        const SizedBox(height: 24),
        _buildRoleGrid(
          'Wild cards & neutrals',
          neutrals,
          ClubBlackoutTheme.neonPurple,
          context,
        ),
        const SizedBox(height: 32),
      ],
    );

    final content = (isNight && !embedded)
        ? SafeArea(child: list)
        : ClubBlackoutTheme.centeredConstrained(
            maxWidth: 920,
            child: list,
          );

    if (embedded) return content;
    return SafeArea(child: content);
  }

  Widget _buildRoleGrid(
    String title,
    List<Role> allianceRoles,
    Color color,
    BuildContext context,
  ) {
    if (allianceRoles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isNight
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                ),
              )
            : NeonGlassCard(
                glowColor: color,
                padding: ClubBlackoutTheme.rowPadding,
                showBorder: false,
                child: Text(
                  title,
                  style: ClubBlackoutTheme.glowTextStyle(
                    base: ClubBlackoutTheme.headingStyle,
                    color: color,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allianceRoles
              .map(
                (role) => RoleTileWidget(
                  role: role,
                  variant: RoleTileVariant.compact,
                  onTap: () => _showRoleDetail(context, role),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _showRoleDetail(BuildContext context, Role role) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: ClubBlackoutTheme.dialogInsetPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The Card itself
              RoleCardWidget(role: role, compact: false),

              const SizedBox(height: 24),

              // Close Button
              Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllianceGraph(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isNight) {
      return Card(
        elevation: 0,
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ALLIANCE STRUCTURE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
              ),
              const SizedBox(height: 16),
              _buildAllianceRow(
                context,
                Icons.dangerous_rounded,
                'DEALERS',
                'Eliminate all Party Animals',
                ClubBlackoutTheme.neonRed,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                    color: cs.onSurface.withValues(alpha: 0.1), height: 1),
              ),
              _buildAllianceRow(
                context,
                Icons.celebration_rounded,
                'PARTY ANIMALS',
                'Vote out all Dealers',
                ClubBlackoutTheme.neonBlue,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                    color: cs.onSurface.withValues(alpha: 0.1), height: 1),
              ),
              _buildAllianceRow(
                context,
                Icons.auto_awesome_rounded,
                'WILD CARDS',
                'Unique/Secret win conditions',
                ClubBlackoutTheme.neonPurple,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ClubBlackoutTheme.neonOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          ClubBlackoutTheme.neonOrange.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: ClubBlackoutTheme.neonOrange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CONVERSION POSSIBILITIES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ClubBlackoutTheme.neonOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildConversionRow(
                      context,
                      'Second Wind',
                      'PARTY ANIMAL → DEALER',
                      'If killed by Dealers, can join them',
                      cs,
                    ),
                    _buildConversionRow(
                      context,
                      'Clinger',
                      'ANY → ATTACK DOG',
                      'If obsession calls them "controller"',
                      cs,
                    ),
                    _buildConversionRow(
                      context,
                      'Creep',
                      'NEUTRAL → MIMIC',
                      'Becomes their chosen target\'s role',
                      cs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NeonGlassCard(
      glowColor: ClubBlackoutTheme.neonPink,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ALLIANCE STRUCTURE',
            style: ClubBlackoutTheme.glowTextStyle(
              base: ClubBlackoutTheme.headingStyle,
              color: ClubBlackoutTheme.neonPink,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          _buildAllianceRow(
            context,
            Icons.dangerous_rounded,
            'DEALERS',
            'Eliminate all Party Animals',
            ClubBlackoutTheme.neonRed,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Divider(color: cs.onSurface.withValues(alpha: 0.1), height: 1),
          ),
          _buildAllianceRow(
            context,
            Icons.celebration_rounded,
            'PARTY ANIMALS',
            'Vote out all Dealers',
            ClubBlackoutTheme.neonBlue,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child:
                Divider(color: cs.onSurface.withValues(alpha: 0.1), height: 1),
          ),
          _buildAllianceRow(
            context,
            Icons.auto_awesome_rounded,
            'WILD CARDS',
            'Unique/Secret win conditions',
            ClubBlackoutTheme.neonPurple,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: ClubBlackoutTheme.neonFrame(
              color: ClubBlackoutTheme.neonOrange,
              opacity: 0.08,
              borderRadius: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: ClubBlackoutTheme.neonOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CONVERSION POSSIBILITIES',
                      style: ClubBlackoutTheme.headingStyle.copyWith(
                        fontSize: 13,
                        color: ClubBlackoutTheme.neonOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildConversionRow(
                  context,
                  'Second Wind',
                  'PARTY ANIMAL → DEALER',
                  'If killed by Dealers, can join them',
                  Theme.of(context).colorScheme,
                ),
                _buildConversionRow(
                  context,
                  'Clinger',
                  'ANY → ATTACK DOG',
                  'If obsession calls them "controller"',
                  Theme.of(context).colorScheme,
                ),
                _buildConversionRow(
                  context,
                  'Creep',
                  'NEUTRAL → MIMIC',
                  'Becomes their chosen target\'s role',
                  Theme.of(context).colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllianceRow(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversionRow(
    BuildContext context,
    String roleName,
    String conversion,
    String condition,
    ColorScheme cs,
  ) {
    // Find role for icon/color
    Role? role;
    try {
      // Flexible lookup
      role = roles.firstWhere((r) {
        final rName = r.name.toLowerCase();
        final qName = roleName.toLowerCase();
        return rName == qName ||
            rName.contains(qName) ||
            qName.contains(rName.replaceAll('the ', ''));
      });
    } catch (_) {}

    final color = role?.color ?? ClubBlackoutTheme.neonOrange;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.3),
        borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Icon
          PlayerIcon(
            assetPath: role?.assetPath ?? '',
            glowColor: color,
            size: 48,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role?.name ?? roleName,
                  style: ClubBlackoutTheme.glowTextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.transform,
                      color: cs.onSurface.withValues(alpha: 0.54),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      conversion,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  condition,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
