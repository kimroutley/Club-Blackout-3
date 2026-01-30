// ignore_for_file: unreachable_switch_case

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/game_script.dart';
import '../data/gossip_repository.dart';
import '../data/role_repository.dart';
import '../models/game_log_entry.dart';
import '../models/player.dart';
import '../models/role.dart';
import '../models/saved_game.dart';
import '../models/script_step.dart';
import '../models/vote_cast.dart';
import '../utils/death_causes.dart';
import '../utils/game_exceptions.dart';
import '../utils/game_logger.dart';
import '../utils/input_validator.dart';
import '../utils/role_validator.dart';
import 'ability_system.dart';
import 'game_state.dart';
import 'games_night_service.dart';
import 'hall_of_fame_service.dart';
import 'reaction_system.dart';
import 'script_builder.dart';

export 'game_state.dart';

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

class GameEndResult {
  final String winner; // e.g. 'DEALER', 'PARTY_ANIMAL'
  final String message;

  const GameEndResult({required this.winner, required this.message});
}

class GameEngine extends ChangeNotifier {
  final RoleRepository roleRepository;

  static const String hostRoleId = 'host';
  static const String hostPlayerId = 'host';

  static const int _saveSchemaVersion = 1;
  static const String _savedGamesIndexKey = 'savedGames';
  static const String _savePrefix = 'gameState_';
  static const String _saveBlobSuffix = '_blob';

  String _saveKey(String saveId, String field) =>
      '$_savePrefix${saveId}_$field';
  String _saveBlobKey(String saveId) => '$_savePrefix$saveId$_saveBlobSuffix';

  void refreshUi() {
    notifyListeners();
  }

  List<Player> players = [];
  GamePhase _currentPhase = GamePhase.lobby;

  // Callback for phase transitions
  void Function(GamePhase oldPhase, GamePhase newPhase)? onPhaseChanged;

  // Callback for clinger double death (clinger, obsession)
  void Function(String clingerName, String obsessionName)? onClingerDoubleDeath;

  // Callback for club manager role reveal (target player)
  void Function(Player target)? onClubManagerReveal;

  // Host UI alerts (one-shot messages; UI watches version changes).
  int hostAlertVersion = 0;
  String? hostAlertTitle;
  String? hostAlertMessage;

  // Gameplay toasts (short-lived, non-blocking UI cues).
  // The UI listens to toastVersion and shows toastTitle/toastMessage once.
  int toastVersion = 0;
  String? toastTitle;
  String? toastMessage;

  // Messy Bitch Victory handling
  bool messyBitchVictoryPending = false;
  void clearMessyBitchVictoryPending() {
    messyBitchVictoryPending = false;
    notifyListeners();
  }

  String? toastActionLabel;
  VoidCallback? toastAction;

