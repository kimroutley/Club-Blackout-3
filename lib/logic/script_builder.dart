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
  /// - Messy Bitch special kill added if she reaches win condition
  /// - Morning report shows results when all night actions complete
  ///
  /// **Late Joiners:**
  /// - Join as "inactive" and become active on next night transition
  /// - Participate in night actions once activated
  ///
  /// Returns a list of [ScriptStep] objects to be executed in sequence.
  static List<ScriptStep> buildNightScript(List<Player> players, int dayCount) {
    List<ScriptStep> steps = [];

    // 1. Start Phase
    // For Night 0, we skip the standard "Close Eyes" because Intro (Party Time) handles it.
    if (dayCount > 1) {
      steps.add(const ScriptStep(
        id: 'night_start',
        title: 'Night Phase',
        readAloudText: "Everyone, close your eyes.",
        instructionText: "Ensure all players have their eyes closed.",
        isNight: true,
      ));
    }

    // 2. Identify Active Roles with Night Actions
    // NOTE: Some roles have night interactions even if their nightPriority is 0
    // (e.g., Whore/Wallflower/Ally Cat are woken alongside other roles).
    Set<Role> activeRoles = {};
    
    // Check for Messy Bitch special kill (after win condition, before used)
    Player? messyBitchWithKill;
    try {
      final messyBitch = players.firstWhere((p) => p.role.id == 'messy_bitch' && p.isAlive);
      final others = players.where((p) => p.id != messyBitch.id && p.isAlive).toList();
      final hasWonCondition = others.isNotEmpty && others.every((p) => p.hasRumour);
      
      if (hasWonCondition && !messyBitch.messyBitchKillUsed) {
        messyBitchWithKill = messyBitch;
      }
    } catch (_) {}

    // SETUP NIGHT (Night 0) - Special one-time configurations only.
    // Priority Order: 1. Clinger, 2. Creep, 3. Medic
    // No murder / protection / investigations happen on Night 0.
    if (dayCount == 0) {
      // 1. Clinger - Choose obsession (FIRST)
      bool hasClinger = players.any((p) => p.role.id == 'clinger');
      if (hasClinger) {
        steps.add(const ScriptStep(
            id: 'clinger_obsession',
            title: 'The Clinger - Setup',
            readAloudText: "Clinger, open your eyes.\n\nChoose the player you wish to be obsessed with.",
            instructionText: "This player becomes your partner. You must vote exactly as they vote. If they die, you die. Write down their choice.",
            actionType: ScriptActionType.selectPlayer,
            roleId: 'clinger',
        ));
        steps.add(const ScriptStep(
            id: 'clinger_reveal',
            title: 'Show Partner Role Card',
            readAloudText: "Clinger, you will now see your obsession's role card.\n\nClinger, close your eyes.",
            instructionText: "Show the Clinger their obsession's role card for 10 seconds so they can mimic their partner's behavior. Then they close eyes.",
            actionType: ScriptActionType.showInfo,
            roleId: 'clinger',
        ));
      }
      
      // 2. Creep - Choose who to mimic (SECOND)
      bool hasCreep = players.any((p) => p.role.id == 'creep');
      if (hasCreep) {
        steps.add(const ScriptStep(
            id: 'creep_act',
            title: 'The Creep - Setup',
            readAloudText: "Creep, open your eyes.\n\nChoose a player whose role you wish to mimic.",
            instructionText: "Wait for them to point. You will inherit this player's role if that player dies. Write down their choice.",
            actionType: ScriptActionType.selectPlayer,
            roleId: 'creep',
        ));
        steps.add(const ScriptStep(
            id: 'creep_reveal',
            title: 'Show Target Role Card',
            readAloudText: "Creep, you will now see your target's role card.\n\nCreep, close your eyes.",
            instructionText: "Show the Creep their target's role card for 10 seconds so they can learn how to pretend to be that role. Then they close eyes.",
            actionType: ScriptActionType.showInfo,
            roleId: 'creep',
        ));
      }

      // 3. Medic - Choose protection mode (PROTECT daily OR REVIVE once) (THIRD)
      bool hasMedic = players.any((p) => p.role.id == 'medic');
      if (hasMedic) {
        steps.add(const ScriptStep(
            id: 'medic_setup_choice',
            title: 'The Medic - Setup',
            readAloudText: "Medic, open your eyes.\n\nYou must choose now: Option 1 (PROTECT daily) or Option 2 (REVIVE once). Signal your choice with a nod or shake.\n\nMedic, close your eyes.",
            instructionText: "PROTECT: You protect one player each night. REVIVE: You can revive one dead player once per game. Write down their choice. Then they close eyes.",
            actionType: ScriptActionType.toggleOption,
            roleId: 'medic',
        ));
      }
      
      // Setup complete - continue directly into Night 1 (eyes stay closed)
      steps.add(const ScriptStep(
        id: 'setup_complete',
        title: 'Setup Phase Complete',
        readAloudText: "Setup is complete. Night 1 begins now. Keep your eyes closed.",
        instructionText: "Transitioning directly to standard night actions.",
        isNight: true,
      ));
      
      return steps;
    }

    for (var p in players) {
      if (!p.isActive) continue;
      if (p.soberSentHome) continue; // Skip players sent home by Sober
      if (p.role.id == 'whore' || p.role.id == 'silver_fox') continue; // Temporarily disabled per host request
      
      // Include roles that have Night Priority > 0.
      // Reactive roles (Tea Spiller, Predator, Drama Queen) share Priority 0 and shouldn't run automatically.
      // Lightweight (Priority 0) DOES need to run every night for the Taboo logic.
      
      if (p.role.nightPriority > 0 || p.role.id == 'lightweight') {
        activeRoles.add(p.role);
      }
    }

    // Sort by priority
    List<Role> sortedRoles = activeRoles.toList()
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
    // 2. Silver Fox (Force Reveal - happens start of night)
    // 3. Dealer (kill target selection + Whore + Wallflower)
    // 4. Bouncer (ID check + Ally Cat)
    // 5. Medic (protection - if chose PROTECT mode)
    // 6. All other roles by their nightPriority (or 0 priority handling)
    const nightActionPriorityRoleIds = ['sober', 'dealer', 'bouncer', 'medic'];

    // Build ordered role list with strict priority
    final orderedRoles = <Role>[];
    for (final priorityId in nightActionPriorityRoleIds) {
      Role? role;
      try {
        role = sortedRoles.firstWhere((r) => r.id == priorityId);
        orderedRoles.add(role);
      } catch (_) {}
    }
    // Add remaining roles (not in priority list)
    for (final r in sortedRoles) {
      if (nightActionPriorityRoleIds.contains(r.id)) continue;
      orderedRoles.add(r);
    }

    for (var role in orderedRoles) {
      if (roleIdsProcessed.contains(role.id)) continue;
      roleIdsProcessed.add(role.id);

      if (integratedRoleIds.contains(role.id)) continue;

      bool isCreepTarget = (role.id == creepTargetRoleId);

      // Skip Bouncer if their ability has been revoked (only one Bouncer exists)
      if (role.id == 'bouncer') {
        final bouncer = players.where((p) => p.isActive && p.role.id == 'bouncer').firstOrNull;
        if (bouncer != null && bouncer.bouncerAbilityRevoked) {
          continue;
        }
      }

      // Skip Roofi if their ability has been revoked
      if (role.id == 'roofi') {
        final activeRoofi = players.where((p) => p.isActive && p.role.id == 'roofi').toList();
        if (activeRoofi.isNotEmpty && activeRoofi.every((p) => p.roofiAbilityRevoked)) {
          continue;
        }
      }

      // MESSY BITCH SPECIAL KILL: Replace standard spread action if available
      // The Messy Bitch has reached her win condition and can choose to use her
      // one-time kill ability instead of spreading rumours.
      if (role.id == 'messy_bitch' && messyBitchWithKill != null) {
          steps.addAll([
            ScriptStep(
              id: 'messy_bitch_special_wake',
              title: 'Messy Bitch Special Kill',
              readAloudText: "Messy Bitch, open your eyes.",
              instructionText: "The Messy Bitch has reached her win condition and can now kill someone directly (one time only).",
              roleId: 'messy_bitch_kill',
            ),
            ScriptStep(
              id: 'messy_bitch_special_kill',
              title: 'Eliminate Target',
              readAloudText: "Choose someone to eliminate.",
              instructionText: "This is a one-time ability after reaching her win condition. If you choose not to use it, you pass.",
              actionType: ScriptActionType.selectPlayer,
              roleId: 'messy_bitch_kill',
            ),
            ScriptStep(
              id: 'messy_bitch_special_sleep',
              title: 'Messy Bitch Returns',
              readAloudText: "Messy Bitch, close your eyes.",
              instructionText: "",
              roleId: 'messy_bitch_kill',
            ),
          ]);
          continue;
      }

      if (role.id == 'dealer') {
        steps.addAll(_buildDealerSteps(players, isCreepTarget: isCreepTarget, dayCount: dayCount));
      } else if (role.id == 'medic') {
        steps.addAll(_buildMedicSteps(players));
      } else if (role.id == 'bouncer') {
        steps.addAll(_buildBouncerSteps(players, isCreepTarget: isCreepTarget, dayCount: dayCount));
      } else {
        steps.addAll(_buildRoleSteps(role, players, isCreepTarget: isCreepTarget));
      }
    }

    // 3. End Night - Everyone Opens Eyes
    steps.add(const ScriptStep(
      id: 'night_complete_wake',
      title: 'Night Complete',
      readAloudText: "Everyone, open your eyes.",
      instructionText: "All night actions are complete. The night is over.",
      isNight: true,
    ));
    
    // 4. Transition to Day Phase
    steps.add(const ScriptStep(
      id: 'night_end',
      title: 'Morning Arrives',
      readAloudText: "The night is over. Prepare for the morning summary.",
      instructionText: "Night summary and voting will begin next.",
      isNight: false,
    ));

    return steps;
  }

  static List<ScriptStep> buildDayScript(int dayCount, String morningAnnouncement, [List<Player> players = const []]) {
    final daySteps = <ScriptStep>[
       ScriptStep(
        id: 'phase_transition_day',
        title: 'DAY BREAKS',
        readAloudText: '',
        instructionText: '',
        actionType: ScriptActionType.phaseTransition,
        isNight: false,
      ),
    ];
    
    // Check for Second Wind Pending Conversion - Add prompt if pending
    if (players.any((p) => p.secondWindPendingConversion && !p.secondWindConverted)) {
       daySteps.add(ScriptStep(
        id: 'second_wind_decision',
        title: 'SECOND WIND DECISION',
        readAloudText: "Dealers, I have secret information regarding your victim... I will now approach you for a decision.",
        instructionText: "Approach the Dealers. Ask them secretly if they wish to convert The Second Wind instead of killing them. Show them the options on screen.",
        isNight: false,
        actionType: ScriptActionType.binaryChoice,
        roleId: 'second_wind',
      ));
    }
    
    daySteps.add(ScriptStep(
      id: 'day_start_discussion_$dayCount',
      title: 'Open Discussion',
      readAloudText: "Now begins the discussion. Who do you think is who? Make your case.",
      instructionText: "Players may now discuss the game, argue theories, and reveal information strategically.",
      isNight: false,
      actionType: ScriptActionType.discussion,
    ));
    
    return daySteps;
  }

  static List<ScriptStep> _buildDealerSteps(List<Player> players, {bool isCreepTarget = false, int dayCount = 0}) {
    // If only one Dealer is alive and that Dealer is stopped by Roofi/Logic, skip murder
    // Note: The 'sober' logic is handled dynamically in GameEngine by replacing these steps if a Dealer is sent home.
    final aliveDealers = players.where((p) => p.isActive && p.role.id == 'dealer').toList();
    if (aliveDealers.length == 1) {
      final d = aliveDealers.first;
      if (d.blockedKillNight == dayCount) {
        return const [
          ScriptStep(
            id: 'dealer_blocked',
            title: 'The Party Crashers',
            readAloudText: "Dealers, remain asleep tonight.",
            instructionText: "The only Dealer is incapacitated and cannot act tonight.",
            actionType: ScriptActionType.showInfo,
            roleId: 'dealer',
          ),
        ];
      }
    }
    String creepText = isCreepTarget ? " (and The Creep)" : "";

    final hasWhore = players.any((p) => p.isActive && p.role.id == 'whore');
    final hasWallflower = players.any((p) => p.isActive && p.role.id == 'wallflower');

    final wakeExtras = <String>[];
    if (hasWhore) wakeExtras.add('Whore');
    if (hasWallflower) wakeExtras.add('Wallflower');

    final wakeText = wakeExtras.isEmpty
        ? "Dealers$creepText, open your eyes."
        : "Dealers$creepText, ${wakeExtras.join(', ')}, open your eyes.";

    final sleepExtras = <String>[];
    if (hasWhore) sleepExtras.add('Whore');
    if (hasWallflower) sleepExtras.add('Wallflower');
    final sleepText = sleepExtras.isEmpty
        ? "Dealers$creepText, close your eyes."
        : "Dealers$creepText, ${sleepExtras.join(', ')}, close your eyes.";
    return [
      ScriptStep(
        id: 'dealer_act',
        title: 'The Party Crashers',
        readAloudText: "$wakeText\n\nDealers$creepText, choose who to kill.",
        instructionText: "Wait for them to acknowledge, then wait for a consensus pointing.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'dealer',
      ),
      // SECOND WIND - Conversion Voting (only if Second Wind was killed)
      if (players.any((p) => p.role.id == 'second_wind' && p.secondWindPendingConversion))
        ScriptStep(
          id: 'second_wind_conversion_vote',
          title: 'Second Wind Conversion Decision',
          readAloudText: "Dealers, The Second Wind has been killed. Do you wish to convert her to become one of you? She will revive as a Dealer, and no one else will die tonight. Vote now: consensus nod if YES, shake head if NO.",
          instructionText: "The Dealers vote together on whether to convert The Second Wind. If majority agree (consensus or show of hands), she converts and revives. If they decline, she stays dead.",
          actionType: ScriptActionType.toggleOption,
          roleId: 'dealer',
        ),
      ScriptStep(
        id: 'dealer_sleep',
        title: 'Dealers Sleep',
        readAloudText: sleepText,
        instructionText: "",
        roleId: 'dealer',
      ),
      // WHORE - Deflection Setup (Happens right after Dealers sleep or during their wake)
      // Since Whore wakes with Dealers, we can add a specific step for her here OR after.
      // To keep it clean, let's allow her to signal her choice just as Dealers go to sleep 
      // or effectively immediately after.
      if (hasWhore)
        ScriptStep(
          id: 'whore_deflect',
          title: 'The Whore - Deflection',
          readAloudText: "Whore, stay awake for a moment.\n\nPoint to a player. If you or a Dealer are voted out tomorrow, this player will die instead.",
          instructionText: "Wait for the Whore to point to a deflection target. Then they close eyes.",
          actionType: ScriptActionType.selectPlayer,
          roleId: 'whore',
        ),
    ];
  }

  static List<ScriptStep> _buildMedicSteps(List<Player> players) {
    // Find the medic and check their permanent choice from Night 0
    final medic = players.where((p) => p.role.id == 'medic' && p.isActive).firstOrNull;
    
    // Only wake medic if they chose PROTECT_DAILY at setup
    // If they chose REVIVE, they don't wake at night (revive happens during day phase)
    if (medic == null || medic.medicChoice != 'PROTECT_DAILY') {
      return [];
    }
    
    // Medic wakes every night to protect someone
    return const [
      ScriptStep(
        id: 'medic_protect',
        title: 'The Medic - Protect',
        readAloudText: "Medic, open your eyes.\n\nSelect a player to protect tonight.",
        instructionText: "Choose any living player (including yourself) to protect from death tonight. This player cannot be killed by Dealers.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'medic',
      ),
      ScriptStep(
        id: 'medic_sleep',
        title: 'Medic Sleep',
        readAloudText: "Medic, close your eyes.",
        instructionText: "Protection has been recorded. Medic closes eyes.",
        roleId: 'medic',
      ),
    ];
  }

  static List<ScriptStep> _buildBouncerSteps(List<Player> players, {bool isCreepTarget = false, int dayCount = 0}) {
    final bouncer = players.where((p) => p.isActive && p.role.id == 'bouncer').firstOrNull;
    if (bouncer != null && bouncer.bouncerAbilityRevoked) {
      return const [];
    }
    final hasAllyCat = players.any((p) => p.isActive && p.role.id == 'ally_cat');
    final allyText = hasAllyCat ? " and Ally Cat" : "";
    final creepText = isCreepTarget ? " (and The Creep)" : "";
    return [
      ScriptStep(
        id: 'bouncer_act',
        title: 'The ID Check',
        readAloudText: "Bouncer$creepText$allyText, open your eyes.\n\nBouncer, select a player to I.D.",
        instructionText: "Nod if Dealer. Shake head if not. If you I.D. The Minor, she becomes vulnerable to being killed later.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'bouncer',
      ),
      // ALLY CAT - Meow Communication (can only communicate via 'meow') - Only on Night 1
      if (hasAllyCat && dayCount == 1)
        ScriptStep(
          id: 'ally_cat_meow',
          title: 'The Ally Cat - Meow Communication',
          readAloudText: "Ally Cat, you can only communicate your findings with meows.",
          instructionText: "Remind the Ally Cat they can only say 'meow' to communicate their findings.",
          actionType: ScriptActionType.showInfo,
          roleId: 'ally_cat',
        ),
      ScriptStep(
        id: 'bouncer_sleep',
        title: 'The ID Check',
        readAloudText: "Bouncer$creepText$allyText, close your eyes.",
        instructionText: "",
        roleId: 'bouncer',
      ),
    ];
  }

  static List<ScriptStep> _buildRoleSteps(Role role, List<Player> players, {bool isCreepTarget = false}) {
    String abilityDescription = role.ability ?? "Perform your action.";
    abilityDescription = abilityDescription.replaceAll('_', ' ');
    String creepText = isCreepTarget ? " (and The Creep)" : "";

    List<ScriptStep> steps = [];

    // Combine wake + action into single step for most roles
    // Special ability handling based on role
    if (role.id == 'club_manager') {
      steps.add(ScriptStep(
        id: 'club_manager_act',
        title: 'View Role Card',
        readAloudText: "Club Manager$creepText, open your eyes.\\n\\nChoose one player's role card to view.\\n\\nClub Manager$creepText, close your eyes.",
        instructionText: "Show them the selected player's character card, then they close eyes.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'club_manager',
      ));
    } else if (role.id == 'wallflower') {
      steps.add(ScriptStep(
        id: 'wallflower_act',
        title: 'Witness Murder',
        readAloudText: "Wallflower$creepText, open your eyes.\\n\\nIf you wish to witness the murder, raise your hand.\\n\\nWallflower$creepText, close your eyes.",
        instructionText: "Optional: If they choose, reveal who the Dealers targeted. Then they close eyes.",
        actionType: ScriptActionType.optional,
        roleId: 'wallflower',
      ));
    } else if (role.id == 'sober') {
      steps.add(ScriptStep(
        id: 'sober_act',
        title: 'Send Someone Home',
        readAloudText: "Sober$creepText, open your eyes.\n\nWho do you wish to save from the night's shenanigans?\n\nSober$creepText, close your eyes.",
        instructionText: "That player will not participate tonight and will not be asked to open their eyes. If a Dealer is sent home, no murders happen tonight. Then they close eyes.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'sober',
      ));
    } else if (role.id == 'silver_fox') {
      steps.add(ScriptStep(
        id: 'silver_fox_act',
        title: 'Force Reveal',
        readAloudText: "Silver Fox$creepText, open your eyes.\n\nOnly once per game, you may ply someone with alcohol to force a reveal. If you wish to use this power now, point to a player.\n\nSilver Fox$creepText, close your eyes.",
        instructionText: "If they choose a player, that player must reveal their card tomorrow. If not, they shake their head.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'silver_fox',
      ));
    } else if (role.id == 'messy_bitch') {
      steps.add(ScriptStep(
        id: 'messy_bitch_act',
        title: 'Spread Rumour',
        readAloudText: "Messy Bitch$creepText, open your eyes.\\n\\nSelect a person to poison with a rumour.\\n\\nMessy Bitch$creepText, close your eyes.",
        instructionText: "Track how many rumours have been spread. When all other alive players have rumours, Messy Bitch can convert to an attack dog. Then they close eyes.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'messy_bitch',
      ));
    } else if (role.id == 'clinger') {
      try {
        final clinger = players.firstWhere((p) => p.role.id == 'clinger' && p.isActive);
        if (clinger.clingerFreedAsAttackDog && !clinger.clingerAttackDogUsed) {
          // CLINGER - Attack Dog ability (only if freed from obsession)
          steps.add(ScriptStep(
            id: 'clinger_act',
            title: 'Attack Dog Ability',
            readAloudText: "Clinger$creepText, open your eyes.\\n\\nIf you have been freed from your obsession (called 'controller'), you may now kill one player. Do you wish to kill? If so, point to your target.\\n\\nClinger$creepText, close your eyes.",
            instructionText: "This ability is only available if Clinger was called 'controller' by their obsession partner in a previous day phase. If they use this, one player dies immediately. Then they close eyes.",
            actionType: ScriptActionType.selectPlayer,
            roleId: 'clinger',
          ));
        }
      } catch (e) {
        // No clinger found or other error, do nothing
      }
    } else if (role.id == 'wallflower') {
        // Wallflower is usually integrated with Dealer, but if they are the ONLY role (e.g. testing), or for some reason not integrated, handle here.
        // Actually, wallflower is in integratedRoleIds, so this block might be redundant if loop skips it.
        // But if for some reason it falls through:
        steps.add(ScriptStep(
          id: 'wallflower_independent_witness',
          title: 'Witness Murder',
          readAloudText: "Wallflower$creepText, open your eyes.\\n\\n(Logic fallback: Wallflower should wake with Dealers). Close your eyes.",
          instructionText: "This step should ideally be merged with Dealer wake.",
          roleId: 'wallflower',
        ));
    } else if (role.id == 'tea_spiller') {
      steps.add(ScriptStep(
        id: 'tea_spiller_act',
        title: 'Mark for Reveal',
        readAloudText: "Tea Spiller$creepText, open your eyes.\n\nMark a player. If you die, their role will be exposed.\n\nTea Spiller$creepText, close your eyes.",
        instructionText: "They choose a target for their potential death reveal.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'tea_spiller',
      ));
    } else if (role.id == 'predator') {
      steps.add(ScriptStep(
        id: 'predator_act',
        title: 'Mark for Retaliation',
        readAloudText: "Predator$creepText, open your eyes.\n\nMark a player. If you are voted out, this player will die with you.\n\nPredator$creepText, close your eyes.",
        instructionText: "They choose a target for their potential retaliation.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'predator',
      ));
    } else if (role.id == 'lightweight') {
      steps.add(ScriptStep(
        id: 'lightweight_act',
        title: 'New Taboo Name',
        readAloudText: "Lightweight$creepText, open your eyes.\n\n(Host, point to a player now to make their name taboo).\n\nLightweight, nod if you understand.\n\nLightweight$creepText, close your eyes.",
        instructionText: "Select the player on screen who you are pointing at in real life to add them to the lightweight's taboo list.",
        actionType: ScriptActionType.selectPlayer,
        roleId: 'lightweight',
      ));
    } else if (role.id == 'drama_queen') {
       steps.add(ScriptStep(
        id: 'drama_queen_act',
        title: 'Mark for Role Swap',
        readAloudText: "Drama Queen$creepText, open your eyes.\n\nSelect TWO players. If you die tonight, their roles will be swapped.\n\nDrama Queen$creepText, close your eyes.",
        instructionText: "Select two players on screen to mark them for the swap.",
        actionType: ScriptActionType.selectTwoPlayers,
        roleId: 'drama_queen',
      ));
    } else {
      // Default ability handling - combine wake, action, and sleep
      // Most roles target one player, but some need two (e.g., Drama Queen swap)
      final actionType = role.id == 'drama_queen'
          ? ScriptActionType.selectTwoPlayers
          : ScriptActionType.selectPlayer;

      steps.add(ScriptStep(
        id: '${role.id}_act',
        title: role.name,
        readAloudText: "${role.name}$creepText, open your eyes.\\n\\nPerform your action now.\\n\\n${role.name}$creepText, close your eyes.",
        instructionText: "Let them target someone, then they close eyes.",
        actionType: actionType,
        roleId: role.id,
      ));
    }

    return steps;
  }
}
