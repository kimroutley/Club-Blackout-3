import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../../models/player.dart';
import '../animations.dart';
import '../styles.dart';
import 'player_tile.dart';

class VotingWidget extends StatefulWidget {
  final List<Player> players;
  final GameEngine gameEngine;
  final Function(Player eliminated, String verdict) onComplete;
  final ValueChanged<int>? onMaxVotesChanged;
  final bool isVotingEnabled;

  const VotingWidget({
    super.key,
    required this.players,
    required this.gameEngine,
    required this.onComplete,
    this.onMaxVotesChanged,
    this.isVotingEnabled = true,
  });

  @override
  State<VotingWidget> createState() => _VotingWidgetState();
}

class _VotingWidgetState extends State<VotingWidget> {
  // Candidate ID -> List of Voter IDs
  final Map<String, List<String>> _manualVotes = {};

  Player? _findEnginePlayer(String id) {
    try {
      return widget.gameEngine.players.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void _removeVoterFromAll(String voterId) {
    final toRemove = <String>[];
    for (final entry in _manualVotes.entries) {
      entry.value.removeWhere((id) => id == voterId);
      if (entry.value.isEmpty) {
        toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) {
      _manualVotes.remove(key);
    }
  }

  void _syncClingerBinding({required String triggerVoterId}) {
    Player clinger;
    try {
      clinger =
          widget.gameEngine.players.firstWhere((p) => p.role.id == 'clinger');
    } catch (_) {
      return;
    }

    if (clinger.id.isEmpty) return;
    if (!clinger.isActive) return;
    if (clinger.clingerFreedAsAttackDog) return;
    final partnerId = clinger.clingerPartnerId;
    if (partnerId == null || partnerId.isEmpty) return;

    if (triggerVoterId == partnerId) {
      String? partnerTargetId;
      for (final entry in _manualVotes.entries) {
        if (entry.value.contains(partnerId)) {
          partnerTargetId = entry.key;
          break;
        }
      }

      _removeVoterFromAll(clinger.id);
      if (partnerTargetId != null) {
        (_manualVotes[partnerTargetId] ??= <String>[]).add(clinger.id);
      }
    }
  }

  void _onVoterChanged(String candidateId, String voterId, bool select) {
    Player? clinger;
    try {
      clinger =
          widget.gameEngine.players.firstWhere((p) => p.role.id == 'clinger');
    } catch (_) {
      clinger = null;
    }

    final isClingerBound = clinger != null &&
        clinger.id.isNotEmpty &&
        clinger.isActive &&
        !clinger.clingerFreedAsAttackDog &&
        clinger.clingerPartnerId != null;

    if (isClingerBound && voterId == clinger.id) {
      return;
    }

    setState(() {
      if (select) {
        _removeVoterFromAll(voterId);
        (_manualVotes[candidateId] ??= <String>[]).add(voterId);
      } else {
        _manualVotes[candidateId]?.removeWhere((id) => id == voterId);
        if (_manualVotes[candidateId]?.isEmpty ?? false) {
          _manualVotes.remove(candidateId);
        }
      }

      _syncClingerBinding(triggerVoterId: voterId);

      widget.onMaxVotesChanged?.call(
        _manualVotes.values
            .fold<int>(0, (max, v) => v.length > max ? v.length : max),
      );
    });
  }

  bool _canFinalize() {
    final currentDay = widget.gameEngine.dayCount;
    return _manualVotes.entries.any((e) {
      final candidate = _findEnginePlayer(e.key);
      if (candidate != null && candidate.alibiDay == currentDay) return false;
      return e.value.length >= 2;
    });
  }

  void _submit() {
    String? eliminatedId;
    int maxVotes = -1;
    bool tie = false;

    final currentDay = widget.gameEngine.dayCount;
    final eligibleCandidates = _manualVotes.entries.where((e) {
      if (e.value.length < 2) return false;
      final candidate = _findEnginePlayer(e.key);
      return candidate == null || candidate.alibiDay != currentDay;
    }).toList();

    if (eligibleCandidates.isEmpty) return;

    for (final entry in eligibleCandidates) {
      if (entry.value.length > maxVotes) {
        maxVotes = entry.value.length;
        eliminatedId = entry.key;
        tie = false;
      } else if (entry.value.length == maxVotes) {
        tie = true;
      }
    }

    if (tie || eliminatedId == null) {
      widget.gameEngine.showToast(
        'Tie vote or no majority.',
        title: 'Voting',
      );
      return;
    }

    final eliminated = widget.players.firstWhere((p) => p.id == eliminatedId);

    widget.gameEngine.clearDayVotes();
    for (final entry in _manualVotes.entries) {
      for (final voterId in entry.value) {
        widget.gameEngine.recordVote(voterId: voterId, targetId: entry.key);
      }
    }

    String verdict = 'INNOCENT';
    if (eliminated.role.alliance == 'The Dealers' ||
        eliminated.role.alliance == 'The Dealers (Converted)') {
      verdict = 'DEALER';
    } else if (eliminated.role.id == 'whore') {
      verdict = 'DEALER ALLY';
    }

    widget.onComplete(eliminated, verdict);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Filter out silenced players from the voting pool entirely to reduce clutter.
    // Includes: Ally Cat (mechanic), Sober-sent-home, and Roofi/Paralyzed targets.
    final voters = widget.gameEngine.players.where((p) {
      if (!p.isActive) return false;
      if (p.role.id == 'ally_cat') return false;
      if (p.soberSentHome) return false;
      if (p.silencedDay == widget.gameEngine.dayCount) return false;
      return true;
    }).toList();

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: widget.players.length,
          separatorBuilder: (_, __) => ClubBlackoutTheme.gap12,
          itemBuilder: (_, i) {
            final candidate = widget.players[i];
            final currentVotes = _manualVotes[candidate.id] ?? const <String>[];
            final voteCount = currentVotes.length;
            final isVoteImmune = candidate.alibiDay != null &&
                candidate.alibiDay == widget.gameEngine.dayCount;

            final clinger = widget.gameEngine.players.firstWhere(
              (p) => p.role.id == 'clinger',
              orElse: () => Player(id: '', name: '', role: candidate.role),
            );
            final isClingerBound = clinger.id != '' &&
                !clinger.clingerFreedAsAttackDog &&
                clinger.clingerPartnerId != null;

            final accentColor = voteCount >= 2
                ? ClubBlackoutTheme.neonRed
                : ClubBlackoutTheme.neonBlue;

            final tileBg = cs.surfaceContainerHighest.withValues(
              alpha: voteCount > 0 ? 0.55 : 0.48,
            );

            return AnimatedContainer(
              duration: ClubMotion.short,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: ClubBlackoutTheme.borderRadiusMdAll,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.55),
                  width: voteCount >= 2 ? 2.0 : 1.2,
                ),
                boxShadow: voteCount >= 2
                    ? ClubBlackoutTheme.circleGlow(accentColor, intensity: 1.15)
                    : null,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    title: PlayerTile(
                      player: candidate,
                      gameEngine: widget.gameEngine,
                      isCompact: true,
                      wrapInCard: false,
                      effectChipsAsBanner: true,
                      showEffectChips: true,
                      enabledOverride: widget.isVotingEnabled,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.75),
                          borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.55),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$voteCount',
                          style: ClubBlackoutTheme.glowTextStyle(
                            color: accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      onTap: null,
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.40)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: voters.map((voter) {
                        final isSelected = currentVotes.contains(voter.id);
                        final isThisVoterBoundClinger =
                            isClingerBound && voter.id == clinger.id;

                        if (isThisVoterBoundClinger && !isSelected) {
                          return const SizedBox.shrink();
                        }

                        final isTapDisabled = isVoteImmune ||
                            isThisVoterBoundClinger ||
                            !widget.isVotingEnabled;

                        return _VoterChip(
                          voter: voter,
                          isSelected: isSelected,
                          isDisabled: isTapDisabled,
                          accent: accentColor,
                          onTap: isTapDisabled
                              ? null
                              : () {
                                  if (voter.id == candidate.id) return;
                                  _onVoterChanged(
                                      candidate.id, voter.id, !isSelected);
                                },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_canFinalize())
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: ClubBlackoutTheme.neonButtonStyle(
                  ClubBlackoutTheme.neonRed,
                  isPrimary: true,
                ),
                onPressed: _submit,
                child: Text(
                  'Finalize elimination',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VoterChip extends StatelessWidget {
  final Player voter;
  final bool isSelected;
  final bool isDisabled;
  final Color accent;
  final VoidCallback? onTap;

  const _VoterChip({
    required this.voter,
    required this.isSelected,
    required this.isDisabled,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bg = isSelected
        ? accent.withValues(alpha: 0.22)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);

    final border = isSelected
        ? accent.withValues(alpha: 0.75)
        : cs.outlineVariant.withValues(alpha: 0.45);

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      onSelected: isDisabled ? null : (_) => onTap?.call(),
      shape: const RoundedRectangleBorder(
        borderRadius: ClubBlackoutTheme.borderRadiusControl,
      ),
      label: Text(
        voter.name,
        overflow: TextOverflow.ellipsis,
        style: tt.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: isDisabled ? cs.onSurfaceVariant : cs.onSurface,
        ),
      ),
      avatar: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: accent,
              shadows: ClubBlackoutTheme.iconGlow(accent, intensity: 0.9),
            )
          : Icon(
              Icons.circle_outlined,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.40),
            ),
      side: BorderSide(color: border, width: isSelected ? 1.6 : 1.0),
      backgroundColor: bg,
      selectedColor: bg,
      disabledColor: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
