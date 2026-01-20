// ignore_for_file: unreachable_switch_case

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/role.dart';
import '../models/script_step.dart';
import '../models/game_log_entry.dart';
import '../models/saved_game.dart';
import '../data/role_repository.dart';
import '../data/game_script.dart';
import '../utils/game_logger.dart';
import '../utils/game_exceptions.dart';
import '../utils/input_validator.dart';
import '../utils/role_validator.dart';
import 'script_builder.dart';
import 'game_state.dart';
import 'ability_system.dart';
import 'reaction_system.dart';

class DramaQueenSwapRecord {
  final int day;
  final String playerAName;
  final String playerBName;
  final String fromRoleA;
  final String fromRoleB;
  final String toRoleA;
  final String toRoleB;

  const DramaQueenSwapRecord({
    required this.day,
    required this.playerAName,
    required this.playerBName,
    required this.fromRoleA,
    required this.fromRoleB,
    required this.toRoleA,
    required this.toRoleB,
  });
}

class GameEngine extends ChangeNotifier {
  final RoleRepository roleRepository;

  final Map<String, Player> _playerMap = {};
  final List<Player> _playerList = [];
  List<Player> get players => UnmodifiableListView(_playerList);

  GamePhase _currentPhase = GamePhase.lobby;

  // Callback for phase transitions
  void Function(GamePhase oldPhase, GamePhase newPhase)? onPhaseChanged;

  // Callback for clinger double death (clinger, obsession)
  void Function(String clingerName, String obsessionName)? onClingerDoubleDeath;

  // Callback for club manager role reveal (target player, target role)
  void Function(Player target)? onClubManagerReveal;

  // Callback for bartender check
  void Function(String p1Name, String p2Name, bool sameTeam)? onBartenderCheck;

  // Script Engine
  List<ScriptStep> _scriptQueue = [];
  int _scriptIndex = 0;

  // Game State Tracking
  int dayCount = 0;
  Map<String, dynamic> nightActions =
      {}; // ActionKey -> TargetID (e.g., 'kill' -> '123')
  List<String> deadPlayerIds = [];
  List<String> nameHistory = [];
  List<GameLogEntry> _gameLog = [];
  String lastNightSummary = ''; // Public summary (deaths, etc.)
  String lastNightHostRecap = ''; // Private full recap for Host
  String? messyBitchGossip; // Daily generated gossip text
  Map<String, int> lastNightStats = {};
  bool dramaQueenSwapPending = false;
  String? dramaQueenMarkedAId;
  String? dramaQueenMarkedBId;
  DramaQueenSwapRecord? lastDramaQueenSwap;
  bool _dayphaseVotesMade =
      false; // Track if any votes were cast during current day phase
  final List<Map<String, String>> _clingerDoubleDeaths =
      []; // Track clinger+obsession deaths for dramatic announcements

  Timer? _saveHistoryDebounceTimer;

  // Ability & Reaction Systems
  final AbilityResolver abilityResolver = AbilityResolver();
  final ReactionSystem reactionSystem = ReactionSystem();
  final StatusEffectManager statusEffectManager = StatusEffectManager();
  final AbilityChainResolver chainResolver = AbilityChainResolver();
  final Map<String, List<String>> _abilityTargets =
      {}; // roleId -> list of target IDs

  List<GameLogEntry> get gameLog => List.unmodifiable(_gameLog);

