// Input validation utilities for robust data handling
// Provides centralized validation with clear error messages

class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult.valid() : isValid = true, error = null;
  const ValidationResult.invalid(this.error) : isValid = false;

  bool get isInvalid => !isValid;
}

class InputValidator {
  /// Validate player name
  static ValidationResult validatePlayerName(String name) {
    final trimmed = name.trim();
    
    if (trimmed.isEmpty) {
      return const ValidationResult.invalid('Name cannot be empty');
    }
    
    if (trimmed.length < 2) {
      return const ValidationResult.invalid('Name must be at least 2 characters');
    }
    
    if (trimmed.length > 20) {
      return const ValidationResult.invalid('Name cannot exceed 20 characters');
    }
    
    // Check for valid characters (letters, numbers, spaces, basic punctuation)
    final validNameRegex = RegExp(r"^[a-zA-Z0-9\s\-'\.]+$");
    if (!validNameRegex.hasMatch(trimmed)) {
      return const ValidationResult.invalid('Name contains invalid characters');
    }
    
    return const ValidationResult.valid();
  }

  /// Validate player count for game start
  static ValidationResult validatePlayerCount(int count, {int min = 4, int max = 20}) {
    if (count < min) {
      return ValidationResult.invalid('Need at least $min players (current: $count)');
    }
    
    if (count > max) {
      return ValidationResult.invalid('Maximum $max players allowed (current: $count)');
    }
    
    return const ValidationResult.valid();
  }

  /// Validate ability target selection
  static ValidationResult validateTargets({
    required List<String> selectedTargets,
    required int minTargets,
    required int maxTargets,
    required List<String> availableTargets,
  }) {
    if (selectedTargets.length < minTargets) {
      return ValidationResult.invalid(
        'Must select at least $minTargets target${minTargets > 1 ? 's' : ''}',
      );
    }
    
    if (selectedTargets.length > maxTargets) {
      return ValidationResult.invalid(
        'Cannot select more than $maxTargets target${maxTargets > 1 ? 's' : ''}',
      );
    }
    
    // Check all selected targets are valid
    for (var target in selectedTargets) {
      if (!availableTargets.contains(target)) {
        return const ValidationResult.invalid('Invalid target selected');
      }
    }
    
    // Check for duplicates
    if (selectedTargets.toSet().length != selectedTargets.length) {
      return const ValidationResult.invalid('Cannot select the same target multiple times');
    }
    
    return const ValidationResult.valid();
  }

  /// Sanitize string input
  static String sanitizeString(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'[^\w\s\-\.]'), ''); // Remove special chars
  }

  /// Validate and sanitize player name
  static String? sanitizeAndValidatePlayerName(String name) {
    final sanitized = sanitizeString(name);
    final result = validatePlayerName(sanitized);
    return result.isValid ? sanitized : null;
  }

  /// Check if a string is a valid non-empty ID
  static bool isValidId(String? id) {
    return id != null && id.isNotEmpty && id.trim().isNotEmpty;
  }

  /// Validate JSON structure
  static bool isValidJsonMap(dynamic json) {
    return json != null && json is Map<String, dynamic>;
  }
}
