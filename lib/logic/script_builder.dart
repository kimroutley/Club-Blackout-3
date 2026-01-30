import '../models/player.dart';
import '../models/role.dart';
import '../models/script_step.dart';

class ScriptBuilder {
  /// Builds the night phase script for a given game state.
  ///
  /// **Night 0 (Setup Night - dayCount == 0):**
  /// - Only used for ONE-TIME game initialization
  /// - Creep chooses mimic target + sees their role card
  /// - Clinger chooses obsession + sees their role card
  /// - Medic chooses strategy (PROTECT daily OR REVIVE once)
  /// - Bouncer gets rules reminder (can check Minor but vulnerability risk)
  /// - **NO ACTUAL DEATHS** occur on Night 0 - it's purely setup
  /// - Game transitions immediately to Day 1 (Morning announcement)
  ///
  /// **Night 1+ (Standard Nights - dayCount > 0):**
  /// - Role-based actions in priority order: Dealer → Medic → Bouncer → Others
  /// - Each role wakes, performs their ability, then sleeps
  /// - Integrated roles (Whore, Wallflower, Ally Cat) wake with Dealer
  /// - Special abilities resolved (protection, kills, investigations, etc.)
  /// - Messy Bitch spreads rumours; wins immediately when all other living players have heard one
  /// - Morning report shows results when all night actions complete
  ///
  /// **Late Joiners:**
  /// - Join as "inactive" and become active on next night transition
  /// - Participate in night actions once activated
  ///
  /// Returns a list of [ScriptStep] objects to be executed in sequence.
  static List<ScriptStep> buildNightScript(List<Player> players, int dayCount) {
    final List<ScriptStep> steps = [];

    // 1. Start Phase
    // For Night 0, we skip the standard "Close Eyes" because Intro (Party Time) handles it.
    // Every standard night (Night 1+) must start by putting everyone to sleep.
    if (dayCount > 0) {
      steps.add(
        const ScriptStep(
          id: 'night_start',
          title: 'Night Phase',
          readAloudText:
              'Everyone, close your eyes.\nHeads down. Don\'t lose your head... yet.\nNo peeking!',
          instructionText:
              'Wait for 10-15 seconds of silence before proceeding. Ensure absolute silence from those sleeping.\n\nVOICE: Deep, clear, and authoritative.\nPACING: Slow down. Silence creates tension.',
          isNight: true,
        ),
      );
    }

    // SPECIAL SETUP PHASE (For mid-game role swaps like Drama Queen)
    // If a player swapped into a role requiring setup (Clinger, Creep, Medic), run it now.
    if (dayCount > 0) {
      final setupRoles = players
          .where((p) => p.needsSetup && p.isActive)
          .map((p) => p.role.id)
          .toSet();

      if (setupRoles.contains('clinger')) {
        steps.add(
          const ScriptStep(
            id: 'clinger_obsession',
            title: 'The Clinger - Setup',
            readAloudText:
                'Clinger, open your eyes.\n\nChoose the player you will be obsessed with.\n\nYou will see their role card now.\n\nNow close your eyes.',
            instructionText:
                'Select the partner in the app to reveal their role card.',
            actionType: ScriptActionType.selectPlayer,
            roleId: 'clinger',
          ),
        );
      }

      if (setupRoles.contains('creep')) {
        steps.add(
          const ScriptStep(
            id: 'creep_act',
            title: 'The Creep - Setup',
            readAloudText:
                'Creep, open your eyes.\n\nChoose a player whose role you wish to mimic.\n\nYou will see their role card now.\n\nNow close your eyes.',
            instructionText:
                'Select the target in the app to reveal their role card.',
            actionType: ScriptActionType.selectPlayer,
            roleId: 'creep',
          ),
        );
      }

      if (setupRoles.contains('medic')) {
        steps.add(
          const ScriptStep(
            id: 'medic_setup_choice',
            title: 'The Medic - Setup',
            readAloudText:
                'Medic, open your eyes.\n\nChoose your ability for the rest of the game.\n\nNow close your eyes.',
            instructionText:
                'Select Protect (daily) or Revive (once per game).',
            actionType: ScriptActionType.toggleOption,
            roleId: 'medic',
          ),
        );
      }
    }

    // 2. Identify Active Roles with Night Actions
    // NOTE: Some roles have night interactions even if their nightPriority is 0
    // (e.g., Whore/Wallflower/Ally Cat are woken alongside other roles).
    final Set<Role> activeRoles = {};

    // SETUP NIGHT (Night 0) - Special one-time configurations only.
    // Priority Order: 1. Clinger, 2. Creep, 3. Medic
    // No murder / protection / investigations happen on Night 0.
    if (dayCount == 0) {
      // 1. Clinger - Choose obsession (FIRST)
      final bool hasClinger = players.any((p) => p.role.id == 'clinger');
      if (hasClinger) {
        steps.add(
          const ScriptStep(
            id: 'clinger_obsession',
            title: 'The Clinger - Setup',
            readAloudText:
                'Clinger, open your eyes. Choose the player you will be obsessed with. You will see their role card now.\n\nNow close your eyes.',
            instructionText:
                'Select the partner in the app to reveal their role card.',
            actionType: ScriptActionType.selectPlayer,
            roleId: 'clinger',
          ),
        );
      }

      // 2. Creep - Choose who to mimic (SECOND)
      final bool hasCreep = players.any((p) => p.role.id == 'creep');
      if (hasCreep) {
        steps.add(
          const ScriptStep(
            id: 'creep_act',
            title: 'The Creep - Setup',
            readAloudText:
                'Creep, open your eyes. Choose a player whose role you wish to mimic. You will see their role card now.\n\nNow close your eyes.',
            instructionText:
                'Select the target in the app to reveal their role card.',
            actionType: ScriptActionType.selectPlayer,
            roleId: 'creep',
          ),
        );
      }

      // 3. Medic - Choose protection mode (PROTECT daily OR REVIVE once) (THIRD)
      final bool hasMedic = players.any((p) => p.role.id == 'medic');
      if (hasMedic) {
        steps.add(
          const ScriptStep(
            id: 'medic_setup_choice',
            title: 'The Medic - Setup',
            readAloudText:
                'Medic, open your eyes. Choose your ability for the rest of the game.\n\nNow close your eyes.',
            instructionText:
                'Select Protect (daily) or Revive (once per game).',
            actionType: ScriptActionType.toggleOption,
            roleId: 'medic',
          ),
        );
      }

      // Setup complete - continue to Day 1
      steps.add(
        const ScriptStep(
          id: 'setup_complete',
          title: 'Setup Phase Complete',
          readAloudText: 'Setup is complete. The game begins now.',
          instructionText: 'Proceed to day 1.',
          isNight: true,
        ),
      );

      return steps;
    }

    // --- Catch-up setup for inherited setup-roles (e.g., Creep inheritance) ---
    // If a player becomes a setup-role mid-game, they still need their one-time
    // configuration at the start of the next night.
    final clingerNeedsSetup = players.any(
      (p) =>
          p.isActive &&
          !p.soberSentHome &&
          p.role.id == 'clinger' &&
          p.clingerPartnerId == null,
    );
    if (clingerNeedsSetup) {
      steps.add(
        const ScriptStep(
          id: 'clinger_obsession',
          title: 'The Clinger - Setup',
          readAloudText:
              'Clinger, open your eyes. Choose the player you will be obsessed with. You will see their role card now.\n\nNow close your eyes.',
          instructionText:
              'Select the partner in the app to reveal their role card.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'clinger',
        ),
      );
    }

    final medicNeedsSetup = players.any(
      (p) =>
          p.isActive &&
          !p.soberSentHome &&
          p.role.id == 'medic' &&
          (p.medicChoice == null || p.medicChoice!.isEmpty),
    );
    if (medicNeedsSetup) {
      steps.add(
        const ScriptStep(
          id: 'medic_setup_choice',
          title: 'The Medic - Setup',
          readAloudText:
              'Medic, open your eyes. Choose your ability for the rest of the game.\n\nNow close your eyes.',
          instructionText: 'Select Protect (daily) or Revive (once per game).',
          actionType: ScriptActionType.toggleOption,
          roleId: 'medic',
        ),
      );
    }

    final creepNeedsSetup = players.any(
      (p) =>
          p.isActive &&
          !p.soberSentHome &&
          p.role.id == 'creep' &&
          p.needsSetup,
    );
    if (creepNeedsSetup) {
      steps.add(
        const ScriptStep(
          id: 'creep_act',
          title: 'The Creep - Setup',
          readAloudText:
              'Creep, open your eyes. Choose a player whose role you wish to mimic. You will see their role card now.\n\nNow close your eyes.',
          instructionText:
              'Select the target in the app to reveal their role card.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'creep',
        ),
      );
    }

    for (var p in players) {
      if (!p.isActive) continue;
      if (p.soberSentHome) continue; // Skip players sent home by Sober

      // One-time abilities: once used, don't keep waking them.
      if (p.role.id == 'sober' && p.soberAbilityUsed) continue;

      // Clinger: only acts at night when freed as Attack Dog.
      if (p.role.id == 'clinger') {
        if (p.clingerFreedAsAttackDog && !p.clingerAttackDogUsed) {
          activeRoles.add(p.role);
        }
        continue;
      }

      if (p.role.id == 'whore') {
        // Whore is integrated into Dealer steps; no standalone wake needed.
        continue;
      }

      // Include roles that have Night Priority > 0.
      // Reactive roles (Tea Spiller, Predator, Drama Queen) share Priority 0 and shouldn't run automatically.
      // Lightweight (Priority 0) DOES need to run every night for the Taboo logic.

      if (p.role.nightPriority > 0 || p.role.id == 'lightweight') {
        activeRoles.add(p.role);
      }
    }

    // Sort by priority
    final List<Role> sortedRoles = activeRoles.toList()
      ..sort((a, b) => a.nightPriority.compareTo(b.nightPriority));

    // Find Creep Target Role
    String? creepTargetRoleId;
    try {
      final creep = players.firstWhere((p) => p.role.id == 'creep');
      if (creep.creepTargetId != null) {
        final target = players.firstWhere((p) => p.id == creep.creepTargetId);
        creepTargetRoleId = target.role.id;
      }
    } catch (_) {}

    // Deduplicate by ID
    final roleIdsProcessed = <String>{};

    // Roles that are handled as part of other turns (no standalone wake needed)
    // Whore wakes with Dealers. Wallflower wakes with Dealers. Ally Cat wakes with Bouncer.
    // Silver Fox needs their own specific wake time.
    const integratedRoleIds = {'whore', 'ally_cat', 'wallflower'};

    // NIGHT ACTION PRIORITY ORDER (Night 1+):
    // 1. Sober (send someone home - affects who wakes)
    // 2. Dealer (kill target selection + Whore + Wallflower)
    // 3. Bouncer (ID check + Ally Cat)
    // 4. Medic (protection - if chose PROTECT mode)
    // 5. All other roles by their nightPriority (or 0 priority handling)
    // 6. Silver Fox (Alibi) ALWAYS goes last after all other actions
    const nightActionPriorityRoleIds = [
      'sober',
      'dealer',
      'bouncer',
      'medic',
    ];

    // Build ordered role list with strict priority.
    // Silver Fox is explicitly appended at the end so their alibi resolves last.
    final orderedRoles = <Role>[];
    for (final priorityId in nightActionPriorityRoleIds) {
      Role? role;
      try {
        role = sortedRoles.firstWhere((r) => r.id == priorityId);
        orderedRoles.add(role);
      } catch (_) {}
    }
    // Add remaining roles (not in priority list, and not Silver Fox)
    for (final r in sortedRoles) {
      if (nightActionPriorityRoleIds.contains(r.id)) continue;
      if (r.id == 'silver_fox') continue;
      orderedRoles.add(r);
    }
    // Finally, Silver Fox goes last (if present)
    try {
      final silverFox = sortedRoles.firstWhere((r) => r.id == 'silver_fox');
      orderedRoles.add(silverFox);
    } catch (_) {}

    for (var role in orderedRoles) {
      if (roleIdsProcessed.contains(role.id)) continue;
      roleIdsProcessed.add(role.id);

      if (integratedRoleIds.contains(role.id)) continue;

      final bool isCreepTarget = (role.id == creepTargetRoleId);

      // Skip Bouncer if their ability has been revoked (only one Bouncer exists)
      if (role.id == 'bouncer') {
        final bouncer = players
            .where((p) => p.isActive && p.role.id == 'bouncer')
            .firstOrNull;
        if (bouncer != null && bouncer.bouncerAbilityRevoked) {
          continue;
        }
      }

      // Skip Roofi if their ability has been revoked
      if (role.id == 'roofi') {
        final activeRoofi =
            players.where((p) => p.isActive && p.role.id == 'roofi').toList();
        if (activeRoofi.isNotEmpty &&
            activeRoofi.every((p) => p.roofiAbilityRevoked)) {
          final bouncerWithStolen = players.any(
            (p) =>
                p.isActive &&
                p.role.id == 'bouncer' &&
                p.bouncerHasRoofiAbility,
          );
          if (!bouncerWithStolen) {
            continue;
          }
        }
      }

      if (role.id == 'dealer') {
        steps.addAll(
          _buildDealerSteps(
            players,
            isCreepTarget: isCreepTarget,
            dayCount: dayCount,
          ),
        );
      } else if (role.id == 'medic') {
        steps.addAll(_buildMedicSteps(players));
      } else if (role.id == 'bouncer') {
        steps.addAll(
          _buildBouncerSteps(
            players,
            isCreepTarget: isCreepTarget,
            dayCount: dayCount,
          ),
        );
      } else if (role.id == 'roofi') {
        final activeRoofi =
            players.where((p) => p.isActive && p.role.id == 'roofi').toList();
        final allRevoked = activeRoofi.isNotEmpty &&
            activeRoofi.every((p) => p.roofiAbilityRevoked);
        if (allRevoked) {
          steps.addAll(
            _buildBouncerStolenRoofiSteps(
              players,
              isCreepTarget: isCreepTarget,
            ),
          );
        } else {
          steps.addAll(
            _buildRoleSteps(role, players, isCreepTarget: isCreepTarget),
          );
        }
      } else {
        steps.addAll(
          _buildRoleSteps(role, players, isCreepTarget: isCreepTarget),
        );
      }
    }

    return steps;
  }

