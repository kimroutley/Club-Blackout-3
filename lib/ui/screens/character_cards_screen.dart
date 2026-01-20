import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../styles.dart';
import '../widgets/role_tile_widget.dart';
import '../widgets/role_card_widget.dart';

class CharacterCardsScreen extends StatelessWidget {
  final List<Role> roles;

  const CharacterCardsScreen({super.key, required this.roles});

  @override
  Widget build(BuildContext context) {
    // Sort roles by alliance
    final dealerTeam = roles
        .where((r) => r.alliance.contains('Dealer'))
        .toList();
    final partyAnimals = roles
        .where((r) => r.alliance.contains('Party Animal'))
        .toList();
    final neutrals = roles
        .where(
          (r) =>
              !r.alliance.contains('Dealer') &&
              !r.alliance.contains('Party Animal'),
        )
        .toList();

    return SafeArea(
      child: ClubBlackoutTheme.centeredConstrained(
        maxWidth: 920,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAllianceGraph(),
            const SizedBox(height: 32),
            _buildRoleGrid(
              'THE DEALERS',
              dealerTeam,
              ClubBlackoutTheme.neonRed,
              context,
            ),
            const SizedBox(height: 32),
            _buildRoleGrid(
              'THE PARTY ANIMALS',
              partyAnimals,
              ClubBlackoutTheme.neonBlue,
              context,
            ),
            const SizedBox(height: 32),
            _buildRoleGrid(
              'WILD CARDS & NEUTRALS',
              neutrals,
              ClubBlackoutTheme.neonPurple,
              context,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
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
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            title,
            style: ClubBlackoutTheme.headingStyle.copyWith(
              color: color,
              fontSize: 18,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 16,
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
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: RoleCardWidget(role: role, compact: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: role.color,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildAllianceGraph() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClubBlackoutTheme.neonBlue.withOpacity(0.15),
            ClubBlackoutTheme.neonRed.withOpacity(0.15),
            ClubBlackoutTheme.neonPurple.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ClubBlackoutTheme.neonPink.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALLIANCE STRUCTURE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ClubBlackoutTheme.neonPink,
              shadows: ClubBlackoutTheme.textGlow(ClubBlackoutTheme.neonPink),
            ),
          ),
          const SizedBox(height: 16),
          _buildAllianceRow(
            Icons.dangerous,
            'DEALERS',
            'Eliminate all Party Animals',
            ClubBlackoutTheme.neonRed,
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildAllianceRow(
            Icons.celebration,
            'PARTY ANIMALS',
            'Vote out all Dealers',
            ClubBlackoutTheme.neonBlue,
          ),
          const Divider(color: Colors.white24, height: 20),
          _buildAllianceRow(
            Icons.auto_awesome,
            'WILD CARDS',
            'Unique win conditions',
            ClubBlackoutTheme.neonPurple,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClubBlackoutTheme.neonOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ClubBlackoutTheme.neonOrange.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      color: ClubBlackoutTheme.neonOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CONVERSION POSSIBILITIES',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: ClubBlackoutTheme.neonOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildConversionRow(
                  'Second Wind',
                  'Party Animal → Dealer',
                  'If killed by Dealers, can join them',
                ),
                _buildConversionRow(
                  'Clinger',
                  'Any → Attack Dog',
                  'If obsession calls them "controller"',
                ),
                _buildConversionRow(
                  'Creep',
                  'Neutral → Mimic',
                  'Becomes their chosen target\'s role',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllianceRow(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversionRow(
    String roleName,
    String conversion,
    String condition,
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
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: ClubBlackoutTheme.circleGlow(color, intensity: 0.8),
              color: Colors.black,
            ),
            child: ClipOval(
              child: role != null && role.assetPath.isNotEmpty
                  ? Image.asset(
                      role.assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, color: color, size: 24),
                    )
                  : Icon(Icons.person, color: color, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (role?.name ?? roleName).toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.8,
                        shadows: ClubBlackoutTheme.textGlow(color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.transform, color: Colors.white54, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      conversion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  condition,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
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

  /* Alliance Section moved to main widget body */
}
