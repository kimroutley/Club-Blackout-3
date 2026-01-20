/// Death cause constants for the game
///
/// Using constants ensures consistency across the codebase and prevents typos.
class DeathCause {
  // Voting-related deaths
  static const String vote = 'vote';
  static const String voteDeflected = 'vote_deflected';

  // Night kill deaths
  static const String nightKill = 'night_kill';
  static const String dealerKill = 'dealer_kill';

  // Role-specific deaths
  static const String predatorRevenge = 'predator_revenge';
  static const String attackDogKill = 'attack_dog_kill';
  static const String clingerSuicide = 'clinger_suicide';
  static const String messyBitchRampage = 'messy_bitch_rampage';
  static const String messyBitchSpecialKill = 'messy_bitch_special_kill';
  static const String spokeTabooName = 'spoke_taboo_name';
  static const String bomb = 'bomb';

  // Debug/Admin deaths
  static const String debugKillAll = 'debug_kill_all';

  // Prefix for ability-based deaths
  static const String abilityPrefix = 'ability_';
}
