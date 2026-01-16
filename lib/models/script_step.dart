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
  final String instructionText; // Instructions for the host (italicized usually)
  final ScriptActionType actionType;
  final String? roleId; // If this step relates to a specific role (for filtering/icons)
  final bool isNight; 

  const ScriptStep({
    required this.id,
    required this.title,
    required this.readAloudText,
    required this.instructionText,
    this.actionType = ScriptActionType.none,
    this.roleId,
    this.isNight = true,
  });
}
