import 'dart:ui';

class Role {
  final String id;
  final String name;
  final String alliance;
  final String type;
  final String description;
  final int nightPriority;
  final bool hasBinaryChoiceAtStart;
  final List<String> choices;
  final String? ability;
  final String? startAlliance;
  final String? deathAlliance;
  final String assetPath;
  final String colorHex;

  Role({
    required this.id,
    required this.name,
    required this.alliance,
    required this.type,
    required this.description,
    required this.nightPriority,
    this.hasBinaryChoiceAtStart = false,
    this.choices = const [],
    this.ability,
    this.startAlliance,
    this.deathAlliance,
    required this.assetPath,
    required this.colorHex,
  });

  Color get color {
    final hexCode = colorHex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      return const Color(0xFFFFFFFF);
    }
  }

  String get emoji => '';

  factory Role.fromJson(Map<String, dynamic> json) {
    String rawAssetPath = json['asset_path'] as String? ?? '';

    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      alliance: json['alliance'] as String,
      type: json['type'] as String,
      description: json['description'] ?? '',
      nightPriority: json['night_priority'] as int? ?? 0,
      hasBinaryChoiceAtStart:
          json['has_binary_choice_at_start'] as bool? ?? false,
      choices:
          (json['choices'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      ability: json['ability'] as String?,
      startAlliance: json['start_alliance'] as String?,
      deathAlliance: json['death_alliance'] as String?,
      assetPath: rawAssetPath,
      colorHex: json['color_hex'] as String? ?? '#FFFFFF',
    );
  }
}
