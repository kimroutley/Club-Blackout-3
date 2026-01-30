enum ScriptActionType {
  none,
  selectPlayer,
  selectTwoPlayers, // For Role Swap or specific interactions
  toggleOption, // e.g. Medic Save vs Protect
  showTimer,
  optional, // For optional actions like Wallflower witnessing
  showInfo, // For showing information (e.g., Clinger seeing obsession's role)
  showDayScene, // For showing the day scene with night events summary and timer
  phaseTransition, // For showing phase transitions (NIGHT FALLS / DAY BREAKS)
  discussion, // For day phase discussion phase
  info, // General information / announcements
  binaryChoice, // Yes/No decision (e.g., Second Wind conversion)
}

class ScriptStep {
  final String id;
  final String title;
  final String readAloudText; // The text the host reads
  final String
      instructionText; // Instructions for the host (italicized usually)
  final ScriptActionType actionType;
  final String?
      roleId; // If this step relates to a specific role (for filtering/icons)
  final bool isNight;
  final List<String>?
      optionLabels; // Custom labels for binaryChoice/toggleOption

  const ScriptStep({
    required this.id,
    required this.title,
    required this.readAloudText,
    required this.instructionText,
    this.actionType = ScriptActionType.none,
    this.roleId,
    this.isNight = true,
    this.optionLabels,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'readAloudText': readAloudText,
      'instructionText': instructionText,
      'actionType': actionType.name,
      'roleId': roleId,
      'isNight': isNight,
      'optionLabels': optionLabels,
    };
  }

  factory ScriptStep.fromJson(Map<String, dynamic> json) {
    final rawAction = json['actionType'] as String?;
    final action = ScriptActionType.values.cast<ScriptActionType?>().firstWhere(
          (e) => e?.name == rawAction,
          orElse: () => ScriptActionType.none,
        );

    return ScriptStep(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      readAloudText: json['readAloudText'] as String? ?? '',
      instructionText: json['instructionText'] as String? ?? '',
      actionType: action ?? ScriptActionType.none,
      roleId: json['roleId'] as String?,
      isNight: json['isNight'] as bool? ?? true,
      optionLabels: (json['optionLabels'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
