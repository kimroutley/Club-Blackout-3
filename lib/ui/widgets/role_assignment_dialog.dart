import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../../utils/game_exceptions.dart';
import '../../utils/role_validator.dart';
import '../styles.dart';
import 'bulletin_dialog_shell.dart';
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
    _selectedMode = widget.initialMode;
    // Check if any player has a 'temp' role (indicating fresh setup)
    final hasTempRoles = widget.players.any((p) => p.role.id == 'temp');

    // Pre-fill with existing roles so validation doesn't falsely complain
    _playerRoles = {
      for (final p in widget.players.where((p) => p.isEnabled)) p.id: p.role,
    };

    // Only consider roles assigned if no temp roles exist AND counts match
    _rolesAssigned = !hasTempRoles &&
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

    // Deterministic role assignment that satisfies mode and constraints
    final recommendedDealers = RoleValidator.recommendedDealerCount(
      playerCount,
    ).clamp(1, playerCount);
    final selected = <Role>[];
    final usedUniqueIds = <String>{};

    // 1. Mandatory Roles
    // Dealers first (repeat allowed)
    for (var i = 0; i < recommendedDealers; i++) {
      selected.add(dealerRole);
    }

    // Ensure at least one Medic or Bouncer
    // Randomize choice unless one is missing
    Role firstSupport;
    if (medicRole != null && bouncerRole != null) {
      firstSupport = random.nextBool() ? medicRole : bouncerRole;
    } else {
      firstSupport = (medicRole ?? bouncerRole)!;
    }
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
    // Current count includes: First Support (maybe), PA, Wallflower, Second Wind (maybe)
    final int partyAlignedCount = selected.where(_isPartyAligned).length;
    if (partyAlignedCount < 2) {
      // Prefer adding the other of Medic/Bouncer if available
      final otherSupport =
          (firstSupport.id == 'medic') ? bouncerRole : medicRole;
      if (otherSupport != null && usedUniqueIds.add(otherSupport.id)) {
        selected.add(otherSupport);
      }
    }

    // 2. Prepare buckets for filling remaining slots
    // Remaining unique role pool
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

    // Mode buckets
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
        // We must re-check usedUniqueIds because a role might be in multiple buckets
        // or selected in a previous step.
        // Also source might have duplicates if we didn't filter strictly enough,
        // but `getCandidates` filters by usedUniqueIds at creation time.
        // However, as we add to `usedUniqueIds` during `takeFrom`, subsequent calls
        // or subsequent iterations need to be careful?
        // Actually `getCandidates` returns a fresh list. If a role is in `offensive` AND `defensive`,
        // it could be in both lists.
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

    // 3. Fill leftovers
    // Recalculate pool because we've used some roles
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

    // 4. Validate and Fix Dependencies (Deterministic fix)
    // Check Bouncer dependency for Ally Cat and Minor
    final hasAllyCat = selected.any((r) => r.id == 'ally_cat');
    final hasMinor = selected.any((r) => r.id == 'minor');
    final hasBouncer = selected.any((r) => r.id == 'bouncer');

    if ((hasAllyCat || hasMinor) && !hasBouncer && bouncerRole != null) {
      // We need to add Bouncer.
      // If we have space (unlikely here), add it.
      if (selected.length < playerCount) {
        selected.add(bouncerRole);
        usedUniqueIds.add('bouncer');
      } else {
        // Swap out a non-critical role for Bouncer.
        // Candidates for removal: NOT Dealer, Ally Cat, Minor, Party Animal, Wallflower.
        // Also prefer removing roles added late (at the end of the list),
        // but let's just find a valid candidate.
        final candidateIndex = selected.lastIndexWhere(
          (r) =>
              r.id != 'dealer' &&
              r.id != 'ally_cat' &&
              r.id != 'minor' &&
              r.id != 'party_animal' &&
              r.id != 'wallflower' &&
              r.id != 'medic' && // prefer keeping medic if present
              r.id != 'second_wind',
        );

        if (candidateIndex != -1) {
          final removed = selected[candidateIndex];
          usedUniqueIds.remove(removed.id);
          selected[candidateIndex] = bouncerRole;
          usedUniqueIds.add('bouncer');
        } else {
          // If we can't find a perfect candidate, we might have to sacrifice Medic or Second Wind?
          // Fallback: Replace ANY non-dealer, non-dependent role.
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

    // Final checks
    if (selected.length < playerCount) {
      throw StateError(
        'Not enough unique roles to fill $playerCount players. Add more roles or reduce players.',
      );
    }

    // Ensure Dealer Majority rule doesn't break game
    // (Should be covered by recommendedDealers, but double check)
    final dealerCount = selected.where(_isDealerRole).length;
    if (dealerCount > (playerCount - dealerCount)) {
      // This is a configuration error if recommendedDealers is broken
      // Force reduce dealers?
      // For now, assuming recommendedDealers is correct (max 3 for 15 players).
    }

    final List<Role> selectedRoles = selected;

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
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return BulletinDialogShell(
          accent: ClubBlackoutTheme.neonPink,
          maxWidth: 520,
          maxHeight: 720,
          padding: EdgeInsets.zero,
          showCloseButton: true,
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: ClubBlackoutTheme.neonPink),
              ClubBlackoutTheme.hGap12,
              Text(
                'Assign role',
                style: ClubBlackoutTheme.headingStyle.copyWith(
                  fontSize: 20,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: ClubBlackoutTheme.neonPink.withValues(alpha: 0.1),
                ),
                child: Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 18,
                    color: ClubBlackoutTheme.neonPink,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: scheme.onSurface.withValues(alpha: 0.12),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: availableRoles.length,
                  separatorBuilder: (_, __) => ClubBlackoutTheme.gap8,
                  itemBuilder: (context, index) {
                    final role = availableRoles[index];
                    final isSelected = _playerRoles[player.id]?.id == role.id;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _playerRoles[player.id] = role;
                          });
                          Navigator.pop(context);
                          HapticFeedback.selectionClick();
                        },
                        borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: ClubBlackoutTheme.neonFrame(
                            color: isSelected
                                ? role.color
                                : scheme.onSurface.withValues(alpha: 0.24),
                            opacity: isSelected ? 0.2 : 0.05,
                            borderWidth: isSelected ? 2 : 1,
                            showGlow: isSelected,
                          ),
                          child: Row(
                            children: [
                              RoleAvatarWidget(
                                role: role,
                                size: 40,
                                showGlow: isSelected,
                              ),
                              ClubBlackoutTheme.hGap16,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? scheme.onSurface
                                            : scheme.onSurface
                                                .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      role.type,
                                      style: TextStyle(
                                        color: role.color.withValues(alpha: 0.7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: role.color,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final issues = _rolesAssigned ? _roleAssignmentIssues() : const <String>[];
    final isValid = _rolesAssigned ? issues.isEmpty : false;

    return BulletinDialogShell(
      accent: ClubBlackoutTheme.neonPink,
      maxWidth: 860,
      maxHeight: 820,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: EdgeInsets.zero,
      content: ClipRRect(
        borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusLg),
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
                      color: ClubBlackoutTheme.neonPink.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  color: cs.surface.withValues(alpha: 0.2),
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
                    ClubBlackoutTheme.hGap16,
                    Expanded(
                      child: Text(
                        'ROLE ASSIGNMENTS',
                        style: ClubBlackoutTheme.glowTextStyle(
                          base: ClubBlackoutTheme.headingStyle,
                          color: cs.onSurface,
                          glowColor: ClubBlackoutTheme.neonPink,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      onPressed: widget.onCancel,
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
                              'SELECT GAME MODE',
                              style: ClubBlackoutTheme.headingStyle.copyWith(
                                color: cs.onSurface,
                                fontSize: 24,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            ClubBlackoutTheme.gap8,
                            Text(
                              'Choose how roles should be distributed among the ${widget.players.length} players.',
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            ClubBlackoutTheme.gap32,
                            _buildGameModeButton(
                              'Bloodbath',
                              'High aggression. 60% Offensive roles.',
                              Icons.whatshot_rounded,
                              ClubBlackoutTheme.neonRed,
                              GameMode.bloodbath,
                            ),
                            ClubBlackoutTheme.gap16,
                            _buildGameModeButton(
                              'Political Nightmare',
                              'High deception. 60% Defensive/Intel roles.',
                              Icons.psychology_rounded,
                              ClubBlackoutTheme.neonPurple,
                              GameMode.politicalNightmare,
                            ),
                            ClubBlackoutTheme.gap16,
                            _buildGameModeButton(
                              'Free For All',
                              'Chaos reigns. 70% Reactive/Wild roles.',
                              Icons.casino_rounded,
                              ClubBlackoutTheme.neonOrange,
                              GameMode.freeForAll,
                            ),
                            ClubBlackoutTheme.gap16,
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
                            decoration: ClubBlackoutTheme.cardDecoration(
                              glowColor:
                                  isValid ? ClubBlackoutTheme.neonGreen : cs.error,
                              surfaceColor: cs.surface,
                              glowIntensity: 0.55,
                              borderRadius: 16,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isValid
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_rounded,
                                  color: isValid
                                      ? ClubBlackoutTheme.neonGreen
                                      : cs.error,
                                ),
                                ClubBlackoutTheme.hGap12,
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
                                color: cs.surface.withValues(alpha: 0.35),
                                borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
                                border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'REQUIREMENTS',
                                    style: TextStyle(
                                      color: ClubBlackoutTheme.neonBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  ClubBlackoutTheme.gap8,
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
                                    'ASSIGNMENTS',
                                    style: ClubBlackoutTheme.headingStyle.copyWith(
                                      color: cs.onSurface,
                                      fontSize: 20,
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
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: ClubBlackoutTheme.neonBlue
                                          .withValues(alpha: 0.3),
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
                          _buildCompositionSummary(),
                          ClubBlackoutTheme.gap8,
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: widget.players.length,
                              separatorBuilder: (context, index) =>
                                  ClubBlackoutTheme.gap8,
                              itemBuilder: (context, index) {
                                final player = widget.players[index];
                                final role = _playerRoles[player.id];
                                final glow = role?.color ?? cs.outlineVariant;

                                return Container(
                                  decoration: ClubBlackoutTheme.neonFrame(
                                    color: glow,
                                    opacity: role == null ? 0.05 : 0.18,
                                    borderWidth: role == null ? 1.0 : 2.0,
                                    showGlow: role != null,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showEditRoleDialog(player),
                                      borderRadius: BorderRadius.circular(16),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        leading: role != null
                                            ? RoleAvatarWidget(role: role, size: 48)
                                            : PlayerIcon(
                                                assetPath: '',
                                                glowColor: cs.onSurface.withValues(alpha: 0.2),
                                                size: 48,
                                              ),
                                        title: Text(
                                          player.name,
                                          style: TextStyle(
                                            color: cs.onSurface,
                                            fontSize: 18,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: role != null
                                            ? Text(
                                                '${role.name} · ${role.type}',
                                                style: TextStyle(
                                                  color: role.color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.8,
                                                ),
                                              )
                                            : Text(
                                                'No role assigned',
                                                style: TextStyle(
                                                  color: cs.onSurface.withValues(alpha: 0.38),
                                                  fontSize: 11,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                        trailing: Icon(
                                          Icons.chevron_right_rounded,
                                          color: role?.color.withValues(alpha: 0.5) ??
                                              cs.onSurface.withValues(alpha: 0.2),
                                        ),
                                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: ClubBlackoutTheme.neonPink.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  color: cs.surface.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    if (!_rolesAssigned)
                      IconButton(
                        onPressed: widget.onCancel,
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _rolesAssigned = false;
                          });
                        },
                        tooltip: 'Back to Modes',
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: ClubBlackoutTheme.neonBlue,
                        ),
                      ),
                    const Spacer(),
                    if (!_rolesAssigned) ...[
                      IconButton(
                        onPressed: widget.onConfirm,
                        tooltip: 'Skip to Gameplay',
                        icon: const Icon(Icons.skip_next_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      ClubBlackoutTheme.hGap12,
                      FilledButton(
                        onPressed: () {
                          _assignRolesByMode(_selectedMode);
                          HapticFeedback.mediumImpact();
                        },
                        style: ClubBlackoutTheme.neonButtonStyle(
                          ClubBlackoutTheme.neonPink,
                          isPrimary: true,
                        ).copyWith(
                          padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                        ),
                        child: const Icon(Icons.casino_rounded),
                      ),
                    ] else ...[
                      IconButton(
                        onPressed: () {
                          _assignRolesByMode(_selectedMode);
                          HapticFeedback.lightImpact();
                        },
                        tooltip: 'Reroll All Roles',
                        icon: const Icon(Icons.refresh_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: ClubBlackoutTheme.neonBlue,
                        ),
                      ),
                      ClubBlackoutTheme.hGap12,
                      FilledButton(
                        onPressed: isValid
                            ? () {
                                try {
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
                                } on GameException catch (e) {
                                  widget.gameEngine.showToast(e.message);
                                } catch (e) {
                                  widget.gameEngine.showToast(e.toString());
                                }
                              }
                            : null,
                        style: ClubBlackoutTheme.neonButtonStyle(
                          ClubBlackoutTheme.neonGreen,
                          isPrimary: true,
                        ).copyWith(
                          padding: WidgetStateProperty.all(const EdgeInsets.all(12)),
                        ),
                        child: const Icon(Icons.check_circle_rounded),
                      ),
                    ],
                  ],
                ),
              ),
          ],
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
    final cs = Theme.of(context).colorScheme;

    return AnimatedScale(
      scale: isSelected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Material(
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
          decoration: ClubBlackoutTheme.neonFrame(
            color: isSelected ? color : cs.outlineVariant,
            opacity: isSelected ? 0.35 : 0.05,
            borderWidth: isSelected ? 2.5 : 1.2,
            showGlow: isSelected,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: isSelected ? 1.0 : 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? color : color.withValues(alpha: 0.5),
                  size: 28,
                ),
              ),
              ClubBlackoutTheme.hGap16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 1.2,
                        color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.7),
                        shadows: isSelected ? ClubBlackoutTheme.textGlow(color) : null,
                      ),
                    ),
                    ClubBlackoutTheme.gap4,
                    Text(
                      description,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: isSelected ? 0.8 : 0.5),
                        fontSize: 12,
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
    ));
  }

  Widget _buildCompositionSummary() {
    final cs = Theme.of(context).colorScheme;
    final roles = _playerRoles.values;
    final aggressive = roles.where((r) => r.type == 'aggressive' || r.type == 'offensive').length;
    final defensive = roles.where((r) => r.type == 'defensive' || r.type == 'protective').length;
    final chaos = roles.where((r) => r.type == 'chaos' || r.type == 'disruptive' || r.type == 'wild').length;
    final other = roles.length - aggressive - defensive - chaos;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: ClubBlackoutTheme.controlPadding,
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.3),
        borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
        border: Border.all(
          color: ClubBlackoutTheme.neonBlue.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryChip('Aggressive', aggressive, ClubBlackoutTheme.neonPink),
          _summaryChip('Defensive', defensive, ClubBlackoutTheme.neonBlue),
          _summaryChip('Chaos', chaos, Colors.orange),
          _summaryChip('Other', other, cs.onSurface.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _styledRequirementRow(String label, bool ok) {
    final cs = Theme.of(context).colorScheme;
    final color = ok ? ClubBlackoutTheme.neonGreen : cs.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 18,
          ),
          ClubBlackoutTheme.hGap8,
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: ok ? cs.onSurface : cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
