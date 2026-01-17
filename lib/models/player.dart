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

  // Specific role state
  bool idCheckedByBouncer = false;
  String? medicChoice; // "PROTECT_DAILY" or "RESUSCITATE_ONCE" - permanent choice made at Night 0 setup
  bool hasReviveToken = false; // True if medic has used their one-time revive ability
  String? creepTargetId; // For The Creep to store who they are mimicking
  bool hasRumour = false; // For Messy Bitch
  bool messyBitchKillUsed = false; // Messy Bitch's special kill after win condition
  
  // Additional role states for new mechanics
  String? clingerPartnerId; // The Clinger's linked partner
  bool clingerFreedAsAttackDog = false; // Clinger freed by being called "controller"
  bool clingerAttackDogUsed = false; // Attack dog ability used
  List<String> tabooNames = []; // Lightweight's forbidden names
  bool minorHasBeenIDd = false; // Minor death protection flag
  bool soberAbilityUsed = false; // Sober's one-time send home
  bool soberSentHome = false; // Player sent home by Sober this night
  bool silverFoxAbilityUsed = false; // Silver Fox's one-time reveal
  bool secondWindConverted = false; // Second Wind conversion status
  bool secondWindPendingConversion = false; // Waiting for Dealer decision
  bool secondWindRefusedConversion = false; // Dealers refused conversion
  bool joinsNextNight = false; // Added mid-day; becomes active next night
  int? deathDay; // Day count when player died (for medic revive time limit)
  // Roofi/Bouncer mechanics
  int? silencedDay; // If set to D, player is silenced during Day D
  int? blockedKillNight; // If set to N, this Dealer cannot kill on Night N (single-dealer case)
  bool roofiAbilityRevoked = false; // Roofi lost ability due to Bouncer challenge
  bool bouncerAbilityRevoked = false; // Bouncer lost ID ability due to failed challenge
  bool bouncerHasRoofiAbility = false; // Bouncer gained Roofi ability from successful challenge

  // Persistent Reactive Targets (persist across Day phase for death reactions)
  String? teaSpillerTargetId;
  String? predatorTargetId;
  String? dramaQueenTargetAId;
  String? dramaQueenTargetBId;

  Player({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.isEnabled = true,
    this.statusEffects = const [],
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
    this.joinsNextNight = false,
    this.deathDay,
    this.silencedDay,
    this.blockedKillNight,
    this.roofiAbilityRevoked = false,
    this.bouncerAbilityRevoked = false,
    this.bouncerHasRoofiAbility = false,
  }) : tabooNames = tabooNames ?? [],
       alliance = role.alliance;

  bool get isActive => isAlive && isEnabled && !joinsNextNight;

  void initialize() {
    // Lives will be set by game engine for roles that need it
    if (role.id == 'ally_cat') {
      lives = 9;
    }

    if (role.alliance == 'VARIABLE' && role.startAlliance != null) {
      alliance = role.startAlliance!;
    }
  }

  void kill([int? currentDay]) {
    lives -= 1;
    if (lives <= 0) {
      die(currentDay);
    }
  }

  void die([int? currentDay]) {
    isAlive = false;
    if (currentDay != null) {
      deathDay = currentDay;
    }
  }

  void setLivesBasedOnDealers(int dealerCount) {
    if (role.id == 'seasoned_drinker') {
      lives = dealerCount; // One life per Dealer
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roleId': role.id,
      'isAlive': isAlive,
      'isEnabled': isEnabled,
      'statusEffects': statusEffects,
      'lives': lives,
      'alliance': alliance,
      'idCheckedByBouncer': idCheckedByBouncer,
      'medicChoice': medicChoice,
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
      'joinsNextNight': joinsNextNight,
      'deathDay': deathDay,
      'silencedDay': silencedDay,
      'blockedKillNight': blockedKillNight,
      'roofiAbilityRevoked': roofiAbilityRevoked,
      'bouncerAbilityRevoked': bouncerAbilityRevoked,
      'teaSpillerTargetId': teaSpillerTargetId,
      'predatorTargetId': predatorTargetId,
      'dramaQueenTargetAId': dramaQueenTargetAId,
      'dramaQueenTargetBId': dramaQueenTargetBId,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json, Role role) {
    return Player(
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
      joinsNextNight: json['joinsNextNight'] ?? false,
      deathDay: json['deathDay'],
      silencedDay: json['silencedDay'],
      blockedKillNight: json['blockedKillNight'],
      roofiAbilityRevoked: json['roofiAbilityRevoked'] ?? false,
      bouncerAbilityRevoked: json['bouncerAbilityRevoked'] ?? false,
    )..alliance = json['alliance'] ?? role.alliance; // Restore alliance
  }
}
