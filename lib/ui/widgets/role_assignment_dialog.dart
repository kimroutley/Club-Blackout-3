import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../../utils/role_validator.dart';
import '../styles.dart';

enum GameMode { bloodbath, politicalNightmare, freeForAll, custom }

class RoleAssignmentDialog extends StatefulWidget {
  final GameEngine gameEngine;
  final List<Player> players;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const RoleAssignmentDialog({
    super.key,
    required this.gameEngine,
    required this.players,
    required this.onConfirm,
    required this.onCancel,
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

  static bool _isNeutral(Role role) {
    final alliance = role.alliance.trim().toLowerCase();
    return alliance.startsWith('none') || alliance.contains('neutral');
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

    // Exclude Host from validation checks
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

    if (dealerCount < 1) issues.add('Missing required role: Dealer');
    if (!hasMedicOrBouncer)
      issues.add('Missing required role: Medic and/or Bouncer');
    if (!hasPartyAnimal) issues.add('Missing required role: Party Animal');
    if (!hasWallflower) issues.add('Missing required role: Wallflower');
    if (partyAlignedCount < 2)
      issues.add('Need at least 2 Party Animal-aligned roles');
    if (bouncerCount > 1) issues.add('Only one Bouncer is allowed.');

    // Prevent trivial setup
    if (dealerCount > (roles.length - dealerCount)) {
      issues.add('Invalid: Dealers already have majority');
    }

    // Uniqueness except Dealer
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
    // Check if any player has a 'temp' role (indicating fresh setup)
    final hasTempRoles = widget.players.any((p) => p.role.id == 'temp');

    // Pre-fill with existing roles so validation doesn't falsely complain
    _playerRoles = {
      for (final p in widget.players.where((p) => p.isEnabled)) p.id: p.role,
    };

    // Only consider roles assigned if no temp roles exist AND counts match
    _rolesAssigned =
        !hasTempRoles &&
        _playerRoles.length == widget.players.where((p) => p.isEnabled).length;
  }

  void _assignRolesByMode(GameMode mode) {
    final allRoles = _eligibleNonHostRoles(
      widget.gameEngine.roleRepository.roles,
    );
    // Only assign roles to non-host players
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

    if (dealerRole == null) {
      throw StateError(
        'Missing required role: dealer. Check assets/data/roles.json.',
      );
    }

    if (partyAnimalRole == null) {
      throw StateError(
        'Missing required role: party_animal. Check assets/data/roles.json.',
      );
    }

    if (wallflowerRole == null) {
      throw StateError(
        'Missing required role: wallflower. Check assets/data/roles.json.',
      );
    }

    if (medicRole == null && bouncerRole == null) {
      throw StateError(
        'Missing required role: medic and/or bouncer. Check assets/data/roles.json.',
      );
    }

    // Try a few times to satisfy the required lineup while keeping the mode's vibe.
    // If we can't, we fall back to a deterministic "always valid" lineup.
    List<Role> buildAttempt() {
      final recommendedDealers = RoleValidator.recommendedDealerCount(
        playerCount,
      ).clamp(1, playerCount);
      final selected = <Role>[];
      final usedUniqueIds = <String>{};

      // Dealers first (repeat allowed)
      for (var i = 0; i < recommendedDealers; i++) {
        selected.add(dealerRole);
      }

      // Ensure at least one Medic or Bouncer
      final firstSupport = (medicRole ?? bouncerRole)!;
      selected.add(firstSupport);
      usedUniqueIds.add(firstSupport.id);

      // Auto-add Second Wind if more than 6 players
      if (playerCount > 6) {
        final secondWindRole = _byId('second_wind');
        if (secondWindRole != null && usedUniqueIds.add(secondWindRole.id)) {
          selected.add(secondWindRole);
        }
      }

      // Required defaults: Party Animal + Wallflower
      if (usedUniqueIds.add(partyAnimalRole.id)) {
        selected.add(partyAnimalRole);
      }
      if (usedUniqueIds.add(wallflowerRole.id)) {
        selected.add(wallflowerRole);
      }

      // Ensure at least 2 Party Animal-aligned players (incl Medic/Bouncer/etc).
      int partyAlignedCount = selected.where(_isPartyAligned).length;
      if (partyAlignedCount < 2) {
        // Prefer adding the other of Medic/Bouncer if available (more consistent with the host guide).
        final otherSupport = (firstSupport.id == 'medic')
            ? bouncerRole
            : medicRole;
        if (otherSupport != null && usedUniqueIds.add(otherSupport.id)) {
          selected.add(otherSupport);
          partyAlignedCount++;
        }
      }

      // Remaining unique role pool
      final pool = allRoles
          .where((r) => !_isDealerRole(r))
          .where((r) => !usedUniqueIds.contains(r.id))
          .toList();

      List<Role> pickFrom(List<Role> candidates) {
        final copy = candidates
            .where((r) => pool.any((p) => p.id == r.id))
            .toList();
        copy.shuffle(random);
        return copy;
      }

      // Mode buckets (best-effort; falls back if role types don't match)
      final offensive = pickFrom(
        pool.where((r) => _isType(r, ['aggressive', 'offensive'])).toList(),
      );
      final defensive = pickFrom(
        pool
            .where(
              (r) => _isType(r, ['defensive', 'protective', 'investigative']),
            )
            .toList(),
      );
      final reactive = pickFrom(
        pool
            .where(
              (r) => _isType(r, ['reactive', 'chaos', 'disruptive', 'wild']),
            )
            .toList(),
      );
      final passive = pickFrom(
        pool.where((r) => _isType(r, ['passive'])).toList(),
      );

      void takeFrom(List<Role> source, int count) {
        for (var i = 0; i < count && source.isNotEmpty; i++) {
          final role = source.removeAt(0);
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
            // "regular" mix
            final regular = <Role>[...offensive, ...defensive, ...passive];
            regular.shuffle(random);
            takeFrom(
              regular,
              remainingSlots - ((remainingSlots * 0.7).round()),
            );
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

      // Fill anything left with whatever remains.
      final leftovers = List<Role>.from(
        pool.where((r) => !usedUniqueIds.contains(r.id)),
      );
      leftovers.shuffle(random);
      for (final role in leftovers) {
        if (selected.length >= playerCount) break;

        // Auto-add Bouncer if Ally Cat is present and Bouncer not already added
        if (selected.any((r) => r.id == 'ally_cat')) {
          if (!selected.any((r) => r.id == 'bouncer') && bouncerRole != null) {
            // Replace a random non-essential Party Animal role with Bouncer
            final replaceableIndex = selected.lastIndexWhere(
              (r) =>
                  r.alliance == 'The Party Animals' &&
                  r.id != 'party_animal' &&
                  r.id != 'wallflower' &&
                  r.id != 'medic' &&
                  r.id != 'ally_cat' &&
                  r.id != 'second_wind',
            );
            if (replaceableIndex != -1) {
              usedUniqueIds.remove(selected[replaceableIndex].id);
              selected[replaceableIndex] = bouncerRole;
              usedUniqueIds.add('bouncer');
            }
          }
        }
        if (usedUniqueIds.add(role.id)) {
          selected.add(role);
        }
      }

      // If we still couldn't fill, that's a content problem.
      if (selected.length < playerCount) {
        throw StateError(
          'Not enough unique roles to fill $playerCount players. Add more roles or reduce players.',
        );
      }

      // Keep the game start from being trivial: dealers cannot already have strict majority.
      final dealerCount = selected.where(_isDealerRole).length;
      if (dealerCount > (playerCount - dealerCount)) {
        return const <Role>[];
      }

      // Ensure we have at least 2 Party Animal-aligned players.
      if (selected.where(_isPartyAligned).length < 2) {
        return const <Role>[];
      }

      // Ensure required defaults exist.
      if (!selected.any((r) => r.id == 'party_animal')) return const <Role>[];
      if (!selected.any((r) => r.id == 'wallflower')) return const <Role>[];

      // Ensure required roles exist
      if (!selected.any(_isDealerRole)) return const <Role>[];
      if (!selected.any((r) => r.id == 'medic' || r.id == 'bouncer'))
        return const <Role>[];

      // Validate role dependencies
      if (!_validateRoleDependencies(selected)) return const <Role>[];

      // Ensure uniqueness except repeatable roles
      final seen = <String>{};
      for (final role in selected) {
        if (RoleValidator.multipleAllowedRoles.contains(role.id)) continue;
        if (!seen.add(role.id)) return const <Role>[];
      }

      return selected;
    }

    List<Role> selectedRoles = const <Role>[];
    for (var attempt = 0; attempt < 40; attempt++) {
      final attemptRoles = buildAttempt();
      if (attemptRoles.isNotEmpty) {
        selectedRoles = attemptRoles;
        break;
      }
    }

    if (selectedRoles.isEmpty) {
      // Deterministic fallback: dealers + medic/bouncer + fill with Party Animal roles first.
      final recommendedDealers = RoleValidator.recommendedDealerCount(
        playerCount,
      ).clamp(1, playerCount);
      final selected = <Role>[];
      final usedUniqueIds = <String>{};
      for (var i = 0; i < recommendedDealers; i++) {
        selected.add(dealerRole);
      }
      final support = (medicRole ?? bouncerRole)!;
      selected.add(support);
      usedUniqueIds.add(support.id);

      // Auto-add Second Wind if more than 6 players
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

      if (support.id == 'medic' && bouncerRole != null) {
        selected.add(bouncerRole);
        usedUniqueIds.add(bouncerRole.id);
      } else if (support.id == 'bouncer' && medicRole != null) {
        selected.add(medicRole);
        usedUniqueIds.add(medicRole.id);
      }

      final partyFirst = allRoles
          .where((r) => !_isDealerRole(r))
          .where((r) => _isPartyAligned(r) && !usedUniqueIds.contains(r.id))
          .toList();
      partyFirst.shuffle(random);

      final others = allRoles
          .where((r) => !_isDealerRole(r))
          .where(
            (r) =>
                !_isNeutral(r) &&
                !_isPartyAligned(r) &&
                !usedUniqueIds.contains(r.id),
          )
          .toList();
      others.shuffle(random);

      final neutrals = allRoles
          .where((r) => !_isDealerRole(r))
          .where((r) => _isNeutral(r) && !usedUniqueIds.contains(r.id))
          .toList();
      neutrals.shuffle(random);

      for (final role in [...partyFirst, ...others, ...neutrals]) {
        // Auto-add Bouncer if Ally Cat is present and Bouncer not already added
        if (selected.any((r) => r.id == 'ally_cat')) {
          if (!selected.any((r) => r.id == 'bouncer') && bouncerRole != null) {
            // If we have space, add bouncer
            if (selected.length < playerCount && usedUniqueIds.add('bouncer')) {
              selected.add(bouncerRole);
            } else if (selected.length >= playerCount) {
              // Replace a non-essential role
              final replaceableIndex = selected.lastIndexWhere(
                (r) =>
                    r.alliance == 'The Party Animals' &&
                    r.id != 'party_animal' &&
                    r.id != 'wallflower' &&
                    r.id != 'medic' &&
                    r.id != 'ally_cat' &&
                    r.id != 'second_wind',
              );
              if (replaceableIndex != -1) {
                usedUniqueIds.remove(selected[replaceableIndex].id);
                selected[replaceableIndex] = bouncerRole;
                usedUniqueIds.add('bouncer');
              }
            }
          }
        }
        if (selected.length >= playerCount) break;
        if (usedUniqueIds.add(role.id)) {
          selected.add(role);
        }
      }

      if (selected.length < playerCount) {
        throw StateError(
          'Not enough unique roles to fill $playerCount players. Add more roles or reduce players.',
        );
      }
      selectedRoles = selected;
    }

    // Shuffle and assign
    selectedRoles.shuffle(random);
    _playerRoles.clear();
    for (var i = 0; i < playersToAssign.length; i++) {
      _playerRoles[playersToAssign[i].id] = selectedRoles[i];
    }
    // Restore Host roles
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
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            decoration: ClubBlackoutTheme.glassmorphism(
              color: Colors.black,
              opacity: 0.9,
              borderColor: ClubBlackoutTheme.neonPink,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Assign Role to ${player.name}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonPink,
                    shadows: ClubBlackoutTheme.textGlow(
                      ClubBlackoutTheme.neonPink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableRoles.length,
                    itemBuilder: (context, index) {
                      final role = availableRoles[index];
                      final isSelected = _playerRoles[player.id]?.id == role.id;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: role.color.withOpacity(0.2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: role.color, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: role.color.withOpacity(0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              role.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  color: role.color,
                                  size: 20,
                                );
                              },
                            ),
                          ),
                        ),
                        title: Text(
                          role.name,
                          style: TextStyle(
                            color: role.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          role.type,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _playerRoles[player.id] = role;
                          });
                          Navigator.pop(context);
                          HapticFeedback.selectionClick();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_eligibleNonHostRoles(widget.gameEngine.roleRepository.roles).isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final issues = _rolesAssigned ? _roleAssignmentIssues() : const <String>[];
    final isValid = _rolesAssigned ? issues.isEmpty : false;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClubBlackoutTheme.centeredConstrained(
        child: Container(
          decoration: ClubBlackoutTheme.glassmorphism(
            color: Colors.black,
            opacity: 0.85,
            borderColor: ClubBlackoutTheme.neonPink.withOpacity(0.5),
            borderRadius: 28,
            borderWidth: 1.5,
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ClubBlackoutTheme.neonPink.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      ClubBlackoutTheme.neonPink.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_ind_rounded,
                      color: ClubBlackoutTheme.neonPink,
                      size: 28,
                      shadows: ClubBlackoutTheme.iconGlow(
                        ClubBlackoutTheme.neonPink,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Role Assignments',
                        style: ClubBlackoutTheme.headingStyle.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          shadows: ClubBlackoutTheme.textGlow(
                            ClubBlackoutTheme.neonPink,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                      ),
                      onPressed: widget.onCancel,
                      style: IconButton.styleFrom(
                        hoverColor: Colors.white10,
                        highlightColor: Colors.white10,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: !_rolesAssigned
                    ?
                      // Mode Selection View
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Select Game Mode',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose how roles should be distributed among the ${widget.players.length} players.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            _buildGameModeButton(
                              'Bloodbath',
                              'High aggression. 60% Offensive roles.',
                              Icons.whatshot_rounded,
                              ClubBlackoutTheme.neonRed,
                              GameMode.bloodbath,
                            ),
                            const SizedBox(height: 16),
                            _buildGameModeButton(
                              'Political Nightmare',
                              'High deception. 60% Defensive/Intel roles.',
                              Icons.psychology_rounded,
                              ClubBlackoutTheme.neonPurple,
                              GameMode.politicalNightmare,
                            ),
                            const SizedBox(height: 16),
                            _buildGameModeButton(
                              'Free For All',
                              'Chaos reigns. 70% Reactive/Wild roles.',
                              Icons.casino_rounded,
                              ClubBlackoutTheme.neonOrange,
                              GameMode.freeForAll,
                            ),
                            const SizedBox(height: 16),
                            _buildGameModeButton(
                              'Custom Balance',
                              'Balanced mix of all role types.',
                              Icons.dashboard_customize_rounded,
                              ClubBlackoutTheme.neonBlue,
                              GameMode.custom,
                            ),
                          ],
                        ),
                      )
                    :
                      // Role Review View
                      Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isValid
                                  ? ClubBlackoutTheme.neonGreen.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isValid
                                    ? ClubBlackoutTheme.neonGreen
                                    : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isValid
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_rounded,
                                  color: isValid
                                      ? ClubBlackoutTheme.neonGreen
                                      : Colors.red,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isValid
                                        ? 'Role setup is valid!'
                                        : issues.join('\n'),
                                    style: TextStyle(
                                      color: isValid
                                          ? ClubBlackoutTheme.neonGreen
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (!isValid)
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'REQUIREMENTS',
                                    style: TextStyle(
                                      color: ClubBlackoutTheme.neonBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _styledRequirementRow(
                                    'Dealer present',
                                    _playerRoles.values.any(_isDealerRole),
                                  ),
                                  _styledRequirementRow(
                                    'Medic or Bouncer',
                                    _playerRoles.values.any(
                                      (r) =>
                                          r.id == 'medic' || r.id == 'bouncer',
                                    ),
                                  ),
                                  _styledRequirementRow(
                                    'Party Animal',
                                    _playerRoles.values.any(
                                      (r) => r.id == 'party_animal',
                                    ),
                                  ),
                                  _styledRequirementRow(
                                    'Wallflower',
                                    _playerRoles.values.any(
                                      (r) => r.id == 'wallflower',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Assignments',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ClubBlackoutTheme.neonBlue
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: ClubBlackoutTheme.neonBlue
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${_playerRoles.length}/${widget.players.length}',
                                    style: const TextStyle(
                                      color: ClubBlackoutTheme.neonBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: widget.players.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final player = widget.players[index];
                                final role = _playerRoles[player.id];

                                return Container(
                                  decoration: BoxDecoration(
                                    color: role != null
                                        ? role.color.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.05),
                                    border: Border.all(
                                      color: role != null
                                          ? role.color.withOpacity(0.3)
                                          : Colors.white10,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: role != null
                                        ? Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: role.color,
                                                width: 2,
                                              ),
                                              boxShadow:
                                                  ClubBlackoutTheme.circleGlow(
                                                    role.color,
                                                    intensity: 0.5,
                                                  ),
                                            ),
                                            child: ClipOval(
                                              child: Image.asset(
                                                role.assetPath,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons.person,
                                                        color: role.color,
                                                      );
                                                    },
                                              ),
                                            ),
                                          )
                                        : const CircleAvatar(
                                            backgroundColor: Colors.white10,
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white38,
                                            ),
                                          ),
                                    title: Text(
                                      player.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: role != null
                                        ? Text(
                                            '${role.name} • ${role.type}',
                                            style: TextStyle(
                                              color: role.color,
                                              fontSize: 13,
                                            ),
                                          )
                                        : const Text(
                                            'No role assigned',
                                            style: TextStyle(
                                              color: Colors.white38,
                                            ),
                                          ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.edit_rounded,
                                        color: role?.color ?? Colors.white54,
                                      ),
                                      onPressed: () =>
                                          _showEditRoleDialog(player),
                                      tooltip: 'Edit Role',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),

              // Footer Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: ClubBlackoutTheme.neonPink.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  color: Colors.white.withOpacity(0.02),
                ),
                child: Row(
                  children: [
                    if (!_rolesAssigned)
                      TextButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _rolesAssigned = false;
                          });
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Modes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    const Spacer(),

                    if (!_rolesAssigned) ...[
                      TextButton(
                        onPressed: widget.onConfirm,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white60,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          _assignRolesByMode(_selectedMode);
                          HapticFeedback.mediumImpact();
                        },
                        style:
                            FilledButton.styleFrom(
                              backgroundColor: ClubBlackoutTheme.neonPink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              elevation: 2,
                            ).copyWith(
                              shadowColor: WidgetStateProperty.all(
                                ClubBlackoutTheme.neonPink.withOpacity(0.5),
                              ),
                            ),
                        icon: const Icon(Icons.casino_rounded),
                        label: const Text('ROLL'),
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () {
                          _assignRolesByMode(_selectedMode);
                          HapticFeedback.lightImpact();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reroll'),
                        style: TextButton.styleFrom(
                          foregroundColor: ClubBlackoutTheme.neonBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: isValid
                            ? () {
                                // Apply roles to players
                                for (var player in widget.players) {
                                  final role = _playerRoles[player.id];
                                  if (role != null) {
                                    widget.gameEngine.updatePlayerRole(
                                      player.id,
                                      role,
                                    );
                                  }
                                }
                                HapticFeedback.heavyImpact();
                                widget.onConfirm();
                              }
                            : null,
                        style:
                            FilledButton.styleFrom(
                              backgroundColor: ClubBlackoutTheme.neonGreen,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white10,
                              disabledForegroundColor: Colors.white38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              elevation: 2,
                            ).copyWith(
                              shadowColor: WidgetStateProperty.all(
                                ClubBlackoutTheme.neonGreen.withOpacity(0.5),
                              ),
                            ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('CONFIRM'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMode = mode;
          });
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
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
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledRequirementRow(String label, bool ok) {
    final color = ok ? ClubBlackoutTheme.neonGreen : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ok ? Colors.white : Colors.white60,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validate that all role dependencies are met
  bool _validateRoleDependencies(List<Role> roles) {
    final roleIds = roles.map((r) => r.id).toSet();

    // Ally Cat requires Bouncer
    if (roleIds.contains('ally_cat') && !roleIds.contains('bouncer')) {
      return false;
    }

    // Minor requires Bouncer to function properly
    if (roleIds.contains('minor') && !roleIds.contains('bouncer')) {
      return false;
    }

    // Whore requires at least one Dealer
    if (roleIds.contains('whore') && !roles.any((r) => r.id == 'dealer')) {
      return false;
    }

    return true;
  }
}