  static List<ScriptStep> buildDayScript(
    int dayCount,
    String morningAnnouncement, [
    List<Player> players = const [],
  ]) {
    final daySteps = <ScriptStep>[];

    // Day phase is handled inside DaySceneDialog.
    // We use a single launcher step + a hidden vote marker to align with GameScreen.
    daySteps.add(
      ScriptStep(
        id: 'day_start_discussion_$dayCount',
        title: 'The club is closed',
        readAloudText:
            "The Club is closed. It's time to go the fuck home—clean yourselves up, have a coffee, because there's some shit we need to discuss. Open your eyes.\n\n$morningAnnouncement",
        instructionText:
            'Read the bulletin aloud, then tap NEXT to open the day phase screen.',
        isNight: false,
        actionType: ScriptActionType.showDayScene,
      ),
    );

    // Marker only (hidden in GameScreen). Voting runs inside the day dialog.
    daySteps.add(
      const ScriptStep(
        id: 'day_vote',
        title: 'The Vote',
        readAloudText: '',
        instructionText: '',
        isNight: false,
        actionType: ScriptActionType.none,
      ),
    );

    return daySteps;
  }

  static List<ScriptStep> _buildDealerSteps(
    List<Player> players, {
    bool isCreepTarget = false,
    int dayCount = 0,
  }) {
    // Dealers always wake up even if blocked by Roofi; the kill fails in-engine.

    final String creepText = isCreepTarget ? ' (and The Creep)' : '';

    final hasWhore = players.any(
      (p) =>
          p.isActive &&
          !p.soberSentHome &&
          p.role.id == 'whore' &&
          p.whoreDeflectionTargetId == null &&
          !p.whoreDeflectionUsed,
    );

    // Check if any Dealer was sent home by the Sober (cancels murders tonight).
    final anyDealerSentHome = players.any(
      (p) => p.role.id == 'dealer' && p.soberSentHome,
    );

    // Wallflower only needs to be woken on nights where murders can occur.
    final hasWallflower = !anyDealerSentHome &&
        players.any(
          (p) => p.isActive && !p.soberSentHome && p.role.id == 'wallflower',
        );

    final wakeExtras = <String>[];
    if (hasWhore) wakeExtras.add('Whore');
    if (hasWallflower) wakeExtras.add('Wallflower');

    final wakeText = wakeExtras.isEmpty
        ? 'Dealers$creepText, open your eyes.'
        : "Dealers$creepText, ${wakeExtras.join(', ')}, open your eyes.";
    final finalSteps = <ScriptStep>[];

    // Second Wind conversion choice is injected by the engine (next-night, host-only).

    if (anyDealerSentHome) {
      finalSteps.add(
        ScriptStep(
          id: 'dealer_kill_blocked',
          title: 'Dealers - Kill Blocked',
          readAloudText:
              '$wakeText\n\nA Dealer was sent home. There will be NO MURDERS tonight.'
              '${hasWhore ? "" : "\n\nNow close your eyes."}',
          instructionText: 'Wait a beat, then continue.',
          actionType: ScriptActionType.showInfo,
          roleId: 'dealer',
        ),
      );
    } else {
      // Standard Wake + Kill
      String actionText = 'Dealers$creepText, choose a player to kill.';
      if (hasWallflower && dayCount == 1) {
        actionText =
            'Wallflower, if you wish to witness the murders, you may keep your eyes open.\n\n$actionText';
      }

      finalSteps.add(
        ScriptStep(
          id: 'dealer_act',
          title: 'The Party Crashers',
          readAloudText: '$wakeText\n\n$actionText'
              '${(!hasWhore && !hasWallflower) ? "\n\nNow close your eyes." : ""}',
          instructionText:
              'Wait for the Dealers to agree, then select the target in the app.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'dealer',
        ),
      );
    }

    if (hasWhore) {
      final shouldCloseAfterWhore = !hasWallflower || anyDealerSentHome;
      finalSteps.add(
        ScriptStep(
          id: 'whore_deflect',
          title: 'The Whore',
          readAloudText:
              'Whore, you may choose on any night to pick your bitch. If you point to someone, I will stop asking you after tonight — so choose wisely.\n\nIf you or a Dealer is voted out tomorrow, your bitch will take the fall instead.'
              '${shouldCloseAfterWhore ? "\n\nNow close your eyes." : ""}',
          instructionText:
              'If the Whore points to someone, select that player (alive, not the Whore, not a Dealer). If she does not point to anyone, just tap NEXT to continue.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'whore',
        ),
      );
    }

    if (hasWallflower && !anyDealerSentHome) {
      finalSteps.add(
        const ScriptStep(
          id: 'wallflower_act',
          title: 'Witness Murder (Optional)',
          readAloudText: 'Dealers, Whore, and Wallflower, close your eyes.',
          instructionText:
              'Tap PEEK, STARE, or SKIP. Then Dealers, Whore, and Wallflower close eyes.',
          actionType: ScriptActionType.toggleOption,
          roleId: 'wallflower',
        ),
      );
    }

    return finalSteps;
  }

