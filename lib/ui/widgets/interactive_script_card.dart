import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../../models/role.dart';
import '../../models/script_step.dart';
import '../styles.dart';
import 'player_icon.dart';

class InteractiveScriptCard extends StatelessWidget {
  final ScriptStep step;
  final bool isActive;
  final Role? role;

  // Back-compat inputs still used by GameScreen.
  final Color? stepColor;
  final String? playerName;
  final Player? player;
  final GameEngine? gameEngine;

  final String hostLabel;
  final bool dense;
  final bool bulletin;
  final Widget? roleContext;
  final Widget? footer;

  const InteractiveScriptCard({
    super.key,
    required this.step,
    required this.isActive,
    this.role,
    this.stepColor,
    this.playerName,
    this.player,
    this.gameEngine,
    this.hostLabel = 'Host',
    this.dense = false,
    this.bulletin = false,
    this.roleContext,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent =
        isActive ? (stepColor ?? role?.color ?? cs.primary) : cs.outline;
    final tt = Theme.of(context).textTheme;

    final byline = (playerName ?? player?.name)?.trim();

    final contentPadding = bulletin
        ? ClubBlackoutTheme.scriptCardPaddingBulletin
        : (dense
            ? ClubBlackoutTheme.scriptCardPaddingDense
            : ClubBlackoutTheme.scriptCardPadding);

    final readAloudText = step.readAloudText.trim();
    final rawInstructionText = step.instructionText.trim();

    var instructionText = rawInstructionText;
    if (hostLabel.trim().isNotEmpty &&
        hostLabel.trim().toLowerCase() != 'host') {
      instructionText = instructionText
          .replaceFirst(
            RegExp(r'^host\s*:', caseSensitive: false),
            '${hostLabel.trim()}:',
          )
          .replaceFirst(
            RegExp(r'^host(\s+only\b)', caseSensitive: false),
            '${hostLabel.trim()}${r'$1'}',
          );
    }

    final readAloudHasPrefix =
        RegExp(r'^read\s*aloud\s*:', caseSensitive: false)
            .hasMatch(readAloudText);
    final instructionHasPrefix = RegExp(
      '^(${RegExp.escape(hostLabel.trim())}|host)\\s*:',
      caseSensitive: false,
    ).hasMatch(instructionText);

    final headerStyle = (dense ? tt.titleMedium : tt.titleLarge)?.copyWith(
      fontWeight: FontWeight.w700,
      color: isActive ? accent : cs.onSurface,
    );

    final labelStyle = tt.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    final bodyStyle = tt.bodyMedium?.copyWith(
      color: cs.onSurface.withValues(alpha: isActive ? 0.90 : 0.75),
      height: 1.35,
    );

    return Card(
      margin: ClubBlackoutTheme.cardMarginVertical8,
      color: isActive ? cs.surfaceContainerHigh : cs.surfaceContainer,
      elevation: isActive ? 2 : 0,
      surfaceTintColor: isActive ? accent.withValues(alpha: 0.20) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(bulletin ? 16 : 20),
        side: isActive
            ? BorderSide(color: accent.withValues(alpha: 0.35), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive && role != null) ...[
                  PlayerIcon(
                    assetPath: role!.assetPath,
                    glowColor: accent,
                    glowIntensity: isActive ? 0.25 : 0.0,
                    size: bulletin ? 28 : 32,
                  ),
                  ClubBlackoutTheme.hGap12,
                ] else ...[
                  Icon(
                    isActive ? Icons.bolt_rounded : Icons.circle_rounded,
                    color: isActive
                        ? accent
                        : cs.onSurfaceVariant.withValues(alpha: 0.6),
                    size: bulletin ? 18 : 20,
                  ),
                  ClubBlackoutTheme.hGap8,
                ],
                Expanded(
                  child: Text(
                    byline == null || byline.isEmpty
                        ? step.title
                        : '${step.title} · $byline',
                    style: headerStyle,
                  ),
                ),
              ],
            ),
            if (roleContext != null) ...[
              ClubBlackoutTheme.gap12,
              roleContext!,
            ],
            if (readAloudText.isNotEmpty) ...[
              ClubBlackoutTheme.gap12,
              if (!readAloudHasPrefix) ...[
                Text('Read aloud', style: labelStyle),
                ClubBlackoutTheme.gap8,
              ],
              Text(
                readAloudText,
                style: bodyStyle?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (instructionText.isNotEmpty) ...[
              ClubBlackoutTheme.gap12,
              if (!instructionHasPrefix) ...[
                Text(
                  hostLabel.trim().isEmpty ? 'Host' : hostLabel.trim(),
                  style: labelStyle,
                ),
                ClubBlackoutTheme.gap8,
              ],
              Text(instructionText, style: bodyStyle),
            ],
            if (footer != null) ...[
              ClubBlackoutTheme.gap12,
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
