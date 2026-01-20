import 'package:flutter/material.dart';
import '../styles.dart';

class PhaseCard extends StatelessWidget {
  final String phaseName;
  final String? subtitle;
  final Color phaseColor;
  final IconData phaseIcon;
  final bool isActive;

  const PhaseCard({
    super.key,
    required this.phaseName,
    this.subtitle,
    required this.phaseColor,
    required this.phaseIcon,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            phaseColor.withOpacity(0.3),
            phaseColor.withOpacity(0.1),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: phaseColor.withOpacity(isActive ? 0.8 : 0.3),
          width: isActive ? 3 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: phaseColor.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: phaseColor, width: 3),
              gradient: RadialGradient(
                colors: [
                  phaseColor.withOpacity(0.3),
                  phaseColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: phaseColor.withOpacity(0.6),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(phaseIcon, size: 80, color: phaseColor),
          ),
          const SizedBox(height: 24),
          Text(
            phaseName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: phaseColor,
              letterSpacing: 3,
              shadows: ClubBlackoutTheme.textGlow(phaseColor),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, phaseColor, Colors.transparent],
              ),
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
