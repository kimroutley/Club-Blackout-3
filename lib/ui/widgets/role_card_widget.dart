import 'package:flutter/material.dart';
import '../../models/role.dart';
import '../styles.dart';
import 'dart:math' as math;
import 'holographic_watermark.dart';

class RoleCardWidget extends StatelessWidget {
  final Role role;
  final String? playerName;
  final bool compact;

  const RoleCardWidget({
    super.key,
    required this.role,
    this.playerName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // ID Card / Access Badge Design
    // Vertical layout with a "plastic" dark background, header strip, and data fields.

    final Color securityColor = role.color;
    final Color cardBackground = const Color(0xFF151515); // Darker plastic look

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: securityColor.withOpacity(0.1),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Holographic Background Watermark
            Positioned.fill(child: HolographicWatermark(color: securityColor)),

            // Dark scrim to boost contrast against the hologram
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),

            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- ID HEADER ---
                Container(
                  height: 40,
                  decoration: BoxDecoration(color: securityColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CLUB ACCESS',
                        style: ClubBlackoutTheme.primaryFont.copyWith(
                          color: Colors.black, // Contrast text on neon
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Icon(
                        Icons.nfc,
                        color: Colors.black.withOpacity(0.6),
                        size: 20,
                      ),
                    ],
                  ),
                ),

                // --- MAIN CONTENT AREA ---
                Padding(
                  padding: const EdgeInsets.all(
                    16.0,
                  ), // Reduced padding for better mobile fit
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Photo + Primary Data
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo ID Box
                          Container(
                            width: 80, // Reduced width to prevent overflow
                            height: 100, // Adjusted aspect ratio
                            decoration: BoxDecoration(
                              color: Colors.black,
                              border: Border.all(
                                color: securityColor.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (role.assetPath.isNotEmpty)
                                  Image.asset(
                                    role.assetPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) =>
                                        _buildPlaceholderIcon(),
                                  )
                                else
                                  _buildPlaceholderIcon(),

                                // Holographic overlay effect line
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.1),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.4, 0.5, 0.6],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12), // Reduced spacing
                          // Data Fields
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                  0.5,
                                ), // Dark background for legibility
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildDataField(
                                    'NAME',
                                    playerName?.toUpperCase() ?? 'UNKNOWN',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDataField(
                                    'CODENAME',
                                    role.name.toUpperCase(),
                                    highlight: true,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDataField(
                                    'CLEARANCE',
                                    role.alliance.toUpperCase(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),

                      // Role Details (Classified Info)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: securityColor.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          '// MISSION BRIEFING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Courier', // Monospace for tech feel
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: securityColor.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Added background container to improve legibility against hologram
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Text(
                          role.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.96),
                            fontSize: 14,
                            height: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (role.ability != null && role.ability!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: securityColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            '// SPECIAL ABILITY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: securityColor.withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // Darker background mix for better contrast
                            color: Color.alphaBlend(
                              securityColor.withOpacity(0.12),
                              Colors.black.withOpacity(0.7),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(color: securityColor, width: 2),
                              top: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                              ),
                              right: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                              ),
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          child: Text(
                            role.ability!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.96),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              shadows: [
                                const Shadow(
                                  color: Colors.black,
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // --- FOOTER (Barcode/Chip) ---
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  color: Colors.black38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ID Number
                      Text(
                        'ID: ${math.Random().nextInt(99999).toString().padLeft(5, '0')}-${role.name.substring(0, 3).toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontFamily: 'Courier',
                          fontSize: 10,
                        ),
                      ),

                      // Faux Barcode
                      Row(
                        children: List.generate(
                          10,
                          (index) => Container(
                            width: 2 + (index % 3) * 2.0,
                            height: 16,
                            color: Colors.white.withOpacity(0.4),
                            margin: const EdgeInsets.only(left: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.person_outline,
        size: 48,
        color: role.color.withOpacity(0.5),
      ),
    );
  }

  Widget _buildDataField(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.bold, // Monospace/Tech feel
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        highlight
            ? Text(
                value,
                style: ClubBlackoutTheme.primaryFont.copyWith(
                  color: role.color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: role.color.withOpacity(0.8), blurRadius: 10),
                  ],
                ),
              )
            : Text(
                value,
                style: ClubBlackoutTheme.primaryFont.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    const Shadow(
                      color: Colors.black,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ],
    );
  }
}
