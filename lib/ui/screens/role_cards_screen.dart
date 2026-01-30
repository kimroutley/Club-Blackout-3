import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../styles.dart';
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

    if (embedded) return list;
    return Scaffold(
      backgroundColor: isNight ? null : Colors.transparent,
      body: SafeArea(child: list),
    );
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoleCardWidget(role: role, compact: false),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
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
                    color: ClubBlackoutTheme.neonOrange.withValues(alpha: 0.2)),
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
    final color = ClubBlackoutTheme.neonOrange;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleName,
                  style: TextStyle(
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