  static List<ScriptStep> _buildMedicSteps(List<Player> players) {
    // Find the medic and check their permanent choice from Night 0
    final medic =
        players.where((p) => p.role.id == 'medic' && p.isActive).firstOrNull;
    if (medic == null) return [];

    final medicMode = medic.medicChoice ?? 'PROTECT_DAILY';
    final hasUsedRevive = medic.reviveUsed;

    // If they chose REVIVE and already used it, they don't wake anymore.
    if (medicMode == 'REVIVE' && hasUsedRevive) {
      return [];
    }

    // Medic wakes every night to use their chosen ability.
    // Terminology is neutral to avoid divulging the medic's choice to other players
    // who might be eavesdropping on the Host's voice.
    return const [
      ScriptStep(
        id: 'medic_act',
        title: 'The Medic',
        readAloudText:
            'Medic, open your eyes. Select a player to use your ability on tonight.\n\nNow close your eyes.',
        instructionText:
            'If you chose Protect: the target is safe tonight. If you chose Revive: you can revive one player who died tonight (once per game).',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'medic',
      ),
    ];
  }

  static List<ScriptStep> _buildBouncerSteps(
    List<Player> players, {
    bool isCreepTarget = false,
    int dayCount = 0,
  }) {
    final bouncer =
        players.where((p) => p.isActive && p.role.id == 'bouncer').firstOrNull;
    if (bouncer != null && bouncer.bouncerAbilityRevoked) {
      return const [];
    }
    final hasAllyCat = players.any(
      (p) => p.isActive && p.role.id == 'ally_cat',
    );
    final allyText = hasAllyCat ? ' and Ally Cat' : '';
    final creepText = isCreepTarget ? ' (and The Creep)' : '';
    final showAllyCatMeow = hasAllyCat && dayCount == 1;

    return [
      ScriptStep(
        id: 'bouncer_act',
        title: 'The ID Check',
        readAloudText: 'Bouncer$creepText$allyText, open your eyes. '
            'Bouncer, select a player to I.D.'
            '${showAllyCatMeow ? "" : "\n\nNow close your eyes."}',
        instructionText: 'Nod for Dealer. Shake your head for not Dealer.',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'bouncer',
      ),
      // ALLY CAT - Meow Communication (can only communicate via 'meow') - Only on Night 1
      if (showAllyCatMeow)
        const ScriptStep(
          id: 'ally_cat_meow',
          title: 'The Ally Cat - Meow Communication',
          readAloudText:
              'Ally Cat, you can only communicate your findings with meows.\n\nNow close your eyes.',
          instructionText:
              'Remind the Ally Cat they can only say \'meow\' to communicate their findings.',
          actionType: ScriptActionType.showInfo,
          roleId: 'ally_cat',
        ),
    ];
  }

