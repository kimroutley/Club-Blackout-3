import 'package:flutter/material.dart';

import '../../logic/hall_of_fame_service.dart';
import '../styles.dart';
import '../widgets/club_alert_dialog.dart';

class HallOfFameScreen extends StatefulWidget {
  final bool isNight;
  const HallOfFameScreen({super.key, this.isNight = false});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  bool _mergeMode = false;
  String? _mergeFromId;

  void _exitMergeMode() {
    setState(() {
      _mergeMode = false;
      _mergeFromId = null;
    });
  }

  Future<void> _confirmAndMerge({
    required BuildContext context,
    required String fromId,
    required String intoId,
    required String fromName,
    required String intoName,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return ClubAlertDialog(
          title: const Text('Merge profiles?'),
          content: Text(
            'Merge "$fromName" into "$intoName"?\n\nThis combines stats and deletes the source profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: ClubBlackoutTheme.neonGold,
                foregroundColor:
                    ClubBlackoutTheme.contrastOn(ClubBlackoutTheme.neonGold),
              ),
              child: const Text('MERGE'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    await HallOfFameService.instance
        .mergeProfiles(fromId: fromId, intoId: intoId);
    _exitMergeMode();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Hall of Fame'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: canPop,
        actions: [
          if (_mergeMode)
            TextButton(
              onPressed: _exitMergeMode,
              child: const Text('Done'),
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListenableBuilder(
          listenable: HallOfFameService.instance,
          builder: (context, _) {
            final profiles = HallOfFameService.instance.allProfiles;

            if (profiles.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No legends yet.\nPlay complete games to record stats.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.70),
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                if (_mergeMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Card(
                      elevation: 0,
                      color: cs.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.merge_type,
                                color: ClubBlackoutTheme.neonGold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _mergeFromId == null
                                    ? 'Merge mode: tap a profile to pick the source.'
                                    : 'Merge mode: tap a profile to merge into (source selected).',
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: _exitMergeMode,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final rank = index + 1;

                      final isMergeFrom = _mergeMode && _mergeFromId == p.id;
                      final isMergePickable = _mergeMode &&
                          (_mergeFromId == null || _mergeFromId != p.id);

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onLongPress: () {
                          if (!_mergeMode) {
                            setState(() {
                              _mergeMode = true;
                              _mergeFromId = p.id;
                            });
                          }
                        },
                        onTap: !_mergeMode
                            ? null
                            : () {
                                if (_mergeFromId == null) {
                                  setState(() => _mergeFromId = p.id);
                                  return;
                                }
                                if (_mergeFromId == p.id) return;

                                final fromId = _mergeFromId!;
                                final fromIndex =
                                    profiles.indexWhere((x) => x.id == fromId);
                                if (fromIndex == -1) {
                                  _exitMergeMode();
                                  return;
                                }

                                final fromProfile = profiles[fromIndex];
                                _confirmAndMerge(
                                  context: context,
                                  fromId: fromId,
                                  intoId: p.id,
                                  fromName: fromProfile.name,
                                  intoName: p.name,
                                );
                              },
                        child: Card(
                          elevation: 0,
                          color: isMergeFrom
                              ? cs.primaryContainer
                              : cs.surfaceContainer,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                _RankBadge(rank: rank, highlight: index < 3),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      if (_mergeMode)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            isMergeFrom
                                                ? 'Merge FROM'
                                                : (_mergeFromId == null
                                                    ? 'Tap to pick as source'
                                                    : (isMergePickable
                                                        ? 'Tap to merge INTO'
                                                        : '')),
                                            style: TextStyle(
                                              color: ClubBlackoutTheme.neonGold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        children: [
                                          _StatBadge(
                                              icon: Icons.casino,
                                              label: '${p.totalGames} Games',
                                              color: cs.primary),
                                          _StatBadge(
                                              icon: Icons.emoji_events,
                                              label: '${p.totalWins} Wins',
                                              color:
                                                  ClubBlackoutTheme.neonGold),
                                          if (p.totalGames > 0)
                                            _StatBadge(
                                                icon: Icons.pie_chart,
                                                label:
                                                    '${(p.winRate * 100).toInt()}% Rate',
                                                color: Colors.green),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (p.awardStats.isNotEmpty)
                                  Tooltip(
                                    message: 'Awards',
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.star,
                                          color: ClubBlackoutTheme.neonGold,
                                          size: 20),
                                    ),
                                  ),
                                if (!_mergeMode)
                                  IconButton(
                                    tooltip: 'Delete profile',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) {
                                          return ClubAlertDialog(
                                            title:
                                                const Text('Delete profile?'),
                                            content: Text(
                                                'Delete "${p.name}" from the Hall of Fame?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('CANCEL')),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: cs.error,
                                                  foregroundColor: cs.onError,
                                                ),
                                                child: const Text('DELETE'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (ok == true) {
                                        await HallOfFameService.instance
                                            .deleteProfile(p.id);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool highlight;
  const _RankBadge({required this.rank, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight
            ? ClubBlackoutTheme.neonGold.withValues(alpha: 0.2)
            : cs.surfaceContainerHighest,
      ),
      child: Text(
        '#$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: highlight ? ClubBlackoutTheme.neonGold : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
