import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../../utils/game_exceptions.dart';
import '../../utils/role_validator.dart';
import '../styles.dart';
import 'club_alert_dialog.dart';
import 'player_icon.dart';
import 'role_avatar_widget.dart';

enum GameMode { bloodbath, politicalNightmare, freeForAll, custom }

class RoleAssignmentDialog extends StatefulWidget {
  final GameEngine gameEngine;
  final List<Player> players;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final GameMode initialMode;

  const RoleAssignmentDialog({
    super.key,
    required this.gameEngine,
    required this.players,
    required this.onConfirm,
    required this.onCancel,
    this.initialMode = GameMode.custom,
  });

  @override
  State<RoleAssignmentDialog> createState() => _RoleAssignmentDialogState();
}

class _RoleAssignmentDialogState extends State<RoleAssignmentDialog> {
  late Map<String, Role> _playerRoles;
  GameMode _selectedMode = GameMode.custom;
  bool _rolesAssigned = false;

  static bool _isDealerRole(Role role) =>
      role.id.trim().toLowerCase() == 'dealer';

  static bool _isPartyAligned(Role role) {
    final alliance = role.alliance.trim().toLowerCase();
    final startAlliance = role.startAlliance?.trim().toLowerCase();
    return alliance == 'the party animals' ||
        role.id.trim().toLowerCase() == 'party_animal' ||
        startAlliance == 'party_animal';
  }

  static bool _isType(Role role, List<String> keywords) {
    final t = role.type.trim().toLowerCase();
    return keywords.any((k) => t.contains(k));
  }

  Role? _byId(String id) {
    return widget.gameEngine.roleRepository.getRoleById(id);
  }

  List<String> _roleAssignmentIssues() {
    final enabledPlayers = widget.players.where((p) => p.isEnabled).toList();
    if (_playerRoles.length != enabledPlayers.length) {
      return const ['Roles not assigned to all enabled players yet.'];
    }

    final roles = _playerRoles.values.where((r) => r.id != 'host').toList();
    final dealerCount = roles.where(_isDealerRole).length;
    final bouncerCount = roles.where((r) => r.id == 'bouncer').length;
    final hasMedicOrBouncer = roles.any(
      (r) => r.id == 'medic' || r.id == 'bouncer',
    );
    final hasPartyAnimal = roles.any((r) => r.id == 'party_animal');
    final hasWallflower = roles.any((r) => r.id == 'wallflower');

    final partyAlignedCount = roles.where(_isPartyAligned).length;
    final issues = <String>[];

    if (dealerCount < 1) {
      issues.add('Missing required role: Dealer');
    }
    if (!hasMedicOrBouncer) {
      issues.add('Missing required role: Medic and/or Bouncer');
    }
    if (!hasPartyAnimal) {
      issues.add('Missing required role: Party Animal');
    }
    if (!hasWallflower) {
      issues.add('Missing required role: Wallflower');
    }
    if (partyAlignedCount < 2) {
      issues.add('Need at least 2 Party Animal-aligned roles');
    }
    if (bouncerCount > 1) {
      issues.add('Only one Bouncer is allowed.');
    }

    if (dealerCount > (roles.length - dealerCount)) {
      issues.add('Invalid: Dealers already have majority');
    }

    final seen = <String>{};
    for (final role in roles) {
      if (RoleValidator.multipleAllowedRoles.contains(role.id)) continue;
      if (!seen.add(role.id)) {
        issues.add('Invalid: Duplicate role ${role.name}');
        break;
      }
    }

    return issues;
  }

  List<Role> _eligibleNonHostRoles(List<Role> allRoles) {
    return allRoles.where((r) => r.id != 'host' && r.id != 'temp').toList();
  }

