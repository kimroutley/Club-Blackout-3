import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../../utils/text_utils.dart';
import '../styles.dart';
import 'holographic_watermark.dart';
import 'player_icon.dart';
import 'role_facts_context.dart';

/// Universal role card.
///
/// Front side: ID badge (name + image + alliance).
/// Back side: details (description/ability/choices).
///
/// Used across Guides, reveals, and gameplay dialogs.
enum RoleCardTransition {
  /// Classic 3D flip.
  flip3d,

  /// Material-ish shared-axis transition (fade + slight translate/scale).
  ///
  /// This avoids 3D transforms and tends to be smoother on midrange devices.
  sharedAxis,
}

class RoleCardWidget extends StatefulWidget {
  final Role role;
  final bool compact;

  /// Optional game/lobby context used to generate dynamic "fun facts"
  /// (e.g., danger rank within the current roster).
  final RoleFactsContext? factsContext;

  /// If true, renders a subtle holographic ID-style background.
  final bool holographicBackground;

  /// Whether the card can flip to show more info.
  final bool allowFlip;

  /// If true, the card starts on the back side.
  final bool initiallyFlipped;

  /// If true, tapping the card flips it (in addition to the button).
  final bool tapToFlip;

  /// Animation style for switching between front/back.
  final RoleCardTransition transition;

  const RoleCardWidget({
    super.key,
    required this.role,
    this.compact = true,
    this.factsContext,
    this.allowFlip = true,
    this.initiallyFlipped = false,
    this.tapToFlip = false,
    this.holographicBackground = true,
    this.transition = RoleCardTransition.flip3d,
  });

  @override
  State<RoleCardWidget> createState() => _RoleCardWidgetState();
}

