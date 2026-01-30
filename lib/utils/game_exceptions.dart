// Custom exception types for better error handling
// This provides type-safe error handling throughout the application

abstract class GameException implements Exception {
  final String message;
  final String? details;
  final StackTrace? stackTrace;

  const GameException(this.message, {this.details, this.stackTrace});

  @override
  String toString() =>
      'GameException: $message${details != null ? '\nDetails: $details' : ''}';
}

class PlayerNotFoundException extends GameException {
  final String playerId;

  const PlayerNotFoundException(this.playerId, {String? details})
      : super('Player not found: $playerId', details: details);
}

class InvalidPlayerCountException extends GameException {
  final int currentCount;
  final int requiredCount;

  const InvalidPlayerCountException(this.currentCount, this.requiredCount)
      : super('Invalid player count: $currentCount (required: $requiredCount)');
}

class RoleAssignmentException extends GameException {
  const RoleAssignmentException(super.message, {super.details});
}

class GameStateException extends GameException {
  final String expectedState;
  final String actualState;

  const GameStateException(this.expectedState, this.actualState)
      : super(
          'Invalid game state transition from $actualState to $expectedState',
        );
}

class SaveLoadException extends GameException {
  const SaveLoadException(super.message, {super.details});
}

class AbilityResolutionException extends GameException {
  final String abilityId;

  const AbilityResolutionException(this.abilityId, {String? details})
      : super('Failed to resolve ability: $abilityId', details: details);
}

class ValidationException extends GameException {
  const ValidationException(super.message, {super.details});
}

class InvalidActionException extends GameException {
  const InvalidActionException(super.message, {super.details});
}

class InvalidTargetException extends GameException {
  final String targetId;
  final String abilityId;

  const InvalidTargetException(this.targetId, this.abilityId)
      : super('Invalid target $targetId for ability $abilityId');
}
