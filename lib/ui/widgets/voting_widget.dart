import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/player.dart';
import '../../services/sound_service.dart';
import '../styles.dart';
import '../animations.dart';

/// Interactive voting widget with live vote counts and animations
class VotingWidget extends StatefulWidget {
  final List<Player> players;
  final Map<String, int> votes;
  final Function(String playerId) onVote;
  final VoidCallback onComplete;
  final bool allowRevote;

  const VotingWidget({
    super.key,
    required this.players,
    required this.votes,
    required this.onVote,
    required this.onComplete,
    this.allowRevote = true,
  });

  @override
  State<VotingWidget> createState() => _VotingWidgetState();
}

class _VotingWidgetState extends State<VotingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: ClubMotion.short, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _vote(String playerId) {
    if (!widget.allowRevote && _selectedPlayerId != null) {
      SoundService().playError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revote disabled for this round'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    setState(() {
      _selectedPlayerId = playerId;
    });

    _controller.forward(from: 0);
    HapticFeedback.selectionClick();
    SoundService().playSelect();
    widget.onVote(playerId);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate leader for highlights
    final maxVotes = widget.votes.values.fold(
      0,
      (prev, curr) => curr > prev ? curr : prev,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ClubBlackoutTheme.neonOrange.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ClubBlackoutTheme.neonOrange.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VOTE CASTING',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ClubBlackoutTheme.neonOrange,
              letterSpacing: 2.0,
              shadows: ClubBlackoutTheme.textGlow(ClubBlackoutTheme.neonOrange),
            ),
          ),
          const SizedBox(height: 20),

          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final player = widget.players[index];
                final isSelected = player.id == _selectedPlayerId;
                final voteCount = widget.votes[player.id] ?? 0;
                // Calculate progress relative to max votes (or 1 if 0)
                final progress = maxVotes > 0 ? (voteCount / maxVotes) : 0.0;

                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final scale = isSelected
                        ? 1.0 + (_controller.value * 0.05)
                        : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: InkWell(
                    onTap: () => _vote(player.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ClubBlackoutTheme.neonOrange.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? ClubBlackoutTheme.neonOrange
                              : Colors.white24,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? ClubBlackoutTheme.neonOrange
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (voteCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ClubBlackoutTheme.neonOrange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$voteCount',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation(
                                isSelected
                                    ? ClubBlackoutTheme.neonOrange
                                    : Colors.white30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: ClubBlackoutTheme.neonOrange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: ClubBlackoutTheme.neonOrange.withOpacity(0.5),
              ),
              child: const Text(
                'CONFIRM VOTES',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