  // ignore: unused_element
  static List<ScriptStep> _buildBouncerStolenRoofiSteps(
    List<Player> players, {
    bool isCreepTarget = false,
  }) {
    final bouncer =
        players.where((p) => p.isActive && p.role.id == 'bouncer').firstOrNull;
    if (bouncer == null || !bouncer.bouncerHasRoofiAbility) {
      return const [];
    }

    final creepText = isCreepTarget ? ' (and The Creep)' : '';
    return [
      ScriptStep(
        id: 'bouncer_roofi_act',
        title: 'Stolen Roofi Powers',
        readAloudText:
            'Bouncer$creepText, open your eyes.\n\nSelect a player to paralyze.\n\nNow close your eyes.',
        instructionText:
            'The selected player is silenced for the next day. If they are the only Dealer, they are also blocked next night.',
        actionType: ScriptActionType.selectPlayer,
        roleId: 'roofi',
      ),
    ];
  }

  static List<ScriptStep> _buildRoleSteps(
    Role role,
    List<Player> players, {
    bool isCreepTarget = false,
  }) {
    String abilityDescription = role.ability ?? 'Perform your action.';
    abilityDescription = abilityDescription.replaceAll('_', ' ');
    final String creepText = isCreepTarget ? ' (and The Creep)' : '';

    final List<ScriptStep> steps = [];

    // Combine wake + action into single step for most roles
    // Special ability handling based on role
    if (role.id == 'club_manager') {
      steps.add(
        ScriptStep(
          id: 'club_manager_act',
          title: 'View Role Card',
          readAloudText:
              "Club Manager$creepText, open your eyes. Choose one player's role card to view.\n\nNow close your eyes.",
          instructionText:
              "Reveal the selected player's role card on screen, then continue.",
          actionType: ScriptActionType.selectPlayer,
          roleId: 'club_manager',
        ),
      );
    } else if (role.id == 'sober') {
      steps.add(
        ScriptStep(
          id: 'sober_act',
          title: 'Send Someone Home',
          readAloudText:
              'Sober$creepText, open your eyes. Choose one player to send home tonight. They are safe from all night actions.\n\nNow close your eyes.',
          instructionText:
              'Sent-home players do not act tonight. If a Dealer is sent home, there are no murders tonight.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'sober',
        ),
      );
    } else if (role.id == 'silver_fox') {
      steps.add(
        ScriptStep(
          id: 'silver_fox_act',
          title: 'Alibi',
          readAloudText:
              'Silver Fox$creepText, open your eyes. Choose one player to receive an alibi. They cannot be voted out tomorrow.\n\nNow close your eyes.',
          instructionText:
              'Tomorrow, ignore votes against the selected player.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'silver_fox',
        ),
      );
    } else if (role.id == 'messy_bitch') {
      steps.add(
        ScriptStep(
          id: 'messy_bitch_act',
          title: 'Spread Rumour',
          readAloudText:
              'Messy Bitch$creepText, open your eyes. Select a player to spread a rumour to.\n\nNow close your eyes.',
          instructionText:
              'Mark the selected player as having heard a rumour. Messy Bitch wins when every other living player has heard one.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'messy_bitch',
        ),
      );
    } else if (role.id == 'roofi') {
      steps.add(
        ScriptStep(
          id: 'roofi_act',
          title: 'Paralyze',
          readAloudText:
              'Roofi$creepText, open your eyes. Select a player to paralyze.\n\nNow close your eyes.',
          instructionText:
              'The selected player is silenced for the next day. If they are the only Dealer, they are also blocked next night.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'roofi',
        ),
      );
    } else if (role.id == 'clinger') {
      try {
        final clinger = players.firstWhere(
          (p) => p.role.id == 'clinger' && p.isActive,
        );
        if (clinger.clingerFreedAsAttackDog && !clinger.clingerAttackDogUsed) {
          // CLINGER - Attack Dog ability (only if freed from obsession)
          steps.add(
            ScriptStep(
              id: 'clinger_act',
              title: 'Attack Dog Ability',
              readAloudText:
                  'Clinger$creepText, open your eyes. You have been freed. Choose one player to kill.\n\nNow close your eyes.',
              instructionText:
                  'Only available if the Clinger was freed earlier. Selecting a target kills them immediately.',
              actionType: ScriptActionType.selectPlayer,
              roleId: 'clinger',
            ),
          );
        }
      } catch (e) {
        // No clinger found or other error, do nothing
      }
      /* Predator step removed - they choose at the moment of voting
    } else if (role.id == 'predator') {
      steps.add(
        ScriptStep(
          id: 'predator_act',
          title: 'Mark for Retaliation',
          readAloudText:
              'Predator$creepText, open your eyes.\n\nMark a player. If you are voted out, this player will die with you.\n\nPredator$creepText, close your eyes.',
          instructionText:
              'They choose a target for their potential retaliation.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'predator',
        ),
      );
    */
    } else if (role.id == 'lightweight') {
      steps.add(
        ScriptStep(
          id: 'lightweight_act',
          title: 'New Taboo Name',
          readAloudText:
              'Lightweight$creepText, open your eyes. Look at the player the host points to. You can no longer say their name. Nod if you understand.\n\nNow close your eyes.',
          instructionText:
              'Point to a player in real life, then select that player in the app to set the taboo name.',
          actionType: ScriptActionType.selectPlayer,
          roleId: 'lightweight',
        ),
      );
    } else if (role.id == 'drama_queen') {
      steps.add(
        ScriptStep(
          id: 'drama_queen_act',
          title: 'Mark for Role Swap',
          readAloudText:
              'Drama Queen$creepText, open your eyes. Select two players. If you die tonight, their roles will be swapped.\n\nNow close your eyes.',
          instructionText: 'Select two players to mark them for the swap.',
          actionType: ScriptActionType.selectTwoPlayers,
          roleId: 'drama_queen',
        ),
      );
    } else if (role.id == 'bartender') {
      steps.add(
        ScriptStep(
          id: 'bartender_act',
          title: 'Mixology Check',
          readAloudText:
              'Bartender$creepText, open your eyes. Select two players. You will learn if they are on the same team or different teams.\n\nNow close your eyes.',
          instructionText:
              'Select two players. The result is shown to the host only.',
          actionType: ScriptActionType.selectTwoPlayers,
          roleId: 'bartender',
        ),
      );
    } else {
      // Default ability handling - combine wake, action, and sleep
      // Most roles target one player, but some need two (e.g., Drama Queen swap)
      final actionType = role.id == 'drama_queen'
          ? ScriptActionType.selectTwoPlayers
          : ScriptActionType.selectPlayer;

      steps.add(
        ScriptStep(
          id: '${role.id}_act',
          title: role.name,
          readAloudText:
              '${role.name}$creepText, open your eyes.\n\nPerform your action now.\n\nNow close your eyes.',
          instructionText: 'Select the target in the app, then continue.',
          actionType: actionType,
          roleId: role.id,
        ),
      );
    }

    return steps;
  }
}

// Add at bottom of file (or near top after imports)
extension _FirstOrNullX<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
