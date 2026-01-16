class AppVersion {
  static const String version = '1.0.1';
  
  static const List<ChangelogEntry> changelog = [
    ChangelogEntry(
      version: '1.0.1',
      date: 'January 13, 2026',
      changes: [
        'Added Host Overview screen with player management',
        'Special status tracking for Clinger, Creep, Ally Cat, and Seasoned Drinker',
        'Host controls: toggle players on/off, revive all, kill all',
        'Setup night improvements: Medic ability selection, role card reveals',
        'Phase transitions now scroll inline instead of overlay dialogs',
        'Enhanced guides with character cards table and alliance graph',
        'Improved UI formatting across all guide screens',
      ],
    ),
    ChangelogEntry(
      version: '1.0.0',
      date: 'January 12, 2026',
      changes: [
        'Initial release',
        'Complete game engine with all roles',
        'Interactive script system with player selection',
        'Phase transitions and sound effects',
        'Voting system with day/night cycles',
        'Game log and rumour mill features',
        'Guides with role overviews',
      ],
    ),
    ChangelogEntry(
      version: '0.9.9',
      date: 'January 11, 2026',
      changes: [
        'Internal beta build',
        'Core UI and role assets wired up',
        'Early script/phase flow prototyping',
      ],
    ),
  ];
}

class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}