class _RoleCardWidgetState extends State<RoleCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  late final Animation<double> _curve;

  /// During the 3D flip we temporarily pause expensive visual effects
  /// (holographic shimmer/gyro) to keep frame times stable.
  bool _isFlipping = false;

  bool get _isBack => _flip.value >= 0.5;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.initiallyFlipped ? 1.0 : 0.0,
    );

    // Material 3 emphasized curve feels smoother than a symmetric cubic.
    _curve = CurvedAnimation(parent: _flip, curve: Curves.easeInOutCubicEmphasized);

    _isFlipping = _flip.isAnimating;
    _flip.addStatusListener((status) {
      final nowFlipping =
          status == AnimationStatus.forward || status == AnimationStatus.reverse;
      if (nowFlipping != _isFlipping && mounted) {
        setState(() => _isFlipping = nowFlipping);
      }
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (!widget.allowFlip) return;
    if (_flip.isAnimating) return;
    if (_isBack) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  String _stableIdCode(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hex = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
    return 'CB-$hex';
  }

  String _nightPositionBlurb(Role role) {
    final p = role.nightPriority;
    if (p <= 0) {
      return 'Night position: no scheduled wake-up (passive / situational).';
    }

    final phase = switch (p) {
      1 || 2 => 'early',
      3 || 4 => 'mid',
      _ => 'late',
    };

    return 'Night position: $phase (priority $p).';
  }

  String _dangerTier(Role role) {
    // Intentionally a "vibes" estimate. Keep it playful and non-authoritative.
    switch (role.id) {
      case 'ally_cat':
      case 'seasoned_drinker':
        return 'Low';
      case 'party_animal':
      case 'sober':
      case 'club_manager':
      case 'drama_queen':
      case 'silver_fox':
      case 'bartender':
      case 'second_wind':
      case 'clinger':
      case 'creep':
        return 'Medium';
      case 'dealer':
      case 'whore':
      case 'roofi':
      case 'bouncer':
      case 'medic':
      case 'wallflower':
      case 'tea_spiller':
      case 'minor':
      case 'messy_bitch':
      case 'predator':
      case 'lightweight':
        return 'High';
      case 'host':
        return 'N/A';
      default:
        return 'Medium';
    }
  }

  List<String> _dynamicOddsLines(Role role, RoleFactsContext ctx) {
    final lines = <String>[];

    if (ctx.alivePlayers > 0) {
      if (ctx.dealerKillersAlive <= 0) {
        lines.add('Lobby threat: no Dealers alive (you’re chill… for now).');
      } else if (ctx.dealerKillersAlive == 1) {
        lines.add('Lobby threat: 1 Dealer alive among ${ctx.alivePlayers}.');
      } else {
        lines.add('Lobby threat: ${ctx.dealerKillersAlive} Dealers alive among ${ctx.alivePlayers}.');
      }
    }

    final rank = ctx.dangerRankFor(role);
    if (rank != null && ctx.dangerRankCount > 0) {
      if (rank == 1) {
        lines.add('Most likely to die: #1 in this lobby.');
      } else {
        lines.add('Most likely to die rank: #$rank of ${ctx.dangerRankCount}.');
      }

      final p = ctx.dangerPercentileFor(role);
      if (p != null) {
        final tier = p >= 0.80
            ? 'High'
            : (p >= 0.45 ? 'Medium' : 'Low');
        lines.add('Death odds (roster-based): $tier.');
      }
    }

    return lines;
  }

  List<String> _roleSpecificFunFacts(Role role) {
    switch (role.id) {
      case 'ally_cat':
        return const [
          'Fun fact: you are the hardest role to fully eliminate (nine lives).',
          'Odds tip: spend your lives buying info, not drama.',
        ];
      case 'seasoned_drinker':
        return const [
          'Fun fact: you can soak up more attempts than most — but only from Dealer kill attempts.',
          'Odds tip: you are a great bait if you can stay believable.',
        ];
      case 'wallflower':
        return const [
          'Fun fact: you live in the most dangerous minute of the night — the murder phase.',
          'Odds tip: subtle hints keep you alive longer than hard accusations.',
        ];
      case 'bouncer':
        return const [
          'Fun fact: investigative roles tend to get deleted if you get loud.',
          'Odds tip: drip-feed reads so you don’t look “too correct.”',
        ];
      case 'medic':
        return const [
          'Fun fact: you’re a “high-value target” if anyone suspects you exist.',
          'Odds tip: don’t save the obvious save for too long — it paints a spotlight.',
        ];
      case 'dealer':
        return const [
          'Fun fact: you’re rarely murdered — you’re usually voted out.',
          'Odds tip: your best defense is not being memorable.',
        ];
      case 'whore':
        return const [
          'Fun fact: your job is to take heat so your team doesn’t have to.',
          'Odds tip: “being sus on purpose” works… until it doesn’t.',
        ];
      case 'roofi':
        return const [
          'Fun fact: your power creates immediate day-time fingerprints.',
          'Odds tip: if someone can’t vote, people will talk — plan around that.',
        ];
      case 'bartender':
        return const [
          'Fun fact: you only learn “same vs different” alignment — not which side.',
          'Odds tip: pairing checks across multiple nights makes your info snowball.',
        ];
      case 'tea_spiller':
        return const [
          'Fun fact: you weaponize day conversation more than night actions.',
          'Odds tip: your safest power is making others say the quiet part out loud.',
        ];
      case 'sober':
        return const [
          'Fun fact: you can cancel a Dealer murder by sending the right person home.',
          'Odds tip: your best nights are when you look clueless.',
        ];
      default:
        return const [];
    }
  }

  List<String> _funFactsFor(Role role) {
    final facts = <String>[
      _nightPositionBlurb(role),
    ];

    final ctx = widget.factsContext;
    if (ctx != null) {
      facts.addAll(_dynamicOddsLines(role, ctx));
    } else {
      final danger = _dangerTier(role);
      if (danger != 'N/A') {
        facts.add('Death odds (vibes): $danger.');
      }
    }

    facts.addAll(_roleSpecificFunFacts(role));
    return facts.where((f) => f.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final maxWidth = widget.compact ? 380.0 : 420.0;
    final maxHeight = widget.compact ? 260.0 : 380.0;

    // Build both sides once per build() (not every animation tick).
    final front = _buildFront(context, cs, tt);
    final back = _buildBack(context, cs, tt);

    final child = AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final t = _curve.value;
        if (widget.transition == RoleCardTransition.flip3d) {
          final angle = math.pi * t;
          final showFront = angle <= (math.pi / 2);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angle),
            child: showFront
                ? front
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: back,
                  ),
          );
        }

        // Shared-axis style: outgoing fades/slightly shrinks and slides out,
        // incoming fades/slightly grows and slides in.
        final inT = Curves.easeOutCubic.transform(t);
        final outT = Curves.easeInCubic.transform(t);

        final frontOpacity = (1.0 - inT).clamp(0.0, 1.0);
        final backOpacity = inT.clamp(0.0, 1.0);

        const dy = 14.0;
        final frontDy = -dy * outT;
        final backDy = dy * (1.0 - outT);

        final frontScale = 1.0 - 0.02 * outT;
        final backScale = 0.98 + 0.02 * outT;

        return IgnorePointer(
          ignoring: _isFlipping,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Opacity(
                opacity: frontOpacity,
                child: Transform.translate(
                  offset: Offset(0, frontDy),
                  child: Transform.scale(
                    scale: frontScale,
                    child: IgnorePointer(
                      ignoring: t > 0.0,
                      child: front,
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: backOpacity,
                child: Transform.translate(
                  offset: Offset(0, backDy),
                  child: Transform.scale(
                    scale: backScale,
                    child: IgnorePointer(
                      ignoring: t < 1.0,
                      child: back,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    final interactive = widget.tapToFlip
        ? InkWell(
            onTap: _toggleFlip,
            borderRadius: BorderRadius.circular(18),
            child: child,
          )
        : child;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: Semantics(
        label:
            '${widget.role.name} role card. ${_isBack ? 'Details' : 'ID badge'} view.',
        child: Material(
          color: Colors.transparent,
          child: interactive,
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context, ColorScheme cs, TextTheme tt) {
    final role = widget.role;

    final titleStyle =
        (widget.compact ? tt.titleMedium : tt.headlineSmall) ??
            (tt.titleLarge ?? const TextStyle());

    final badgeLabelStyle = (tt.labelSmall ?? const TextStyle()).copyWith(
      color: cs.onSurface.withValues(alpha: 0.70),
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
    );

    final name = role.name;
    final idCode = _stableIdCode(role.id);
    const typeLabel = 'Attitude';
    final roleKind = role.type.trim().isEmpty ? 'Guest' : toTitleCase(role.type.trim());

    return Container(
      decoration: ClubBlackoutTheme.neonFrame(
        color: role.color,
        opacity: 0.95,
        borderRadius: ClubBlackoutTheme.radiusLg,
        borderWidth: 0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.holographicBackground)
              IgnorePointer(
                child: HolographicWatermark(
                  color: role.color,
                  text: 'CLUBBLACKOUT',
                  enabled: !_isFlipping,
                  enableGyro: true,
                ),
              ),
            // Subtle diagonal sheen
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surface.withValues(alpha: 0.18),
                      Colors.transparent,
                      role.color.withValues(alpha: 0.10),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(widget.compact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER ROW
                  Row(
                    children: [
                      Icon(Icons.nfc_rounded, size: 16, color: role.color.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        'CLUB BLACKOUT',
                        style: badgeLabelStyle.merge(ClubBlackoutTheme.neonGlowFont).copyWith(
                              letterSpacing: 3.0,
                              fontSize: 10,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.role.color.withValues(alpha: 0.10),
                          border: Border.all(
                            color: widget.role.color.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: ClubBlackoutTheme.boxGlow(
                            widget.role.color,
                            intensity: 0.2,
                          ),
                        ),
                        child: Text(
                          'PASS',
                          style: badgeLabelStyle.copyWith(
                            color: widget.role.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ClubBlackoutTheme.gap12,
                  // MAIN CONTENT ROW
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            _IdPhotoBlock(
                              accent: role.color,
                              child: PlayerIcon(
                                assetPath: role.assetPath,
                                glowColor: role.color,
                                size: widget.compact ? 80 : 100, // Slightly smaller for better proportions
                                glowIntensity: 0.65,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        ClubBlackoutTheme.hGap16,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ClubBlackoutTheme.glowTextStyle(
                                  base: titleStyle.copyWith(height: 1.1),
                                  color: role.color,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  glowIntensity: 0.95,
                                ),
                              ),
                              ClubBlackoutTheme.gap12,
                              _IdField(label: idCode, value: role.alliance),
                              ClubBlackoutTheme.gap4,
                              _IdField(label: typeLabel.toUpperCase(), value: roleKind),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // FOOTER ROW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BarcodeStrip(
                              accent: role.color,
                              height: widget.compact ? 22 : 26,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              idCode,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9,
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ClubBlackoutTheme.hGap12,
                      Transform.rotate(
                        angle: -0.15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cs.onSurface.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VALID',
                            style: (tt.labelMedium ?? const TextStyle()).copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ClubBlackoutTheme.gap8,
                  if (widget.allowFlip)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: IconButton(
                        onPressed: _toggleFlip,
                        tooltip: 'View Role Details',
                        style: IconButton.styleFrom(
                          backgroundColor: role.color.withValues(alpha: 0.1),
                          foregroundColor: role.color,
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 20),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(BuildContext context, ColorScheme cs, TextTheme tt) {
    final role = widget.role;

    final headerStyle = (widget.compact ? tt.titleMedium : tt.titleLarge) ??
        (tt.titleMedium ?? const TextStyle());

    final bodyStyle = (tt.bodyMedium ?? const TextStyle()).copyWith(
      color: cs.onSurface.withValues(alpha: 0.8),
      height: 1.4,
      fontSize: 13,
    );

    final choices = role.choices.where((c) => c.trim().isNotEmpty).toList();
    final ability = role.ability?.trim();
    final funFacts = _funFactsFor(role);

    Widget bullet(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: role.color,
                  boxShadow: ClubBlackoutTheme.circleGlow(
                    role.color,
                    intensity: 0.8,
                  ),
                ),
              ),
            ),
            ClubBlackoutTheme.hGap12,
            Expanded(
              child: Text(
                text,
                style: bodyStyle.copyWith(color: cs.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: ClubBlackoutTheme.neonFrame(
        color: role.color,
        opacity: 0.98,
        borderRadius: ClubBlackoutTheme.radiusLg,
        borderWidth: 0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.holographicBackground)
              IgnorePointer(
                child: HolographicWatermark(
                  color: role.color,
                  text: 'CLUBBLACKOUT',
                  enabled: !_isFlipping,
                  enableGyro: true,
                ),
              ),
            // Dark gradient overlay for readability of back text
            Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
            Padding(
              padding: EdgeInsets.all(widget.compact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          role.name,
                          style: headerStyle.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      ClubBlackoutTheme.hGap12,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: role.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: role.color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          role.alliance.toUpperCase(),
                          style: (tt.labelSmall ?? const TextStyle()).copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ClubBlackoutTheme.gap12,
                  Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.1)),
                  ClubBlackoutTheme.gap12,
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoSection(
                            title: 'About',
                            icon: Icons.person_outline_rounded,
                            accent: role.color,
                            children: [Text(role.description, style: bodyStyle)],
                          ),
                          if (ability != null && ability.isNotEmpty) ...[
                            ClubBlackoutTheme.gap12,
                            _InfoSection(
                              title: 'Ability',
                              icon: Icons.flash_on_rounded,
                              accent: role.color,
                              children: [Text(ability, style: bodyStyle)],
                            ),
                          ],
                          if (choices.isNotEmpty) ...[
                            ClubBlackoutTheme.gap12,
                            _InfoSection(
                              title: 'Options',
                              icon: Icons.calculate_outlined,
                              accent: role.color,
                              children: choices.map(bullet).toList(),
                            ),
                          ],
                          if (funFacts.isNotEmpty) ...[
                            ClubBlackoutTheme.gap12,
                            _InfoSection(
                              title: 'Intel',
                              icon: Icons.lightbulb_outline_rounded,
                              accent: role.color,
                              children: funFacts.map(bullet).toList(),
                            ),
                          ],
                          const SizedBox(height: 48), // Bottom padding for FAB
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.allowFlip)
              Positioned(
                bottom: widget.compact ? 12 : 16,
                right: widget.compact ? 12 : 16,
                child: IconButton(
                  onPressed: _toggleFlip,
                  tooltip: 'Return to Card Front',
                  style: IconButton.styleFrom(
                    backgroundColor: role.color.withValues(alpha: 0.15),
                    foregroundColor: role.color,
                    side: BorderSide(
                      color: role.color.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.flip_to_front_rounded, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _IdField extends StatelessWidget {
  final String label;
  final String value;

  const _IdField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (tt.labelSmall ?? const TextStyle()).copyWith(
            color: cs.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (tt.bodyMedium ?? const TextStyle()).copyWith(
            color: cs.onSurface.withValues(alpha: 0.92),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _IdPhotoBlock extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _IdPhotoBlock({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
        boxShadow: ClubBlackoutTheme.circleGlow(accent, intensity: 0.55),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusSm),
        child: child,
      ),
    );
  }
}

class _BarcodeStrip extends StatelessWidget {
  final Color accent;
  final double height;

  const _BarcodeStrip({required this.accent, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ClubBlackoutTheme.radiusSm),
        border: Border.all(color: accent.withValues(alpha: 0.22), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barCount = math.max(14, (constraints.maxWidth / 10).floor());
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(barCount, (i) {
              final isWide = i % 7 == 0 || i % 11 == 0;
              final w = isWide ? 4.0 : 2.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: w,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color accent;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.children,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: tt.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
