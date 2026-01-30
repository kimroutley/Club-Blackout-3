import 'role.dart';

class Player {
  final String id;
  String name;
  Role role;
  bool isAlive;
  bool isEnabled;
  List<String> statusEffects;
  int lives;
  String alliance;

  /// Some roles require a one-time setup action (e.g., after role swaps).
  /// When true, the script will insert a setup step for that role.
  bool needsSetup = false;

  // Specific role state
  bool idCheckedByBouncer = false;
  String?
      medicChoice; // "PROTECT_DAILY" or "REVIVE" - permanent choice made at Night 0 setup
  bool hasReviveToken =
      false; // True if medic has used their one-time revive ability
  String? creepTargetId; // For The Creep to store who they are mimicking
  bool hasRumour = false; // For Messy Bitch
  bool messyBitchKillUsed =
      false; // Messy Bitch's special kill after win condition

  // Additional role states for new mechanics
  String? clingerPartnerId; // The Clinger's linked partner
  bool clingerFreedAsAttackDog =
      false; // Clinger freed by being called "controller"
  bool clingerAttackDogUsed = false; // Attack dog ability used
  List<String> tabooNames = []; // Lightweight's forbidden names
  bool minorHasBeenIDd = false; // Minor death protection flag
  bool soberAbilityUsed = false; // Sober's one-time send home
  bool soberSentHome = false; // Player sent home by Sober this night
  bool silverFoxAbilityUsed = false; // Silver Fox's one-time reveal
  bool secondWindConverted = false; // Second Wind conversion status
  bool secondWindPendingConversion = false; // Waiting for Dealer decision
  bool secondWindRefusedConversion = false; // Dealers refused conversion
  int?
      secondWindConversionNight; // Night number when conversion choice is available
  bool joinsNextNight = false; // Added mid-day; becomes active next night
  int? deathDay; // Day count when player died (for medic revive time limit)
  // Roofi/Bouncer mechanics
  int? silencedDay; // If set to D, player is silenced during Day D
  int?
      blockedKillNight; // If set to N, this Dealer cannot kill on Night N (single-dealer case)
  bool roofiAbilityRevoked =
      false; // Roofi lost ability due to Bouncer challenge
  bool bouncerAbilityRevoked =
      false; // Bouncer lost ID ability due to failed challenge
  bool bouncerHasRoofiAbility =
      false; // Bouncer gained Roofi ability from successful challenge

  // Death metadata
  String? deathReason; // The cause of death (Vote, Night Kill, etc.)

  // Persistent Reactive Targets (persist across Day phase for death reactions)
  String? teaSpillerTargetId;
  String? predatorTargetId;
  String? dramaQueenTargetAId;
  String? dramaQueenTargetBId;
  String? whoreDeflectionTargetId;
  bool whoreDeflectionUsed = false;

  /// Silver Fox: prevents vote-out on a specific day.
  int? alibiDay;

  Player({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.isEnabled = true,
    List<String>? statusEffects,
    this.lives = 1,
    this.idCheckedByBouncer = false,
    this.medicChoice,
    this.hasReviveToken = false,
    this.creepTargetId,
    this.hasRumour = false,
    this.messyBitchKillUsed = false,
    this.clingerPartnerId,
    this.clingerFreedAsAttackDog = false,
    this.clingerAttackDogUsed = false,
    List<String>? tabooNames,
    this.minorHasBeenIDd = false,
    this.soberAbilityUsed = false,
    this.soberSentHome = false,
    this.silverFoxAbilityUsed = false,
    this.secondWindConverted = false,
    this.secondWindPendingConversion = false,
    this.secondWindRefusedConversion = false,
    this.secondWindConversionNight,
    this.joinsNextNight = false,
    this.deathDay,
    this.silencedDay,
    this.blockedKillNight,
    this.roofiAbilityRevoked = false,
    this.bouncerAbilityRevoked = false,
    this.bouncerHasRoofiAbility = false,
    this.deathReason,
    this.whoreDeflectionTargetId,
    this.whoreDeflectionUsed = false,
    this.needsSetup = false,
    this.alibiDay,
  })  : tabooNames = tabooNames ?? [],
        statusEffects = statusEffects ?? [],
        alliance = role.alliance;

  bool get isActive => isAlive && isEnabled && !joinsNextNight;

  // Back-compat aliases used throughout the engine/tests.
  bool get reviveUsed => hasReviveToken;
  set reviveUsed(bool value) => hasReviveToken = value;

  String? get teaSpillerMarkId => teaSpillerTargetId;
  set teaSpillerMarkId(String? value) => teaSpillerTargetId = value;

  void initialize() {
    // Lives will be set by game engine for roles that need it
    if (role.id == 'ally_cat') {
      lives = 9;
    }

    // Some roles start on a different alliance than their base descriptor.
    // Note: roles.json uses "Variable" (not "VARIABLE"), so treat this as
    // case-insensitive and primarily key off startAlliance.
    if (role.startAlliance != null) {
      alliance = role.startAlliance!;
    } else if (role.alliance.toLowerCase() == 'variable') {
      // Default variable roles to Party Animal until their mechanic
      // (e.g., Creep mimic / Second Wind conversion) changes it.
      alliance = 'The Party Animals';
    }
  }

  void kill([int? currentDay]) {
    lives -= 1;
    if (lives <= 0) {
      die(currentDay);
    }
  }

  void die([int? currentDay, String? reason]) {
    isAlive = false;
    deathReason = reason;
    if (currentDay != null) {
      deathDay = currentDay;
    }
  }