  void showToast(
    String message, {
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    toastTitle = title;
    toastMessage = message;
    toastActionLabel = actionLabel;
    toastAction = onAction;
    toastVersion++;
    notifyListeners();
  }

  void _queueToast({required String title, required String message}) =>
      showToast(message, title: title);

  void queueHostAlert({required String title, required String message}) {
    hostAlertTitle = title;
    hostAlertMessage = message;
    hostAlertVersion++;
    notifyListeners();
  }

  void triggerMeowAlert() {
    queueHostAlert(title: 'THE ALLY CAT', message: 'M E O W ! 🐾');
    logAction('Social', 'The Ally Cat meowed.');
  }

  // Script Engine
  List<ScriptStep> _scriptQueue = [];
  int _scriptIndex = 0;

  // Game State Tracking
  int dayCount = 0;
  Map<String, dynamic> nightActions = {};
  List<String> deadPlayerIds = [];
  List<String> nameHistory = [];
  List<GameLogEntry> _gameLog = [];
  String lastNightSummary = '';

  /// Host-facing recap (UI reads this first, falls back to lastNightSummary).
  String lastNightHostRecap = '';

  /// Host-facing numeric deltas (kept minimal; UI expects a map).
  final Map<String, int> lastNightStats = <String, int>{};

  bool dramaQueenSwapPending = false;
  String? dramaQueenMarkedAId;
  String? dramaQueenMarkedBId;
  DramaQueenSwapRecord? lastDramaQueenSwap;

  bool _dayphaseVotesMade = false;
  final List<Map<String, String>> _clingerDoubleDeaths = [];

  // Predator retaliation in-flight state (persisted)
  String? pendingPredatorId;
  List<String> pendingPredatorEligibleVoterIds = [];
  String? pendingPredatorPreferredTargetId;

  bool get hasPendingPredatorRetaliation => pendingPredatorId != null;

  // Tea Spiller reveal in-flight state (persisted)
  String? pendingTeaSpillerId;
  List<String> pendingTeaSpillerEligibleVoterIds = [];
  bool get hasPendingTeaSpillerReveal => pendingTeaSpillerId != null;

  final ReactionSystem reactionSystem = ReactionSystem();
  final StatusEffectManager statusEffectManager = StatusEffectManager();
  final AbilityChainResolver chainResolver = AbilityChainResolver();
  final AbilityResolver abilityResolver = AbilityResolver();
  final Map<String, List<String>> _abilityTargets = {};

  // Voting telemetry (used by HostInsights/VotingInsights/StoryExporter)
  final List<VoteCast> voteHistory = [];
  final List<Map<String, dynamic>> nightHistory =
      []; // Archives nightActions per night
  final List<VoteCast> voteChanges =
      []; // Tracks real-time vote switching within a day
  final Map<String, String?> currentDayVotesByVoter = {};
  final Map<String, List<String>> currentDayVotesByTarget = {};
  int _voteSequence = 0;

  // Win state (used by GameScreen)
  String? _winner;
  String? _winMessage;

  List<GameLogEntry> get gameLog => List.unmodifiable(_gameLog);

  GamePhase get currentPhase => _currentPhase;
  set currentPhase(GamePhase value) {
    if (_currentPhase != value) {
      final old = _currentPhase;
      _currentPhase = value;
      notifyListeners();
      onPhaseChanged?.call(old, value);
    }
  }

  List<ScriptStep> get scriptQueue => List.unmodifiable(_scriptQueue);
  int get currentScriptIndex => _scriptIndex;

  ScriptStep? get currentScriptStep {
    if (_scriptQueue.isNotEmpty && _scriptIndex < _scriptQueue.length) {
      return _scriptQueue[_scriptIndex];
    }
    return null;
  }

  /// Guests excludes host placeholder.
  Iterable<Player> get guests => players.where((p) => p.role.id != 'host');

  Player? get hostPlayer {
    try {
      return players.firstWhere((p) => p.role.id == hostRoleId);
    } catch (_) {
      return null;
    }
  }

  String? get hostName {
    final host = hostPlayer;
    final name = host?.name.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  String get hostDisplayName => hostName ?? 'Host';

  void setHostName(String rawName) {
    final sanitized = InputValidator.sanitizeString(rawName).trim();
    if (sanitized.isEmpty) {
      // Clear host
      players.removeWhere((p) => p.role.id == hostRoleId);
      notifyListeners();
      return;
    }

    final validation = InputValidator.validatePlayerName(sanitized);
    if (validation.isInvalid) {
      throw ArgumentError(validation.error);
    }

    // Ensure uniqueness vs all players (case-insensitive)
    final host = hostPlayer;
    final lower = sanitized.toLowerCase();
    final collision = players.any((p) {
      if (host != null && p.id == host.id) return false;
      return p.name.trim().toLowerCase() == lower;
    });
    if (collision) {
      throw ArgumentError('A player with this name already exists');
    }

    _addToHistory(sanitized);

    // Ensure role exists (fallback if assets are out of date).
    final hostRole = roleRepository.getRoleById(hostRoleId) ??
        Role(
          id: hostRoleId,
          name: 'The Host',
          alliance: 'Host',
          type: 'meta',
          description: 'Facilitator / game master.',
          nightPriority: 0,
          assetPath: '',
          colorHex: '#B0B0B0',
        );

    if (host != null) {
      host.name = sanitized;
      host.role = hostRole;
      notifyListeners();
      return;
    }

    final player = Player(
      id: hostPlayerId,
      name: sanitized,
      role: hostRole,
      isAlive: true,
      isEnabled: true,
    )..initialize();

    players.add(player);
    notifyListeners();
  }

  String? get winner => _winner;
  String? get winMessage => _winMessage;

  GameEngine({required this.roleRepository, bool loadNameHistory = true}) {
    if (loadNameHistory) {
      _loadNameHistory();
    }
  }

  /// Export a single-map representation of the current engine state.
  ///
  /// This is similar to the persistence “blob” save format, but does not touch
  /// disk. Intended for simulations/tests/tools.
  Map<String, dynamic> exportSaveBlobMap({bool includeLog = true}) {
    return <String, dynamic>{
      'schemaVersion': _saveSchemaVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'players': players.map((p) => p.toJson()).toList(growable: false),
      'log': includeLog
          ? _gameLog.map((l) => l.toJson()).toList(growable: false)
          : const <dynamic>[],
      'phaseIndex': _currentPhase.index,
      'dayCount': dayCount,
      'scriptIndex': _scriptIndex,
      'nightActions': nightActions,
      'deadPlayerIds': deadPlayerIds,
      'votesByVoter': currentDayVotesByVoter,
      'votesByTarget': currentDayVotesByTarget,
      'voteHistory': includeLog
          ? voteHistory.map((v) => v.toJson()).toList(growable: false)
          : const <dynamic>[],
      'voteSequence': _voteSequence,
      'predatorPending': {
        'pendingPredatorId': pendingPredatorId,
        'eligibleVoterIds': pendingPredatorEligibleVoterIds,
        'preferredTargetId': pendingPredatorPreferredTargetId,
      },
      'teaSpillerPending': {
        'pendingTeaSpillerId': pendingTeaSpillerId,
        'eligibleVoterIds': pendingTeaSpillerEligibleVoterIds,
      },
      'dramaQueenPending': {
        'swapPending': dramaQueenSwapPending,
        'markedAId': dramaQueenMarkedAId,
        'markedBId': dramaQueenMarkedBId,
      },
      'statusEffects': statusEffectManager.toJson(),
      'abilityQueue': abilityResolver.toJson(),
      'reactionHistory': reactionSystem.getHistoryJson(),
      if (lastDramaQueenSwap != null)
        'lastDramaQueenSwap': {
          'day': lastDramaQueenSwap!.day,
          'playerAName': lastDramaQueenSwap!.playerAName,
          'playerBName': lastDramaQueenSwap!.playerBName,
          'fromRoleA': lastDramaQueenSwap!.fromRoleA,
          'fromRoleB': lastDramaQueenSwap!.fromRoleB,
          'toRoleA': lastDramaQueenSwap!.toRoleA,
          'toRoleB': lastDramaQueenSwap!.toRoleB,
        },
    };
  }

  /// Load engine state from a save-map (blob format). Does not read prefs.
  Future<void> importSaveBlobMap(
    Map<String, dynamic> map, {
    bool notify = true,
  }) async {
    await _loadFromSaveMap(map);

    // Ensure dead list contains any actually-dead players, but do not discard
    // persisted in-flight state (tests expect this).
    final derivedDead = players
        .where((p) => p.isEnabled && p.role.id != 'host' && !p.isAlive)
        .map((p) => p.id)
        .toList(growable: false);
    final merged =
        <String>{...deadPlayerIds, ...derivedDead}.toList(growable: true);
    deadPlayerIds = merged;

    // Keep night action keys compatible with engine rules.
    _canonicalizeNightActions();

    if (notify) {
      notifyListeners();
    }
  }

  /// Creates a deep-ish clone suitable for Monte Carlo simulations.
  Future<GameEngine> cloneForSimulation({bool includeLog = false}) async {
    final clone =
        GameEngine(roleRepository: roleRepository, loadNameHistory: false);
    await clone.importSaveBlobMap(exportSaveBlobMap(includeLog: includeLog),
        notify: false);
    return clone;
  }

  Future<void> _loadNameHistory() async {
    final prefs = await SharedPreferences.getInstance();
    nameHistory = prefs.getStringList('player_name_history') ?? [];
    notifyListeners();
  }

  Future<void> _addToHistory(String name) async {
    if (name.isEmpty) return;
    nameHistory.removeWhere((n) => n == name);
    nameHistory.add(name);

    const maxHistory = 200;
    if (nameHistory.length > maxHistory) {
      nameHistory = nameHistory.sublist(nameHistory.length - maxHistory);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('player_name_history', nameHistory);
    notifyListeners();
  }

  /// Removes the provided names from the saved name history.
  Future<void> removeNamesFromHistory(List<String> names) async {
    if (names.isEmpty) return;
    nameHistory.removeWhere((n) => names.contains(n));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('player_name_history', nameHistory);
    notifyListeners();
  }

  List<Player> get enabledPlayers => players.where((p) => p.isEnabled).toList();
  List<Player> get activePlayers => players.where((p) => p.isActive).toList();

  /// Rule-aware vote tally: only counts votes from eligible voters.
  ///
  /// Defensive by design: the UI should already use [recordVote], which blocks
  /// ineligible voters (e.g., Sober-sent-home), but this protects against any
  /// direct map mutations or stale saved state.
  Map<String, List<String>> get eligibleDayVotesByTarget {
    final eligibleVoterIds = players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .where((p) => !p.soberSentHome)
        .where((p) => p.silencedDay != dayCount)
        .map((p) => p.id)
        .toSet();

    final filtered = <String, List<String>>{};
    for (final entry in currentDayVotesByTarget.entries) {
      final targetId = entry.key;
      final target = players.where((p) => p.id == targetId).firstOrNull;
      if (target != null && target.alibiDay == dayCount) {
        // Silver Fox alibi: targets with vote immunity cannot accrue votes today.
        continue;
      }
      final voters = entry.value.where(eligibleVoterIds.contains).toList();
      if (voters.isNotEmpty) {
        filtered[targetId] = voters;
      }
    }
    return filtered;
  }

  bool _isVoteImmuneTarget(String targetId) {
    final target = players.where((p) => p.id == targetId).firstOrNull;
    return target != null && target.alibiDay == dayCount;
  }

  // --- Voting telemetry API (safe even if UI never calls it) ---

  void recordVote({
    required String voterId,
    required String? targetId,
  }) {
    final voter = players.where((p) => p.id == voterId).firstOrNull;
    if (voter != null && voter.soberSentHome) {
      logAction('Sober', '${voter.name} is SENT HOME and cannot vote.');
      return;
    }

    if (voter != null && voter.silencedDay == dayCount) {
      logAction('Roofi', '${voter.name} is SILENCED and cannot vote today.');
      return;
    }

    var effectiveTargetId = targetId;
    if (effectiveTargetId != null && _isVoteImmuneTarget(effectiveTargetId)) {
      final target =
          players.where((p) => p.id == effectiveTargetId).firstOrNull;
      if (target != null) {
        logAction('Silver Fox',
            '${target.name} has an ALIBI today and cannot receive votes.');
      }
      effectiveTargetId = null;
    }

    // Remove voter from previous target bucket
    final prev = currentDayVotesByVoter[voterId];
    if (prev != null) {
      if (prev != effectiveTargetId) {
        // Changed vote
        voteChanges.add(VoteCast(
          day: dayCount,
          voterId: voterId,
          targetId: effectiveTargetId,
          timestamp: DateTime.now(),
          sequence: _voteSequence++,
        ));
      }
      currentDayVotesByTarget[prev]?.remove(voterId);
      if (currentDayVotesByTarget[prev]?.isEmpty ?? false) {
        currentDayVotesByTarget.remove(prev);
      }
    }

    currentDayVotesByVoter[voterId] = effectiveTargetId;

    if (effectiveTargetId != null) {
      currentDayVotesByTarget
          .putIfAbsent(effectiveTargetId, () => <String>[])
          .add(voterId);
    }

    voteHistory.add(
      VoteCast(
        day: dayCount,
        voterId: voterId,
        targetId: effectiveTargetId,
        timestamp: DateTime.now(),
        sequence: _voteSequence++,
      ),
    );

    // Clinger mechanic: Clinger must vote exactly as their obsession votes.
    // This is enforced whenever any vote is recorded, so partner vote changes
    // automatically propagate.
    _syncClingerVotesToPartner();
    notifyListeners();
  }

  void _syncClingerVotesToPartner() {
    final clingers = players
        .where((p) =>
            p.role.id == 'clinger' &&
            p.isActive &&
            !p.soberSentHome &&
            !p.clingerFreedAsAttackDog &&
            p.clingerPartnerId != null)
        .toList();

    for (final clinger in clingers) {
      final partnerId = clinger.clingerPartnerId;
      if (partnerId == null) continue;

      final partnerVote = currentDayVotesByVoter[partnerId];
      final existing = currentDayVotesByVoter[clinger.id];
      if (existing == partnerVote) continue;

      // This will also write a VoteCast entry (useful for audits/exports) and
      // is idempotent because we only call it when a change is needed.
      recordVote(voterId: clinger.id, targetId: partnerVote);
    }
  }

  /// Host-triggered: mark that the obsession called the Clinger "controller".
  /// This frees the Clinger from heartbreak and enables their one-time Attack Dog kill.
  bool freeClingerFromObsession(String clingerId) {
    final clinger = players.where((p) => p.id == clingerId).firstOrNull;
    if (clinger == null) return false;
    if (!clinger.isActive) return false;
    if (clinger.role.id != 'clinger') return false;
    if (clinger.clingerFreedAsAttackDog) return false;

    final partnerId = clinger.clingerPartnerId;
    final partnerName = partnerId != null
        ? players.where((p) => p.id == partnerId).firstOrNull?.name
        : null;

    clinger.clingerFreedAsAttackDog = true;
    clinger.clingerPartnerId = null;

    logAction(
      'Clinger Freed',
      partnerName != null
          ? '${clinger.name} was called "controller" by $partnerName and is now UNLEASHED (Attack Dog).'
          : '${clinger.name} is now UNLEASHED (Attack Dog).',
    );
    notifyListeners();
    return true;
  }

  /// Back-compat API used by tests.
  void setDayVote({
    required String voterId,
    required String targetId,
  }) {
    recordVote(voterId: voterId, targetId: targetId);
  }

  void clearDayVotes() {
    currentDayVotesByVoter.clear();
    currentDayVotesByTarget.clear();
    notifyListeners();
  }

  /// Test helper: populate the engine with a deterministic roster.
  ///
  /// When `fullRoster` is true, adds one player per role in the repository
  /// (excluding placeholder roles). Roles are assigned manually so `startGame`
  /// will not overwrite them.
  Future<void> createTestGame({bool fullRoster = false}) async {
    // Start from a known-clean lobby state so scripts/dayCount/etc are reset.
    resetToLobby(keepGuests: false, keepAssignedRoles: false);

    if (!fullRoster) {
      // Small, practical roster for quick playthroughs.
      final dealer = roleRepository.getRoleById('dealer');
      final party = roleRepository.getRoleById('party_animal');
      final medic = roleRepository.getRoleById('medic');
      final wallflower = roleRepository.getRoleById('wallflower');
      final whore = roleRepository.getRoleById('whore');

      if (dealer != null) addPlayer('Dealer1', role: dealer);
      if (party != null) {
        addPlayer('PA1', role: party);
        addPlayer('PA2', role: party);
      }
      if (medic != null) addPlayer('Medic1', role: medic);
      if (wallflower != null) addPlayer('Wallflower1', role: wallflower);
      if (whore != null) addPlayer('Whore1', role: whore);

      // Defensive fallback: ensure the roster is startable (4+ enabled players).
      if (enabledPlayers.length < 4) {
        final fillers = roleRepository.roles
            .where((r) => r.id != 'temp' && r.id != 'host')
            .toList();
        var i = 1;
        while (enabledPlayers.length < 4 && fillers.isNotEmpty) {
          addPlayer('Guest$i', role: fillers[i % fillers.length]);
          i++;
        }
      }
      return;
    }

    final roles = roleRepository.roles
        .where((r) => r.id != 'temp' && r.id != 'host')
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    var i = 1;
    for (final role in roles) {
      // Keep names within InputValidator constraints (no underscores, <= 20 chars)
      addPlayer('Player $i', role: role);
      i++;
    }
  }

  /// Back-compat API used by gameplay scenario tests.
  ///
  /// Returns a simple winner token when the game is over, otherwise null.
  GameEndResult? checkGameEnd() {
    // Messy Bitch immediate win: rumours have reached every enabled guest.
    if (_isMessyBitchWinConditionMet()) {
      return const GameEndResult(
        winner: 'MESSY_BITCH',
        message: 'Messy Bitch spread a rumour to every player.',
      );
    }

    final alive = players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .toList();

    if (alive.isEmpty) {
      return const GameEndResult(
        winner: 'NONE',
        message: 'No one wins. Everyone is dead.',
      );
    }

    final dealerCount = alive
        .where((p) =>
            p.role.id == 'dealer' ||
            p.alliance.toLowerCase().contains('dealer'))
        .length;
    final partyCount =
        alive.where((p) => p.alliance.toLowerCase().contains('party')).length;

    // Party Animals win when all Dealers are dead (and at least one Party Animal remains).
    if (dealerCount == 0 && partyCount > 0) {
      return const GameEndResult(
        winner: 'PARTY_ANIMAL',
        message: 'All Dealers are eliminated.',
      );
    }

    // Special case: Club Manager vs Dealers.
    // Dealers do NOT win at parity if a Club Manager is still alive to maintain order.
    final clubManagerAlive = alive.any((p) => p.role.id == 'club_manager');

    // Dealer win condition:
    // 1. Dealers outnumber or equal Party Animals (control the vote).
    // 2. Exception: Club Manager wins a 1v1 standoff against a Dealer or others.
    if (dealerCount >= partyCount) {
      if (alive.length == 2 && clubManagerAlive) {
        return const GameEndResult(
          winner: 'CLUB_MANAGER',
          message:
              'Final showdown: Club Manager wins the standoff against the Dealer.',
        );
      }

      if (alive.length == 2 && dealerCount == 1 && partyCount == 1) {
        return const GameEndResult(
          winner: 'DEALER',
          message: 'Final showdown: Dealer wins the standoff.',
        );
      }

      // If CM is alive and it's not a 1v1, it might not be over yet (maintaining order).
      if (clubManagerAlive && alive.length > 2) {
        return null;
      }

      // Otherwise, Dealers control the room.
      return const GameEndResult(
        winner: 'DEALER',
        message: 'Dealers have reached parity and control the club.',
      );
    }

    return null;
  }

  bool _isMessyBitchWinConditionMet() {
    final messyBitch = players
        .where((p) => p.isEnabled && p.role.id == 'messy_bitch')
        .firstOrNull;
    if (messyBitch == null) return false;
    if (!messyBitch.isAlive) return false;

    // Rules: wins immediately if every currently living player (besides herself)
    // has heard a rumour.
    final targets = players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .where((p) => p.id != messyBitch.id)
        .toList();

    // Vacuously true if Messy Bitch is the last living player.
    return targets.every((p) => p.hasRumour);
  }

  // --- Roles / Players ---

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
      throw StateError(
          'Missing required role: party_animal. Check assets/data/roles.json.');
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

    final usedUniqueRoleIds = players
        .map((p) => p.role.id)
        .where((id) => id != 'temp' && id != 'host')
        .where((id) => !RoleValidator.multipleAllowedRoles.contains(id))
        .toSet();

    final uniqueAvailable = allRoles
        .where((r) => r.id != 'temp' && r.id != 'host')
        .where((r) => !RoleValidator.multipleAllowedRoles.contains(r.id))
        .where((r) => !usedUniqueRoleIds.contains(r.id))
        .toList();

    final currentEnabledNonHost =
        players.where((p) => p.isEnabled && p.role.id != 'host').length;
    final newTotal = currentEnabledNonHost + 1;
    final recommendedDealers = RoleValidator.recommendedDealerCount(newTotal);
    final currentDealersAlive = players
        .where((p) => p.isEnabled && p.isAlive && p.role.id == 'dealer')
        .length;
    final canAddDealer =
        dealerRole.id != 'missing' && currentDealersAlive < recommendedDealers;

    final results = <Role>[...uniqueAvailable];
    if (canAddDealer) results.add(dealerRole);

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }

  void addPlayer(String name, {Role? role}) {
    GameLogger.debug('Adding player: $name', context: 'GameEngine');

    final validation = InputValidator.validatePlayerName(name);
    if (validation.isInvalid) {
      GameLogger.warning('Invalid player name: ${validation.error}',
          context: 'GameEngine');
      throw ArgumentError(validation.error);
    }

    final sanitizedName = InputValidator.sanitizeString(name);

    if (players
        .any((p) => p.name.toLowerCase() == sanitizedName.toLowerCase())) {
      GameLogger.warning('Duplicate player name: $sanitizedName',
          context: 'GameEngine');
      throw ArgumentError('A player with this name already exists');
    }

    _addToHistory(sanitizedName);
    unawaited(HallOfFameService.instance.registerPlayer(sanitizedName));

    final assignedRole = role ??
        Role(
          id: 'temp',
          name: 'Unassigned',
          alliance: 'None',
          type: 'Placeholder',
          description: 'Role will be assigned when the game starts',
          nightPriority: 0,
          assetPath: '',
          colorHex: '#888888',
        );

    final player = Player(
      id: '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(10000)}',
      name: sanitizedName,
      role: assignedRole,
    );

    players.add(player);
    GameLogger.info('Player added: ${player.name} as ${assignedRole.name}',
        context: 'GameEngine');
    notifyListeners();
  }

  Player addPlayerDuringDay(String name, {Role? role}) {
    if (_currentPhase == GamePhase.lobby) {
      throw StateError('Players can only join after the game has started');
    }

    GameLogger.debug('Adding late joiner: $name', context: 'GameEngine');

    final validation = InputValidator.validatePlayerName(name);
    if (validation.isInvalid) throw ArgumentError(validation.error);

    final sanitizedName = InputValidator.sanitizeString(name);

    if (players
        .any((p) => p.name.toLowerCase() == sanitizedName.toLowerCase())) {
      throw ArgumentError('A player with this name already exists');
    }

    _addToHistory(sanitizedName);
    unawaited(HallOfFameService.instance.registerPlayer(sanitizedName));

    final available = availableRolesForNewPlayer();
    if (available.isEmpty) {
      throw StateError('No roles are available for new players');
    }

    final assignedRole = role != null
        ? (available.any((r) => r.id == role.id)
            ? role
            : throw ArgumentError('Selected role is not available'))
        : available[Random().nextInt(available.length)];

    final player = Player(
      id: '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(10000)}',
      name: sanitizedName,
      role: assignedRole,
      joinsNextNight: true,
    )..initialize();

    players.add(player);
    notifyListeners();
    return player;
  }

  void updatePlayerRole(String playerId, Role? newRole) {
    if (newRole == null) return;
    if (!InputValidator.isValidId(playerId)) {
      throw PlayerNotFoundException(playerId);
    }

    final index = players.indexWhere((p) => p.id == playerId);
    if (index == -1) throw PlayerNotFoundException(playerId);

    if (newRole.id == 'bouncer') {
      final existing = players.firstWhere(
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
      if (existing.id != 'none') {
        throw StateError(
            'Only one Bouncer is allowed. ${existing.name} already has this role.');
      }
    }

    players[index].role = newRole;
    players[index].initialize();
    notifyListeners();
  }

  /// Clears the entire guest list and all associated session state.
  void clearAllPlayers() {
    players.clear();
    deadPlayerIds.clear();
    currentDayVotesByVoter.clear();
    currentDayVotesByTarget.clear();
    notifyListeners();
  }

  void removePlayer(String id) {
    if (!InputValidator.isValidId(id)) throw PlayerNotFoundException(id);

    players.removeWhere((p) => p.id == id);

    // Keep auxiliary state in sync
    deadPlayerIds.remove(id);
    currentDayVotesByVoter.remove(id);
    currentDayVotesByTarget.remove(id);
    currentDayVotesByTarget.forEach((_, voters) => voters.remove(id));

    notifyListeners();
  }

  /// Restores a previously removed player (used by Lobby undo).
  ///
  /// Returns false if the restore cannot be applied safely (e.g., a name
  /// collision occurred after removal).
  bool restorePlayer(Player player, {int? index}) {
    final restoredName = player.name.trim();
    if (restoredName.isEmpty) return false;

    final lower = restoredName.toLowerCase();
    final nameCollision =
        players.any((p) => p.name.trim().toLowerCase() == lower);
    if (nameCollision) return false;

    final idCollision = players.any((p) => p.id == player.id);
    if (idCollision) return false;

    var insertIndex = index ?? players.length;
    if (insertIndex < 0) insertIndex = 0;
    if (insertIndex > players.length) insertIndex = players.length;

    players.insert(insertIndex, player);
    notifyListeners();
    return true;
  }

  /// Restores a previously cleared roster (used by Lobby undo).
  ///
  /// Returns false if any player name would collide with an existing player.
  bool restoreAllPlayers(List<Player> roster) {
    final normalized = <String>{};
    for (final p in roster) {
      final name = p.name.trim().toLowerCase();
      if (name.isEmpty) return false;
      if (normalized.contains(name)) return false;
      normalized.add(name);
    }

    // If the current roster isn't empty, do not merge; only allow restore into empty.
    if (players.isNotEmpty) return false;

    players.addAll(roster);
    notifyListeners();
    return true;
  }

  void renamePlayer(String playerId, String newName) {
    final player = players.firstWhere((p) => p.id == playerId);
    final validation = InputValidator.validatePlayerName(newName);
    if (validation.isInvalid) {
      throw ArgumentError(validation.error);
    }

    final sanitizedName = InputValidator.sanitizeString(newName);

    // If case-insensitive match with self, just update it (case update)
    if (player.name.toLowerCase() == sanitizedName.toLowerCase()) {
      player.name = sanitizedName;
      notifyListeners();
      return;
    }

    if (players
        .any((p) => p.name.toLowerCase() == sanitizedName.toLowerCase())) {
      throw ArgumentError('A player with this name already exists');
    }

    player.name = sanitizedName;
    notifyListeners();
  }

  // --- Game start / scripts ---

  Future<void> startGame() async {
    final enabledGuestPlayers =
        players.where((p) => p.isEnabled && p.role.id != hostRoleId).toList();
    final enabledCount = enabledGuestPlayers.length;

    final validation = InputValidator.validatePlayerCount(enabledCount);
    if (validation.isInvalid) {
      throw InvalidPlayerCountException(enabledCount, 4);
    }

    _assignRoles();

    // Ensure bookkeeping starts clean
    deadPlayerIds = players
        .where((p) => p.isEnabled && p.role.id != 'host' && !p.isAlive)
        .map((p) => p.id)
        .toList(growable: true);

    _scriptQueue = [
      ...GameScript.intro,
      ...ScriptBuilder.buildNightScript(enabledGuestPlayers, dayCount),
    ];
    _scriptIndex = 0;
    _currentPhase = GamePhase.setup;

    lastNightSummary = '';
    lastNightHostRecap = '';
    lastNightStats.clear();
    _winner = null;
    _winMessage = null;

    // Games Night recording should treat each startGame as a new game boundary.
    GamesNightService.instance.recordGameStarted(this);

    _logCurrentStep();
    notifyListeners();
  }

  void rebuildNightScript() {
    if (_currentPhase != GamePhase.night) return;

    final currentIndex = _scriptIndex;
    final currentStep =
        currentIndex < _scriptQueue.length ? _scriptQueue[currentIndex] : null;
    final newQueue = ScriptBuilder.buildNightScript(players, dayCount);

    if (currentStep != null) {
      final newIndex = newQueue.indexWhere((s) => s.id == currentStep.id);
      if (newIndex != -1) {
        _scriptQueue = newQueue;
        _scriptIndex = newIndex;
      } else {
        int bestMatchNewIndex = 0;
        for (int i = currentIndex - 1; i >= 0; i--) {
          final pastStep = _scriptQueue[i];
          final match = newQueue.indexWhere((s) => s.id == pastStep.id);
          if (match != -1) {
            bestMatchNewIndex = match;
            break;
          }
        }
        _scriptQueue = newQueue;
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
    if (_scriptIndex >= _scriptQueue.length) {
      _loadNextPhaseScript();
    }
    _logCurrentStep();
    notifyListeners();
  }

  void regressScript() {
    if (_scriptIndex > 0) {
      _scriptIndex--;
      notifyListeners();
    }
  }

  void skipToNextPhase() {
    _scriptIndex = _scriptQueue.length;
    _loadNextPhaseScript();
    _logCurrentStep();
    notifyListeners();
  }

  void _logCurrentStep() {
    final step = currentScriptStep;
    if (step == null) return;

    if (_gameLog.isNotEmpty) {
      final last = _gameLog.first;
      final desc = step.readAloudText.isNotEmpty
          ? step.readAloudText
          : step.instructionText;
      if (last.title == step.title && last.description == desc) return;
    }

    logAction(
      step.title,
      step.readAloudText.isNotEmpty ? step.readAloudText : step.instructionText,
      type: GameLogType.script,
    );
  }

  void _loadNextPhaseScript() {
    final oldPhase = _currentPhase;

    if (_currentPhase == GamePhase.setup) {
      _currentPhase = GamePhase.night;
      onPhaseChanged?.call(oldPhase, _currentPhase);

      // Archive setup night actions if any (rare, but setup choices exist)
      nightHistory.add(Map<String, dynamic>.from(nightActions));
      nightActions.clear();
      _abilityTargets.clear();
      abilityResolver.clear();

      for (final p in players) {
        p.soberSentHome = false;
      }

      dayCount++;

      for (final p in players.where((p) => p.joinsNextNight)) {
        p.joinsNextNight = false;
        p.initialize();
      }

      reactionSystem.triggerEvent(
          GameEvent(type: GameEventType.nightPhaseStart), players);
      statusEffectManager.updateEffects();

      _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
      _scriptIndex = 0;
      return;
    }

    if (_currentPhase == GamePhase.night) {
      _currentPhase = GamePhase.day;
      onPhaseChanged?.call(oldPhase, _currentPhase);

      // Resolve deaths/results BEFORE clearing actions
      final announcement = _resolveNightPhase();

      // Archive Night N actions
      nightHistory.add(Map<String, dynamic>.from(nightActions));
      nightActions.clear();
      _abilityTargets.clear();
      abilityResolver.clear();

      _dayphaseVotesMade = false;
      clearDayVotes();

      final dayQueue =
          ScriptBuilder.buildDayScript(dayCount, announcement, players);

      // Second Wind conversion choice is a NEXT-NIGHT decision (after the day + vote).
      // Do not inject anything into the Day script.
      _scriptQueue = dayQueue;
      _scriptIndex = 0;
      dayCount++;
      return;
    }

    if (_currentPhase == GamePhase.day) {
      if (!_dayphaseVotesMade) {
        logAction('No Vote Cast',
            'Time ran out without a vote being called. No one was eliminated.');
      }

      _currentPhase = GamePhase.night;
      onPhaseChanged?.call(oldPhase, _currentPhase);

      for (final p in players) {
        p.soberSentHome = false;
      }

      // Silver Fox: alibi lasts only for the day/vote round.
      // We clear it when the Day phase ends so it doesn't linger into the Night.
      for (final p in players) {
        if (p.alibiDay == dayCount) {
          p.alibiDay = null;
        }
      }

      for (final p in players.where((p) => p.joinsNextNight)) {
        p.joinsNextNight = false;
        p.initialize();
      }

      reactionSystem.triggerEvent(
          GameEvent(type: GameEventType.nightPhaseStart), players);
      statusEffectManager.updateEffects();

      var nightQueue = ScriptBuilder.buildNightScript(players, dayCount);

      // If Second Wind was killed by Dealers on the previous night, the Dealers may
      // choose TONIGHT to convert them (forfeiting their kill) or proceed with a kill.
      final hasPendingSecondWindThisNight = players.any(
        (p) =>
            p.isEnabled &&
            p.role.id == 'second_wind' &&
            p.secondWindPendingConversion &&
            !p.secondWindConverted &&
            !p.secondWindRefusedConversion &&
            p.secondWindConversionNight == dayCount,
      );

      if (hasPendingSecondWindThisNight) {
        final insertBefore = nightQueue.indexWhere((s) => s.id == 'dealer_act');
        if (insertBefore != -1) {
          nightQueue = <ScriptStep>[
            ...nightQueue.take(insertBefore),
            const ScriptStep(
              id: 'second_wind_conversion_choice',
              title: 'Second Wind (Host Only)',
              readAloudText: '',
              instructionText:
                  'Host only (do not read aloud): The Dealers killed the Second Wind last night.\n\nTonight, choose:\n\nCONVERT — revive them as a Dealer (Dealers forfeit their kill tonight).\nKILL — do not convert; proceed with a normal Dealer kill tonight.',
              actionType: ScriptActionType.binaryChoice,
              roleId: 'dealer',
              isNight: true,
              optionLabels: ['CONVERT', 'KILL'],
            ),
            ...nightQueue.skip(insertBefore),
          ];
        }
      }

      _scriptQueue = nightQueue;
      _scriptIndex = 0;
    }
  }

  // --- Death handling ---

  void processDeath(Player victim, {String cause = 'unknown'}) {
    if (!victim.isAlive) return;

    final causeLower = cause.toLowerCase();

    // Sober: sent-home players cannot be killed by night murders.
    // Also, when a Dealer is sent home, guest murders are cancelled.
    final noDealersActiveTonight = nightActions['no_murders_tonight'] == true;
    final isDealerKillAttempt = causeLower == 'night_kill' ||
        causeLower == 'dealer_kill' ||
        causeLower == 'night_kill_special';
    final isClingerKill = causeLower == 'clinger_attack_dog';

    // Rule: Sent-home players are safe from ALL night murders.
    if ((isDealerKillAttempt || isClingerKill) && victim.soberSentHome) {
      logAction(
        'Sober',
        '${victim.name} would have died, but was sent home by The Sober.',
      );
      return;
    }

    // Rule: If a Dealer was sent home, Dealer-specific murders are cancelled.
    if (isDealerKillAttempt && noDealersActiveTonight) {
      logAction(
        'Sober',
        '${victim.name} would have died, but a Dealer was sent home — Dealer murders cancelled.',
      );
      return;
    }

    // Second Wind should only intercept Dealer-kill attempts (per rules).

    // Minor: cannot die to Dealer kill attempts until ID'd by the Bouncer.
    if (victim.role.id == 'minor' &&
        isDealerKillAttempt &&
        !victim.minorHasBeenIDd) {
      logAction('Minor',
          '${victim.name} is The Minor and cannot be killed by the Dealers until ID’d by the Bouncer.');
      notifyListeners();
      return;
    }

    // Second Wind: When killed by a Dealer kill attempt, they can be converted
    // on the FOLLOWING night (Dealers must forfeit that night's kill).
    if (victim.role.id == 'second_wind' &&
        isDealerKillAttempt &&
        !victim.secondWindConverted &&
        !victim.secondWindRefusedConversion) {
      victim.secondWindPendingConversion = true;

      // Conversion choice is available on the next night.
      victim.secondWindConversionNight = dayCount + 1;

      logAction(
        'Second Wind',
        '${victim.name} was killed by the Dealers. Conversion choice will be available next night.',
      );
    }

    // If the host explicitly refused conversion, allow the kill to proceed.
    if (victim.role.id == 'second_wind' && causeLower.contains('refus')) {
      victim.secondWindRefusedConversion = true;
      victim.secondWindPendingConversion = false;
    }

    if (_absorbDeathWithLives(victim, cause)) {
      notifyListeners();
      return;
    }

    final deathEvent = GameEvent(
      type: GameEventType.playerDied,
      sourcePlayerId: victim.id,
      data: {'cause': cause},
    );
    final reactions = reactionSystem.triggerEvent(deathEvent, players);
    _processDeathReactions(victim, reactions);

    victim.die(dayCount, cause);
    if (!deadPlayerIds.contains(victim.id)) {
      deadPlayerIds.add(victim.id);
    }

    logAction(
        'Death', '${victim.name} (${victim.role.name}) died. Cause: $cause');

    _handleCreepInheritance(victim);
    _handleClingerObsessionDeath(victim);

    notifyListeners();
  }

  /// Lightweight: if they speak a taboo name, they die immediately.
  ///
  /// This is a real-world speech rule, so the host triggers it explicitly.
  void markLightweightTabooViolation(
      {String? tabooName, String? lightweightId}) {
    Player? lightweight;

    if (lightweightId != null) {
      lightweight = players.where((p) => p.id == lightweightId).firstOrNull;
      if (lightweight == null) {
        logAction('Taboo Violation', 'No player found for id=$lightweightId.');
        return;
      }
    } else {
      final livingLightweights = players
          .where((p) => p.isAlive && p.role.id == 'lightweight')
          .toList();

      if (livingLightweights.isEmpty) {
        logAction('Taboo Violation', 'No alive Lightweight in game.');
        return;
      }
      if (livingLightweights.length > 1) {
        logAction('Taboo Violation',
            'Multiple Lightweights are alive; specify which one violated the taboo.');
        return;
      }
      lightweight = livingLightweights.first;
    }

    if (!lightweight.isAlive) {
      logAction('Taboo Violation', '${lightweight.name} is already dead.');
      return;
    }

    final cleaned = tabooName?.trim();
    final detail =
        (cleaned != null && cleaned.isNotEmpty) ? ' ("$cleaned")' : '';
    logAction('Taboo Violation',
        '${lightweight.name} spoke a taboo name$detail and dies immediately.');
    processDeath(lightweight, cause: DeathCause.spokeTabooName);
  }

  bool _absorbDeathWithLives(Player victim, String cause) {
    if (victim.role.id == 'ally_cat') {
      victim.lives = (victim.lives - 1).clamp(0, 999);
      if (victim.lives > 0) {
        final isVote = cause.toLowerCase().contains('vote');
        logAction('Nine Lives',
            '${victim.name} survived ${isVote ? "the vote" : "death"}. Lives left: ${victim.lives}.');
        return true;
      }
      return false;
    }

    final causeLower = cause.toLowerCase();
    final isDealerKillAttempt = causeLower == 'night_kill' ||
        causeLower == 'dealer_kill' ||
        causeLower == 'night_kill_special';
    if (victim.role.id == 'seasoned_drinker' && isDealerKillAttempt) {
      victim.lives = (victim.lives - 1).clamp(0, 999);
      if (victim.lives > 0) {
        logAction('Seasoned Drinker',
            '${victim.name} burned a life against the Dealers. Lives left: ${victim.lives}.');
        return true;
      }
      return false;
    }

    return false;
  }

  // --- Night resolution (kept compatible with your existing UI expectations) ---

  String _resolveNightPhase({bool buildMorningReports = true}) {
    _canonicalizeNightActions();

    if (players.isEmpty) {
      return 'No players in game state; night resolution skipped.';
    }

    _clingerDoubleDeaths.clear();
    lastNightStats
      ..clear()
      ..addAll({'killed': 0, 'saved': 0, 'silenced': 0});

    // Sober can send someone home. Sent-home players are protected from night murders.
    // If a Dealer is sent home, there are no murders at all tonight.
    final soberTargetId = nightActions['sober_sent_home'] as String?;
    if (soberTargetId != null) {
      final target = players.where((p) => p.id == soberTargetId).firstOrNull;
      if (target != null) {
        target.soberSentHome = true;

        // Apply protection via resolver so Dealer kills are deterministically blocked.
        abilityResolver.queueAbility(
          ActiveAbility(
            abilityId: 'sober_send_home',
            sourcePlayerId:
                players.where((p) => p.role.id == 'sober').firstOrNull?.id ??
                    'sober',
            targetPlayerIds: [target.id],
            trigger: AbilityTrigger.nightAction,
            effect: AbilityEffect.protect,
            priority: 1,
          ),
        );

        if (target.role.id == 'dealer') {
          nightActions['no_murders_tonight'] = true;
          nightActions.remove('kill');
        }
      }
    }

    // Bridge legacy nightActions into the ability queue (so resolution is deterministic)
    final protectTargetId = nightActions['protect'] as String?;
    if (protectTargetId != null) {
      abilityResolver.queueAbility(
        ActiveAbility(
          abilityId: 'medic_protect',
          sourcePlayerId:
              players.where((p) => p.role.id == 'medic').firstOrNull?.id ??
                  'medic',
          targetPlayerIds: [protectTargetId],
          trigger: AbilityTrigger.nightAction,
          effect: AbilityEffect.protect,
          priority: 20,
        ),
      );
    }

    final killTargetId = nightActions['kill'] as String?;

    // Dealer Block Logic (Roofi): If the solo dealer is blocked, the kill attempt proceeds in narrative but fails in mechanics.
    final aliveDealers =
        players.where((p) => p.isActive && p.role.id == 'dealer').toList();
    bool killBlockedByRoofi = false;
    if (aliveDealers.length == 1 &&
        aliveDealers.first.blockedKillNight == dayCount) {
      killBlockedByRoofi = true;
    }

    if (killTargetId != null && !killBlockedByRoofi) {
      abilityResolver.queueAbility(
        ActiveAbility(
          abilityId: 'dealer_kill',
          sourcePlayerId:
              players.where((p) => p.role.id == 'dealer').firstOrNull?.id ??
                  'dealer',
          targetPlayerIds: [killTargetId],
          trigger: AbilityTrigger.nightAction,
          effect: AbilityEffect.kill,
          priority: 50,
        ),
      );
    }

    final results = abilityResolver.resolveAllAbilities(players);

    final killedIds = <String>[];
    final protectedIds = <String>[];
    final minorProtectedIds = <String>[];
    final livesLostIds = <String>[];

    for (final r in results) {
      if (r.abilityId.contains('kill') && r.success) {
        killedIds.addAll(r.targets);
        protectedIds
            .addAll((r.metadata['protected'] as List<String>?) ?? const []);
        minorProtectedIds.addAll(
            (r.metadata['minor_protected'] as List<String>?) ?? const []);
        livesLostIds
            .addAll((r.metadata['lives_lost'] as List<String>?) ?? const []);
      }
    }

    final clean = StringBuffer()
      ..writeln('Good Morning, Clubbers!')
      ..writeln('Here is what went down last night:\n');

    final spicy = StringBuffer()
      ..writeln('Good Morning, Clubbers!')
      ..writeln('Here is what went down last night:\n');

    void addLine({String? cleanLine, String? spicyLine}) {
      final c = cleanLine?.trim();
      if (c != null && c.isNotEmpty) {
        clean.writeln(c);
      }
      final s = (spicyLine ?? cleanLine)?.trim();
      if (s != null && s.isNotEmpty) {
        spicy.writeln(s);
      }
    }

    var quietNight = true;

    if (soberTargetId != null) {
      final target = players.where((p) => p.id == soberTargetId).firstOrNull;
      if (target != null) {
        addLine(
          cleanLine: '• ${target.name} was sent home early.',
          spicyLine: '• The Sober sent ${target.name} home early.',
        );
        quietNight = false;
        if (target.role.id == 'dealer') {
          addLine(
            cleanLine:
                '• With someone important sent home, there were no murders tonight.',
            spicyLine:
                '• With a Dealer sent home, there were no Dealer murders tonight.',
          );
          quietNight = false;
        }
      }
    }

    final silverFoxTargetId = nightActions['silver_fox_alibi'] as String?;
    if (silverFoxTargetId != null) {
      final target =
          players.where((p) => p.id == silverFoxTargetId).firstOrNull;
      if (target != null) {
        addLine(
          cleanLine:
              '• ${target.name} has an alibi today (today only) and cannot be voted out.',
          spicyLine:
              '• Silver Fox gave ${target.name} an ALIBI — votes against them do not count today (today only).',
        );
        quietNight = false;
      }
    }

    final messyRumourTargetId = nightActions['messy_bitch_rumour'] as String?;
    if (messyRumourTargetId != null) {
      final target =
          players.where((p) => p.id == messyRumourTargetId).firstOrNull;
      if (target != null) {
        final gossip = kGossips[Random().nextInt(kGossips.length)];
        addLine(
          cleanLine: '• RUMOUR: ${target.name} $gossip',
          spicyLine:
              '• Messy Bitch spread a rumour that ${target.name} $gossip',
        );
        quietNight = false;
      }
    }

    final processed = <String>{};

    final clingerKillId = nightActions['kill_clinger'] as String?;
    if (clingerKillId != null) {
      final victim = players.where((p) => p.id == clingerKillId).firstOrNull;
      if (victim != null) {
        addLine(
          cleanLine: victim.isAlive
              ? '• ${victim.name} was attacked, but survived.'
              : '• ${victim.name} was attacked. Sadly, they died.',
          spicyLine: victim.isAlive
              ? '• The Clinger attacked ${victim.name}, but they survived.'
              : '• The Clinger attacked ${victim.name}. Sadly, they died.',
        );
        quietNight = false;
        processed.add(clingerKillId);
      }
    }

    // Creep
    final creepTargetSelection = nightActions['creep_target'] as String?;
    if (creepTargetSelection != null) {
      try {
        final creep = players.firstWhere((p) => p.role.id == 'creep');
        creep.creepTargetId = creepTargetSelection;
        final target = players.firstWhere((p) => p.id == creepTargetSelection);
        addLine(
          cleanLine: null,
          spicyLine: '• The Creep targeted ${target.name}.',
        );
        quietNight = false;
      } catch (_) {}
    }

    // Dealer kill narrative
    if (nightActions.containsKey('kill')) {
      final targetId = nightActions['kill'] as String;
      processed.add(targetId);

      final target = players.where((p) => p.id == targetId).firstOrNull;
      if (target == null) {
        addLine(
          cleanLine:
              '• There was a murder attempt, but the target was invalid.',
          spicyLine:
              '• The Dealers tried to kill someone... but the target was invalid.',
        );
      } else {
        if (target.soberSentHome || soberTargetId == targetId) {
          addLine(
            cleanLine:
                '• ${target.name} was targeted, but they were away for the night.',
            spicyLine:
                '• The Dealers tried to kill ${target.name}, but they were already sent home by The Sober.',
          );
          lastNightStats['saved'] = (lastNightStats['saved'] ?? 0) + 1;
        } else if (killBlockedByRoofi) {
          // Special case: Single Dealer was blocked by Roofi (paralyzed previous day).
          // Narratively they wake and choose, but the kill fails.
          addLine(
            cleanLine: '• ${target.name} was attacked, but survived.',
            spicyLine:
                '• The Dealer tried to kill ${target.name}, but failed to slip a blackout into the victim\'s drink.',
          );
          lastNightStats['saved'] = (lastNightStats['saved'] ?? 0) + 1;
        } else if (killedIds.contains(targetId)) {
          processDeath(target, cause: 'night_kill');

          if (target.role.id == 'second_wind' &&
              target.secondWindPendingConversion) {
            addLine(
              cleanLine: '• ${target.name} was attacked. Sadly, they died.',
              spicyLine:
                  '• The Dealers attacked ${target.name}. Sadly, they died. ($hostDisplayName: Conversion option may be available next night.)',
            );
            lastNightStats['killed'] = (lastNightStats['killed'] ?? 0) + 1;
          } else if (target.isAlive) {
            addLine(
              cleanLine: '• ${target.name} was attacked, but survived.',
              spicyLine:
                  '• The Dealers attacked ${target.name}, but they survived.',
            );
          } else {
            addLine(
              cleanLine: '• ${target.name} was attacked. Sadly, they died.',
              spicyLine:
                  '• The Dealers attacked ${target.name}. Sadly, they died.',
            );
            lastNightStats['killed'] = (lastNightStats['killed'] ?? 0) + 1;
          }
        } else if (protectedIds.contains(targetId)) {
          addLine(
            cleanLine: '• ${target.name} was attacked, but survived.',
            spicyLine:
                '• The Dealers chose to kill ${target.name}. But! The Medic arrived just in time to save them!',
          );
          lastNightStats['saved'] = (lastNightStats['saved'] ?? 0) + 1;
        } else if (minorProtectedIds.contains(targetId)) {
          addLine(
            cleanLine: '• ${target.name} was attacked, but survived.',
            spicyLine:
                '• The Dealers tried to kill ${target.name}, but the Bouncer was checking their ID! Safe!',
          );
          lastNightStats['saved'] = (lastNightStats['saved'] ?? 0) + 1;
        } else if (livesLostIds.contains(targetId)) {
          addLine(
            cleanLine:
                '• ${target.name} was attacked, but survived (lost a life).',
            spicyLine:
                '• The Dealers attacked ${target.name}, but they survived (Lost a Life).',
          );
        }
      }

      quietNight = false;
    }

    // Other kills
    for (final killedId in killedIds) {
      if (processed.contains(killedId)) continue;
      final victim = players.where((p) => p.id == killedId).firstOrNull;
      if (victim == null) {
        addLine(
          cleanLine: '• Someone was found dead.',
          spicyLine: '• Someone was found dead under mysterious circumstances.',
        );
        processed.add(killedId);
        quietNight = false;
        continue;
      }
      processDeath(victim, cause: 'night_kill_special');

      if (victim.role.id == 'second_wind' &&
          victim.secondWindPendingConversion) {
        addLine(
          cleanLine: '• ${victim.name} was found dead.',
          spicyLine:
              '• ${victim.name} was found dead. ($hostDisplayName: Conversion option may be available next night.)',
        );
        lastNightStats['killed'] = (lastNightStats['killed'] ?? 0) + 1;
      } else if (victim.isAlive) {
        addLine(
          cleanLine: '• ${victim.name} was attacked, but survived.',
          spicyLine:
              '• ${victim.name} was attacked under mysterious circumstances... but survived.',
        );
      } else {
        addLine(
          cleanLine: '• ${victim.name} was found dead.',
          spicyLine:
              '• ${victim.name} was found dead under mysterious circumstances.',
        );
        lastNightStats['killed'] = (lastNightStats['killed'] ?? 0) + 1;
      }

      processed.add(killedId);
      quietNight = false;
    }

    // Silences (legacy flags)
    final silencedToday =
        players.where((p) => p.isAlive && p.silencedDay == dayCount).toList();
    if (silencedToday.isNotEmpty) {
      final names = silencedToday.map((p) => p.name).join(', ');
      addLine(
        cleanLine: '• Silenced today: $names.',
        spicyLine: '• Shhh! Silenced for today: $names.',
      );
      lastNightStats['silenced'] = silencedToday.length;
      quietNight = false;
    }

    // Clinger heartbreak report
    if (_clingerDoubleDeaths.isNotEmpty) {
      for (final death in _clingerDoubleDeaths) {
        addLine(
          cleanLine: "• ${death['clinger']} was found dead.",
          spicyLine:
              "• HEARTBREAK: ${death['clinger']} couldn't live without ${death['obsession']} and died of a broken heart!",
        );
      }
      quietNight = false;
    }

    // Wallflower witness flavor (host-entered; should NOT reveal identity publicly).
    final wallflowerWitnessMode =
        (nightActions['wallflower_witness_mode'] as String?)?.toLowerCase();
    if (wallflowerWitnessMode == 'peek' || wallflowerWitnessMode == 'stare') {
      final verb = wallflowerWitnessMode == 'peek' ? 'peeked' : 'stared';
      addLine(
        cleanLine: '• Someone $verb at the chaos in the dark.',
        spicyLine:
            '• Wallflower $verb at the murder (logged for story export).',
      );
      quietNight = false;
    }

    // Medic revive (nightActions key)
    final reviveTargetId = nightActions['medic_revive'] as String?;
    if (reviveTargetId != null) {
      try {
        final medic = players.where((p) => p.role.id == 'medic').firstOrNull;
        final target = players.where((p) => p.id == reviveTargetId).firstOrNull;

        // Ignore invalid revive requests silently (host UI may have stale state).
        if (medic != null && target != null) {
          final medicPlayer = medic;
          final targetPlayer = target;

          final medicChoseRevive =
              (medicPlayer.medicChoice ?? '').toUpperCase() == 'REVIVE';
          final alreadyUsedRevive = medicPlayer.reviveUsed;
          final isSelfRevive = targetPlayer.id == medicPlayer.id;

          // If the Medic is dead, only allow self-revive.
          final allowedWhileDead = medicPlayer.isAlive || isSelfRevive;

          final targetIsPartyAnimal =
              targetPlayer.alliance.toLowerCase().contains('party');

          final canRevive = medicChoseRevive &&
              !alreadyUsedRevive &&
              allowedWhileDead &&
              targetIsPartyAnimal;

          // SPECIAL RULE: Medic can only revive someone who died THIS specific night.
          final diedThisNight = targetPlayer.deathDay == dayCount;

          if (canRevive && !targetPlayer.isAlive && diedThisNight) {
            targetPlayer.isAlive = true;
            targetPlayer.deathDay = null;
            targetPlayer.deathReason = null;
            if (targetPlayer.lives <= 0) targetPlayer.lives = 1;
            deadPlayerIds.remove(targetPlayer.id);

            medicPlayer.reviveUsed = true;
            addLine(
              cleanLine:
                  '• MIRACLE! ${targetPlayer.name} returned from the dead!',
              spicyLine:
                  '• MIRACLE! The Medic revived ${targetPlayer.name} from the dead!',
            );
            quietNight = false;
          }
        }
      } catch (_) {}
    }

    // Drama Queen Swap Results
    final lastSwap = lastDramaQueenSwap;
    if (lastSwap != null && lastSwap.day == dayCount) {
      addLine(
        cleanLine: '• ROLES SWAPPED: Two players have switched personas!',
        spicyLine:
            '• DRAMA QUEEN: ${lastSwap.playerAName} and ${lastSwap.playerBName} have swapped roles!',
      );
      quietNight = false;
    }

    if (quietNight) {
      addLine(
        cleanLine: '• Surprisingly... nothing happened. It was a quiet night.',
        spicyLine: '• Surprisingly... nothing happened. It was a quiet night.',
      );
    }

    final cleanText = clean.toString();
    final spicyText = spicy.toString();

    if (buildMorningReports) {
      lastNightSummary = cleanText;
      lastNightHostRecap = spicyText;
    }

    return cleanText;
  }

  bool voteOutPlayer(String playerId) {
    if (players.isEmpty) {
      logAction('Vote Error', 'No players available for voting.');
      return false;
    }

    _dayphaseVotesMade = true;

    final votedOutPlayer = players.where((p) => p.id == playerId).firstOrNull;
    if (votedOutPlayer == null) {
      logAction('Vote Error', 'Player with ID $playerId not found for voting.');
      return false;
    }

    if (votedOutPlayer.alibiDay == dayCount) {
      logAction(
        'Silver Fox',
        '${votedOutPlayer.name} has an ALIBI today and cannot be voted out.',
      );
      return false;
    }

    // Whore: vote deflection (only triggers when Dealer or Whore is voted out).
    if (votedOutPlayer.isAlive &&
        (votedOutPlayer.role.id == 'dealer' ||
            votedOutPlayer.role.id == 'whore')) {
      final whore =
          players.where((p) => p.role.id == 'whore' && p.isActive).firstOrNull;
      final deflectTargetId = whore?.whoreDeflectionTargetId;
      if (whore != null && deflectTargetId != null) {
        final target =
            players.where((p) => p.id == deflectTargetId).firstOrNull;
        if (target != null && target.isAlive) {
          whore.whoreDeflectionTargetId = null;
          whore.whoreDeflectionUsed = true; // Mark as used
          logAction('Vote Deflection',
              '${whore.name} deflected the vote from ${votedOutPlayer.name} to ${target.name}.');
          processDeath(target, cause: 'vote_deflection');
          return false;
        }
      }
    }

    // Predator: capture eligible voters at the moment of elimination.
    if (votedOutPlayer.role.id == 'predator') {
      pendingPredatorId = votedOutPlayer.id;
      // Capture voters from the raw vote map to avoid edge cases where
      // eligibility filters (sent-home / silenced) would prevent retaliation.
      // The engine will still validate the final retaliation target.
      pendingPredatorEligibleVoterIds = List<String>.from(
        currentDayVotesByTarget[votedOutPlayer.id] ?? const <String>[],
        growable: true,
      );

      // Prefer the marked target (if any), even if they weren't eligible to vote
      // (e.g., driven home / paralyzed). This keeps retaliation usable.
      final marked = nightActions['predator_mark'];
      if (marked is String) {
        final markedPlayer = players.where((p) => p.id == marked).firstOrNull;
        if (markedPlayer != null &&
            markedPlayer.isAlive &&
            markedPlayer.id != votedOutPlayer.id) {
          pendingPredatorPreferredTargetId = markedPlayer.id;
        } else {
          pendingPredatorPreferredTargetId = null;
        }
      } else {
        pendingPredatorPreferredTargetId = null;
      }

      queueHostAlert(
        title: 'Predator Retaliation',
        message:
            '${votedOutPlayer.name} was voted out. Resolve their retaliation in Host Overview → Pending actions.',
      );
    }

    processDeath(votedOutPlayer, cause: 'vote');
    return votedOutPlayer.role.id == 'dealer';
  }

  // --- Reactions ---

  void _processDeathReactions(Player victim, List<PendingReaction> reactions) {
    for (final reaction in reactions) {
      if (reaction.ability.id == 'drama_queen_swap') {
        _handleDramaQueenSwap(reaction);
      } else if (reaction.ability.id == 'tea_spiller_reveal') {
        _handleTeaSpillerReveal(reaction);
      }
    }
  }

  void _handleDramaQueenSwap(PendingReaction reaction) {
    dramaQueenSwapPending = true;
    dramaQueenMarkedAId ??= nightActions['drama_swap_a'] as String?;
    dramaQueenMarkedBId ??= nightActions['drama_swap_b'] as String?;

    final aName = dramaQueenMarkedAId != null
        ? players
            .firstWhere((p) => p.id == dramaQueenMarkedAId,
                orElse: () => reaction.sourcePlayer)
            .name
        : null;
    final bName = dramaQueenMarkedBId != null
        ? players
            .firstWhere((p) => p.id == dramaQueenMarkedBId,
                orElse: () => reaction.sourcePlayer)
            .name
        : null;

    final pendingLine = (aName != null && bName != null)
        ? 'Marked pair: $aName ↔ $bName.'
        : 'No marked pair. Host must choose two players.';

    logAction(
      "Drama Queen's Final Act",
      '${reaction.sourcePlayer.name} died. Open the action menu to swap two players. $pendingLine',
    );
    notifyListeners();
  }

  DramaQueenSwapRecord? completeDramaQueenSwap(Player playerA, Player playerB) {
    try {
      final roleA = playerA.role;
      final roleB = playerB.role;

      final fromRoleA = roleA.name;
      final fromRoleB = roleB.name;

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
        'Drama Queen Swap',
        'Swapped ${record.playerAName} (${record.fromRoleA} → ${record.toRoleA}) with ${record.playerBName} (${record.fromRoleB} → ${record.toRoleB}).',
      );
      notifyListeners();
      return record;
    } catch (e) {
      debugPrint('Error completing Drama Queen swap: $e');
      return null;
    }
  }

  void _resetPlayerStateForNewRole(Player player) {
    player.initialize();
    player.lives = 1;
    player.setLivesBasedOnDealers(players
        .where((p) => p.role.id == 'dealer' && p.isEnabled && p.isAlive)
        .length);

    // ...reset all role-state flags...
    player.idCheckedByBouncer = false;
    player.medicChoice = null;
    player.reviveUsed = false;
    player.creepTargetId = null;
    player.hasRumour = false;
    player.messyBitchKillUsed = false;
    player.clingerPartnerId = null;
    player.clingerFreedAsAttackDog = false;
    player.clingerAttackDogUsed = false;
    player.teaSpillerMarkId = null;
    player.tabooNames = [];
    player.minorHasBeenIDd = false;
    player.soberAbilityUsed = false;
    player.soberSentHome = false;
    player.silverFoxAbilityUsed = false;
    player.alibiDay = null;
    player.secondWindConverted = false;
    player.secondWindPendingConversion = false;
    player.secondWindRefusedConversion = false;
    player.secondWindConversionNight = null;
    player.joinsNextNight = false;
    player.deathDay = null;
    player.silencedDay = null;
    player.blockedKillNight = null;
    player.roofiAbilityRevoked = false;
    player.bouncerAbilityRevoked = false;
    player.bouncerHasRoofiAbility = false;
    player.whoreDeflectionTargetId = null;
    player.whoreDeflectionUsed = false;
    player.deathReason = null;

    // Check if new role requires setup
    if (['clinger', 'creep', 'medic'].contains(player.role.id)) {
      player.needsSetup = true;
    }
  }

  void _handleTeaSpillerReveal(PendingReaction reaction) {
    // Spec: triggers only when eliminated by vote, and can only target voters.
    final rawCause = reaction.triggeringEvent.data['cause'];
    final cause = rawCause is String ? rawCause.toLowerCase() : '';
    final isVoteElimination = cause == 'vote' || cause == 'voted_out';
    if (!isVoteElimination) return;

    if (pendingTeaSpillerId != null) return;

    final teaId = reaction.sourcePlayer.id;
    pendingTeaSpillerId = teaId;
    pendingTeaSpillerEligibleVoterIds = List<String>.from(
      eligibleDayVotesByTarget[teaId] ?? const <String>[],
      growable: true,
    );

    // Clean up any legacy mark so old saves don't show stale chips.
    reaction.sourcePlayer.teaSpillerMarkId = null;
    nightActions.remove('tea_spiller_mark');

    if (pendingTeaSpillerEligibleVoterIds.isEmpty) {
      logAction(
        'Tea Spiller',
        '${reaction.sourcePlayer.name} was eliminated by vote, but had no eligible voters to target.',
      );
      pendingTeaSpillerId = null;
      return;
    }

    logAction(
      'Tea Spiller',
      '${reaction.sourcePlayer.name} was eliminated by vote. Hand the screen to them to choose 1 of their voters to expose.',
    );
    notifyListeners();
  }

  bool completeTeaSpillerReveal(String targetId) {
    final teaId = pendingTeaSpillerId;
    if (teaId == null) return false;

    final tea = players.where((p) => p.id == teaId).firstOrNull;
    if (tea == null) {
      pendingTeaSpillerId = null;
      return false;
    }

    final target = players.where((p) => p.id == targetId).firstOrNull;
    if (target == null || target.role.id == 'host') return false;
    if (target.id == teaId) return false;

    if (!pendingTeaSpillerEligibleVoterIds.contains(targetId)) {
      return false;
    }

    pendingTeaSpillerId = null;
    pendingTeaSpillerEligibleVoterIds = <String>[];

    // Emit a reveal event so any future reaction logic can hook into this.
    reactionSystem.triggerEvent(
      GameEvent(
        type: GameEventType.roleRevealed,
        sourcePlayerId: teaId,
        targetPlayerId: targetId,
        data: const {'reason': 'tea_spiller'},
      ),
      players,
    );

    logAction(
      'Tea Spilled!',
      '${tea.name} exposed ${target.name} as ${target.role.name}.',
    );
    notifyListeners();
    return true;
  }

  void _handleCreepInheritance(Player victim) {
    try {
      final creeps = players
          .where((p) =>
              p.role.id == 'creep' &&
              p.isActive &&
              p.creepTargetId == victim.id)
          .toList();
      for (final creep in creeps) {
        logAction('Creep Inheritance',
            '${creep.name} inherited ${victim.role.name} from ${victim.name}');
        creep.role = victim.role;
        _resetPlayerStateForNewRole(creep);
        creep.alliance = victim.alliance;
      }
    } catch (_) {}
  }

  void _handleClingerObsessionDeath(Player victim) {
    try {
      final clingers = players
          .where((p) =>
              p.role.id == 'clinger' &&
              p.isActive &&
              p.clingerPartnerId == victim.id &&
              !p.clingerFreedAsAttackDog)
          .toList();
      for (final clinger in clingers) {
        logAction(
          'DOUBLE DEATH',
          "OBSESSION OVER! ${clinger.name} (The Clinger) couldn't live without ${victim.name} and has died of a broken heart!",
        );

        processDeath(clinger, cause: 'clinger_heartbreak');

        _clingerDoubleDeaths
            .add({'clinger': clinger.name, 'obsession': victim.name});
        onClingerDoubleDeath?.call(clinger.name, victim.name);
      }
    } catch (_) {}
  }

  // --- Role assignment ---

  void _assignRoles() {
    final eligiblePlayers =
        players.where((p) => p.isEnabled && p.role.id != hostRoleId).toList();
    if (eligiblePlayers.isEmpty) return;

    final random = Random();
    final dealerRole = roleRepository.getRoleById('dealer');
    if (dealerRole == null) {
      throw StateError('Dealer role is missing from the role repository.');
    }

    final partyAnimalRole = roleRepository.getRoleById('party_animal');
    final medicRole = roleRepository.getRoleById('medic');
    final bouncerRole = roleRepository.getRoleById('bouncer');

    final manualPlayers =
        eligiblePlayers.where((p) => p.role.id != 'temp').toList();
    final autoPlayers =
        eligiblePlayers.where((p) => p.role.id == 'temp').toList();

    final usedUniqueRoleIds = <String>{};
    var manualDealerCount = 0;

    for (final p in manualPlayers) {
      if (p.role.id == 'dealer') {
        manualDealerCount++;
      } else if (p.role.id != 'party_animal' &&
          !RoleValidator.multipleAllowedRoles.contains(p.role.id)) {
        if (!usedUniqueRoleIds.add(p.role.id)) {
          throw StateError(
              'Duplicate role detected: ${p.role.id}. Only Dealers and Party Animals can repeat.');
        }
      }
      p.initialize();
    }

    if (autoPlayers.isNotEmpty) {
      final deck = <Role>[];

      final recommendedDealers =
          RoleValidator.recommendedDealerCount(eligiblePlayers.length);
      final dealersToAssign =
          (recommendedDealers - manualDealerCount).clamp(0, autoPlayers.length);
      for (var i = 0; i < dealersToAssign; i++) {
        deck.add(dealerRole);
      }

      void addRequired(Role? role) {
        if (role == null) return;
        if (role.id == 'dealer') return;
        if (usedUniqueRoleIds.contains(role.id)) return;
        if (deck.length >= autoPlayers.length) return;
        usedUniqueRoleIds.add(role.id);
        deck.add(role);
      }

      addRequired(partyAnimalRole);
      if (!usedUniqueRoleIds.contains('medic') &&
          !usedUniqueRoleIds.contains('bouncer')) {
        addRequired(medicRole ?? bouncerRole);
      }

      final candidates = roleRepository.roles
          .where((r) => r.id != 'dealer' && r.id != 'temp')
          .where((r) => !usedUniqueRoleIds.contains(r.id))
          .toList()
        ..shuffle(random);

      for (final r in candidates) {
        if (deck.length >= autoPlayers.length) break;
        usedUniqueRoleIds.add(r.id);
        deck.add(r);
      }

      if (deck.length < autoPlayers.length) {
        throw StateError(
            'Not enough unique roles to assign ${autoPlayers.length} player(s).');
      }

      deck.shuffle(random);
      for (var i = 0; i < autoPlayers.length; i++) {
        autoPlayers[i].role = deck[i];
        autoPlayers[i].initialize();
      }
    }

    final dealerCount =
        eligiblePlayers.where((p) => p.role.id == 'dealer').length;
    for (final p in eligiblePlayers) {
      p.setLivesBasedOnDealers(dealerCount);
    }
  }

  // --- Logging ---

  void logAction(String title, String description,
      {GameLogType type = GameLogType.action, bool toast = false}) {
    final entry = GameLogEntry(
      turn: dayCount,
      phase: _currentPhase.name.toUpperCase(),
      title: title,
      description: description,
      timestamp: DateTime.now(),
      type: type,
    );

    _gameLog.insert(0, entry);

    // Games Night session recorder (no-op unless active).
    GamesNightService.instance.recordLogEntry(entry);

    // Optional UI toast for script actions (kept non-blocking).
    if (toast) {
      final trimmed = description.trim();
      final lower = trimmed.toLowerCase();
      final isTrivial = lower == 'acknowledged.' ||
          lower == 'skipped.' ||
          lower == 'no selection made.';
      if (trimmed.isNotEmpty && !isTrivial) {
        _queueToast(title: title, message: trimmed);
      }
    }

    notifyListeners();
  }

  // --- Script actions ---

  void handleScriptAction(ScriptStep step, List<String> selectedPlayerIds) {
    // Many script steps are informational (no selection required). Avoid treating
    // these as errors, since the host may simply tap NEXT.
    if (selectedPlayerIds.isEmpty) {
      switch (step.actionType) {
        case ScriptActionType.none:
        case ScriptActionType.showInfo:
        case ScriptActionType.info:
        case ScriptActionType.showTimer:
        case ScriptActionType.showDayScene:
        case ScriptActionType.phaseTransition:
        case ScriptActionType.discussion:
          logAction(step.title, 'Acknowledged.');
          return;
        case ScriptActionType.optional:
          logAction(step.title, 'Skipped.');
          return;
        default:
          logAction(step.title, 'No selection made.');
          return;
      }
    }

    final selections = selectedPlayerIds.toList();
    final roleId = step.roleId;
    if (roleId == null) {
      logAction(step.title, 'Step has no roleId; selection ignored.');
      return;
    }

    Player resolvePlayer(String id) => players.firstWhere(
          (p) => p.id == id,
          orElse: () => Player(
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
          ),
        );

    Player? sourcePlayer;
    try {
      sourcePlayer =
          players.firstWhere((p) => p.role.id == roleId && p.isActive);
    } catch (_) {}

    if (sourcePlayer != null && sourcePlayer.soberSentHome) {
      logAction(step.title,
          '${sourcePlayer.name} is SENT HOME and cannot act right now.');
      return;
    }

    // Roofi paralysis: a silenced player cannot act during the silenced day,
    // and if they were roofi'd tonight they cannot act for the remainder
    // of this night script.
    if (sourcePlayer != null && sourcePlayer.silencedDay != null) {
      final silenced = sourcePlayer.silencedDay;
      final isSilencedToday =
          _currentPhase == GamePhase.day && silenced == dayCount;
      final isSilencedThisNight =
          _currentPhase == GamePhase.night && silenced == (dayCount + 1);
      if (isSilencedToday || isSilencedThisNight) {
        logAction(step.title,
            '${sourcePlayer.name} is PARALYZED (Roofi) and cannot act right now.');
        return;
      }
    }

    bool? parseBinaryChoice(String raw) {
      final v = raw.trim().toLowerCase();
      if (v == 'true' || v == 'yes' || v == 'y' || v == '1') return true;
      if (v == 'false' || v == 'no' || v == 'n' || v == '0') return false;
      return null;
    }

    void applySecondWindDecision(
        {required bool convert, required String sourceTitle}) {
      final secondWind = players
          .where((p) =>
              p.role.id == 'second_wind' && p.secondWindPendingConversion)
          .firstOrNull;
      if (secondWind == null) {
        logAction(sourceTitle, 'No pending Second Wind conversion found.');
        return;
      }

      if (convert) {
        secondWind.secondWindConverted = true;
        secondWind.secondWindPendingConversion = false;
        secondWind.secondWindRefusedConversion = false;
        secondWind.secondWindConversionNight = null;

        final dealerRole = roleRepository.getRoleById('dealer');
        if (dealerRole != null) {
          secondWind.role = dealerRole;
          secondWind.alliance = dealerRole.alliance;
        }

        logAction(
            sourceTitle, '${secondWind.name} was converted into a Dealer.',
            toast: _currentPhase == GamePhase.night);

        // CRITICAL: Since they converted, skip the next "Dealer Kill" step.
        // We find the next step. If it is 'dealer_act', we consume it.
        final nextIndex = _scriptIndex + 1;
        if (nextIndex < _scriptQueue.length) {
          final nextStep = _scriptQueue[nextIndex];
          if (nextStep.id == 'dealer_act') {
            _scriptIndex++; // Advance index to "skip" it effectively
            logAction(
                'System', 'Skipping Dealer Kill phase due to Conversion.');
            // Note: GameScreen might need a refresh to pick up the skip
            // but usually next button press advances anyway.
            // Actually, we are IN the current step processing.
            // When this function returns, GameScreen will likely waiting for next.
            // We just moved the pointer forward.
          }
        }

        // Must revive the player!
        secondWind.isAlive = true;
        deadPlayerIds.remove(secondWind.id);
        secondWind.deathReason = null;
      } else {
        // They refused conversion.
        secondWind.secondWindRefusedConversion = true;
        secondWind.secondWindPendingConversion = false;

        // They remain dead. Clear the eligibility so we don't prompt again.
        secondWind.secondWindConversionNight = null;

        logAction(sourceTitle,
            'Dealers refused conversion. ${secondWind.name} remains dead.',
            toast: _currentPhase == GamePhase.night);

        // We do NOT skip the next step. They will proceed to 'dealer_act' to pick a new victim.
      }
    }

    switch (roleId) {
      case 'dealer':
        // Second Wind conversion choice (host-only). New flow uses CONVERT/KILL.
        // Keep legacy support for older saves that may still reference yes/no.
        if (step.actionType == ScriptActionType.binaryChoice &&
            (step.id == 'second_wind_conversion_choice' ||
                step.id == 'second_wind_conversion_vote')) {
          final raw = selections.first.trim().toLowerCase();
          final decision = raw == 'convert'
              ? true
              : (raw == 'kill' ? false : parseBinaryChoice(selections.first));
          if (decision == null) {
            logAction(step.title,
                'Invalid choice. Expected CONVERT/KILL (or yes/no legacy).');
            break;
          }
          applySecondWindDecision(convert: decision, sourceTitle: step.title);
          break;
        }

        final target = resolvePlayer(selections.first);
        nightActions['kill'] = target.id;
        logAction(step.title, 'Dealers selected ${target.name} to eliminate.',
            toast: _currentPhase == GamePhase.night);
        break;

      case 'second_wind':
        if (step.actionType != ScriptActionType.binaryChoice) {
          logAction(step.title, 'Second Wind step is not a binary choice.');
          break;
        }

        final decision = parseBinaryChoice(selections.first);
        if (decision == null) {
          logAction(step.title, 'Invalid choice. Expected yes/no.');
          break;
        }

        applySecondWindDecision(convert: decision, sourceTitle: step.title);
        break;

      case 'sober':
        final sober = players
            .where((p) => p.role.id == 'sober' && p.isActive)
            .firstOrNull;
        if (sober == null) {
          logAction(step.title, 'No active Sober in game.');
          break;
        }
        if (sober.soberAbilityUsed) {
          logAction(step.title, 'Sober ability already used.');
          break;
        }

        final target = resolvePlayer(selections.first);
        if (target.id == '?') {
          logAction(step.title, 'Invalid target selection.');
          break;
        }

        sober.soberAbilityUsed = true;
        target.soberSentHome = true;
        nightActions['sober_sent_home'] = target.id;
        if (target.role.id == 'dealer') {
          nightActions['no_murders_tonight'] = true;
        }
        logAction(step.title, 'Sober sent ${target.name} home for the night.',
            toast: _currentPhase == GamePhase.night);

        // This affects who wakes up, so rebuild the remaining night script.
        rebuildNightScript();
        break;

      case 'silver_fox':
        final silverFox = players
            .where((p) => p.role.id == 'silver_fox' && p.isActive)
            .firstOrNull;
        if (silverFox == null) {
          logAction(step.title, 'No active Silver Fox in game.');
          break;
        }

        final silverTarget = resolvePlayer(selections.first);
        if (silverTarget.id == '?') {
          logAction(step.title, 'Invalid target selection.');
          break;
        }

        // Alibi applies to the FOLLOWING day. Day count is incremented at the
        // end of the night->day transition, so use (dayCount + 1).
        silverTarget.alibiDay = dayCount + 1;
        nightActions['silver_fox_alibi'] = silverTarget.id;
        logAction(step.title,
            'Silver Fox gave ${silverTarget.name} an alibi (cannot be voted out tomorrow).',
            toast: _currentPhase == GamePhase.night);
        break;

      case 'medic':
        if (step.id == 'medic_setup_choice') {
          final decision = selections.first;
          final medic = players
                  .where(
                      (p) => p.role.id == 'medic' && p.isActive && p.needsSetup)
                  .firstOrNull ??
              players
                  .where((p) => p.role.id == 'medic' && p.isActive)
                  .firstOrNull;
          if (medic != null) {
            medic.medicChoice = decision;
            medic.needsSetup = false;
            logAction(step.title, 'Medic chose ability: $decision.',
                toast: _currentPhase == GamePhase.night);
          }
          break;
        }
        final target = resolvePlayer(selections.first);
        final medic = players.where((p) => p.role.id == 'medic').firstOrNull;
        if (medic != null) {
          if (medic.medicChoice == 'PROTECT_DAILY') {
            nightActions['protect'] = target.id;
            logAction(step.title, 'Medic protected ${target.name}.',
                toast: _currentPhase == GamePhase.night);
          } else if (medic.medicChoice == 'REVIVE') {
            // Only allow if not already used
            if (!medic.reviveUsed) {
              nightActions['medic_revive'] = target.id;
              logAction(step.title, 'Medic chose to revive ${target.name}.',
                  toast: _currentPhase == GamePhase.night);
            }
          }
        }
        break;

      case 'bouncer':
        final bouncer = players
            .where((p) => p.isActive && p.role.id == 'bouncer')
            .firstOrNull;
        if (bouncer != null && bouncer.bouncerAbilityRevoked) {
          logAction(step.title,
              'Bouncer ID-check ability has been revoked; action ignored.');
          break;
        }

        final target = resolvePlayer(selections.first);
        final wasMinorImmune =
            target.role.id == 'minor' && target.minorHasBeenIDd == false;
        nightActions['bouncer_check'] = target.id;
        target.idCheckedByBouncer = true;
        var queuedSpecialAlert = false;
        if (target.role.id == 'minor') {
          target.minorHasBeenIDd = true;
          if (wasMinorImmune) {
            queueHostAlert(
              title: 'Minor is now vulnerable',
              message:
                  "${target.name} was I.D.'d by the Bouncer and is no longer immune to Dealer kills.",
            );
            queuedSpecialAlert = true;
          }
        }

        // Host Feedback for ID Check (avoid overwriting a special alert, e.g. Minor vulnerability)
        if (!queuedSpecialAlert) {
          final isDealerSide = target.alliance == 'The Dealers' ||
              target.role.alliance == 'The Dealers';
          if (isDealerSide) {
            queueHostAlert(
              title: 'Gotcha!',
              message: 'A Dealer or a Friend of the Dealers was caught.',
            );
          } else {
            queueHostAlert(
              title: 'Clear',
              message: '${target.name} appears innocent.',
            );
          }
        }

        logAction(
            step.title, "Bouncer I.D.'d ${target.name} → ${target.alliance}.",
            toast: _currentPhase == GamePhase.night);
        break;

      case 'roofi':
        final activeRoofi = players
            .where((p) =>
                p.isActive && p.role.id == 'roofi' && !p.roofiAbilityRevoked)
            .firstOrNull;
        final stolenByBouncer = players
            .where((p) =>
                p.isActive &&
                p.role.id == 'bouncer' &&
                p.bouncerHasRoofiAbility)
            .firstOrNull;
        if (activeRoofi == null && stolenByBouncer == null) {
          logAction(step.title,
              'No active Roofi power available (revoked or missing).');
          break;
        }

        final target = resolvePlayer(selections.first);
        nightActions['roofi'] = target.id;
        target.silencedDay = dayCount + 1;
        if (target.role.id == 'dealer') target.blockedKillNight = dayCount + 1;

        final actorLabel =
            stolenByBouncer != null ? 'Bouncer (stolen Roofi powers)' : 'Roofi';
        logAction(step.title,
            '$actorLabel silenced ${target.name} for Day ${dayCount + 1}.',
            toast: _currentPhase == GamePhase.night);
        break;

      case 'creep':
        final target = resolvePlayer(selections.first);
        nightActions['creep_target'] = target.id;
        final creep = players
                .where(
                    (p) => p.role.id == 'creep' && p.isActive && p.needsSetup)
                .firstOrNull ??
            players
                .where((p) => p.role.id == 'creep' && p.isActive)
                .firstOrNull;
        if (creep != null) {
          creep.creepTargetId = target.id;
          creep.needsSetup = false;
        }
        logAction(step.title, 'Creep chose to mimic ${target.name}.',
            toast: _currentPhase == GamePhase.night);
        break;

      case 'clinger':
        final target = resolvePlayer(selections.first);
        if (step.id == 'clinger_act') {
          final clinger = players
              .where((p) => p.role.id == 'clinger' && p.isActive)
              .firstOrNull;
          if (clinger == null) {
            logAction(step.title, 'No active Clinger in game.');
            break;
          }

          // Guardrails: the script builder should only surface this step when
          // unleashed, but keep the engine safe if UI/host triggers it anyway.
          if (!clinger.clingerFreedAsAttackDog) {
            logAction(step.title,
                'Clinger is not UNLEASHED yet. Attack Dog cannot be used.');
            break;
          }
          if (clinger.clingerAttackDogUsed) {
            logAction(step.title, 'Attack Dog already used.');
            break;
          }
          if (target.id == '?') {
            logAction(step.title, 'Invalid target selection.');
            break;
          }

          clinger.clingerAttackDogUsed = true;
          nightActions['kill_clinger'] = target.id;
          // Per role rules: this kill happens immediately.
          processDeath(target, cause: 'clinger_attack_dog');
          logAction(step.title,
              'Clinger used Attack Dog ability on ${target.name} (immediate).',
              toast: _currentPhase == GamePhase.night);
        } else {
          final clinger = players
                  .where((p) =>
                      p.role.id == 'clinger' && p.isAlive && p.needsSetup)
                  .firstOrNull ??
              players
                  .where((p) => p.role.id == 'clinger' && p.isAlive)
                  .firstOrNull;
          if (clinger != null) {
            clinger.clingerPartnerId = target.id;
            clinger.needsSetup = false;
            nightActions['clinger_obsession'] = target.id;
            // Force immediate UI update so chips appear instantly
            notifyListeners();
            logAction(
                step.title, 'Clinger chose ${target.name} as their obsession.',
                toast: _currentPhase == GamePhase.night);
          }
        }
        break;

      case 'lightweight':
        final target = resolvePlayer(selections.first);
        nightActions['lightweight_taboo'] = target.id;
        if (sourcePlayer != null &&
            !sourcePlayer.tabooNames.contains(target.name)) {
          sourcePlayer.tabooNames.add(target.name);
        }
        logAction(step.title, 'Lightweight taboo added: ${target.name}.',
            toast: _currentPhase == GamePhase.night);
        break;

      case 'messy_bitch':
        // Defensive: only accept rumours from the expected step id.
        if (step.id != 'messy_bitch_act') {
          logAction(step.title,
              'Ignored Messy Bitch action from unexpected step id.');
          break;
        }

        final messyBitch = players
            .where((p) => p.role.id == 'messy_bitch' && p.isActive)
            .firstOrNull;
        if (messyBitch == null) {
          logAction(step.title, 'No active Messy Bitch in game.');
          break;
        }
        if (!messyBitch.isAlive) {
          logAction(
              step.title, 'Messy Bitch is dead and cannot spread rumours.');
          break;
        }
        if (messyBitch.soberSentHome) {
          logAction(
              step.title, 'Messy Bitch was sent home and cannot act tonight.');
          break;
        }

        final rumourTarget = resolvePlayer(selections.first);
        if (rumourTarget.id == '?') {
          logAction(step.title, 'Invalid target selection.');
          break;
        }
        if (rumourTarget.role.id == 'host') {
          logAction(step.title, 'Cannot spread rumours about the host.');
          break;
        }
        if (!rumourTarget.isEnabled || !rumourTarget.isAlive) {
          logAction(step.title, 'Rumour target must be a living player.');
          break;
        }
        if (rumourTarget.id == messyBitch.id) {
          logAction(
              step.title, 'Messy Bitch must choose another living player.');
          break;
        }

        rumourTarget.hasRumour = true;
        nightActions['messy_bitch_rumour'] = rumourTarget.id;
        logAction(
            step.title, 'Messy Bitch spread a rumour to ${rumourTarget.name}.',
            toast: _currentPhase == GamePhase.night);
        break;

      case 'drama_queen':
        if (selections.length >= 2) {
          final a = resolvePlayer(selections[0]);
          final b = resolvePlayer(selections[1]);
          nightActions['drama_swap_a'] = a.id;
          nightActions['drama_swap_b'] = b.id;
          dramaQueenMarkedAId = a.id;
          dramaQueenMarkedBId = b.id;
          logAction(step.title,
              'Drama Queen marked ${a.name} and ${b.name} for swap on death.',
              toast: _currentPhase == GamePhase.night);
        }
        break;

      case 'bartender':
        if (selections.length >= 2) {
          final a = resolvePlayer(selections[0]);
          final b = resolvePlayer(selections[1]);
          final sameTeam = a.alliance == b.alliance;
          nightActions['bartender_a'] = a.id;
          nightActions['bartender_b'] = b.id;
          logAction(
            step.title,
            "Bartender checked ${a.name} + ${b.name} → ${sameTeam ? 'SAME team' : 'DIFFERENT teams'}.",
            toast: _currentPhase == GamePhase.night,
          );
        } else {
          logAction(step.title, 'Bartender needs two selections.');
        }
        break;

      case 'tea_spiller':
        logAction(
          step.title,
          'Tea Spiller has no night action. Reveal triggers on death.',
        );
        break;

/* Predator Night Action Removed - Happens on Death 
      case 'predator':
        final target = resolvePlayer(selections.first);
        if (sourcePlayer != null) {
          sourcePlayer.predatorMarkId = target.id;
        }
        nightActions['predator_mark'] = target.id;
        logAction(step.title,
            'Predator will retaliate against ${target.name} if voted out.');
        break;
*/

      case 'whore':
        final target = resolvePlayer(selections.first);
        final whore = players
            .where((p) => p.role.id == 'whore' && p.isActive)
            .firstOrNull;
        if (whore != null) {
          if (whore.whoreDeflectionUsed) {
            logAction(step.title,
                'Whore deflection already USED. Scapegoat selection ignored.');
            break;
          }
          if (whore.whoreDeflectionTargetId != null) {
            final lockedTarget = players
                .where((p) => p.id == whore.whoreDeflectionTargetId)
                .firstOrNull;
            logAction(
              step.title,
              'Whore scapegoat already locked${lockedTarget != null ? ': ${lockedTarget.name}' : ''} (ignored: ${target.name}).',
            );
            break;
          }
          if (target.id == '?' || !target.isEnabled || !target.isAlive) {
            logAction(step.title, 'Invalid scapegoat target selection.');
            break;
          }
          if (target.role.id == 'host') {
            logAction(step.title, 'Whore cannot select the host.');
            break;
          }
          if (target.id == whore.id) {
            logAction(step.title, 'Whore must choose another player.');
            break;
          }
          // Scapegoat must be a non-Dealer so it actually "takes the fall".
          if (target.alliance.toLowerCase().contains('dealer') ||
              target.role.id == 'dealer') {
            logAction(step.title, 'Scapegoat must be a non-Dealer player.');
            break;
          }

          whore.whoreDeflectionTargetId = target.id;
          nightActions['whore_deflect'] = target.id;
          logAction(step.title,
              "Whore chose ${target.name} as THE WHORE'S BITCH (one-time scapegoat).\nIf the Whore or a Dealer is voted out, ${target.name} will take the fall once.",
              toast: _currentPhase == GamePhase.night);
        }
        break;

      case 'wallflower':
        // Legacy path: older scripts/tests may call handleScriptAction with a
        // binary choice. Map yes/no -> peek/skip, and store via handleScriptOption.
        final wantsWitness = parseBinaryChoice(selections.first);
        if (wantsWitness == null) {
          logAction(step.title, 'Invalid choice. Expected yes/no.');
          break;
        }
        handleScriptOption(step, wantsWitness ? 'PEEK' : 'SKIP');
        break;

      case 'club_manager':
      case 'club_manager_act':
        final clubManager = sourcePlayer;
        if (clubManager == null) {
          logAction(step.title, 'No active Club Manager in game.');
          break;
        }

        final target = resolvePlayer(selections.first);
        if (target.id == '?' || !target.isEnabled || !target.isAlive) {
          logAction(step.title, 'Invalid Club Manager target selection.');
          break;
        }
        if (target.role.id == 'host') {
          logAction(step.title, 'Club Manager cannot view the host.');
          break;
        }
        if (target.id == clubManager.id) {
          logAction(step.title, 'Club Manager must choose a fellow player.');
          break;
        }

        logAction(step.title,
            "Club Manager viewed ${target.name}'s role: ${target.role.name}",
            toast: _currentPhase == GamePhase.night);
        onClubManagerReveal?.call(target);
        break;

      default:
        final names = selections.map((id) => resolvePlayer(id).name).join(', ');
        logAction(step.title, 'Selected: $names',
            toast: _currentPhase == GamePhase.night);
        break;
    }
  }

  /// Completes Predator retaliation by killing one eligible voter.
  ///
  /// If vote telemetry was not recorded, falls back to any alive non-Predator.
  bool completePredatorRetaliation(String targetId) {
    final predatorId = pendingPredatorId;
    if (predatorId == null) return false;

    final predator = players.where((p) => p.id == predatorId).firstOrNull;
    if (predator == null) {
      pendingPredatorId = null;
      pendingPredatorEligibleVoterIds = <String>[];
      pendingPredatorPreferredTargetId = null;
      return false;
    }

    final alive = players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .toList();

    final baseEligible = alive.where((p) => p.id != predatorId).toList();

    // If we have captured voter telemetry, restrict to those voters...
    final restricted = pendingPredatorEligibleVoterIds.isNotEmpty
        ? baseEligible
            .where((p) => pendingPredatorEligibleVoterIds.contains(p.id))
            .toList()
        : baseEligible;

    // ...but always allow the preferred marked target (if alive), even if they
    // were sent home / silenced and didn't vote.
    final preferredId = pendingPredatorPreferredTargetId;
    final preferred = preferredId == null
        ? null
        : baseEligible.where((p) => p.id == preferredId).firstOrNull;

    final eligible =
        <Player>{...restricted, if (preferred != null) preferred}.toList();

    final target = eligible.where((p) => p.id == targetId).firstOrNull;
    if (target == null) {
      logAction('Predator Retaliation', 'Invalid retaliation target selected.');
      return false;
    }

    processDeath(target, cause: 'predator_retaliation');
    logAction('Predator Retaliation',
        '${predator.name} took ${target.name} down with them.');

    pendingPredatorId = null;
    pendingPredatorEligibleVoterIds = <String>[];
    pendingPredatorPreferredTargetId = null;
    notifyListeners();
    return true;
  }

  /// The Bouncer may challenge a suspected Roofi to steal their paralyze power.
  ///
  /// - If the suspect is an active Roofi, Roofi loses their ability and the
  ///   Bouncer gains it.
  /// - If incorrect, the Bouncer permanently loses their ID-check ability.
  ///
  /// Defensive behavior: this is a one-time resolution per game because either
  /// success or failure sets a terminal flag.
  bool resolveBouncerRoofiChallenge(String suspectedPlayerId) {
    final bouncer =
        players.where((p) => p.isActive && p.role.id == 'bouncer').firstOrNull;
    if (bouncer == null) {
      logAction('Bouncer Challenge', 'No active Bouncer in game.');
      return false;
    }

    // If the Bouncer already lost ID checks or already has Roofi powers,
    // the challenge should not run again.
    if (bouncer.bouncerAbilityRevoked) {
      logAction('Bouncer Challenge',
          'Bouncer already lost ID-check ability; cannot challenge again.');
      return false;
    }
    if (bouncer.bouncerHasRoofiAbility) {
      logAction('Bouncer Challenge',
          'Bouncer already has Roofi powers; cannot challenge again.');
      return false;
    }

    final suspect = players.where((p) => p.id == suspectedPlayerId).firstOrNull;
    if (suspect == null || !suspect.isActive) {
      logAction('Bouncer Challenge', 'Invalid Roofi challenge target.');
      return false;
    }

    if (suspect.role.id == 'roofi' && !suspect.roofiAbilityRevoked) {
      suspect.roofiAbilityRevoked = true;
      bouncer.bouncerHasRoofiAbility = true;
      logAction('Bouncer Challenge',
          'Bouncer correctly challenged ${suspect.name} and stole Roofi powers.');
      rebuildNightScript();
      notifyListeners();
      return true;
    }

    bouncer.bouncerAbilityRevoked = true;
    logAction('Bouncer Challenge',
        'Bouncer incorrectly challenged ${suspect.name} — ID checks are lost forever.');
    rebuildNightScript();
    notifyListeners();
    return true;
  }

  void handleScriptOption(ScriptStep step, String selectedOption) {
    final roleId = step.roleId;

    switch (roleId) {
      case 'wallflower':
        final raw = selectedOption.trim().toUpperCase();
        String? mode;
        if (raw == 'SKIP') mode = 'skip';
        if (raw == 'PEEK') mode = 'peek';
        if (raw == 'STARE') mode = 'stare';

        // Back-compat: older scripts/tests may still send YES/NO.
        if (mode == null && raw == 'YES') mode = 'peek';
        if (mode == null && raw == 'NO') mode = 'skip';

        if (mode == null) {
          logAction(step.title, 'Invalid Wallflower option: $selectedOption');
          break;
        }

        final wallflower = players
            .where((p) => p.role.id == 'wallflower' && p.isActive)
            .firstOrNull;
        if (wallflower == null) {
          logAction(step.title, 'No active Wallflower in game.');
          break;
        }
        if (!wallflower.isAlive) {
          logAction(step.title, 'Wallflower is dead; witness choice ignored.');
          break;
        }
        if (wallflower.soberSentHome) {
          logAction(
              step.title, 'Wallflower was sent home; witness choice ignored.');
          break;
        }

        nightActions['wallflower_witness_mode'] = mode;

        if (mode == 'skip') {
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'wallflower_skip',
              sourcePlayerId: wallflower.id,
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.other,
              priority: 60,
            ),
          );
          logAction(step.title, 'Wallflower declined to witness.',
              toast: _currentPhase == GamePhase.night);
        } else {
          abilityResolver.queueAbility(
            ActiveAbility(
              abilityId: 'wallflower_witness',
              sourcePlayerId: wallflower.id,
              trigger: AbilityTrigger.nightAction,
              effect: AbilityEffect.other,
              priority: 60,
              metadata: {'mode': mode},
            ),
          );
          logAction(step.title, 'Wallflower chose to $mode.',
              toast: _currentPhase == GamePhase.night);
        }
        break;

      case 'medic':
        final option = selectedOption.toUpperCase();
        if (option != 'PROTECT' && option != 'REVIVE') return;

        final medic = players.where((p) => p.role.id == 'medic').firstOrNull;
        if (medic != null) {
          if (medic.medicChoice != null && medic.medicChoice!.isNotEmpty) {
            logAction(step.title,
                'Medic choice already locked: ${medic.medicChoice} (ignored: $option)');
            break;
          }
          medic.medicChoice = option == 'PROTECT' ? 'PROTECT_DAILY' : 'REVIVE';
          medic.needsSetup = false;
          logAction(step.title, 'Medic permanently chose: ${medic.medicChoice}',
              toast: _currentPhase == GamePhase.night);
        }
        break;

      default:
        logAction(step.title, 'Selected option: $selectedOption',
            toast: _currentPhase == GamePhase.night);
        break;
    }
    notifyListeners();
  }

  // --- Win checks (minimal, matches common rules + your LiveGameStats normalization) ---

  bool checkWinConditions() {
    // Once a winner is locked in, keep returning true without re-evaluating.
    if (_winner != null) return true;

    // Messy Bitch immediate win: rumours have reached every enabled guest.
    if (_isMessyBitchWinConditionMet()) {
      _winner = 'Messy Bitch';
      _winMessage = 'Messy Bitch spread a rumour to every player.';
      GamesNightService.instance.recordGameEnded(this);
      return true;
    }

    final alive = players
        .where((p) => p.isAlive && p.isEnabled && p.role.id != 'host')
        .toList();
    final dealerAlive = alive
        .where((p) =>
            p.alliance.toLowerCase().contains('dealer') ||
            p.role.id == 'dealer')
        .length;
    final partyAlive =
        alive.where((p) => p.alliance.toLowerCase().contains('party')).length;

    if (alive.isEmpty) {
      _winner = 'No one';
      _winMessage = 'No one wins. Everyone is dead.';
      GamesNightService.instance.recordGameEnded(this);
      return true;
    }

    // Club Manager special win: only Club Manager + 1 Dealer remain.
    if (alive.length == 2 && dealerAlive == 1) {
      final clubManagerAlive = alive.any((p) => p.role.id == 'club_manager');
      if (clubManagerAlive) {
        _winner = 'Club Manager';
        _winMessage = 'Only the Club Manager and a Dealer remain.';
        GamesNightService.instance.recordGameEnded(this);
        return true;
      }
    }

    // Party wins if no dealers remain (and at least one party remains).
    if (dealerAlive == 0 && partyAlive > 0) {
      _winner = 'Party Animals';
      _winMessage = 'All Dealers are eliminated.';
      GamesNightService.instance.recordGameEnded(this);
      return true;
    }

    // Dealer win condition: exactly 1 Dealer vs 1 Party Animal.
    if (alive.length == 2 && dealerAlive == 1 && partyAlive == 1) {
      _winner = 'Dealers';
      _winMessage = 'Final showdown: 1 Dealer vs 1 Party Animal.';
      GamesNightService.instance.recordGameEnded(this);
      return true;
    }

    return false;
  }

  // --- Persistence (kept minimal; extend as needed) ---

  Future<void> saveGame(String saveName, {String? overwriteId}) async {
    final prefs = await SharedPreferences.getInstance();

    final saveId =
        overwriteId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // If overwriting, clear out old keys we know about to avoid stale state.
    if (overwriteId != null) {
      await _deleteSaveKeys(prefs, saveId);
    }

    final playersJson = jsonEncode(players.map((p) => p.toJson()).toList());
    final logJson = jsonEncode(_gameLog.map((l) => l.toJson()).toList());

    // New: single-blob save (preferred for robustness).
    final blob = <String, dynamic>{
      'schemaVersion': _saveSchemaVersion,
      'savedAt': DateTime.now().toIso8601String(),
      'players': jsonDecode(playersJson),
      'log': jsonDecode(logJson),
      'phaseIndex': _currentPhase.index,
      'dayCount': dayCount,
      'scriptIndex': _scriptIndex,
      'lastNightSummary': lastNightSummary,
      'lastNightHostRecap': lastNightHostRecap,
      'nightActions': nightActions,
      'deadPlayerIds': deadPlayerIds,
      'votesByVoter': currentDayVotesByVoter,
      'votesByTarget': currentDayVotesByTarget,
      'voteHistory': voteHistory.map((v) => v.toJson()).toList(),
      'voteSequence': _voteSequence,
      'predatorPending': {
        'pendingPredatorId': pendingPredatorId,
        'eligibleVoterIds': pendingPredatorEligibleVoterIds,
        'preferredTargetId': pendingPredatorPreferredTargetId,
      },
      'teaSpillerPending': {
        'pendingTeaSpillerId': pendingTeaSpillerId,
        'eligibleVoterIds': pendingTeaSpillerEligibleVoterIds,
      },
      'dramaQueenPending': {
        'swapPending': dramaQueenSwapPending,
        'markedAId': dramaQueenMarkedAId,
        'markedBId': dramaQueenMarkedBId,
      },
      'statusEffects': statusEffectManager.toJson(),
      'abilityQueue': abilityResolver.toJson(),
      'reactionHistory': reactionSystem.getHistoryJson(),
      if (lastDramaQueenSwap != null)
        'lastDramaQueenSwap': {
          'day': lastDramaQueenSwap!.day,
          'playerAName': lastDramaQueenSwap!.playerAName,
          'playerBName': lastDramaQueenSwap!.playerBName,
          'fromRoleA': lastDramaQueenSwap!.fromRoleA,
          'fromRoleB': lastDramaQueenSwap!.fromRoleB,
          'toRoleA': lastDramaQueenSwap!.toRoleA,
          'toRoleB': lastDramaQueenSwap!.toRoleB,
        },
    };

    await prefs.setString(_saveBlobKey(saveId), jsonEncode(blob));

    // Legacy per-field keys (kept for backward compatibility + existing tests).
    await prefs.setString(_saveKey(saveId, 'players'), playersJson);
    await prefs.setString(_saveKey(saveId, 'log'), logJson);
    await prefs.setInt(_saveKey(saveId, 'phase'), _currentPhase.index);
    await prefs.setInt(_saveKey(saveId, 'dayCount'), dayCount);
    await prefs.setInt(_saveKey(saveId, 'scriptIndex'), _scriptIndex);

    // Host-facing recap (keeps Day bulletin consistent after load).
    await prefs.setString(
        _saveKey(saveId, 'lastNightSummary'), lastNightSummary);
    await prefs.setString(
        _saveKey(saveId, 'lastNightHostRecap'), lastNightHostRecap);

    // In-flight engine state used by tests / mid-game resumes
    await prefs.setString(
        _saveKey(saveId, 'nightActions'), jsonEncode(nightActions));
    await prefs.setString(
        _saveKey(saveId, 'deadPlayerIds'), jsonEncode(deadPlayerIds));
    await prefs.setString(
        _saveKey(saveId, 'votesByVoter'), jsonEncode(currentDayVotesByVoter));
    await prefs.setString(
        _saveKey(saveId, 'votesByTarget'), jsonEncode(currentDayVotesByTarget));
    await prefs.setString(_saveKey(saveId, 'voteHistory'),
        jsonEncode(voteHistory.map((v) => v.toJson()).toList()));
    await prefs.setInt(_saveKey(saveId, 'voteSequence'), _voteSequence);
    await prefs.setString(
      _saveKey(saveId, 'predatorPending'),
      jsonEncode({
        'pendingPredatorId': pendingPredatorId,
        'eligibleVoterIds': pendingPredatorEligibleVoterIds,
        'preferredTargetId': pendingPredatorPreferredTargetId,
      }),
    );
    await prefs.setString(
      _saveKey(saveId, 'teaSpillerPending'),
      jsonEncode({
        'pendingTeaSpillerId': pendingTeaSpillerId,
        'eligibleVoterIds': pendingTeaSpillerEligibleVoterIds,
      }),
    );
    await prefs.setString(
      _saveKey(saveId, 'dramaQueenPending'),
      jsonEncode({
        'swapPending': dramaQueenSwapPending,
        'markedAId': dramaQueenMarkedAId,
        'markedBId': dramaQueenMarkedBId,
      }),
    );
    await prefs.setString(_saveKey(saveId, 'statusEffects'),
        jsonEncode(statusEffectManager.toJson()));
    await prefs.setString(
        _saveKey(saveId, 'abilityQueue'), jsonEncode(abilityResolver.toJson()));

    final saveMetadata = SavedGame(
      id: saveId,
      name: saveName,
      savedAt: DateTime.now(),
      dayCount: dayCount,
      alivePlayers: players.where((p) => p.isActive).length,
      totalPlayers: players.where((p) => p.isEnabled).length,
      currentPhase: _currentPhase.toString().split('.').last,
    );

    final saves = await getSavedGames();
    // Remove any existing entry for this id (overwrite / duplicate repair).
    saves.removeWhere((s) => s.id == saveId);
    saves.add(saveMetadata);
    await prefs.setString(
        _savedGamesIndexKey, jsonEncode(saves.map((s) => s.toJson()).toList()));

    if (lastDramaQueenSwap != null) {
      prefs.setString(
        _saveKey(saveId, 'lastDramaQueenSwap'),
        jsonEncode({
          'day': lastDramaQueenSwap!.day,
          'playerAName': lastDramaQueenSwap!.playerAName,
          'playerBName': lastDramaQueenSwap!.playerBName,
          'fromRoleA': lastDramaQueenSwap!.fromRoleA,
          'fromRoleB': lastDramaQueenSwap!.fromRoleB,
          'toRoleA': lastDramaQueenSwap!.toRoleA,
          'toRoleB': lastDramaQueenSwap!.toRoleB,
        }),
      );
    }

    prefs.setString(_saveKey(saveId, 'reactionHistory'),
        jsonEncode(reactionSystem.getHistoryJson()));
  }

  Future<List<SavedGame>> getSavedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final savesJson = prefs.getString(_savedGamesIndexKey);
    if (savesJson == null) return [];

    try {
      final decoded = jsonDecode(savesJson) as List<dynamic>;
      final saves = decoded
          .whereType<Map>()
          .map((j) => SavedGame.fromJson(j.cast<String, dynamic>()))
          .where((s) => s.id.isNotEmpty)
          .toList();
      return saves;
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteSavedGame(String saveId) async {
    final prefs = await SharedPreferences.getInstance();
    await _deleteSaveKeys(prefs, saveId);

    final saves = await getSavedGames();
    saves.removeWhere((s) => s.id == saveId);
    await prefs.setString(
      _savedGamesIndexKey,
      jsonEncode(saves.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _deleteSaveKeys(SharedPreferences prefs, String saveId) async {
    // Blob format
    await prefs.remove(_saveBlobKey(saveId));

    // Legacy per-field keys.
    const fields = <String>[
      'players',
      'log',
      'phase',
      'dayCount',
      'scriptIndex',
      'lastNightSummary',
      'lastNightHostRecap',
      'nightActions',
      'deadPlayerIds',
      'votesByVoter',
      'votesByTarget',
      'voteHistory',
      'voteSequence',
      'predatorPending',
      'teaSpillerPending',
      'dramaQueenPending',
      'statusEffects',
      'abilityQueue',
      'lastDramaQueenSwap',
      'reactionHistory',
    ];

    for (final f in fields) {
      await prefs.remove(_saveKey(saveId, f));
    }
  }

  Future<bool> loadGame(String saveId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_saveBlobKey(saveId)) &&
        !prefs.containsKey(_saveKey(saveId, 'players'))) {
      return false;
    }

    try {
      // Prefer blob format.
      final blobStr = prefs.getString(_saveBlobKey(saveId));
      if (blobStr != null) {
        final decoded = jsonDecode(blobStr);
        if (decoded is Map) {
          await _loadFromSaveMap(decoded.cast<String, dynamic>());
        }
      } else {
        // Fallback: legacy per-field keys.
        await _loadFromLegacyKeys(prefs, saveId);
      }

      if (_currentPhase == GamePhase.night) {
        _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
      } else if (_currentPhase == GamePhase.day) {
        final bulletin = lastNightSummary.trim().isNotEmpty
            ? lastNightSummary
            : 'Game Loaded.';
        _scriptQueue =
            ScriptBuilder.buildDayScript(dayCount, bulletin, players);
      } else {
        _scriptQueue = [];
      }

      final dqDataStr = prefs.getString(_saveKey(saveId, 'lastDramaQueenSwap'));
      if (dqDataStr != null) {
        final dqData = jsonDecode(dqDataStr) as Map<String, dynamic>;
        lastDramaQueenSwap = DramaQueenSwapRecord(
          day: dqData['day'] as int,
          playerAName: dqData['playerAName'] as String,
          playerBName: dqData['playerBName'] as String,
          fromRoleA: dqData['fromRoleA'] as String,
          fromRoleB: dqData['fromRoleB'] as String,
          toRoleA: dqData['toRoleA'] as String,
          toRoleB: dqData['toRoleB'] as String,
        );
      }

      final reactionHistoryStr =
          prefs.getString(_saveKey(saveId, 'reactionHistory'));
      if (reactionHistoryStr != null) {
        final decoded = jsonDecode(reactionHistoryStr) as List<dynamic>;
        reactionSystem.loadHistoryFromJson(decoded);
      }
    } catch (_) {
      return false;
    }

    // Ensure dead list contains any actually-dead players, but do not discard
    // persisted in-flight state (tests expect this).
    final derivedDead = players
        .where((p) => p.isEnabled && p.role.id != 'host' && !p.isAlive)
        .map((p) => p.id)
        .toList(growable: false);
    final merged =
        <String>{...deadPlayerIds, ...derivedDead}.toList(growable: true);
    deadPlayerIds = merged;

    // Keep night action keys compatible with engine rules.
    _canonicalizeNightActions();

    notifyListeners();
    return true;
  }

  Future<void> _loadFromSaveMap(Map<String, dynamic> map) async {
    int asInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    List<dynamic> asList(dynamic v) => v is List ? v : const [];
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

    final playersList = asList(map['players']);
    players = playersList.map((json) {
      final p = (json as Map).cast<String, dynamic>();
      final roleId = (p['roleId'] as String?) ?? 'temp';
      final role = roleRepository.getRoleById(roleId) ??
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
      return Player.fromJson(p, role);
    }).toList();

    final logList = asList(map['log']);
    _gameLog = logList
        .map((j) => GameLogEntry.fromJson((j as Map).cast<String, dynamic>()))
        .toList();

    final phaseIdx = asInt(map['phaseIndex'], fallback: 0);
    if (phaseIdx >= 0 && phaseIdx < GamePhase.values.length) {
      _currentPhase = GamePhase.values[phaseIdx];
    }

    dayCount = asInt(map['dayCount'], fallback: 0);
    _scriptIndex = asInt(map['scriptIndex'], fallback: 0);

    lastNightSummary = (map['lastNightSummary'] as String?) ?? lastNightSummary;
    lastNightHostRecap =
        (map['lastNightHostRecap'] as String?) ?? lastNightHostRecap;

    // In-flight state
    nightActions = asMap(map['nightActions']);
    deadPlayerIds = asList(map['deadPlayerIds'])
        .map((e) => e.toString())
        .toList(growable: true);

    final votesByVoter = asMap(map['votesByVoter']);
    currentDayVotesByVoter
      ..clear()
      ..addAll(votesByVoter.map((k, v) => MapEntry(k, v as String?)));

    final votesByTarget = asMap(map['votesByTarget']);
    currentDayVotesByTarget.clear();
    for (final entry in votesByTarget.entries) {
      final list = entry.value;
      if (list is List) {
        currentDayVotesByTarget[entry.key] =
            list.map((e) => e.toString()).toList();
      }
    }

    final historyList = asList(map['voteHistory']);
    voteHistory
      ..clear()
      ..addAll(historyList
          .map((e) => VoteCast.fromJson((e as Map).cast<String, dynamic>())));

    _voteSequence = asInt(map['voteSequence'], fallback: _voteSequence);

    final predatorPending = asMap(map['predatorPending']);
    pendingPredatorId = predatorPending['pendingPredatorId'] as String?;
    pendingPredatorPreferredTargetId =
        predatorPending['preferredTargetId'] as String?;
    final eligible = predatorPending['eligibleVoterIds'];
    if (eligible is List) {
      pendingPredatorEligibleVoterIds =
          eligible.map((e) => e.toString()).toList(growable: true);
    } else {
      pendingPredatorEligibleVoterIds = <String>[];
    }

    final dqPending = asMap(map['dramaQueenPending']);
    dramaQueenSwapPending =
        dqPending['swapPending'] as bool? ?? dramaQueenSwapPending;
    dramaQueenMarkedAId = dqPending['markedAId'] as String?;
    dramaQueenMarkedBId = dqPending['markedBId'] as String?;

    final teaPending = asMap(map['teaSpillerPending']);
    pendingTeaSpillerId = teaPending['pendingTeaSpillerId'] as String?;
    final teaEligible = teaPending['eligibleVoterIds'];
    if (teaEligible is List) {
      pendingTeaSpillerEligibleVoterIds =
          teaEligible.map((e) => e.toString()).toList(growable: true);
    } else {
      pendingTeaSpillerEligibleVoterIds = <String>[];
    }

    final statusEffects = asMap(map['statusEffects']);
    if (statusEffects.isNotEmpty) {
      statusEffectManager.loadFromJson(statusEffects);
    }

    final abilityQueue = asMap(map['abilityQueue']);
    if (abilityQueue.isNotEmpty) {
      abilityResolver.loadFromJson(abilityQueue);
    }

    final reactionHistory = map['reactionHistory'];
    if (reactionHistory is List) {
      reactionSystem.loadHistoryFromJson(reactionHistory);
    }

    final dq = map['lastDramaQueenSwap'];
    if (dq is Map) {
      final d = dq.cast<String, dynamic>();
      lastDramaQueenSwap = DramaQueenSwapRecord(
        day: asInt(d['day']),
        playerAName: (d['playerAName'] as String?) ?? '',
        playerBName: (d['playerBName'] as String?) ?? '',
        fromRoleA: (d['fromRoleA'] as String?) ?? '',
        fromRoleB: (d['fromRoleB'] as String?) ?? '',
        toRoleA: (d['toRoleA'] as String?) ?? '',
        toRoleB: (d['toRoleB'] as String?) ?? '',
      );
    }

    if (_currentPhase == GamePhase.night) {
      _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
    } else if (_currentPhase == GamePhase.day) {
      _scriptQueue =
          ScriptBuilder.buildDayScript(dayCount, 'Game Loaded.', players);
    } else {
      _scriptQueue = [];
    }
  }

  Future<void> _loadFromLegacyKeys(
      SharedPreferences prefs, String saveId) async {
    final playersStr = prefs.getString(_saveKey(saveId, 'players'));
    if (playersStr != null) {
      final decoded = jsonDecode(playersStr) as List<dynamic>;
      players = decoded.map((json) {
        final map = (json as Map).cast<String, dynamic>();
        final roleId = map['roleId'] as String;
        final role = roleRepository.getRoleById(roleId) ??
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
        return Player.fromJson(map, role);
      }).toList();
    }

    final logStr = prefs.getString(_saveKey(saveId, 'log'));
    if (logStr != null) {
      final decoded = jsonDecode(logStr) as List<dynamic>;
      _gameLog = decoded
          .map((j) => GameLogEntry.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    }

    final phaseIdx = prefs.getInt(_saveKey(saveId, 'phase'));
    if (phaseIdx != null && phaseIdx < GamePhase.values.length) {
      _currentPhase = GamePhase.values[phaseIdx];
    }

    dayCount = prefs.getInt(_saveKey(saveId, 'dayCount')) ?? 0;
    _scriptIndex = prefs.getInt(_saveKey(saveId, 'scriptIndex')) ?? 0;

    lastNightSummary = prefs.getString(_saveKey(saveId, 'lastNightSummary')) ??
        lastNightSummary;
    lastNightHostRecap =
        prefs.getString(_saveKey(saveId, 'lastNightHostRecap')) ??
            lastNightHostRecap;

    if (_currentPhase == GamePhase.night) {
      _scriptQueue = ScriptBuilder.buildNightScript(players, dayCount);
    } else if (_currentPhase == GamePhase.day) {
      _scriptQueue =
          ScriptBuilder.buildDayScript(dayCount, 'Game Loaded.', players);
    } else {
      _scriptQueue = [];
    }

    final nightActionsStr = prefs.getString(_saveKey(saveId, 'nightActions'));
    if (nightActionsStr != null) {
      nightActions =
          (jsonDecode(nightActionsStr) as Map).cast<String, dynamic>();
    }

    final deadIdsStr = prefs.getString(_saveKey(saveId, 'deadPlayerIds'));
    if (deadIdsStr != null) {
      deadPlayerIds = (jsonDecode(deadIdsStr) as List)
          .map((e) => e as String)
          .toList(growable: true);
    }

    final votesByVoterStr = prefs.getString(_saveKey(saveId, 'votesByVoter'));
    if (votesByVoterStr != null) {
      final decoded =
          (jsonDecode(votesByVoterStr) as Map).cast<String, dynamic>();
      currentDayVotesByVoter
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(k, v as String?)));
    }

    final votesByTargetStr = prefs.getString(_saveKey(saveId, 'votesByTarget'));
    if (votesByTargetStr != null) {
      final decoded =
          (jsonDecode(votesByTargetStr) as Map).cast<String, dynamic>();
      currentDayVotesByTarget.clear();
      for (final entry in decoded.entries) {
        final list = entry.value;
        if (list is List) {
          currentDayVotesByTarget[entry.key] =
              list.map((e) => e as String).toList();
        }
      }
    }

    final voteHistoryStr = prefs.getString(_saveKey(saveId, 'voteHistory'));
    if (voteHistoryStr != null) {
      final decoded = jsonDecode(voteHistoryStr) as List<dynamic>;
      voteHistory
        ..clear()
        ..addAll(decoded
            .map((e) => VoteCast.fromJson((e as Map).cast<String, dynamic>())));
    }

    _voteSequence =
        prefs.getInt(_saveKey(saveId, 'voteSequence')) ?? _voteSequence;

    final predatorPendingStr =
        prefs.getString(_saveKey(saveId, 'predatorPending'));
    if (predatorPendingStr != null) {
      final decoded =
          (jsonDecode(predatorPendingStr) as Map).cast<String, dynamic>();
      pendingPredatorId = decoded['pendingPredatorId'] as String?;
      pendingPredatorPreferredTargetId =
          decoded['preferredTargetId'] as String?;
      final voters = decoded['eligibleVoterIds'];
      if (voters is List) {
        pendingPredatorEligibleVoterIds =
            voters.map((e) => e as String).toList(growable: true);
      }
    }

    final teaPendingStr =
        prefs.getString(_saveKey(saveId, 'teaSpillerPending'));
    if (teaPendingStr != null) {
      final decoded =
          (jsonDecode(teaPendingStr) as Map).cast<String, dynamic>();
      pendingTeaSpillerId = decoded['pendingTeaSpillerId'] as String?;
      final voters = decoded['eligibleVoterIds'];
      if (voters is List) {
        pendingTeaSpillerEligibleVoterIds =
            voters.map((e) => e.toString()).toList(growable: true);
      } else {
        pendingTeaSpillerEligibleVoterIds = <String>[];
      }
    }

    final dqPendingStr = prefs.getString(_saveKey(saveId, 'dramaQueenPending'));
    if (dqPendingStr != null) {
      final decoded = (jsonDecode(dqPendingStr) as Map).cast<String, dynamic>();
      dramaQueenSwapPending =
          decoded['swapPending'] as bool? ?? dramaQueenSwapPending;
      dramaQueenMarkedAId = decoded['markedAId'] as String?;
      dramaQueenMarkedBId = decoded['markedBId'] as String?;
    }

    final statusEffectsStr = prefs.getString(_saveKey(saveId, 'statusEffects'));
    if (statusEffectsStr != null) {
      statusEffectManager.loadFromJson(
          (jsonDecode(statusEffectsStr) as Map).cast<String, dynamic>());
    }

    final abilityQueueStr = prefs.getString(_saveKey(saveId, 'abilityQueue'));
    if (abilityQueueStr != null) {
      abilityResolver.loadFromJson(
          (jsonDecode(abilityQueueStr) as Map).cast<String, dynamic>());
    }
  }

  /// Reset the engine back to the lobby.
  ///
  /// - When [keepGuests] is true, keeps names/ids/enabled flags.
  /// - When [keepAssignedRoles] is false, guests are reset to the temp role so
  ///   roles can be assigned again.
  void resetToLobby({bool keepGuests = true, bool keepAssignedRoles = false}) {
    final kept = keepGuests ? guests.toList(growable: false) : const <Player>[];

    final tempRole = roleRepository.getRoleById('temp') ??
        Role(
          id: 'temp',
          name: 'Unassigned',
          alliance: 'None',
          type: 'None',
          description: '',
          nightPriority: 0,
          assetPath: '',
          colorHex: '#FFFFFF',
        );

    players = kept.map(
      (p) {
        final role = keepAssignedRoles ? p.role : tempRole;
        final rebuilt = Player(
          id: p.id,
          name: p.name,
          role: role,
          isAlive: true,
          isEnabled: p.isEnabled,
        );
        rebuilt.initialize();
        return rebuilt;
      },
    ).toList(growable: true);

    _currentPhase = GamePhase.lobby;
    dayCount = 0;
    _scriptQueue = [];
    _scriptIndex = 0;

    _winner = null;
    _winMessage = null;

    _gameLog = [];
    lastNightSummary = '';
    lastNightHostRecap = '';
    lastNightStats.clear();

    nightActions = {};
    deadPlayerIds = <String>[];
    clearDayVotes();
    voteHistory.clear();
    _voteSequence = 0;

    pendingPredatorId = null;
    pendingPredatorEligibleVoterIds = <String>[];
    pendingPredatorPreferredTargetId = null;

    dramaQueenSwapPending = false;
    dramaQueenMarkedAId = null;
    dramaQueenMarkedBId = null;
    lastDramaQueenSwap = null;

    abilityResolver.clear();
    reactionSystem.clearHistory();
    statusEffectManager.clearAll();

    notifyListeners();
  }

  // Canonicalize UI-written nightActions keys (step.id) into engine keys
  void _canonicalizeNightActions() {
    // Tea Spiller no longer marks at night (target is chosen on death).
    nightActions.remove('tea_spiller_mark');

    // dealer_act -> kill
    final dealerTarget = nightActions['dealer_act'];
    if (nightActions['kill'] == null && dealerTarget is String) {
      nightActions['kill'] = dealerTarget;
    }

    // medic_protect -> protect
    final medicTarget = nightActions['medic_protect'];
    if (nightActions['protect'] == null && medicTarget is String) {
      nightActions['protect'] = medicTarget;
    }

    // bouncer_act -> bouncer_check
    final bouncerTarget = nightActions['bouncer_act'];
    if (nightActions['bouncer_check'] == null && bouncerTarget is String) {
      nightActions['bouncer_check'] = bouncerTarget;
    }

    // roofi_act -> roofi
    final roofiTarget = nightActions['roofi_act'];
    if (nightActions['roofi'] == null && roofiTarget is String) {
      nightActions['roofi'] = roofiTarget;
    }

    // creep_act -> creep_target
    final creepTarget = nightActions['creep_act'];
    if (nightActions['creep_target'] == null && creepTarget is String) {
      nightActions['creep_target'] = creepTarget;
    }

    // NOTE: clinger_obsession is already used as-is in the UI and engine.
  }

  @visibleForTesting
  void assertStateIsConsistent() {
    assert(() {
      final deadSet = deadPlayerIds.toSet();
      if (deadSet.length != deadPlayerIds.length) {
        throw StateError('deadPlayerIds contains duplicates.');
      }
      for (final id in deadPlayerIds) {
        final p = players.where((x) => x.id == id).firstOrNull;
        if (p == null) {
          throw StateError('deadPlayerIds contains unknown player id: $id');
        }
        if (p.isAlive) {
          throw StateError(
              'Player ${p.name} isAlive=true but is listed in deadPlayerIds.');
        }
      }
      return true;
    }());
  }

  /// Special handling for the Messy Bitch "Soft Win".
  /// Logs the victory, removes the Messy Bitch from the game (treated as sent home),
  /// and clears the game-ending state so the party can continue.
  void continueAfterMessyBitchWin() {
    // 1. Identify the Messy Bitch
    final messyBitch = players
        .where((p) => p.isEnabled && p.role.id == 'messy_bitch')
        .firstOrNull;

    if (messyBitch == null) {
      // Should not happen if called correctly, but safety first.
      _winner = null;
      _winMessage = null;
      notifyListeners();
      return;
    }

    // 2. Log the "Win" as a major event before they leave
    logAction('Messy Bitch Victory',
        '${messyBitch.name} has successfully spread rumours to everyone. She takes her win and leaves the party in chaos.');

    // 3. Remove the player (Soft kill / Send home)
    messyBitch.isAlive = false;
    messyBitch.isEnabled = false;
    messyBitch.soberSentHome =
        true; // Mark as sent home to distinguish from death if needed

    // Add to dead/inactive list logic if needed, but isAlive=false usually suffices for exclusion
    if (!deadPlayerIds.contains(messyBitch.id)) {
      deadPlayerIds.add(messyBitch.id);
    }

    // 4. Reset Win State
    _winner = null;
    _winMessage = null;

    // 5. Notify
    notifyListeners();
  }
}

extension _FirstOrNullX<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