  GameEngine({required this.roleRepository}) {
    _loadNameHistory();
    // Hook up ability logging
    abilityResolver.onAbilityQueued = (ability) {
      // 1. Log to Reaction System (History/Triggers)
      reactionSystem.triggerEvent(
        GameEvent(
          type: GameEventType.abilityUsed,
          sourcePlayerId: ability.sourcePlayerId,
          targetPlayerId: ability.targetPlayerIds.isNotEmpty
              ? ability.targetPlayerIds.first
              : null,
          data: {
            'abilityId': ability.abilityId,
            'trigger': ability.trigger.toString(),
            'effect': ability.effect.toString(),
            'allTargets': ability.targetPlayerIds,
            'metadata': ability.metadata,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
        _playerList,
      );

      // 2. Log to Game Log (Visible UI)
      logAction(
        'Input Recorded: ${ability.metadata['roleName'] ?? 'Unknown Role'}',
        'Ability: ${ability.abilityId}. Targets: ${ability.targetPlayerIds.map((id) => _playerMap[id]?.name ?? id).join(", ")}',
      );

      // 3. Real-Time Status Update (For Host Overview)
      for (var targetId in ability.targetPlayerIds) {
        String statusName = '';
        String statusDesc = '';
        String statusEmoji = '';

        switch (ability.effect) {
          case AbilityEffect.protect:
            statusName = 'Protected (Pending)';
            statusDesc = 'Targeted for protection';
            statusEmoji = '???';
            break;
          case AbilityEffect.kill:
            statusName = 'Targeted (Pending)';
            statusDesc = 'Targeted for elimination';
            statusEmoji = '??';
            break;
          case AbilityEffect.silence:
            statusName = 'Silenced (Pending)';
            statusDesc = 'Will be silenced';
            statusEmoji = '??';
            break;
          case AbilityEffect.mark:
            statusName = 'Marked (${ability.metadata['roleName'] ?? '?'})';
            statusDesc = 'Marked by ability';
            statusEmoji = '??';
            break;
          case AbilityEffect.redirect:
            statusName = 'Redirect Target';
            statusDesc = 'Votes/Attacks deflected here';
            statusEmoji = '??';
            break;
          case AbilityEffect.inherit:
            statusName = 'Mimicked';
            statusDesc = 'Role copied via inheritance';
            statusEmoji = '??';
            break;
          case AbilityEffect.copy:
            statusName = 'Mimicked';
            statusDesc = 'Role being copied';
            statusEmoji = '??';
            break;
          case AbilityEffect.modify:
            if (ability.metadata.containsKey('taboo_name')) {
              statusName = 'Taboo Name';
              statusDesc = 'Name is taboo for Lightweight';
              statusEmoji = '??';
            }
            break;
          case AbilityEffect.block:
            statusName = 'Blocked';
            statusDesc = 'Ability blocked';
            statusEmoji = '??';
            break;
          case AbilityEffect.reveal:
            statusName = 'Revealed (Pending)';
            statusDesc = 'Role will be forced revealed';
            statusEmoji = '???';
            break;
          case AbilityEffect.investigate:
            // Optional: Show check status briefly?
            // Leaving skipped for now as per design to avoid clutter,
            // but could add if user specifically asks.
            continue;
          default:
            // Don't show generic status for checks/investigations to avoid clutter
            continue;
        }

        if (statusName.isNotEmpty) {
          statusEffectManager.applyEffect(
            targetId,
            StatusEffect(
              id: 'pending_${ability.abilityId}_${DateTime.now().millisecondsSinceEpoch}',
              name: '$statusEmoji $statusName',
              description: statusDesc,
              duration: 1, // Lasts until processed/cleared
              isPermanent: false,
            ),
          );
        }
      }
      notifyListeners(); // Ensure UI updates immediately
    };
  }

  Future<void> _loadNameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    nameHistory = prefs.getStringList('player_name_history') ?? [];
    notifyListeners();
  }

  Future<void> _addToHistory(String name) async {
    if (name.isEmpty) return;

    // Keep newest at the end; ensure uniqueness
    nameHistory.removeWhere((n) => n == name);
    nameHistory.add(name);

    // Optional cap to prevent unbounded growth
    const maxHistory = 200;
    if (nameHistory.length > maxHistory) {
      nameHistory = nameHistory.sublist(nameHistory.length - maxHistory);
    }

    _scheduleHistorySave();
    notifyListeners();
  }

  /// Removes the provided names from the saved name history.
  Future<void> removeNamesFromHistory(List<String> names) async {
    if (names.isEmpty) return;
    nameHistory.removeWhere((n) => names.contains(n));
    _scheduleHistorySave();
    notifyListeners();
  }

  void _scheduleHistorySave() {
    _saveHistoryDebounceTimer?.cancel();
    _saveHistoryDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _persistHistory();
      _saveHistoryDebounceTimer = null;
    });
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('player_name_history', nameHistory);
    } catch (e) {
      GameLogger.error(
        'Failed to save name history',
        context: 'GameEngine',
        error: e,
      );
    }
  }

  @override
  void dispose() {
    if (_saveHistoryDebounceTimer != null &&
        _saveHistoryDebounceTimer!.isActive) {
      _saveHistoryDebounceTimer!.cancel();
      _persistHistory();
    }
    super.dispose();
  }

  GamePhase get currentPhase => _currentPhase;
  set currentPhase(GamePhase value) {
    if (_currentPhase != value) {
      final old = _currentPhase;
      _currentPhase = value;
      notifyListeners();
      if (onPhaseChanged != null) {
        onPhaseChanged!(old, value);
      }
    }
  }

  List<ScriptStep> get scriptQueue => List.unmodifiable(_scriptQueue);
  int get currentScriptIndex => _scriptIndex;

  /// Roles not currently in play (alive or dead), used for late joiners.
  List<Role> availableRolesForNewPlayer() {
    final allRoles = roleRepository.roles;

    final partyAnimalRole = allRoles.firstWhere(
      (r) => r.id == 'party_animal',
      orElse: () => Role(
        id: 'missing',
        name: 'Missing Role',
        alliance: 'None',
        type: 'Placeholder',
        description: '',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      ),
    );
    if (partyAnimalRole.id == 'missing') {
      // Party Animal is treated as the default filler role.
      throw RoleAssignmentException(
        'Missing required role: party_animal. Check assets/data/roles.json.',
      );
    }

    final dealerRole = allRoles.firstWhere(
      (r) => r.id == 'dealer',
      orElse: () => Role(
        id: 'missing',
        name: 'Missing Role',
        alliance: 'None',
        type: 'Placeholder',
        description: '',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#FFFFFF',
      ),
    );

    // Unique roles become unavailable once they've appeared in the game at all (alive OR dead).
    final usedUniqueRoleIds = _playerList
        .map((p) => p.role.id)
        .where((id) => id != 'temp')
        .where((id) => !RoleValidator.multipleAllowedRoles.contains(id))
        .toSet();

    final uniqueAvailable = allRoles
        .where((r) => r.id != 'temp')
        .where((r) => r.id != 'host')
        .where((r) => !RoleValidator.multipleAllowedRoles.contains(r.id))
        .where((r) => !usedUniqueRoleIds.contains(r.id))
        .toList();

    // Allow Dealers only if within the recommended scaling AFTER adding this player.
    final currentEnabledNonHost = _playerList
        .where((p) => p.isEnabled && p.role.id != 'host')
        .length;
    final newTotal = currentEnabledNonHost + 1;
    final recommendedDealers = RoleValidator.recommendedDealerCount(newTotal);
    final currentDealersAlive = _playerList
        .where((p) => p.isEnabled && p.isAlive && p.role.id == 'dealer')
        .length;
    final canAddDealer =
        dealerRole.id != 'missing' && currentDealersAlive < recommendedDealers;

    final results = <Role>[...uniqueAvailable];
    // Party Animal is always a valid fallback filler.
    results.add(partyAnimalRole);
    if (canAddDealer) results.add(dealerRole);

    // Sort for dropdown friendliness.
    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  List<Player> get enabledPlayers =>
      _playerList.where((p) => p.isEnabled).toList();
  List<Player> get activePlayers =>
      _playerList.where((p) => p.isActive).toList();
  List<Player> get enabledGuests =>
      _playerList.where((p) => p.isEnabled && p.role.id != 'host').toList();
  List<Player> get guests =>
      UnmodifiableListView(_playerList.where((p) => p.role.id != 'host'));
  List<Player> get activeGuests => UnmodifiableListView(
    _playerList.where((p) => p.role.id != 'host' && p.isActive),
  );

  ScriptStep? get currentScriptStep {
    if (_scriptQueue.isNotEmpty && _scriptIndex < _scriptQueue.length) {
      return _scriptQueue[_scriptIndex];
    }
    return null;
  }

  void addPlayer(String name, {Role? role}) {
    GameLogger.debug('Adding player: $name', context: 'GameEngine');

    // Validate and sanitize player name
    final validation = InputValidator.validatePlayerName(name);
    if (validation.isInvalid) {
      GameLogger.warning(
        'Invalid player name: ${validation.error}',
        context: 'GameEngine',
      );
      throw ValidationException(validation.error ?? 'Invalid input');
    }

    final sanitizedName = InputValidator.sanitizeString(name);

    // Check for duplicate names
    if (_playerList.any(
      (p) => p.name.toLowerCase() == sanitizedName.toLowerCase(),
    )) {
      GameLogger.warning(
        'Duplicate player name: $sanitizedName',
        context: 'GameEngine',
      );
      throw ValidationException('A player with this name already exists');
    }

    // Add to history if new
    _addToHistory(sanitizedName);

    // Use temporary placeholder role - will be assigned properly when game starts
    Role assignedRole;
    if (role != null) {
      assignedRole = role;
      GameLogger.debug(
        'Assigned specific role: ${role.name}',
        context: 'GameEngine',
      );
    } else {
      // Assign temporary placeholder role
      GameLogger.debug(
        'Assigning temporary placeholder role',
        context: 'GameEngine',
      );
      assignedRole = Role(
        id: 'temp',
        name: 'Unassigned',
        alliance: 'None',
        type: 'Placeholder',
        description: 'Role will be assigned when the game starts',
        nightPriority: 0,
        assetPath: '',
        colorHex: '#888888',
      );
    }

    final player = Player(
      id:
          DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(10000).toString(),
      name: sanitizedName,
      role: assignedRole,
    );

    _playerMap[player.id] = player;
    _playerList.add(player);
    GameLogger.info(
      'Player added: ${player.name} as ${assignedRole.name}',
      context: 'GameEngine',
    );
    notifyListeners();
  }

  /// Add a player mid-day who will become active next night.
  Player addPlayerDuringDay(String name, {Role? role}) {
    if (_currentPhase == GamePhase.lobby) {
      throw GameStateException(GamePhase.day.name, GamePhase.lobby.name);
    }

    GameLogger.debug('Adding late joiner: $name', context: 'GameEngine');

    final validation = InputValidator.validatePlayerName(name);
    if (validation.isInvalid) {
      GameLogger.warning(
        'Invalid player name: ${validation.error}',
        context: 'GameEngine',
      );
      throw ValidationException(validation.error ?? 'Invalid input');
    }

    final sanitizedName = InputValidator.sanitizeString(name);

    if (_playerList.any(
      (p) => p.name.toLowerCase() == sanitizedName.toLowerCase(),
    )) {
      GameLogger.warning(
        'Duplicate player name: $sanitizedName',
        context: 'GameEngine',
      );
      throw ValidationException('A player with this name already exists');
    }

    _addToHistory(sanitizedName);

    final available = availableRolesForNewPlayer();
    if (available.isEmpty) {
      throw InvalidActionException(
        'No roles are available for new players at this point in the game',
      );
    }

    Role assignedRole;
    if (role != null) {
      if (!available.any((r) => r.id == role.id)) {
        throw RoleAssignmentException('Selected role is not available');
      }
      assignedRole = role;
    } else {
      assignedRole = available[Random().nextInt(available.length)];
    }

    final player = Player(
      id:
          DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(10000).toString(),
      name: sanitizedName,
      role: assignedRole,
      joinsNextNight: true,
    );
    player.initialize();

    _playerMap[player.id] = player;
    _playerList.add(player);
    GameLogger.info(
      'Late joiner added: ${player.name} as ${assignedRole.name}',
      context: 'GameEngine',
    );
    notifyListeners();
    return player;
  }

  void updatePlayerRole(String playerId, Role? newRole) {
    if (newRole == null) {
      GameLogger.warning(
        'Attempted to update player role with null role',
        context: 'GameEngine',
      );
      return;
    }

    if (!InputValidator.isValidId(playerId)) {
      throw PlayerNotFoundException(playerId);
    }

    final player = _playerMap[playerId];
    if (player == null) {
      GameLogger.error('Player not found: $playerId', context: 'GameEngine');
      throw PlayerNotFoundException(playerId);
    }

    // Enforce single Bouncer rule at assignment time
    if (newRole.id == 'bouncer') {
      final existingBouncer = _playerList.firstWhere(
        (p) => p.id != playerId && p.role.id == 'bouncer' && p.isEnabled,
        orElse: () => Player(
          id: 'none',
          name: '',
          role: Role(
            id: 'none',
            name: '',
            alliance: '',
            type: '',
            description: '',
            nightPriority: 0,
            assetPath: '',
            colorHex: '#FFFFFF',
          ),
        ),
      );
      if (existingBouncer.id != 'none') {
        GameLogger.warning(
          'Attempted to assign a second Bouncer to ${player.name}',
          context: 'GameEngine',
        );
        throw RoleAssignmentException(
          'Only one Bouncer is allowed. ${existingBouncer.name} already has this role.',
        );
      }
    }

    final oldRole = player.role.name;
    player.role = newRole;
    player.initialize();

    GameLogger.info(
      'Updated ${player.name} role: $oldRole ? ${newRole.name}',
      context: 'GameEngine',
    );
    notifyListeners();
  }

  void removePlayer(String id) {
    if (!InputValidator.isValidId(id)) {
      throw PlayerNotFoundException(id);
    }

    final player = _playerMap[id];
    if (player == null) {
      GameLogger.warning(
        'Attempted to remove non-existent player: $id',
        context: 'GameEngine',
      );
      return;
    }

    _playerMap.remove(id);
    _playerList.removeWhere((p) => p.id == id);
    GameLogger.info('Removed player: ${player.name}', context: 'GameEngine');
    notifyListeners();
  }

  Future<void> startGame() async {
    final enabledCount = enabledGuests.length;
    GameLogger.info(
      'Starting game with $enabledCount players',
      context: 'GameEngine',
    );

    // Validate player count
    final validation = InputValidator.validatePlayerCount(enabledCount);
    if (validation.isInvalid) {
      GameLogger.error(
        'Cannot start game: ${validation.error}',
        context: 'GameEngine',
      );
      throw InvalidPlayerCountException(enabledCount, 4);
    }

    final startTime = DateTime.now();

    try {
      _assignRoles();
      GameLogger.info('Roles assigned successfully', context: 'GameEngine');

      // Initialize Script: Intro -> Dynamic Night
      _scriptQueue = [
        ...GameScript.intro,
        ...ScriptBuilder.buildNightScript(enabledGuests, dayCount),
      ];
      _scriptIndex = 0;
      _currentPhase = GamePhase.setup;
      lastNightSummary = '';

      GameLogger.stateTransition('lobby', 'setup', reason: 'Game started');

      final duration = DateTime.now().difference(startTime);
      GameLogger.performance('Game initialization', duration);

      _logCurrentStep();

      notifyListeners();
    } catch (e, stackTrace) {
      GameLogger.error(
        'Failed to start game',
        context: 'GameEngine',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void rebuildNightScript() {
    if (_currentPhase != GamePhase.night) return;

    final currentIndex = _scriptIndex;
    ScriptStep? currentStep;
    if (currentIndex < _scriptQueue.length) {
      currentStep = _scriptQueue[currentIndex];
    }

    // Rebuild script with new player states (e.g. Sober sentHome)
    final newQueue = ScriptBuilder.buildNightScript(players, dayCount);

    if (currentStep != null) {
      // Attempt to find the specific current script step in the new queue
      // This works if the current role (e.g. Sober) wasn't removed
      final newIndex = newQueue.indexWhere((s) => s.id == currentStep!.id);

      if (newIndex != -1) {
        _scriptQueue = newQueue;
        _scriptIndex = newIndex;
      } else {
        // The current step disappeared (e.g. Sober sent themselves home).
        // We need to maintain continuity.
        // We can keep the OLD steps up to current index, and append the NEW steps that come AFTER.
        // But merging is messy.

        // Alternative: If the current running step is gone from the new script,
        // it means we are in a "zombie" step that technically shouldn't exist anymore.
        // But we need to finish it.
        // So we use the new queue, but we must decide where to place the index.

        // Heuristic: Find the closest preceding step that exists in both.
        int bestMatchNewIndex = 0;

        // Look backwards from current index in OLD queue
        for (int i = currentIndex - 1; i >= 0; i--) {
          final pastStep = _scriptQueue[i];
          final match = newQueue.indexWhere((s) => s.id == pastStep.id);
          if (match != -1) {
            bestMatchNewIndex = match;
            break;
          }
        }

        _scriptQueue = newQueue;
        // Set index to the match. When user clicks "Next", it advances to match + 1.
        // If match was "Night Start", next is the first role in new queue.
        _scriptIndex = bestMatchNewIndex;
      }
    } else {
      _scriptQueue = newQueue;
      _scriptIndex = 0;
    }

    notifyListeners();
  }

  void advanceScript() {
    _scriptIndex++;

    // Check if we reached the end of the current script queue
    if (_scriptIndex >= _scriptQueue.length) {
      _loadNextPhaseScript();
    }

    _logCurrentStep();

    notifyListeners();
  }

  void _logCurrentStep() {
    final step = currentScriptStep;
    if (step != null) {
      // Prevent duplicate logs for the same step (e.g. regressing and advancing)
      if (_gameLog.isNotEmpty) {
        final last = _gameLog.first;
        if (last.title == step.title &&
            last.description ==
                (step.instructionText.isNotEmpty
                    ? step.instructionText
                    : step.readAloudText)) {
          return;
        }
      }

      logAction(
        step.title,
        step.instructionText.isNotEmpty
            ? step.instructionText
            : step.readAloudText,
        type: GameLogType.script,
      );
    }
  }

  void regressScript() {
    if (_scriptIndex > 0) {
      _scriptIndex--;
      notifyListeners();
    }
  }

  void skipToNextPhase() {
    // Jump to the end of the current script to trigger phase transition
    _scriptIndex = _scriptQueue.length;
    _loadNextPhaseScript();
    _logCurrentStep();
    notifyListeners();
  }

  void _loadNextPhaseScript() {
    final oldPhase = _currentPhase;
    final players = guests;

    if (_currentPhase == GamePhase.setup) {
      // After setup (Night 0), go directly to Night 1
      _currentPhase = GamePhase.night;
      onPhaseChanged?.call(oldPhase, _currentPhase);

      // Resolve setup night so abilities like Creep or Clinger take effect
      _resolveNightPhase();

      // Log separation for clarity
      logAction(
        "Setup Complete",
        "Transitioning to Day 1 / Night 1 cycle.",
        type: GameLogType.system,
      );

      // Clear ability queue from Setup so it doesn't pollute Night 1
      nightActions.clear();
      _abilityTargets.clear();
      abilityResolver.clear();

      // Reset Sober sent-home status for new night
      for (final p in players) {
        p.soberSentHome = false;
      }

      // Increment day count to 1 (first actual night)
      dayCount++;

      // Activate any players who joined during setup
      for (final p in players.where((p) => p.joinsNextNight)) {
        p.joinsNextNight = false;
        p.initialize();
      }

      // Trigger night phase start event
      final nightStartEvent = GameEvent(type: GameEventType.nightPhaseStart);
      reactionSystem.triggerEvent(nightStartEvent, players);

      // Update status effects
      statusEffectManager.updateEffects();

      // Build Night 1 Script
      _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
      _scriptIndex = 0;
    } else if (_currentPhase == GamePhase.night) {
      // Switch to Day - RESOLVE NIGHT with new ability system
      _currentPhase = GamePhase.day;
      onPhaseChanged?.call(oldPhase, _currentPhase);

      String announcement = _resolveNightPhase();
      lastNightSummary = announcement;

      // Clear ability queue for next night
      nightActions.clear();
      _abilityTargets.clear();
      abilityResolver.clear();

      // Reset vote tracking for new day phase
      _dayphaseVotesMade = false;

      // Build Day Script with Morning Report
      _scriptQueue = ScriptBuilder.buildDayScript(
        dayCount,
        announcement,
        players,
      );
      _scriptIndex = 0;
      // Day count increment moved to end of day phase
    } else if (_currentPhase == GamePhase.day) {
      // End of Day Phase -> Start Night Phase
      dayCount++;

      // Check if any votes were made during the day phase
      if (!_dayphaseVotesMade) {
        // No votes cast - announce and skip to night directly
        logAction(
          "No Vote Cast",
          "Time ran out without a vote being called. No one was eliminated.",
        );

        _currentPhase = GamePhase.night;
        onPhaseChanged?.call(oldPhase, _currentPhase);

        // Reset Sober sent-home status for new night
        for (final p in players) {
          p.soberSentHome = false;
        }

        // Activate any players who joined during the day
        for (final p in players.where((p) => p.joinsNextNight)) {
          p.joinsNextNight = false;
          p.initialize();
        }

        // Trigger night phase start event
        final nightStartEvent = GameEvent(type: GameEventType.nightPhaseStart);
        reactionSystem.triggerEvent(nightStartEvent, players);

        // Update status effects (remove expired)
        statusEffectManager.updateEffects();

        // Build next night script and continue
        _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
        _scriptIndex = 0;

        notifyListeners();
        return;
      }

      // Votes were made - continue normally
      _currentPhase = GamePhase.night;
      onPhaseChanged?.call(oldPhase, _currentPhase);

      // Reset Sober sent-home status for new night
      for (final p in players) {
        p.soberSentHome = false;
      }

      // Activate any players who joined during the day
      for (final p in players.where((p) => p.joinsNextNight)) {
        p.joinsNextNight = false;
        p.initialize();
      }

      // Trigger night phase start event
      final nightStartEvent = GameEvent(type: GameEventType.nightPhaseStart);
      reactionSystem.triggerEvent(nightStartEvent, players);

      // Update status effects (remove expired)
      statusEffectManager.updateEffects();

      _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
      _scriptIndex = 0;
    }
  }

  /// Centralized death processing to ensure all side effects (Creep, Clinger, Reactions)
  /// occur regardless of whether death happens at Night or via Day Ability/Event.
  void processDeath(Player victim, {String cause = 'unknown'}) {
    // If player is already fully processed as dead, skip.
    if (!victim.isAlive && deadPlayerIds.contains(victim.id)) return;

    // UNIVERSAL SECOND WIND CHECK
    // This triggers for ANY death (Night Kill, Vote, Tea Spiller, etc)
    if (victim.role.id == 'second_wind' &&
        !victim.secondWindConverted &&
        !victim.secondWindRefusedConversion) {
      victim.secondWindPendingConversion = true;

      // If it's night, we also flag it for the night actions to ensure proper script flow if needed
      if (_currentPhase == GamePhase.night) {
        nightActions['second_wind_victim_id'] = victim.id;
      }

      logAction(
        "Second Wind",
        "${victim.name} triggered Second Wind! Dealers must decide their fate.",
      );
      notifyListeners();
      return; // PREVENT DEATH
    }

    // Multi-life shields (Ally Cat & Seasoned Drinker)
    if (_absorbDeathWithLives(victim, cause)) {
      notifyListeners();
      return; // Death prevented; life consumed
    }

    // 1. Trigger Death Events (for Drama Queen/Tea Spiller if active)
    final deathEvent = GameEvent(
      type: GameEventType.playerDied,
      sourcePlayerId: victim.id,
      data: {'cause': cause},
    );
    final reactions = reactionSystem.triggerEvent(deathEvent, players);
    _processDeathReactions(victim, reactions);

    // 2. Mark as Dead
    victim.die(dayCount, cause);
    deadPlayerIds.add(victim.id);

    // 3. Log
    if (cause == 'night_kill') {
      // Standard night log
      logAction("Death", "${victim.name} (${victim.role.name}) eliminated.");
    } else {
      logAction(
        "Death",
        "${victim.name} (${victim.role.name}) died. Cause: $cause",
      );
    }

    // 4. Side Effects
    _handleCreepInheritance(victim);
    _handleClingerObsessionDeath(victim);

    notifyListeners();
  }

  // Returns true if the death is absorbed by remaining lives (so death should halt)
  bool _absorbDeathWithLives(Player victim, String cause) {
    // Ally Cat: lose a life for any death attempt (vote or kill) until lives run out
    if (victim.role.id == 'ally_cat') {
      victim.lives = (victim.lives - 1).clamp(0, 999);
      if (victim.lives > 0) {
        logAction(
          'Nine Lives',
          '${victim.name} dodged death. Lives left: ${victim.lives}.',
        );
        return true;
      }
      return false; // No lives left; allow death
    }

    // Seasoned Drinker: only resistant to Dealer attempts (night_kill). Votes kill normally.
    final isDealerAttempt = cause == 'night_kill';
    if (victim.role.id == 'seasoned_drinker' && isDealerAttempt) {
      victim.lives = (victim.lives - 1).clamp(0, 999);
      if (victim.lives > 0) {
        logAction(
          'Seasoned Drinker',
          '${victim.name} burned a life against the Dealers. Lives left: ${victim.lives}.',
        );
        return true;
      }
      return false; // Out of lives; allow death
    }

    // The Minor: Immune to Dealer attacks (Night Kill) until ID checked by Bouncer
    if (victim.role.id == 'minor' && isDealerAttempt) {
      if (!victim.minorHasBeenIDd) {
        logAction(
          'Minor Protection',
          '${victim.name} (The Minor) was attacked but had ID immunity. Safe.',
        );
        return true; // Death absorbed
      }
      // If ID has been checked, she dies normally.
    }

    return false;
  }

  /// Process all night abilities using the new ability system
  String _resolveNightPhase() {
    final players = guests;
    _clingerDoubleDeaths.clear();
    messyBitchGossip = null;
    final Set<String> processedAbilityIds = {};

    // Process abilities in priority order
    final results = abilityResolver.resolveAllAbilities(players);

    // Check for kills, protections, and lives lost from ALL kill abilities
    List<String> killedIds = [];
    List<String> protectedIds = [];
    List<String> minorProtectedIds = [];
    List<String> livesLostIds = [];

    for (var result in results) {
      if (result.abilityId.contains('kill') && result.success) {
        killedIds.addAll(result.targets);
        final pIds = (result.metadata['protected'] as List<String>?) ?? [];
        protectedIds.addAll(pIds);

        final mpIds =
            (result.metadata['minor_protected'] as List<String>?) ?? [];
        minorProtectedIds.addAll(mpIds);

        livesLostIds.addAll(
          (result.metadata['lives_lost'] as List<String>?) ?? [],
        );
      }
    }

    // --- LOGIC EXECUTION & REPORT GENERATION ---
    // We maintain two buffers:
    // 1. report (Public): Deaths, revives, loud events.
    // 2. hostReport (Private): Detailed log of moves.
    StringBuffer report = StringBuffer();
    StringBuffer hostReport = StringBuffer();

    // 1. CREEP
    // Recover Creep action from Ability Resolver to ensure persistence
    final creepResult = results.firstWhere(
      (r) => r.abilityId == 'creep_mimic',
      orElse: () => AbilityResult(
        abilityId: 'none',
        success: false,
        message: 'No Action',
      ),
    );

    String? creepTargetSelection = nightActions['creep_target'];
    // Fallback: Use the resolved ability result if map is empty (e.g., after reload)
    if (creepTargetSelection == null &&
        creepResult.success &&
        creepResult.targets.isNotEmpty) {
      creepTargetSelection = creepResult.targets.first;
    }

    if (creepTargetSelection != null) {
      try {
        final creep = _playerList.firstWhere((p) => p.role.id == 'creep');
        creep.creepTargetId = creepTargetSelection;
        final target = _playerMap[creepTargetSelection]!;
        creep.alliance = target.role.alliance;
        logAction("Creep Selection", "Creep chose to mimic ${target.name}");
        final msg =
            "👁️ 💋 Someone was caught staring a little too long at ${target.name}'s backside... Just a lingering vibe check.";
        report.writeln(msg);
        hostReport.writeln(msg);
        processedAbilityIds.add('creep_mimic');
      } catch (e) {
        /* ignore */
      }
    }

    // 2. DEATHS & ATTEMPTED KILLS
    // We combine kills and protections into a narrative
    Set<String> processedVictims = {};

    // Fallback killer in case an ability result is missing but the intent map has the target
    void applyFallbackKill({
      required String abilityId,
      required String? targetId,
      required String publicLabel,
      required String hostLabel,
    }) {
      if (targetId == null || targetId.isEmpty) return;
      if (processedVictims.contains(targetId)) return;
      final victim = _playerMap[targetId];
      if (victim == null) return;

      final wasAliveBefore = victim.isAlive;
      processDeath(victim, cause: abilityId);
      processedVictims.add(targetId);

      if (!victim.isAlive) {
        final msg = "💀 $publicLabel ${victim.name}.";
        report.writeln(msg);
        hostReport.writeln("💀 $hostLabel ${victim.name}.");
      } else if (wasAliveBefore) {
        livesLostIds.add(victim.id);
        report.writeln(
          " ${victim.name} was hit by $publicLabel but burned a life to survive.",
        );
        hostReport.writeln(
          " $hostLabel ${victim.name} (survived; life consumed).",
        );
      }
    }

    // Standard Dealer Kills
    final dealerResult = results.firstWhere(
      (r) => r.abilityId == 'dealer_kill',
      orElse: () => AbilityResult(
        abilityId: 'none',
        success: false,
        message: 'No Action',
      ),
    );

    // Robust Check: Intent (nightActions) OR Result (dealerResult)
    if (nightActions.containsKey('kill') ||
        dealerResult.abilityId == 'dealer_kill') {
      processedAbilityIds.add('dealer_kill');

      // Attempt to resolve target from result first, then fallback to intent map
      String targetId = dealerResult.targets.isNotEmpty
          ? dealerResult.targets.first
          : (nightActions['kill'] ?? '');

      if (targetId.isNotEmpty) {
        final target = _playerMap[targetId] ?? _playerList.first;

        final bool missingResult =
            dealerResult.abilityId == 'none' ||
            (!dealerResult.success && dealerResult.message == "No Action");

        if (dealerResult.message == "Ability was blocked") {
          final msg =
              " BLOCKED: The Dealers tried to strike ${target.name}, but were blocked!";
          report.writeln(msg);
          hostReport.writeln(msg);
        } else if (missingResult) {
          applyFallbackKill(
            abilityId: 'dealer_kill',
            targetId: targetId,
            publicLabel: '🍹 🩸 SPILT DRINK! The Dealers cornered and cut off',
            hostLabel: 'DEALER (fallback) eliminated',
          );
        } else {
          processedVictims.add(targetId);

          final isKilled = dealerResult.targets.contains(targetId);
          final isLossOfLife =
              (dealerResult.metadata['lives_lost'] as List<String>?)?.contains(
                targetId,
              ) ??
              false;
          final isProtected =
              (dealerResult.metadata['protected'] as List<String>?)?.contains(
                targetId,
              ) ??
              false;
          final isMinorProtected =
              (dealerResult.metadata['minor_protected'] as List<String>?)
                  ?.contains(targetId) ??
              false;

          if (isKilled || isLossOfLife) {
            processDeath(target, cause: 'night_kill');

            if (!target.isAlive) {
              final msg =
                  "🍹 🩸 SPILT DRINK! The Dealers cornered ${target.name} in the VIP booth. They've been cut off permanently - the party's over.";
              report.writeln(msg);
              hostReport.writeln(msg);
              statusEffectManager.applyEffect(
                target.id,
                StatusEffect(
                  id: "killed_dealer_${dayCount}_${target.id}",
                  name: "KILLED (DEALER)",
                  description: "Murdered by Dealers",
                  duration: 1,
                ),
              );

              if (target.role.id == 'tea_spiller') {
                final tea =
                    "☕ 🔥 THE TEA IS SCALDING: The Tea Spiller is out, and the gossip is burning up the floor! Check the menu!";
                report.writeln(tea);
                hostReport.writeln(tea);
              }
              if (target.role.id == 'drama_queen') {
                final dq =
                    "👑 🎬 DRAMA QUEEN ALERT: A spotlight-stealing swap is required! Check the menu!";
                report.writeln(dq);
                hostReport.writeln(dq);
              }
            } else {
              if (target.isAlive && target.secondWindPendingConversion) {
                report.writeln(
                  " The Dealers cornered ${target.name}, but... they survived unexpectedly?",
                );
                hostReport.writeln(
                  " SECOND WIND TRIGGERED: ${target.name} is converting. Check script/pending actions!",
                );
              } else if (isLossOfLife) {
                final msg =
                    "🍻 🍺 ONE MORE ROUND: The Dealers hit ${target.name} hard, but they just wiped their mouth and ordered another double. (Lost 1 life, gained a headache).";
                report.writeln(msg);
                hostReport.writeln(msg);
                statusEffectManager.applyEffect(
                  target.id,
                  StatusEffect(
                    id: "lost_life_${dayCount}_${target.id}",
                    name: "LOST LIFE",
                    description: "Lost 1 life to attack",
                    duration: 1,
                  ),
                );
              }
            }
          } else if (isProtected) {
            final msg =
                "🩺 💋 MOUTH TO MOUTH! The Dealers tried to finish off ${target.name}, but The Medic performed a 'hands-on' rescue with a shot of adrenaline (and maybe some tongue). SAVED!";
            report.writeln(msg);
            hostReport.writeln(msg);
            statusEffectManager.applyEffect(
              target.id,
              StatusEffect(
                id: "saved_medic_${dayCount}_${target.id}",
                name: "SAVED (MEDIC)",
                description: "Dealer attack blocked by Medic",
                duration: 1,
              ),
            );
          } else if (isMinorProtected) {
            final msg =
                "🍼 🔞 UNDERAGE OVERRULE! The Dealers tried to bounce ${target.name}, but they've got that youthful immunity. Too young for this trouble!";
            report.writeln(msg);
            hostReport.writeln(msg);
            statusEffectManager.applyEffect(
              target.id,
              StatusEffect(
                id: "saved_minor_${dayCount}_${target.id}",
                name: "SAVED (MINOR)",
                description: "Dealer attack blocked by Minor trait",
                duration: 1,
              ),
            );
          } else {
            final msg =
                "❓ 🍹 The Dealers targeted ${target.name}, but they survived mysteriously.";
            report.writeln(msg);
            hostReport.writeln(msg);
            statusEffectManager.applyEffect(
              target.id,
              StatusEffect(
                id: "saved_unknown_${dayCount}_${target.id}",
                name: "SURVIVED (?)",
                description: "Survived attack (Unknown reason)",
                duration: 1,
              ),
            );
          }
        }
      }
    }

    // 3. OTHER Kills & Special Attacks (Unified Loop)
    for (var result in results) {
      if (result.abilityId == 'dealer_kill') continue;

      if (result.abilityId.contains('kill') && result.success) {
        processedAbilityIds.add(result.abilityId);
        final targets = [
          ...result.targets,
          ...?(result.metadata['lives_lost'] as List<String>?),
        ];

        for (var targetId in targets) {
          final victim = _playerMap[targetId];
          if (victim == null) continue;

          processedVictims.add(targetId);
          processDeath(victim, cause: result.abilityId);

          if (!victim.isAlive) {
            final causeName = result.abilityId
                .replaceAll('_', ' ')
                .replaceFirst('kill', '')
                .trim()
                .toUpperCase();

            final msg =
                "🕶️ 💀 A NIGHT TO FORGET: ${victim.name} got tangled up with the $causeName and won't be waking up for breakfast.";
            report.writeln(msg);
            hostReport.writeln(msg);
            statusEffectManager.applyEffect(
              victim.id,
              StatusEffect(
                id: "killed_${result.abilityId}_${dayCount}_${victim.id}",
                name: "KILLED ($causeName)",
                description: "Eliminated by $causeName",
                duration: 1,
              ),
            );

            if (victim.role.id == 'tea_spiller') {
              final tea = "  ? ! SPILT TEA ALERT: The Tea Spiller died!";
              report.writeln(tea);
              hostReport.writeln(tea);
            }
          } else {
            final msg =
                " OUCH: ${victim.name} took a hit from ${result.abilityId} but is still standing (Lost a Life).";
            report.writeln(msg);
            hostReport.writeln(msg);
          }
        }
      }
    }

    // Fallbacks for any kill intents that never produced a result (e.g., attack dog)
    if (!processedAbilityIds.contains('clinger_attack_dog')) {
      applyFallbackKill(
        abilityId: 'clinger_attack_dog',
        targetId: nightActions['kill_clinger'],
        publicLabel: '🐕 🩸 ATTACK DOG tore apart',
        hostLabel: 'ATTACK DOG eliminated',
      );
    }

    // 4. CLINGER HEARTBREAK
    if (_clingerDoubleDeaths.isNotEmpty) {
      for (var death in _clingerDoubleDeaths) {
        final msg =
            "💔 💀 FATAL OBSESSION: ${death['clinger']} couldn't handle the rejection! They've checked out for good since ${death['obsession']} is gone.";
        report.writeln(msg);
        hostReport.writeln(msg);
      }
    }

    // 5. SILENCE & BLOCKS & SAVES
    final sentHomePlayers = players.where((p) => p.soberSentHome).toList();
    if (sentHomePlayers.isNotEmpty) {
      for (final p in sentHomePlayers) {
        // Public sees generic message always to avoid spoilers
        final publicMsg =
            "🚫 🛋️ COCKBLOCK! The Sober cut off ${p.name} and called them an Uber. No more action for you tonight!";
        report.writeln(publicMsg);

        if (p.role.id == 'dealer') {
          hostReport.writeln(
            "🚫 🛋️ COCKBLOCK (DEALER): The Sober targeted ${p.name}, blocking the Dealers!",
          );
        } else {
          hostReport.writeln(publicMsg);
        }
      }
    }

    // Bouncer Check (Legacy Check) - will likely be handled by generic loop
    if (nightActions.containsKey('bouncer_check') &&
        !processedAbilityIds.contains('bouncer_check')) {
      // Only log here if generic loop misses it, but generic loop iterates results.
      // If no result exists but action exists, we might want to log failure?
      // Let's rely on generic loop for success/failure reporting.
    }

    final silencedToday = players
        .where((p) => p.isAlive && p.silencedDay == dayCount)
        .toList();
    if (silencedToday.isNotEmpty) {
      final names = silencedToday.map((p) => p.name).join(", ");
      final msg =
          "🤐  Sore Throat? $names had their mouth full last night and can't say a word today.";
      report.writeln(msg);
      hostReport.writeln(msg);
    }

    final dealersBlocked = players
        .where(
          (p) =>
              p.isAlive &&
              p.role.id == 'dealer' &&
              p.blockedKillNight == dayCount,
        )
        .toList();
    if (dealersBlocked.isNotEmpty) {
      final names = dealersBlocked.map((p) => p.name).join(", ");
      final msg =
          "⛔ Blocked! Dealers prevented from killing next night: $names.";
      report.writeln(msg);
      hostReport.writeln(msg);
    }

    // 6. MEDIC REVIVE
    final reviveTargetId = nightActions['medic_revive'];
    if (reviveTargetId != null) {
      try {
        final medic = _playerList.firstWhere(
          (p) => p.role.id == 'medic' && p.isAlive,
        );
        if (!medic.hasReviveToken) {
          final target = _playerMap[reviveTargetId]!;
          if (!target.isAlive) {
            target.isAlive = true;
            target.deathDay = null;
            if (target.lives <= 0) target.lives = 1;
            medic.hasReviveToken = true;
            logAction('Medic Revive', 'Revived ${target.name}.');

            final msg =
                "🧟  IT'S ALIVE! The Medic performed some 'invigorating' mouth-to-mouth and brought ${target.name} back for one last round!";
            report.writeln(msg);
            hostReport.writeln(msg);
          }
        }
      } catch (e) {
        /* ignore */
      }
    }

    // 7. GENERIC REPORTING (Global Stats)
    // Iterate remaining results to provide full transparency for Host
    for (var result in results) {
      if (processedAbilityIds.contains(result.abilityId)) continue;
      // Skip system abilities
      if (result.abilityId.startsWith('system_')) continue;

      if (result.success) {
        final targetNames = result.targets
            .map((id) => _playerMap[id]?.name ?? 'Unknown')
            .join(', ');

        String icon = "📝";
        String msg = "";

        switch (result.abilityId) {
          case 'medic_protect':
            icon = "🩺";
            msg =
                "The Medic gave $targetNames a private 'physical' examination.";
            break;
          case 'whore_redirect':
            icon = "💋";
            msg =
                "The Whore took $targetNames back to the VIP room for a little distraction.";
            break;
          case 'bouncer_check':
            icon = "👮";
            msg =
                "The Bouncer gave $targetNames a full body pat-down. Very thorough.";
            break;
          case 'reporter_scoop':
            icon = "📸";
            msg =
                "The Reporter caught $targetNames in a compromising position.";
            break;
          case 'psychic_read':
            icon = "🔮";
            msg = "The Psychic felt a rising energy coming from $targetNames.";
            break;
          case 'party_animal_party':
            icon = "💃";
            msg =
                "The Party Animal ground up against $targetNames on the dance floor.";
            break;
          case 'bartender_mix':
            icon = "🍸";
            msg =
                "The Bartender served $targetNames something stiff and salty.";
            break;
          case 'cupid_link':
            icon = "💘";
            msg = "Cupid tied $targetNames together in a very kinky knot.";
            break;
          case 'messy_bitch_spread':
            icon = "??";
            final gossipTemplates = [
              "I heard [Target] was on their knees in the VIP lounge... and they certainly weren't praying.",
              "Rumour has it [Target] isn't wearing a single stitch of underwear tonight. Easy access.",
              "[Target] was just seen leaving the handicapped stall with two other people. Must be a tight squeeze.",
              "Someone saw [Target] doing things with an ice cube that honestly shouldn't be legal in public.",
              "[Target] disappeared into the coat check for 20 minutes and came out walking a little funny.",
              "Word is [Target] offered the bartender more than just a cash tip for that last drink.",
              "I saw [Target] drop their keys on purpose just to bend over in front of the DJ. Desperate.",
              "[Target]'s lipstick is smeared, and I'm pretty sure that wasn't their own zipper they were adjusting.",
              "Apparently [Target] has a piercing in a place you usually only show your doctor... or a very lucky date.",
              "[Target] was spotted whispering their room number to arguably the ugliest staff member here.",
              "They say [Target] has a special talent for swallowing... shots. And other things.",
              "[Target] was caught doing body shots off the bouncer's... belt buckle.",
              "Who knew [Target] had a tattoo that says 'Open 24/7' right above their... lower back?",
              "[Target] was seen engaging in some heavy petting in the dark corner. With themselves.",
            ];
            final gossip =
                gossipTemplates[Random().nextInt(gossipTemplates.length)]
                    .replaceAll('[Target]', targetNames);
            messyBitchGossip = gossip;
            // Add prominent gossip to the public report
            report.writeln(" RUMOUR MILL: $gossip");

            msg = "The Messy Bitch spread a rumour about $targetNames.";
            break;
          default:
            final niceName = result.abilityId
                .replaceAll('_', ' ')
                .toUpperCase();
            msg =
                "Action: $niceName on ${targetNames.isEmpty ? 'Self/Global' : targetNames}.";
            icon = "?";
            break;
        }

        if (msg.isNotEmpty) {
          // Host sees detailed stats
          hostReport.writeln("$icon $msg");

          // Apply status effects so Host Overview reflects night actions
          // This makes "Roofie", "Checks", "Protections" etc visible on player cards
          for (var targetId in result.targets) {
            statusEffectManager.applyEffect(
              targetId,
              StatusEffect(
                id: "status_${result.abilityId}_${dayCount}_$targetId",
                name: result.abilityId
                    .split('_')
                    .map((s) => s.toUpperCase())
                    .join(' '),
                description: msg,
                duration: 1, // Lasts for the day
              ),
            );
          }

          // These roles have visible effects that players should see in the Morning Briefing
          if ([
            'party_animal_party',
            'bartender_mix',
          ].contains(result.abilityId)) {
            report.writeln("$icon $msg");
          }
        }
      } else {
        // Report failures too for Host Stats benefit (Private)
        if (result.message == "Ability was blocked") {
          final roleName = result.abilityId.split('_').first.toUpperCase();
          hostReport.writeln(" $roleName action on targets was BLOCKED.");
        }
      }
      processedAbilityIds.add(result.abilityId);
    }

    if (report.length == 0) {
      report.writeln(
        "😴 Surprisingly... nothing happened. It was a quiet night.",
      );
    }

    if (hostReport.length == 0) {
      hostReport.writeln(
        "😴 Surprisingly... nothing happened. It was a quiet night.",
      );
    }
    final deathNames = processedVictims
        .map((id) => _playerMap[id])
        .whereType<Player>()
        .where((p) => !p.isAlive)
        .map((p) => p.name)
        .toList();

    final savedNames = {...protectedIds, ...minorProtectedIds}
        .map((id) => _playerMap[id])
        .whereType<Player>()
        .where((p) => p.isAlive)
        .map((p) => p.name)
        .toList();

    final lifeDingNames = livesLostIds
        .map((id) => _playerMap[id])
        .whereType<Player>()
        .map((p) => p.name)
        .toList();

    final headlineParts = <String>[];
    if (deathNames.isNotEmpty) {
      // Enhanced Death Messages
      for (final name in deathNames) {
        headlineParts.add('$name was spiked and died last night');
      }
    }

    if (savedNames.isNotEmpty) {
      // Enhanced Saved Messages
      for (final name in savedNames) {
        headlineParts.add(
          '$name was nearly spiked by the dealers but was saved from a murder on the dance floor',
        );
      }
    }

    if (lifeDingNames.isNotEmpty) {
      for (final name in lifeDingNames) {
        headlineParts.add('$name took a hit but survived the night');
      }
    }

    if (_clingerDoubleDeaths.isNotEmpty) {
      for (var d in _clingerDoubleDeaths) {
        headlineParts.add(
          "${d['clinger']} died of a broken heart over ${d['obsession']}",
        );
      }
    }

    // Add Silenced Status
    if (silencedToday.isNotEmpty) {
      for (final p in silencedToday) {
        headlineParts.add("${p.name} was silenced by the Bouncer");
      }
    }

    // Add Sent Home Status (Sober)
    if (sentHomePlayers.isNotEmpty) {
      for (final p in sentHomePlayers) {
        headlineParts.add("${p.name} was sent home early by the Sober");
      }
    }

    final nightLabel = dayCount.clamp(1, 99);
    // Combine with new lines for readability rather than ' • ' joiner
    // Check if there were ANY actions (not just deaths/saves) by checking if report buffer has content
    final hasAnyActions = report.length > 0 || headlineParts.isNotEmpty;
    final headline = !hasAnyActions
        ? '? Night $nightLabel recap: All quiet — everyone stumbled back alive.'
        : headlineParts.isNotEmpty
        ? '? Night $nightLabel Summary:\n • ${headlineParts.join('\n • ')}'
        : '? Night $nightLabel Summary';

    // Store stats for UI visualization (Reset each night resolution to show ONLY last night's impact)
    lastNightStats = {
      'deaths': deathNames.length,
      'saved': savedNames.length,
      'injured': lifeDingNames.length,
      'hearts_broken': _clingerDoubleDeaths.length,
    };

    // Store private report
    lastNightHostRecap = "$headline\n\n${hostReport.toString().trimRight()}";

    // Log to Game History for persistence and visibility
    logAction(
      "Morning Report (Night $nightLabel)",
      "$headline\n\n${report.toString().trimRight()}",
    );

    // Return public report
    final body = report.toString().trimRight();
    return [headline, body].where((s) => s.trim().isNotEmpty).join('\n');
  }

  /// Process reactions that trigger when a player dies
  void _processDeathReactions(Player victim, List<PendingReaction> reactions) {
    for (var reaction in reactions) {
      if (reaction.ability.id == 'drama_queen_swap') {
        _handleDramaQueenSwap(reaction);
      } else if (reaction.ability.id == 'tea_spiller_reveal') {
        _handleTeaSpillerReveal(reaction);
      }
    }
  }

  void _handleDramaQueenSwap(PendingReaction reaction) {
    dramaQueenSwapPending = true;
    dramaQueenMarkedAId ??=
        nightActions['drama_swap_a'] ??
        reaction.sourcePlayer.dramaQueenTargetAId;
    dramaQueenMarkedBId ??=
        nightActions['drama_swap_b'] ??
        reaction.sourcePlayer.dramaQueenTargetBId;

    final String? markedAName = dramaQueenMarkedAId != null
        ? (_playerMap[dramaQueenMarkedAId] ?? reaction.sourcePlayer).name
        : null;
    final String? markedBName = dramaQueenMarkedBId != null
        ? (_playerMap[dramaQueenMarkedBId] ?? reaction.sourcePlayer).name
        : null;

    final pendingLine = (markedAName != null && markedBName != null)
        ? "Marked pair: $markedAName ? $markedBName."
        : "No marked pair. Host must choose two players.";

    logAction(
      "Drama Queen's Final Act",
      "${reaction.sourcePlayer.name} died. Open the action menu to swap two players. $pendingLine",
    );
    notifyListeners();
  }

  DramaQueenSwapRecord? completeDramaQueenSwap(Player playerA, Player playerB) {
    try {
      final roleA = playerA.role;
      final roleB = playerB.role;

      // Capture before state
      final fromRoleA = roleA.name;
      final fromRoleB = roleB.name;

      // Perform swap
      playerA.role = roleB;
      playerB.role = roleA;
      _resetPlayerStateForNewRole(playerA);
      _resetPlayerStateForNewRole(playerB);

      final record = DramaQueenSwapRecord(
        day: dayCount,
        playerAName: playerA.name,
        playerBName: playerB.name,
        fromRoleA: fromRoleA,
        fromRoleB: fromRoleB,
        toRoleA: playerA.role.name,
        toRoleB: playerB.role.name,
      );

      lastDramaQueenSwap = record;
      dramaQueenSwapPending = false;
      dramaQueenMarkedAId = null;
      dramaQueenMarkedBId = null;

      logAction(
        "Drama Queen Swap",
        "Swapped ${record.playerAName} (${record.fromRoleA} ? ${record.toRoleA}) with ${record.playerBName} (${record.fromRoleB} ? ${record.toRoleB}).",
      );
      notifyListeners();
      return record;
    } catch (e) {
      debugPrint("Error completing Drama Queen swap: $e");
      return null;
    }
  }

  void _resetPlayerStateForNewRole(Player player) {
    player.initialize();
    player.alliance = player.role.startAlliance ?? player.role.alliance;
    player.lives = 1;
    player.setLivesBasedOnDealers(
      players
          .where((p) => p.role.id == 'dealer' && p.isEnabled && p.isAlive)
          .length,
    );
    player.idCheckedByBouncer = false;
    player.medicChoice = null;
    player.hasReviveToken = false;
    player.creepTargetId = null;
    player.hasRumour = false;
    player.messyBitchKillUsed = false;
    player.clingerPartnerId = null;
    player.clingerFreedAsAttackDog = false;
    player.clingerAttackDogUsed = false;
    player.tabooNames = [];
    player.minorHasBeenIDd = false;
    player.soberAbilityUsed = false;
    player.soberSentHome = false;
    player.silverFoxAbilityUsed = false;
    player.secondWindConverted = false;
    player.secondWindPendingConversion = false;
    player.secondWindRefusedConversion = false;
    player.joinsNextNight = false;
    player.deathDay = null;
    player.silencedDay = null;
    player.blockedKillNight = null;
    player.roofiAbilityRevoked = false;
    player.bouncerAbilityRevoked = false;
    player.teaSpillerTargetId = null;
    player.predatorTargetId = null;
    player.dramaQueenTargetAId = null;
    player.dramaQueenTargetBId = null;
  }

  void _handleTeaSpillerReveal(PendingReaction reaction) {
    String? targetId =
        nightActions['tea_spiller_mark'] ??
        reaction.sourcePlayer.teaSpillerTargetId;

    if (targetId != null) {
      try {
        final revealed = _playerMap[targetId]!;
        logAction(
          "Tea Spilled!",
          "${reaction.sourcePlayer.name} revealed: ${revealed.name} is the ${revealed.role.name}!",
        );
      } catch (e) {
        debugPrint("Error revealing role: $e");
      }
    }
  }

  void _handleCreepInheritance(Player victim) {
    try {
      final creeps = _playerList
          .where(
            (p) =>
                p.role.id == 'creep' &&
                p.isActive &&
                p.creepTargetId == victim.id,
          )
          .toList();

      for (var creep in creeps) {
        logAction(
          "Creep Inheritance",
          "${creep.name} inherited ${victim.role.name} from ${victim.name}",
        );
        creep.role = victim.role;
        creep.alliance = victim.alliance;
        creep.initialize();
      }
    } catch (e) {
      debugPrint("Error processing Creep inheritance: $e");
    }
  }

  void _handleClingerObsessionDeath(Player victim) {
    try {
      final clingers = _playerList
          .where(
            (p) =>
                p.role.id == 'clinger' &&
                p.isActive &&
                p.clingerPartnerId == victim.id &&
                !p.clingerFreedAsAttackDog, // Only die if not freed as attack dog
          )
          .toList();

      for (var clinger in clingers) {
        clinger.die(dayCount, 'clinger_suicide');
        deadPlayerIds.add(clinger.id);

        // Add dramatic double death log
        logAction(
          "?? DOUBLE DEATH ??",
          "OBSESSION OVER! ${clinger.name} (The Clinger) couldn't live without ${victim.name} and has died of a broken heart!",
        );

        // Add to night announcements for morning report
        _clingerDoubleDeaths.add({
          'clinger': clinger.name,
          'obsession': victim.name,
        });

        // Trigger callback for dramatic popup
        onClingerDoubleDeath?.call(clinger.name, victim.name);
      }
    } catch (e) {
      debugPrint("Error processing Clinger obsession death: $e");
    }
  }

  void _assignRoles() {
    final eligiblePlayers = _playerList
        .where((p) => p.isEnabled && p.role.id != 'host')
        .toList();
    if (eligiblePlayers.isEmpty) return;

    final random = Random();

    final dealerRole = roleRepository.getRoleById('dealer');
    if (dealerRole == null) {
      throw RoleAssignmentException(
        'Dealer role is missing from the role repository.',
      );
    }

    final partyAnimalRole = roleRepository.getRoleById('party_animal');
    final medicRole = roleRepository.getRoleById('medic');
    final bouncerRole = roleRepository.getRoleById('bouncer');

    // Separate players
    final manualPlayers = eligiblePlayers
        .where((p) => p.role.id != 'temp')
        .toList();
    final autoPlayers = eligiblePlayers
        .where((p) => p.role.id == 'temp')
        .toList();

    // Track which unique roles are already taken (non-dealer only)
    final usedUniqueRoleIds = <String>{};
    var manualDealerCount = 0;
    for (final p in manualPlayers) {
      if (p.role.id == 'dealer') {
        manualDealerCount++;
      } else if (p.role.id != 'temp') {
        // Party Animals and Dealers can repeat. All others must be unique.
        if (p.role.id != 'party_animal' && !usedUniqueRoleIds.add(p.role.id)) {
          throw RoleAssignmentException(
            'Duplicate role detected: ${p.role.id}. Only Dealers and Party Animals can repeat.',
          );
        }
      }
      p.initialize();
    }

    if (autoPlayers.isNotEmpty) {
      final deck = <Role>[];

      // Dealers: 1 per 7 total enabled players (1 per 6 other roles)
      final recommendedDealers = RoleValidator.recommendedDealerCount(
        eligiblePlayers.length,
      );
      var dealersToAssign = (recommendedDealers - manualDealerCount).clamp(
        0,
        autoPlayers.length,
      );
      for (var i = 0; i < dealersToAssign; i++) {
        deck.add(dealerRole);
      }

      // Ensure required unique roles exist when possible (without duplicating)
      void addRequired(Role? role) {
        if (role == null) return;
        if (role.id == 'dealer') return;
        if (usedUniqueRoleIds.contains(role.id)) return;
        if (deck.length >= autoPlayers.length) return;
        usedUniqueRoleIds.add(role.id);
        deck.add(role);
      }

      // Keep the game functional: prefer at least one Party Animal and at least one Medic/Bouncer
      addRequired(partyAnimalRole);
      if (!usedUniqueRoleIds.contains('medic') &&
          !usedUniqueRoleIds.contains('bouncer')) {
        addRequired(medicRole ?? bouncerRole);
      }

      // Fill remaining with unique roles (excluding dealer)
      final candidates = roleRepository.roles
          .where((r) => r.id != 'dealer' && r.id != 'temp' && r.id != 'host')
          .where((r) => !usedUniqueRoleIds.contains(r.id))
          .toList();
      candidates.shuffle(random);

      for (final role in candidates) {
        if (deck.length >= autoPlayers.length) break;
        usedUniqueRoleIds.add(role.id);
        deck.add(role);
      }

      if (deck.length < autoPlayers.length) {
        throw RoleAssignmentException(
          'Not enough unique roles to assign ${autoPlayers.length} player(s). '
          'Add more roles to roles.json or reduce enabled players.',
        );
      }

      deck.shuffle(random);
      for (var i = 0; i < autoPlayers.length; i++) {
        autoPlayers[i].role = deck[i];
        autoPlayers[i].initialize();
      }
    }

    // Initialize Seasoned Drinker lives based on dealer count
    final dealerCount = eligiblePlayers
        .where((p) => p.role.id == 'dealer')
        .length;
    for (var player in eligiblePlayers) {
      player.setLivesBasedOnDealers(dealerCount);
    }
  }

  void logAction(
    String title,
    String description, {
    GameLogType type = GameLogType.action,
  }) {
    _gameLog.insert(
      0,
      GameLogEntry(
        turn: dayCount,
        phase: _currentPhase.name.toUpperCase(),
        title: title,
        description: description,
        timestamp: DateTime.now(),
        type: type,
      ),
    );
    notifyListeners();
  }

  void handleScriptAction(ScriptStep step, List<String> selectedPlayerIds) {
    if (selectedPlayerIds.isEmpty) {
      logAction(step.title, "No selection made.");
      return;
    }

    final selections = selectedPlayerIds.toList();
    final String? roleId = step.roleId;

    Player resolvePlayer(String id) =>
        _playerMap[id] ??
        Player(
          id: '?',
          name: 'Unknown',
          role: Role(
            id: '?',
            name: 'Unknown',
            alliance: '?',
            type: '?',
            description: '',
            nightPriority: 0,
            assetPath: '',
            colorHex: '#FFFFFF',
          ),
        );

    // Find the source player for this action
    Player? sourcePlayer;
    try {
      sourcePlayer = _playerList.firstWhere(
        (p) => p.role.id == roleId && p.isActive,
      );
    } catch (e) {
      debugPrint("Could not find source player for role: $roleId");
    }

    // Map role-specific actions and create ability instances
    switch (roleId) {
      case 'dealer':
        if (step.id == 'second_wind_conversion_vote') {
          // Handle Conversion Vote
          // Typical toggle output is "true" (Yes) or "false" (No)
          bool accepted =
              selections.isNotEmpty &&
              (selections.first == 'true' ||
                  selections.first == 'yes' ||
                  selections.first == '1');

          final secondWind = _playerList.firstWhere(
            (p) => p.secondWindPendingConversion,
            orElse: () => _playerList.first,
          );
          if (secondWind.id != _playerList.first.id) {
            if (accepted) {
              logAction(step.title, "Dealers chose to CONVERT Second Wind.");
              // Perform Conversion
              final dealerRole = roleRepository.getRoleById('dealer');
              if (dealerRole != null) {
                secondWind.role = dealerRole;
                secondWind.alliance = dealerRole.alliance;
                secondWind.isAlive = true;
                secondWind.secondWindConverted = true;
                secondWind.secondWindPendingConversion = false;
                secondWind.initialize();

                // Cancel the kill on them
                nightActions.remove('kill');

                // Cancel the queued ability so they don't die
                abilityResolver.cancelAbility(
                  'dealer_kill',
                  targetPlayerId: secondWind.id,
                );
              }
            } else {
              logAction(step.title, "Dealers chose to KILL Second Wind.");
              secondWind.secondWindRefusedConversion = true;
              secondWind.secondWindPendingConversion = false;
              // Kill action proceeds as normal in _resolveNightPhase
            }
          }
          break;
        }

        final target = resolvePlayer(selections.first);
        nightActions['kill'] = target.id;

        // Queue the ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'dealer_kill',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.kill,
            priority: 5,
          ),
        );

        logAction(step.title, "Dealers selected ${target.name} to eliminate.");

        // Check for Second Wind Trigger
        if (target.role.id == 'second_wind' &&
            !target.secondWindConverted &&
            !target.secondWindRefusedConversion) {
          // Check if already protected (Medic acts before Dealers in script)
          bool isProtected = nightActions['protect'] == target.id;

          if (!isProtected) {
            target.secondWindPendingConversion = true;
            // Force script rebuild to inject the Conversion Vote step
            // This ensures the Host sees the "Second Wind Conversion Decision" immediately
            rebuildNightScript();
          }
        }
        break;

      case 'medic':
        final target = resolvePlayer(selections.first);
        final medic = _playerList
            .where((p) => p.role.id == 'medic')
            .firstOrNull;

        // Medic only wakes at night if they chose PROTECT_DAILY
        // This step should only appear if medicChoice == 'PROTECT_DAILY'
        if (medic != null && medic.medicChoice == 'PROTECT_DAILY') {
          nightActions['protect'] = target.id;

          // Queue protection ability
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'medic_protect',
              sourcePlayerId: medic.id,
              targetPlayerIds: [target.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.protect,
              priority: 2,
            ),
          );

          logAction(step.title, "Medic protected ${target.name}.");
        }
        break;

      case 'whore':
        final target = resolvePlayer(selections.first);

        // Queue redirect ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'whore_redirect',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.redirect, // Use redirect effect
            priority: 3,
            metadata: {
              'roleName': 'The Whore', // For logging
              'redirect_type': 'vote_deflection',
            },
          ),
        );

        // Keep legacy map for safety until voting logic is fully refactored
        nightActions['whore_redirect_target'] = target.id;

        logAction(
          step.title,
          "Whore selected ${target.name} to deflect votes to.",
        );
        break;

      case 'bouncer':
        final target = resolvePlayer(selections.first);
        nightActions['bouncer_check'] = target.id;

        // Mark target as checked (used by Minor protection rules)
        target.idCheckedByBouncer = true;
        if (target.role.id == 'minor') {
          target.minorHasBeenIDd = true;
        }

        // Queue investigate ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'bouncer_check',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.investigate,
            priority: 4,
            metadata: {'roleName': 'The Bouncer', 'result': target.alliance},
          ),
        );

        logAction(
          step.title,
          "Bouncer I.D.'d ${target.name} ? ${target.alliance}.",
        );
        break;

      case 'roofi':
        final target = resolvePlayer(selections.first);
        nightActions['roofi'] = target.id;

        // Queue silence ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'roofi_silence',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.silence,
            priority: 4,
          ),
        );
        // Apply fine-tuned effects:
        // - Everyone: silenced next Day (cannot talk/move)
        // - If target is a Dealer: also blocked from killing the following Night
        target.silencedDay = dayCount + 1;
        if (target.role.id == 'dealer') {
          target.blockedKillNight = dayCount + 1;
          logAction(
            step.title,
            "Roofi silenced ${target.name} (Dealer). They cannot speak during Day ${dayCount + 1} and cannot participate in the kill on Night ${dayCount + 1}.",
          );
        } else {
          logAction(
            step.title,
            "Roofi silenced ${target.name} for Day ${dayCount + 1}.",
          );
        }
        break;

      case 'messy_bitch':
        final target = resolvePlayer(selections.first);

        // Queue spread ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'messy_bitch_spread',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.spread,
            priority: 6,
          ),
        );

        logAction(step.title, "Messy Bitch spread a rumour to ${target.name}.");
        checkMessyBitchWin();
        break;

      case 'creep':
        final target = resolvePlayer(selections.first);
        nightActions['creep_target'] = target.id;

        // Queue mimic ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'creep_mimic',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.copy,
            priority: 1, // High priority to ensure mimic happens early
            metadata: {
              'roleName': 'The Creep',
              'mimic_role': target.role.name,
              'mimic_alliance': target.role.alliance,
            },
          ),
        );

        logAction(step.title, "Creep chose to mimic ${target.name}.");
        break;

      case 'clinger':
        final target = resolvePlayer(selections.first);

        if (step.id == 'clinger_act') {
          // Attack Dog Ability (Kill)
          nightActions['kill_clinger'] = target.id;

          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'clinger_attack_dog',
              sourcePlayerId: sourcePlayer?.id ?? 'unknown',
              targetPlayerIds: [target.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.kill,
              priority: 4,
              metadata: {'roleName': 'The Clinger'},
            ),
          );

          final clinger = _playerList.firstWhere((p) => p.role.id == 'clinger');
          clinger.clingerAttackDogUsed = true;
          logAction(
            step.title,
            "Clinger used Attack Dog ability on ${target.name}.",
          );
        } else {
          // Night 0 Setup (Obsession)
          try {
            final clinger = _playerList.firstWhere(
              (p) => p.role.id == 'clinger',
            );
            // We set it here for immediate state, but also queue it for persistence/logs
            clinger.clingerPartnerId = target.id;
            nightActions['clinger_obsession'] = target.id;

            abilityResolver.queueAbility(
              ActiveAbility(
                abilityId: 'clinger_obsession',
                sourcePlayerId: clinger.id,
                targetPlayerIds: [target.id],
                trigger: AbilityTrigger.startup,
                effect: AbilityEffect.mark,
                priority: 0,
                metadata: {'roleName': 'The Clinger', 'mark_type': 'obsession'},
              ),
            );

            logAction(
              step.title,
              "Clinger chose ${target.name} as their obsession.",
            );
          } catch (e) {
            debugPrint("Error setting clinger obsession: $e");
          }
        }
        break;

      case 'bartender':
        if (selections.length == 2) {
          final p1 = resolvePlayer(selections[0]);
          final p2 = resolvePlayer(selections[1]);

          // Check if alliances match (Party Animals vs Dealers)
          // Neutrals are considered solo and never on the "same team"
          bool sameTeam = p1.alliance == p2.alliance;
          if (p1.alliance.contains("Neutral") || p1.alliance.contains("None")) {
            sameTeam = false;
          }

          // Queue ability for record keeping
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'bartender_check',
              sourcePlayerId: sourcePlayer?.id ?? 'unknown',
              targetPlayerIds: [p1.id, p2.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.investigate,
              priority: 5,
              metadata: {
                'roleName': 'The Bartender',
                'result_same_team': sameTeam,
              },
            ),
          );

          logAction(
            step.title,
            "Bartender checked ${p1.name} and ${p2.name}. Match: $sameTeam",
          );
          onBartenderCheck?.call(p1.name, p2.name, sameTeam);
        }
        break;

      case 'drama_queen':
        if (selections.length >= 2) {
          final first = resolvePlayer(selections[0]);
          final second = resolvePlayer(selections[1]);
          nightActions['drama_swap_a'] = first.id;
          nightActions['drama_swap_b'] = second.id;
          dramaQueenMarkedAId = first.id;
          dramaQueenMarkedBId = second.id;

          if (sourcePlayer != null) {
            sourcePlayer.dramaQueenTargetAId = first.id;
            sourcePlayer.dramaQueenTargetBId = second.id;
          }

          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'drama_queen_mark_pair',
              sourcePlayerId: sourcePlayer?.id ?? 'unknown',
              targetPlayerIds: [first.id, second.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.mark,
              priority: 3,
              metadata: {'roleName': 'Drama Queen', 'mark_type': 'swap_pair'},
            ),
          );

          logAction(
            step.title,
            "Drama Queen marked ${first.name} and ${second.name} for swap on death.",
          );
        } else {
          final target = resolvePlayer(selections.first);
          dramaQueenMarkedAId = target.id;
          dramaQueenMarkedBId = null;

          if (sourcePlayer != null) {
            sourcePlayer.dramaQueenTargetAId = target.id;
            sourcePlayer.dramaQueenTargetBId = null;
          }

          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'drama_queen_mark_single',
              sourcePlayerId: sourcePlayer?.id ?? 'unknown',
              targetPlayerIds: [target.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.mark,
              priority: 3,
              metadata: {
                'roleName': 'Drama Queen',
                'mark_type': 'swap_partial',
              },
            ),
          );

          logAction(
            step.title,
            "Drama Queen selected ${target.name} (needs two targets for swap).",
          );
        }
        break;

      case 'tea_spiller':
        final target = resolvePlayer(selections.first);
        nightActions['tea_spiller_mark'] = target.id;

        if (sourcePlayer != null) {
          sourcePlayer.teaSpillerTargetId = target.id;
        }

        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'tea_spiller_mark',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.mark,
            priority: 3,
            metadata: {
              'roleName': 'Tea Spiller',
              'mark_type': 'reveal_on_death',
            },
          ),
        );

        logAction(
          step.title,
          "Tea Spiller marked ${target.name} for reveal on death.",
        );
        break;

      case 'predator':
        final target = resolvePlayer(selections.first);
        nightActions['predator_mark'] = target.id;

        if (sourcePlayer != null) {
          sourcePlayer.predatorTargetId = target.id;
        }

        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'predator_mark',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.mark,
            priority: 3,
            metadata: {'roleName': 'The Predator', 'mark_type': 'retaliation'},
          ),
        );

        logAction(
          step.title,
          "Predator will retaliate against ${target.name} if voted out.",
        );
        break;

      case 'messy_bitch_kill':
        final target = resolvePlayer(selections.first);
        final messyBitch = _playerList.firstWhere(
          (p) => p.role.id == 'messy_bitch',
        );

        // Mark kill as used
        messyBitch.messyBitchKillUsed = true;

        // Queue immediate kill ability
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'messy_bitch_special_kill',
            sourcePlayerId: messyBitch.id,
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.kill,
            priority: 1, // High priority to execute early
          ),
        );

        logAction(
          step.title,
          "Messy Bitch used her special kill on ${target.name}.",
        );
        break;

      case 'club_manager':
      case 'club_manager_act':
        final target = resolvePlayer(selections.first);

        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'club_manager_investigate',
            sourcePlayerId: sourcePlayer?.id ?? 'unknown',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.investigate,
            priority: 5,
            metadata: {
              'roleName': 'Club Manager',
              'result_role': target.role.name,
            },
          ),
        );

        logAction(
          step.title,
          "Club Manager viewed ${target.name}'s role: ${target.role.name}",
        );

        // Trigger callback to show role reveal to host
        onClubManagerReveal?.call(target);
        break;

      case 'silver_fox':
        final target = resolvePlayer(selections.first);

        if (sourcePlayer != null && !sourcePlayer.silverFoxAbilityUsed) {
          sourcePlayer.silverFoxAbilityUsed = true;
          nightActions['silver_fox_reveal'] = target.id;

          // Queue reveal ability
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: AbilityLibrary.silverFoxReveal.id,
              sourcePlayerId: sourcePlayer.id,
              targetPlayerIds: [target.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.reveal,
              priority: 1,
              metadata: {'roleName': 'Silver Fox'},
            ),
          );

          logAction(
            step.title,
            "Silver Fox chose to force ${target.name} to reveal their role tomorrow.",
          );
        } else {
          logAction(
            step.title,
            "Silver Fox ability already used or no source player.",
          );
        }
        break;

      case 'wallflower':
        if (selections.isNotEmpty) {
          // Wallflower chose to witness
          // Query the nightActions right now for immediate feedback in log
          String witnessResult = "No murder seen.";
          if (nightActions.containsKey('kill')) {
            final victimId = nightActions['kill'];
            final victim = resolvePlayer(victimId!);
            witnessResult = "${victim.name} targeted.";
          }

          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'wallflower_witness',
              sourcePlayerId: sourcePlayer?.id ?? 'unknown',
              targetPlayerIds: [], // Witnesses the "scene", no specific target
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.investigate,
              priority: 6, // Late priority to see kills
              metadata: {
                'roleName': 'The Wallflower',
                'witness_result': witnessResult,
              },
            ),
          );

          if (nightActions.containsKey('kill')) {
            final victimId = nightActions['kill'];
            final victim = resolvePlayer(victimId!);
            logAction(
              step.title,
              "Wallflower witnessed that ${victim.name} was targeted by the Dealers.",
            );
          } else {
            logAction(
              step.title,
              "Wallflower attempted to witness, but no murder occurred tonight.",
            );
          }
        } else {
          // Explicitly log "No Action" so we have a record that they woke up
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'wallflower_skip',
              sourcePlayerId: sourcePlayer?.id ?? 'unknown',
              targetPlayerIds: [],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.investigate, // Dummy effect
              priority: 6,
              metadata: {'roleName': 'The Wallflower', 'action': 'skip'},
            ),
          );
          logAction(step.title, "Wallflower chose not to witness.");
        }
        break;

      case 'sober':
        final target = resolvePlayer(selections.first);

        if (sourcePlayer != null && !sourcePlayer.soberAbilityUsed) {
          sourcePlayer.soberAbilityUsed = true;
          target.soberSentHome = true;

          // Queue protection ability
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'sober_send_home',
              sourcePlayerId: sourcePlayer.id,
              targetPlayerIds: [target.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.protect,
              priority: 1, // Early priority to intercept before kills
            ),
          );

          // Also block them from acting
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'sober_block_${step.id}',
              sourcePlayerId: sourcePlayer.id,
              targetPlayerIds: [target.id],
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.block,
              priority: 1,
            ),
          );

          // Dynamic Script Adjustment: Block the target's role from waking/acting
          for (int i = _scriptIndex + 1; i < _scriptQueue.length; i++) {
            // Check if step belongs to the target's role
            if (_scriptQueue[i].roleId == target.role.id) {
              // Special handling for Dealers (Group Role)
              if (target.role.id == 'dealer') {
                if (_scriptQueue[i].id.contains('wake')) {
                  _scriptQueue[i] = ScriptStep(
                    id: 'dealer_blocked_wake',
                    title: 'The Dealers (Blocked)',
                    readAloudText: "Dealers, open your eyes.",
                    instructionText:
                        "Dealers have been blocked because ${target.name} was sent home.",
                    roleId: 'dealer',
                    isNight: true,
                  );
                } else if (_scriptQueue[i].actionType ==
                    ScriptActionType.selectPlayer) {
                  _scriptQueue[i] = ScriptStep(
                    id: 'dealer_blocked_inform',
                    title: 'Kill Blocked',
                    readAloudText: "You cannot kill tonight.",
                    instructionText:
                        "Inform them: One of the Dealers was sent home by The Sober.\nSignal them to sleep.",
                    roleId: 'dealer',
                    actionType: ScriptActionType.showInfo,
                    isNight: true,
                  );
                } else if (_scriptQueue[i].id.contains('sleep')) {
                  _scriptQueue[i] = ScriptStep(
                    id: 'dealer_blocked_sleep',
                    title: 'Dealers Sleep',
                    readAloudText: "Dealers, close your eyes.",
                    instructionText: "",
                    roleId: 'dealer',
                    isNight: true,
                  );
                }
              } else {
                // Generic Individual Role Blocking (Medic, Bouncer, etc.)
                // They are sent home, so they are effectively skipped.
                _scriptQueue[i] = ScriptStep(
                  id: '${target.role.id}_blocked_sober',
                  title: '${target.role.name} (Sent Home)',
                  readAloudText: "(Skip ${target.role.name})",
                  instructionText:
                      "${target.name} was sent home. Validated status: Asleep.",
                  roleId: target.role.id,
                  actionType: ScriptActionType.showInfo,
                  isNight: true,
                );
              }
            }
          }

          // Fully rebuild the remaining night to ensure the sent-home player is removed from all wakes.
          rebuildNightScript();

          if (target.role.id == 'dealer') {
            logAction(
              step.title,
              "Sober sent ${target.name} (a Dealer!) home. NO murders tonight!",
            );
          } else {
            logAction(
              step.title,
              "Sober sent ${target.name} home. They are protected and blocked tonight.",
            );
          }
        } else {
          logAction(step.title, "Sober ability already used.");
        }
        break;

      case 'lightweight':
        final target = resolvePlayer(selections.first);

        if (sourcePlayer != null) {
          // Add the new taboo name to the list
          if (!sourcePlayer.tabooNames.contains(target.name)) {
            sourcePlayer.tabooNames.add(target.name);

            // Queue ability for status tracking
            abilityResolver.queueAbility(
              ActiveAbility(
                abilityId: 'lightweight_taboo',
                sourcePlayerId: sourcePlayer.id,
                targetPlayerIds: [target.id], // The target whose name is taboo
                trigger: AbilityTrigger.nightAction,
                effect: AbilityEffect.modify,
                priority: 0,
                metadata: {
                  'roleName': 'The Lightweight',
                  'taboo_name': target.name,
                },
              ),
            );

            logAction(
              step.title,
              "Lightweight now has ${target.name} as a taboo name (Total: ${sourcePlayer.tabooNames.length}).",
            );
          } else {
            logAction(
              step.title,
              "${target.name} is already a taboo name for Lightweight.",
            );
          }
        }
        break;

      default:
        final names = selections.map((id) => resolvePlayer(id).name).join(', ');
        logAction(step.title, "Selected: $names");
        break;
    }
  }

  /// Handles option-based script steps (e.g., Medic choose PROTECT vs REVIVE at setup).
  void handleScriptOption(ScriptStep step, String selectedOption) {
    if (step.id == 'second_wind_decision') {
      final option = selectedOption.toLowerCase();
      bool accepted =
          option == 'yes' || option == 'true' || option == 'convert';

      final secondWind = players.firstWhere(
        (p) => p.secondWindPendingConversion,
        orElse: () => players.first,
      );

      if (secondWind.id != players.first.id ||
          secondWind.secondWindPendingConversion) {
        if (accepted) {
          logAction(
            "Second Wind Decision",
            "Dealers chose to CONVERT Second Wind.",
          );
          final dealerRole = roleRepository.getRoleById('dealer');
          if (dealerRole != null) {
            secondWind.role = dealerRole;
            secondWind.alliance = dealerRole.alliance;
            secondWind.isAlive = true;
            secondWind.secondWindConverted = true;
            secondWind.secondWindPendingConversion = false;
            secondWind.initialize();
          }
        } else {
          logAction(
            "Second Wind Decision",
            "Dealers chose to KILL Second Wind.",
          );
          secondWind.secondWindRefusedConversion = true;
          secondWind.secondWindPendingConversion = false;
          // Kill action proceeds as normal in _resolveNightPhase
        }
      }
      notifyListeners();
      return;
    }

    final roleId = step.roleId;

    switch (roleId) {
      case 'medic':
        final option = selectedOption.toLowerCase();
        if (option != 'protect' && option != 'revive') return;

        // Store permanently in Player's medicChoice field (Night 0 setup only)
        final medic = players.where((p) => p.role.id == 'medic').firstOrNull;
        if (medic != null) {
          medic.medicChoice = option == 'protect'
              ? 'PROTECT_DAILY'
              : 'RESUSCITATE_ONCE';
          logAction(
            step.title,
            'Medic permanently chose: ${medic.medicChoice}',
          );
        }
        break;
      default:
        logAction(step.title, 'Selected option: $selectedOption');
        break;
    }
    notifyListeners();
  }

  void checkMessyBitchWin() {
    // Find Messy Bitch
    try {
      final messyBitch = players.firstWhere(
        (p) => p.role.id == 'messy_bitch' && p.isAlive,
      );

      // Check if all OTHER alive players have a rumour
      final others = players
          .where((p) => p.id != messyBitch.id && p.isAlive)
          .toList();
      if (others.isNotEmpty && others.every((p) => p.hasRumour)) {
        logAction(
          "Messy Bitch Victory!",
          "The Messy Bitch has spread rumours to everyone alive!",
        );
        if (!messyBitchVictoryAnnounced) {
          _messyBitchVictoryPending = true;
          messyBitchVictoryAnnounced = true;
          notifyListeners(); // Trigger UI update
        }
      }
    } catch (_) {}
  }

  bool _messyBitchVictoryPending = false;
  bool messyBitchVictoryAnnounced =
      false; // To ensure we only announce once per game

  bool get messyBitchVictoryPending => _messyBitchVictoryPending;

  void clearMessyBitchVictoryPending() {
    _messyBitchVictoryPending = false;
    notifyListeners();
  }

  // --- Persistence Methods ---

  Future<void> saveGame(String saveName) async {
    final prefs = await SharedPreferences.getInstance();
    final saveId = DateTime.now().millisecondsSinceEpoch.toString();

    // Players
    final playersJson = jsonEncode(_playerList.map((p) => p.toJson()).toList());

    // Log
    final logJson = jsonEncode(_gameLog.map((l) => l.toJson()).toList());

    // Save game data
    await prefs.setString('gameState_${saveId}_players', playersJson);
    await prefs.setString('gameState_${saveId}_log', logJson);
    await prefs.setInt('gameState_${saveId}_phase', _currentPhase.index);
    await prefs.setInt('gameState_${saveId}_dayCount', dayCount);
    await prefs.setInt('gameState_${saveId}_scriptIndex', _scriptIndex);
    await prefs.setString(
      'gameState_${saveId}_lastNightSummary',
      lastNightSummary,
    );
    await prefs.setString(
      'gameState_${saveId}_lastNightHostRecap',
      lastNightHostRecap,
    );
    await prefs.setString(
      'gameState_${saveId}_lastNightStats',
      jsonEncode(lastNightStats),
    );
    if (messyBitchGossip != null) {
      await prefs.setString(
        'gameState_${saveId}_messyBitchGossip',
        messyBitchGossip!,
      );
    }

    // Create save metadata
    final saveMetadata = SavedGame(
      id: saveId,
      name: saveName,
      savedAt: DateTime.now(),
      dayCount: dayCount,
      alivePlayers: _playerList.where((p) => p.isActive).length,
      totalPlayers: _playerList.where((p) => p.isEnabled).length,
      currentPhase: _currentPhase.toString().split('.').last,
    );

    // Add to saves list
    final saves = await getSavedGames();
    saves.add(saveMetadata);
    await prefs.setString(
      'savedGames',
      jsonEncode(saves.map((s) => s.toJson()).toList()),
    );

    debugPrint("Game saved as: $saveName");
  }

  Future<List<SavedGame>> getSavedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final savesJson = prefs.getString('savedGames');
    if (savesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(savesJson);
      return decoded.map((json) => SavedGame.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error loading saved games list: $e");
      return [];
    }
  }

  Future<bool> loadGame(String saveId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('gameState_${saveId}_players')) return false;

    try {
      // Load Players
      final playersStr = prefs.getString('gameState_${saveId}_players');
      if (playersStr != null) {
        final List<dynamic> decoded = jsonDecode(playersStr);
        _playerList.clear();
        _playerMap.clear();
        final loadedPlayers = decoded.map((json) {
          // We need to find the role object
          String roleId = json['roleId'];
          Role role =
              roleRepository.getRoleById(roleId) ??
              Role(
                id: 'temp',
                name: 'Unknown',
                alliance: 'None',
                type: 'None',
                description: '',
                nightPriority: 0,
                assetPath: '',
                colorHex: '#FFFFFF',
              );
          return Player.fromJson(json, role);
        }).toList();

        for (var p in loadedPlayers) {
          _playerList.add(p);
          _playerMap[p.id] = p;
        }
      }

      // Load Log
      final logStr = prefs.getString('gameState_${saveId}_log');
      if (logStr != null) {
        final List<dynamic> decoded = jsonDecode(logStr);
        _gameLog = decoded.map((j) => GameLogEntry.fromJson(j)).toList();
      }

      // State
      int? phaseIdx = prefs.getInt('gameState_${saveId}_phase');
      if (phaseIdx != null && phaseIdx < GamePhase.values.length) {
        _currentPhase = GamePhase.values[phaseIdx];
      }

      dayCount = prefs.getInt('gameState_${saveId}_dayCount') ?? 0;
      _scriptIndex = prefs.getInt('gameState_${saveId}_scriptIndex') ?? 0;
      lastNightSummary =
          prefs.getString('gameState_${saveId}_lastNightSummary') ?? '';
      lastNightHostRecap =
          prefs.getString('gameState_${saveId}_lastNightHostRecap') ?? '';
      messyBitchGossip = prefs.getString(
        'gameState_${saveId}_messyBitchGossip',
      );

      final statsStr = prefs.getString('gameState_${saveId}_lastNightStats');
      if (statsStr != null) {
        lastNightStats = Map<String, int>.from(jsonDecode(statsStr));
      } else {
        lastNightStats = {};
      }

      // Load History & Status Effects
      final historyStr = prefs.getString('gameState_${saveId}_history');
      if (historyStr != null) {
        reactionSystem.loadHistoryFromJson(jsonDecode(historyStr));
      } else {
        reactionSystem.clearHistory();
      }

      final statusStr = prefs.getString('gameState_${saveId}_statusEffects');
      if (statusStr != null) {
        statusEffectManager.loadFromJson(jsonDecode(statusStr));
      } else {
        statusEffectManager.clearAll();
      }

      final queueStr = prefs.getString('gameState_${saveId}_abilityQueue');
      if (queueStr != null) {
        abilityResolver.loadFromJson(jsonDecode(queueStr));
      } else {
        abilityResolver.clear();
      }

      // Reconstruct Script
      if (_currentPhase == GamePhase.night) {
        _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
      } else if (_currentPhase == GamePhase.day) {
        _scriptQueue = ScriptBuilder.buildDayScript(
          dayCount,
          "Game Loaded.",
          players,
        );
      } else {
        // If loading in setup/lobby state
        _scriptQueue = [];
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error loading game: $e");
      return false;
    }
  }

  Future<void> deleteSavedGame(String saveId) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove game data
    await prefs.remove('gameState_${saveId}_players');
    await prefs.remove('gameState_${saveId}_log');
    await prefs.remove('gameState_${saveId}_phase');
    await prefs.remove('gameState_${saveId}_dayCount');
    await prefs.remove('gameState_${saveId}_scriptIndex');

    // Remove from saves list
    final saves = await getSavedGames();
    saves.removeWhere((s) => s.id == saveId);
    await prefs.setString(
      'savedGames',
      jsonEncode(saves.map((s) => s.toJson()).toList()),
    );

    debugPrint("Game deleted: $saveId");
  }

  void resetGame() {
    _playerList.clear();
    _playerMap.clear();
    _scriptQueue.clear();
    _scriptIndex = 0;
    _currentPhase = GamePhase.lobby;
    dayCount = 0;
    nightActions.clear();
    deadPlayerIds.clear();
    _gameLog.clear();
    abilityResolver.clear();
    reactionSystem.clearAllReactions();
    reactionSystem.clearHistory();
    statusEffectManager.clearAll();
    chainResolver.clear();
    _abilityTargets.clear();
    lastNightStats.clear();
    lastNightSummary = '';
    messyBitchGossip = null;
    notifyListeners();
  }

  /// Handle a player being voted out during the day phase
  /// Returns true if a Dealer was caught, false if innocent
  bool voteOutPlayer(String playerId) {
    final player = _playerMap[playerId];
    if (player == null) return false;

    // Mark that a vote was made during this day phase
    _dayphaseVotesMade = true;

    // Trigger voting event
    final voteEvent = GameEvent(
      type: GameEventType.playerVoted,
      targetPlayerId: playerId,
      data: {'phase': 'day', 'votedOut': true},
    );

    reactionSystem.triggerEvent(voteEvent, _playerList);

    // Check for Predator retaliation
    if (player.role.id == 'predator') {
      final retaliationTarget =
          nightActions['predator_mark'] ?? player.predatorTargetId;
      if (retaliationTarget != null) {
        final victim = _playerMap[retaliationTarget] ?? _playerList.first;
        if (victim.id == retaliationTarget) {
          processDeath(victim, cause: 'predator_revenge');
          logAction(
            "Predator's Revenge",
            "As ${player.name} was voted out, they took ${victim.name} with them!",
          );
        }
      }
    }

    // Process other death reactions (handled within processDeath now mostly, but vote specific event is "playerDied" with 'vote')
    // We used to trigger manually here. processDeath does it too.
    // However, we want to trigger specifically for the *voted* player before they die?
    // No, processDeath handles it.

    // Store whether a dealer was caught before killing the player
    final wasDealer = player.alliance == 'The Dealers';

    // WHORE VOTE DEFLECTION CHECK
    final whoreRedirectTargetId = nightActions['whore_redirect_target'];
    if ((wasDealer || player.role.id == 'whore') &&
        whoreRedirectTargetId != null) {
      final redirectPlayer =
          _playerMap[whoreRedirectTargetId] ?? _playerList.first;

      // If the Whore set a redirection target, and a Dealer or the Whore was voted out...
      // The original target SURVIVES and the redirected TARGET DIES.
      if (redirectPlayer.id == whoreRedirectTargetId &&
          redirectPlayer.isAlive) {
        // Log the deflection
        logAction(
          "Vote Deflection",
          "The Whore deflected the vote! ${player.name} survives, and ${redirectPlayer.name} dies instead.",
        );

        // Kill the deflected target instead
        processDeath(redirectPlayer, cause: 'vote_deflected');

        // The original target stays alive
        notifyListeners();
        return true; // A dealer-aligned player was caught, even if not killed
      }
    }

    // Kill the voted player
    processDeath(player, cause: 'vote');

    if (player.isAlive) {
      // Player survived (e.g. Second Wind)
      // Log generic participation but not death
      logAction(
        "Vote Survival",
        "${player.name} received the most votes but survived.",
      );
    } else {
      logAction("Voted Out", "${player.name} was voted out by the group.");
    }

    notifyListeners();

    return wasDealer;
  }

  void killLightweightForTaboo(String lightweightPlayerId, String spokenName) {
    try {
      final lightweight = _playerMap[lightweightPlayerId];
      if (lightweight != null &&
          lightweight.role.id == 'lightweight' &&
          lightweight.tabooNames.contains(spokenName)) {
        processDeath(lightweight, cause: 'spoke_taboo_name');
        logAction(
          "Taboo!",
          "${lightweight.name} (The Lightweight) spoke the taboo name '$spokenName' and died!",
        );
      }
    } catch (e) {
      debugPrint("Error in killLightweightForTaboo: $e");
    }
  }

  void liberateClinger(String clingerPlayerId) {
    try {
      final clinger = _playerMap[clingerPlayerId];
      if (clinger != null &&
          clinger.role.id == 'clinger' &&
          !clinger.clingerFreedAsAttackDog) {
        clinger.clingerFreedAsAttackDog = true;
        logAction(
          "Clinger Liberated!",
          "${clinger.name} (The Clinger) was called 'controller' and has been liberated! They are now an Attack Dog.",
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error in liberateClinger: $e");
    }
  }

  String? getClingerObsessionId(String clingerPlayerId) {
    try {
      final clinger = _playerMap[clingerPlayerId];
      if (clinger != null && clinger.role.id == 'clinger') {
        return clinger.clingerPartnerId;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if game has ended and determine winner
  GameEndResult? checkGameEnd() {
    final alivePlayers = _playerList.where((p) => p.isActive).toList();

    if (alivePlayers.isEmpty) {
      return GameEndResult(
        winner: 'NONE',
        message: 'Everyone died! No one wins.',
      );
    }

    // Count alliances
    final dealerCount = alivePlayers
        .where((p) => p.alliance == 'The Dealers')
        .length;
    final partyAnimalCount = alivePlayers
        .where((p) => p.alliance == 'The Party Animals')
        .length;

    // Party Animals win if all Dealers are dead
    if (dealerCount == 0 && partyAnimalCount > 0) {
      return GameEndResult(
        winner: 'PARTY_ANIMAL',
        message: 'The Party Animals saved the club!',
      );
    }

    // Check for Messy Bitch solo victory first (absolute win)
    if (messyBitchVictoryAnnounced) {
      final messyBitch = _playerList.firstWhere(
        (p) => p.role.id == 'messy_bitch' && p.isAlive,
        orElse: () => _playerList.first,
      );
      if (messyBitch.role.id == 'messy_bitch') {
        return GameEndResult(
          winner: 'MESSY_BITCH',
          message: '${messyBitch.name} won by spreading all the rumours!',
        );
      }
    }

    // Game ends if only one dealer and one party animal remain
    if (dealerCount == 1 && partyAnimalCount == 1 && alivePlayers.length == 2) {
      return GameEndResult(
        winner: 'DRAW',
        message:
            'Final showdown! One Dealer and one Party Animal remain - it\'s a Standoff!',
      );
    }

    // Dealers win if they outnumber Party Animals
    if (dealerCount > partyAnimalCount) {
      // Logic Check: If Messy Bitch is alive when Dealers win (last PA dies/outnumbered),
      // she steals the victory (Survival Win Condition).
      try {
        final messyBitch = alivePlayers.firstWhere(
          (p) => p.role.id == 'messy_bitch',
        );
        return GameEndResult(
          winner: 'MESSY_BITCH',
          message:
              '${messyBitch.name} (The Messy Bitch) survived the chaos and steals the win!',
        );
      } catch (e) {
        // No Messy Bitch alive, Dealers win normally
      }

      return GameEndResult(
        winner: 'DEALER',
        message: 'The Dealers have taken over the club!',
      );
    }

    return null; // Game continues
  }

  GameEndResult? _lastResult;
  bool checkWinConditions() {
    _lastResult = checkGameEnd();
    return _lastResult != null;
  }

  GameEndResult? get lastGameResult => _lastResult;
  String? get winner => _lastResult?.winner;
  String? get winMessage => _lastResult?.message;

  void randomizePlayerRole(String playerId) {
    if (roleRepository.roles.isEmpty) return;
    final random = Random();
    final newRole =
        roleRepository.roles[random.nextInt(roleRepository.roles.length)];
    updatePlayerRole(playerId, newRole);
  }

  // Re-enable creating test game
  Future<void> createTestGame({
    int roleCount = 23,
    bool fullRoster = false,
  }) async {
    if (roleRepository.roles.isEmpty) {
      await roleRepository.loadRoles();
    }

    resetGame();

    // Add Host
    Role? hostRole = roleRepository.getRoleById('host');
    hostRole ??= Role(
      id: 'host',
      name: 'The Host',
      alliance: 'Neutral',
      type: 'special',
      description: 'Runs the game.',
      nightPriority: 0,
      assetPath: 'Icons/host.png',
      colorHex: '#FFFFFF',
    );

    // Check if we need to add host as a player (optional based on architecture)
    // For now, allow proceeding even if host wasn't in repo

    // Get all unique playable roles
    final allRoles = roleRepository.roles
        .where((r) => r.id != 'host' && r.id != 'temp')
        .toList();

    // Determine target count
    final targetCount = fullRoster ? allRoles.length : roleCount;

    // List of test names base
    final testNames = [
      'Alpha',
      'Beta',
      'Gamma',
      'Delta',
      'Epsilon',
      'Zeta',
      'Eta',
      'Theta',
      'Iota',
      'Kappa',
      'Lambda',
      'Mu',
      'Nu',
      'Xi',
      'Omicron',
      'Pi',
      'Rho',
      'Sigma',
      'Tau',
      'Upsilon',
      'Phi',
      'Chi',
      'Psi',
      'Omega',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Red',
      'Blue',
      'Green',
      'Yellow',
      'Purple',
      'Orange',
      'Pink',
      'Cyan',
    ];

    // Fallback role
    final partyAnimalRole =
        roleRepository.getRoleById('party_animal') ?? allRoles.first;

    for (int i = 0; i < targetCount; i++) {
      // Generate name
      String name;
      if (i < testNames.length) {
        name = testNames[i];
      } else {
        name = 'Player ${i + 1}';
      }

      Role assignedRole;
      if (i < allRoles.length) {
        // Assign unique role until exhausted
        assignedRole = allRoles[i];
      } else {
        // Fallback to Party Animal once other roles are used
        assignedRole = partyAnimalRole;
      }

      addPlayer(name, role: assignedRole);
    }
  }
}

/// Result of a game ending
class GameEndResult {
  final String winner;
  final String message;

  const GameEndResult({required this.winner, required this.message});
}