  void setLivesBasedOnDealers(int dealerCount) {
    if (role.id == 'seasoned_drinker') {
      // Baseline 1 life + one extra life per Dealer.
      lives = 1 + dealerCount;
    }
  }

  void applyStatus(String status) {
    if (!statusEffects.contains(status)) {
      statusEffects = List.from(statusEffects)..add(status);
    }
  }

  void removeStatus(String status) {
    statusEffects = List.from(statusEffects)..remove(status);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roleId': role.id,
        'isAlive': isAlive,
        'isEnabled': isEnabled,
        'statusEffects': statusEffects,
        'lives': lives,
        'alliance': alliance,
        'needsSetup': needsSetup,
        'idCheckedByBouncer': idCheckedByBouncer,
        'medicChoice': medicChoice,
        'hasReviveToken': hasReviveToken,
        'creepTargetId': creepTargetId,
        'hasRumour': hasRumour,
        'messyBitchKillUsed': messyBitchKillUsed,
        'clingerPartnerId': clingerPartnerId,
        'clingerFreedAsAttackDog': clingerFreedAsAttackDog,
        'clingerAttackDogUsed': clingerAttackDogUsed,
        'tabooNames': tabooNames,
        'minorHasBeenIDd': minorHasBeenIDd,
        'soberAbilityUsed': soberAbilityUsed,
        'soberSentHome': soberSentHome,
        'silverFoxAbilityUsed': silverFoxAbilityUsed,
        'secondWindConverted': secondWindConverted,
        'secondWindPendingConversion': secondWindPendingConversion,
        'secondWindRefusedConversion': secondWindRefusedConversion,
        'secondWindConversionNight': secondWindConversionNight,
        'joinsNextNight': joinsNextNight,
        'deathDay': deathDay,
        'silencedDay': silencedDay,
        'blockedKillNight': blockedKillNight,
        'roofiAbilityRevoked': roofiAbilityRevoked,
        'bouncerAbilityRevoked': bouncerAbilityRevoked,
        'bouncerHasRoofiAbility': bouncerHasRoofiAbility,
        'deathReason': deathReason,
        'alibiDay': alibiDay,
        'teaSpillerTargetId': teaSpillerTargetId,
        'predatorTargetId': predatorTargetId,
        'dramaQueenTargetAId': dramaQueenTargetAId,
        'dramaQueenTargetBId': dramaQueenTargetBId,
        'whoreDeflectionTargetId': whoreDeflectionTargetId,
        'whoreDeflectionUsed': whoreDeflectionUsed,
      };

  factory Player.fromJson(Map<String, dynamic> json, Role role) {
    final player = Player(
      id: json['id'],
      name: json['name'],
      role: role,
      isAlive: json['isAlive'],
      isEnabled: json['isEnabled'] ?? true,
      statusEffects: List<String>.from(json['statusEffects'] ?? []),
      lives: json['lives'],
      idCheckedByBouncer: json['idCheckedByBouncer'] ?? false,
      medicChoice: json['medicChoice'],
      hasReviveToken: json['hasReviveToken'] ?? false,
      creepTargetId: json['creepTargetId'],
      hasRumour: json['hasRumour'] ?? false,
      messyBitchKillUsed: json['messyBitchKillUsed'] ?? false,
      clingerPartnerId: json['clingerPartnerId'],
      clingerFreedAsAttackDog: json['clingerFreedAsAttackDog'] ?? false,
      clingerAttackDogUsed: json['clingerAttackDogUsed'] ?? false,
      tabooNames: List<String>.from(json['tabooNames'] ?? []),
      minorHasBeenIDd: json['minorHasBeenIDd'] ?? false,
      soberAbilityUsed: json['soberAbilityUsed'] ?? false,
      soberSentHome: json['soberSentHome'] ?? false,
      silverFoxAbilityUsed: json['silverFoxAbilityUsed'] ?? false,
      secondWindConverted: json['secondWindConverted'] ?? false,
      secondWindPendingConversion: json['secondWindPendingConversion'] ?? false,
      secondWindRefusedConversion: json['secondWindRefusedConversion'] ?? false,
      secondWindConversionNight: json['secondWindConversionNight'] as int?,
      joinsNextNight: json['joinsNextNight'] ?? false,
      deathDay: json['deathDay'],
      silencedDay: json['silencedDay'],
      blockedKillNight: json['blockedKillNight'],
      roofiAbilityRevoked: json['roofiAbilityRevoked'] ?? false,
      bouncerAbilityRevoked: json['bouncerAbilityRevoked'] ?? false,
      bouncerHasRoofiAbility: json['bouncerHasRoofiAbility'] as bool? ?? false,
      deathReason: json['deathReason'] as String?,
      whoreDeflectionTargetId: json['whoreDeflectionTargetId'] as String?,
      whoreDeflectionUsed: json['whoreDeflectionUsed'] as bool? ?? false,
      needsSetup: json['needsSetup'] as bool? ?? false,
      alibiDay: json['alibiDay'] as int?,
    );
    player.alliance = json['alliance'] ?? role.alliance;
    player.deathReason = json['deathReason'];

    // Persistent reactive targets
    player.teaSpillerTargetId = json['teaSpillerTargetId'];
    player.predatorTargetId = json['predatorTargetId'];
    player.dramaQueenTargetAId = json['dramaQueenTargetAId'];
    player.dramaQueenTargetBId = json['dramaQueenTargetBId'];

    return player;
  }
}
