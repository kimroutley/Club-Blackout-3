import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../services/sound_service.dart';
import '../styles.dart';

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
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _vote(String playerId) {
    if (!widget.allowRevote && _selectedPlayerId != null) {
      SoundService().playError();
      return;
    }

    setState(() {
      _selectedPlayerId = playerId;
    });

    _controller.forward(from: 0);
    SoundService().playSelect();
    widget.onVote(playerId);
  }

  int _getVoteCount(String playerId) {
    return widget.votes[playerId] ?? 0;
  }

  Player? _getLeader() {
    if (widget.votes.isEmpty) return null;
    
    String? leaderId;
    int maxVotes = 0;
    
    for (final entry in widget.votes.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        leaderId = entry.key;
      }
    }
    
    if (leaderId == null) return null;
    return widget.players.firstWhere((p) => p.id == leaderId);
  }

  @override
  Widget build(BuildContext context) {
    final leader = _getLeader();
    
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
          // Header
          Row(
            children: [
              Icon(
                Icons.how_to_vote_rounded,
                color: ClubBlackoutTheme.neonOrange,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'VOTE TO ELIMINATE',
                  style: ClubBlackoutTheme.primaryFont.copyWith(
                    fontSize: 24,
                    color: ClubBlackoutTheme.neonOrange,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Vote leader indicator
          if (leader != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ClubBlackoutTheme.crimsonRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ClubBlackoutTheme.crimsonRed.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    color: ClubBlackoutTheme.crimsonRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${leader.name} is leading with ${_getVoteCount(leader.id)} vote${_getVoteCount(leader.id) != 1 ? 's' : ''}',
                    style: ClubBlackoutTheme.primaryFont.copyWith(
                      fontSize: 14,
                      color: ClubBlackoutTheme.crimsonRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Player grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.players.length,
            itemBuilder: (context, index) {
              final player = widget.players[index];
              final voteCount = _getVoteCount(player.id);
              final isSelected = _selectedPlayerId == player.id;
              
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = isSelected
                      ? 1.0 + (_controller.value * 0.1)
                      : 1.0;
                  
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () => _vote(player.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ClubBlackoutTheme.neonOrange.withOpacity(0.2)
                          : const Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? ClubBlackoutTheme.neonOrange
                            : ClubBlackoutTheme.neonOrange.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: ClubBlackoutTheme.neonOrange.withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              player.name,
                              style: ClubBlackoutTheme.primaryFont.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? ClubBlackoutTheme.neonOrange
                                    : Colors.white,
                                shadows: isSelected
                                    ? ClubBlackoutTheme.textGlow(ClubBlackoutTheme.neonOrange)
                                    : null,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        
                        // Vote count badge
                        if (voteCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ClubBlackoutTheme.crimsonRed,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: ClubBlackoutTheme.crimsonRed.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Text(
                                '$voteCount',
                                style: ClubBlackoutTheme.primaryFont.copyWith(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
          
          const SizedBox(height: 20),
          
          // Complete button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubBlackoutTheme.neonOrange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CONFIRM VOTE',
                style: ClubBlackoutTheme.primaryFont.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