  List<Role> _availableRolesForPlayerInDraft(String playerId) {
    final allRoles = _eligibleNonHostRoles(
      widget.gameEngine.roleRepository.roles,
    );

    final usedUniqueIds = <String>{};
    for (final entry in _playerRoles.entries) {
      if (entry.key == playerId) continue;
      final rid = entry.value.id;
      if (rid == 'host' || rid == 'temp') continue;
      if (RoleValidator.multipleAllowedRoles.contains(rid)) continue;
      usedUniqueIds.add(rid);
    }

    final available = allRoles.where((r) {
      if (r.id == 'host' || r.id == 'temp') return false;
      if (RoleValidator.multipleAllowedRoles.contains(r.id)) return true;
      return !usedUniqueIds.contains(r.id);
    }).toList();
    available.sort((a, b) => a.name.compareTo(b.name));
    return available;
  }

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    final hasTempRoles = widget.players.any((p) => p.role.id == 'temp');

    _playerRoles = {
      for (final p in widget.players.where((p) => p.isEnabled)) p.id: p.role,
    };

    _rolesAssigned = !hasTempRoles &&
        _playerRoles.length == widget.players.where((p) => p.isEnabled).length;
  }

  void _assignRolesByMode(GameMode mode) {
    final allRoles = _eligibleNonHostRoles(
      widget.gameEngine.roleRepository.roles,
    );
    final playersToAssign = widget.players
        .where((p) => p.isEnabled && p.role.id != 'host')
        .toList();
    final playerCount = playersToAssign.length;

    final random = Random();

    final dealerRole = _byId('dealer');
    final partyAnimalRole = _byId('party_animal');
    final wallflowerRole = _byId('wallflower');
    final medicRole = _byId('medic');
    final bouncerRole = _byId('bouncer');

    if (dealerRole == null) throw StateError('Missing required role: dealer');
    if (partyAnimalRole == null)
      throw StateError('Missing required role: party_animal');
    if (wallflowerRole == null)
      throw StateError('Missing required role: wallflower');
    if (medicRole == null && bouncerRole == null)
      throw StateError('Missing required role: medic and/or bouncer');

    final recommendedDealers = RoleValidator.recommendedDealerCount(
      playerCount,
    ).clamp(1, playerCount);
    final selected = <Role>[];
    final usedUniqueIds = <String>{};

    for (var i = 0; i < recommendedDealers; i++) {
      selected.add(dealerRole);
    }

    Role firstSupport;
    if (medicRole != null && bouncerRole != null) {
      firstSupport = random.nextBool() ? medicRole : bouncerRole;
    } else {
      firstSupport = (medicRole ?? bouncerRole)!;
    }
    selected.add(firstSupport);
    usedUniqueIds.add(firstSupport.id);

    if (playerCount > 6) {
      final secondWindRole = _byId('second_wind');
      if (secondWindRole != null && usedUniqueIds.add(secondWindRole.id)) {
        selected.add(secondWindRole);
      }
    }

    if (usedUniqueIds.add(partyAnimalRole.id)) {
      selected.add(partyAnimalRole);
    }
    if (usedUniqueIds.add(wallflowerRole.id)) {
      selected.add(wallflowerRole);
    }

    final int partyAlignedCount = selected.where(_isPartyAligned).length;
    if (partyAlignedCount < 2) {
      final otherSupport =
          (firstSupport.id == 'medic') ? bouncerRole : medicRole;
      if (otherSupport != null && usedUniqueIds.add(otherSupport.id)) {
        selected.add(otherSupport);
      }
    }

    final pool = allRoles
        .where((r) => !_isDealerRole(r))
        .where((r) => !usedUniqueIds.contains(r.id))
        .toList();

    List<Role> getCandidates(List<String> keywords) {
      final copy = pool
          .where((r) => _isType(r, keywords) && !usedUniqueIds.contains(r.id))
          .toList();
      copy.shuffle(random);
      return copy;
    }

    final offensive = getCandidates(['aggressive', 'offensive']);
    final defensive = getCandidates([
      'defensive',
      'protective',
      'investigative',
    ]);
    final reactive = getCandidates(['reactive', 'chaos', 'disruptive', 'wild']);
    final passive = getCandidates(['passive']);

    void takeFrom(List<Role> source, int count) {
      for (var i = 0; i < count && source.isNotEmpty; i++) {
        final role = source.removeAt(0);
        if (usedUniqueIds.contains(role.id)) continue;

        if (usedUniqueIds.add(role.id)) {
          selected.add(role);
        }
      }
    }

    final remainingSlots = playerCount - selected.length;
    if (remainingSlots > 0) {
      switch (mode) {
        case GameMode.bloodbath:
          takeFrom(offensive, (remainingSlots * 0.6).round());
          takeFrom(defensive, (remainingSlots * 0.25).round());
          takeFrom(
            reactive,
            remainingSlots -
                ((remainingSlots * 0.6).round()) -
                ((remainingSlots * 0.25).round()),
          );
          break;
        case GameMode.politicalNightmare:
          takeFrom(defensive, (remainingSlots * 0.6).round());
          takeFrom(offensive, (remainingSlots * 0.2).round());
          takeFrom(
            reactive,
            remainingSlots -
                ((remainingSlots * 0.6).round()) -
                ((remainingSlots * 0.2).round()),
          );
          break;
        case GameMode.freeForAll:
          takeFrom(reactive, (remainingSlots * 0.7).round());
          final regular = <Role>[...offensive, ...defensive, ...passive];
          regular.shuffle(random);
          takeFrom(regular, remainingSlots - ((remainingSlots * 0.7).round()));
          break;
        case GameMode.custom:
          final mixed = <Role>[
            ...defensive,
            ...reactive,
            ...offensive,
            ...passive,
          ];
          mixed.shuffle(random);
          takeFrom(mixed, remainingSlots);
          break;
      }
    }

    final leftovers = allRoles
        .where((r) => !_isDealerRole(r) && !usedUniqueIds.contains(r.id))
        .toList();
    leftovers.shuffle(random);

    for (final role in leftovers) {
      if (selected.length >= playerCount) break;
      if (usedUniqueIds.add(role.id)) {
        selected.add(role);
      }
    }

    final hasAllyCat = selected.any((r) => r.id == 'ally_cat');
    final hasMinor = selected.any((r) => r.id == 'minor');
    final hasBouncer = selected.any((r) => r.id == 'bouncer');

    if ((hasAllyCat || hasMinor) && !hasBouncer && bouncerRole != null) {
      if (selected.length < playerCount) {
        selected.add(bouncerRole);
        usedUniqueIds.add('bouncer');
      } else {
        final candidateIndex = selected.lastIndexWhere(
          (r) =>
              r.id != 'dealer' &&
              r.id != 'ally_cat' &&
              r.id != 'minor' &&
              r.id != 'party_animal' &&
              r.id != 'wallflower' &&
              r.id != 'medic' &&
              r.id != 'second_wind',
        );

        if (candidateIndex != -1) {
          final removed = selected[candidateIndex];
          usedUniqueIds.remove(removed.id);
          selected[candidateIndex] = bouncerRole;
          usedUniqueIds.add('bouncer');
        } else {
          final fallbackIndex = selected.lastIndexWhere(
            (r) =>
                r.id != 'dealer' &&
                r.id != 'ally_cat' &&
                r.id != 'minor' &&
                r.id != 'party_animal' &&
                r.id != 'wallflower',
          );
          if (fallbackIndex != -1) {
            final removed = selected[fallbackIndex];
            usedUniqueIds.remove(removed.id);
            selected[fallbackIndex] = bouncerRole;
            usedUniqueIds.add('bouncer');
          }
        }
      }
    }

    if (selected.length < playerCount) {
      throw StateError(
        'Not enough unique roles to fill $playerCount players. Add more roles or reduce players.',
      );
    }

    final List<Role> selectedRoles = selected;

    selectedRoles.shuffle(random);
    _playerRoles.clear();
    for (var i = 0; i < playersToAssign.length; i++) {
      _playerRoles[playersToAssign[i].id] = selectedRoles[i];
    }
    for (final p in widget.players.where(
      (p) => p.isEnabled && p.role.id == 'host',
    )) {
      _playerRoles[p.id] = p.role;
    }

    setState(() {
      _rolesAssigned = true;
    });
  }

  void _showEditRoleDialog(Player player) {
    final availableRoles = _availableRolesForPlayerInDraft(player.id);
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return ClubAlertDialog(
          title: Text(
            'Assign Role to ${player.name}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            height: 400,
            width: double.maxFinite,
            child: ListView.separated(
              itemCount: availableRoles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final role = availableRoles[index];
                final isSelected = _playerRoles[player.id]?.id == role.id;

                return ListTile(
                  onTap: () {
                    setState(() {
                      _playerRoles[player.id] = role;
                    });
                    Navigator.pop(context);
                    HapticFeedback.selectionClick();
                  },
                  tileColor: isSelected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: RoleAvatarWidget(role: role, size: 40),
                  title: Text(
                    role.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(role.type),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: cs.primary)
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_eligibleNonHostRoles(widget.gameEngine.roleRepository.roles).isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs = Theme.of(context).colorScheme;
    final issues = _rolesAssigned ? _roleAssignmentIssues() : const <String>[];
    final isValid = _rolesAssigned ? issues.isEmpty : false;

    return ClubAlertDialog(
      title: Text(
        _rolesAssigned ? 'Review Roles' : 'Select Game Mode',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: _rolesAssigned
            ? _buildReviewContent(isValid, issues)
            : _buildModeSelectionContent(),
      ),
      actions: [
        if (!_rolesAssigned)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          )
        else
          TextButton(
            onPressed: () => setState(() => _rolesAssigned = false),
            child: const Text('Back'),
          ),
        if (!_rolesAssigned) ...[
          TextButton(
            onPressed: widget.onConfirm,
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () {
              _assignRolesByMode(_selectedMode);
              HapticFeedback.mediumImpact();
            },
            child: const Text('Generate'),
          ),
        ] else ...[
          IconButton(
            onPressed: () {
              _assignRolesByMode(_selectedMode);
              HapticFeedback.lightImpact();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Reroll',
          ),
          FilledButton(
            onPressed: isValid
                ? () {
                    try {
                      for (var player in widget.players) {
                        final role = _playerRoles[player.id];
                        if (role != null) {
                          widget.gameEngine.updatePlayerRole(player.id, role);
                        }
                      }
                      HapticFeedback.heavyImpact();
                      widget.onConfirm();
                    } on GameException catch (e) {
                      widget.gameEngine.showToast(e.message);
                    } catch (e) {
                      widget.gameEngine.showToast(e.toString());
                    }
                  }
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ],
    );
  }

  Widget _buildModeSelectionContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose how roles should be distributed.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildGameModeButton(
            'Bloodbath',
            'High aggression. 60% Offensive roles.',
            Icons.whatshot,
            Colors.red,
            GameMode.bloodbath,
          ),
          const SizedBox(height: 12),
          _buildGameModeButton(
            'Political Nightmare',
            'High deception. 60% Defensive/Intel roles.',
            Icons.psychology,
            Colors.purple,
            GameMode.politicalNightmare,
          ),
          const SizedBox(height: 12),
          _buildGameModeButton(
            'Free For All',
            'Chaos reigns. 70% Reactive/Wild roles.',
            Icons.casino,
            Colors.orange,
            GameMode.freeForAll,
          ),
          const SizedBox(height: 12),
          _buildGameModeButton(
            'Custom Balance',
            'Balanced mix of all role types.',
            Icons.dashboard_customize,
            Colors.blue,
            GameMode.custom,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewContent(bool isValid, List<String> issues) {
    return Column(
      children: [
        Card(
          color: isValid
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.warning,
                  color: isValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isValid ? 'Valid Setup' : issues.join('\n'),
                    style: TextStyle(
                      color: isValid ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: widget.players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final player = widget.players[index];
              final role = _playerRoles[player.id];
              return ListTile(
                onTap: () => _showEditRoleDialog(player),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: role != null
                    ? RoleAvatarWidget(role: role, size: 40)
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(player.name),
                subtitle: Text(role?.name ?? 'Unassigned'),
                trailing: const Icon(Icons.edit, size: 16),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameModeButton(
    String title,
    String description,
    IconData icon,
    Color color,
    GameMode mode,
  ) {
    final isSelected = _selectedMode == mode;
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? cs.primary : color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
