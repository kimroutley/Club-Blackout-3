import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/script_step.dart';
import '../../models/role.dart';
import '../../models/player.dart';
import '../../logic/game_engine.dart';
import '../../services/sound_service.dart';
import '../styles.dart';
import '../animations.dart';
import 'host_player_status_card.dart';

class InteractiveScriptCard extends StatefulWidget {
  final ScriptStep step;
  final bool isActive;
  final Color stepColor;
  final Role? role;
  final String? playerName;
  final Player? player; // Optional player object for rich display
  final GameEngine? gameEngine; // Required if player is provided
  final VoidCallback? onTap;

  const InteractiveScriptCard({
    super.key,
    required this.step,
    required this.isActive,
    required this.stepColor,
    this.role,
    this.playerName,
    this.player,
    this.gameEngine,
    this.onTap,
  });

  @override
  State<InteractiveScriptCard> createState() => _InteractiveScriptCardState();
}

class _InteractiveScriptCardState extends State<InteractiveScriptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isExpanded = false;
  bool _hasBeenRead = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isActive) {
      // Pulse animation removed for script cards
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(InteractiveScriptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Pulse animation removed for script cards
      _isExpanded = true;
    } else if (!widget.isActive && oldWidget.isActive) {
      _hasBeenRead = true;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _normalizeMultiline(String text) {
    if (text.isEmpty) return text;

    final newlineNormalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final decodedNewlines = newlineNormalized.replaceAll('\\n', '\n');
    final collapsed = decodedNewlines.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return collapsed.trimRight();
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        SoundService().playExpand();
      } else {
        SoundService().playCollapse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNight = widget.step.isNight;
    final bgColor = isNight ? Colors.black : const Color(0xFF1a1a2e);
    final borderColor = widget.isActive
        ? widget.stepColor
        : widget.stepColor.withOpacity(0.3);

    return GestureDetector(
      onTap: widget.onTap ?? _toggleExpand,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: widget.isActive ? 3 : 2,
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: widget.stepColor.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: widget.stepColor.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ]
              : _hasBeenRead
              ? [
                  BoxShadow(
                    color: ClubBlackoutTheme.neonGreen.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedSize(
              duration: ClubMotion.quick,
              curve: ClubMotion.easeOut,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      bgColor.withOpacity(0.9),
                      bgColor.withOpacity(0.8),
                      widget.stepColor.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(),

                    // Expandable Content
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildExpandedContent(),
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: ClubMotion.medium,
                      sizeCurve: ClubMotion.easeInOut,
                    ),

                    // Action Indicator
                    if (widget.isActive &&
                        widget.step.actionType != ScriptActionType.none)
                      _buildActionIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.stepColor.withOpacity(0.2), Colors.transparent],
        ),
        border: Border(
          bottom: BorderSide(
            color: widget.stepColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.stepColor.withOpacity(0.2),
              border: Border.all(color: widget.stepColor, width: 2),
            ),
            child: Icon(_getStepIcon(), color: widget.stepColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.step.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.stepColor,
                    shadows: widget.isActive
                        ? ClubBlackoutTheme.textGlow(widget.stepColor)
                        : null,
                  ),
                ),
                if (widget.role != null)
                  Text(
                    widget.role!.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.role!.color.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (widget.playerName != null)
                  Text(
                    widget.playerName!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),

          // Expand Icon
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: widget.stepColor,
          ),

          // Completion Check
          if (_hasBeenRead && !widget.isActive)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_circle,
                color: ClubBlackoutTheme.neonGreen,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final readText = _normalizeMultiline(widget.step.readAloudText);
    final instructionText = _normalizeMultiline(widget.step.instructionText);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rich Player Card (if available)
          if (widget.player != null && widget.gameEngine != null) ...[
            HostPlayerStatusCard(
              player: widget.player!,
              gameEngine: widget.gameEngine!,
              showControls: false, // Read-only view in script
            ),
            const SizedBox(height: 16),
          ],

          // Read Aloud Section
          if (readText.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  color: ClubBlackoutTheme.neonBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'READ ALOUD',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonBlue,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClubBlackoutTheme.neonBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ClubBlackoutTheme.neonBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: SelectableText(
                readText,
                style: widget.step.id.startsWith('morning_report')
                    ? const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.2,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      )
                    : const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Host Instructions
          if (instructionText.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: ClubBlackoutTheme.neonOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'HOST NOTES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ClubBlackoutTheme.neonOrange,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ClubBlackoutTheme.neonOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ClubBlackoutTheme.neonOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                instructionText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionIndicator() {
    String actionText;
    IconData actionIcon;
    Color actionColor = widget.stepColor;

    switch (widget.step.actionType) {
      case ScriptActionType.selectPlayer:
        actionText = 'SELECT PLAYER'; // Shortened
        actionIcon = Icons.person_pin;
        break;
      case ScriptActionType.selectTwoPlayers:
        actionText = 'SELECT TWO'; // Shortened
        actionIcon = Icons.people;
        break;
      case ScriptActionType.showDayScene:
        actionText = 'DAY SCENE'; // Shortened
        actionIcon = Icons.wb_sunny;
        break;
      case ScriptActionType.showInfo:
        actionText = 'VIEW INFO'; // Shortened
        actionIcon = Icons.visibility;
        break;
      case ScriptActionType.showTimer:
        actionText = 'TIMER'; // Shortened
        actionIcon = Icons.timer;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 12,
      ), // Reduced padding
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [actionColor.withOpacity(0.3), actionColor.withOpacity(0.1)],
        ),
        border: Border(
          top: BorderSide(color: actionColor.withOpacity(0.5), width: 2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(actionIcon, color: actionColor, size: 18), // Smaller icon
          const SizedBox(width: 8),
          Flexible(
            // Allow text to shrink if needed
            child: Text(
              actionText,
              style: TextStyle(
                fontSize: 13, // Smaller font
                fontWeight: FontWeight.bold,
                color: actionColor,
                letterSpacing: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon() {
    if (_hasBeenRead && !widget.isActive) {
      return Icons.check_circle_outline;
    }

    if (widget.step.isNight) {
      return Icons.nightlight_round;
    }

    switch (widget.step.actionType) {
      case ScriptActionType.selectPlayer:
      case ScriptActionType.selectTwoPlayers:
        return Icons.touch_app;
      case ScriptActionType.showDayScene:
        return Icons.wb_sunny;
      case ScriptActionType.showInfo:
        return Icons.remove_red_eye;
      case ScriptActionType.showTimer:
        return Icons.timer;
      default:
        return Icons.play_circle_outline;
    }
  }
}
