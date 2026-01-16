import 'package:flutter/material.dart';
import '../../models/role.dart';
// import '../styles.dart'; // Unused if we stick to local styling or standard theme

class RoleCardWidget extends StatelessWidget {
  final Role role;
  final String? playerName;

  const RoleCardWidget({super.key, required this.role, this.playerName});

  @override
  Widget build(BuildContext context) {
    // Determine a high-contrast color driven by the role color, but readable
    // If role color is very dark, lighten it. If very light, keep it.
    // For a dark theme receipt, we often want bright neon text.
    final Color textColor = role.color; 
    
    // Receipt Style Text
    final TextStyle receiptStyle = TextStyle(
      fontFamily: 'Courier', // Monospace mostly available
      fontSize: 14,
      color: textColor,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.4,
    );
    
    final TextStyle headerStyle = receiptStyle.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      letterSpacing: 2.0,
    );

    final TextStyle labelStyle = receiptStyle.copyWith(
      fontSize: 12,
      color: textColor.withOpacity(0.7),
    );

    Widget dashedLine() {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          '-' * 40,
          style: receiptStyle.copyWith(color: textColor.withOpacity(0.3)),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E1E1E), // Dark card background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: role.color.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Section
            Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: role.color, width: 2),
                      image: DecorationImage(
                        image: AssetImage(role.assetPath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    role.name.toUpperCase(),
                    style: headerStyle,
                    textAlign: TextAlign.center,
                  ),
                  if (playerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "ID: ${playerName!.toUpperCase()}",
                      style: receiptStyle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        backgroundColor: textColor.withOpacity(0.2),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            dashedLine(),
            
            // Attributes Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ALLIANCE", style: labelStyle),
                      Text(role.alliance.toUpperCase(), style: receiptStyle),
                    ],
                  ),
                ),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("TYPE", style: labelStyle),
                        Text(role.type.toUpperCase(), style: receiptStyle),
                      ],
                    ),
                ),
              ],
            ),
            
            dashedLine(),
            
            // Description Section
            Text("MISSION OBJECTIVE", style: labelStyle),
            const SizedBox(height: 4),
            Text(
              role.description,
              style: receiptStyle.copyWith(fontSize: 13, color: Colors.white.withOpacity(0.9)),
            ),
            
            if (role.ability != null && role.ability!.isNotEmpty) ...[
              dashedLine(),
              Text("SPECIAL ABILITY", style: labelStyle),
              const SizedBox(height: 4),
              Text(
                role.ability!,
                style: receiptStyle.copyWith(fontSize: 13, color: Colors.white.withOpacity(0.9)),
              ),
            ],
            
            dashedLine(),
            
            // Footer / Barcode-ish look
            Center(
              child: Column(
                children: [
                  Text(
                    "CLUB BLACKOUT VERIFIED",
                    style: labelStyle.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  // Pseudo-barcode using vertical bars
                  Text(
                    "||| |||| | ||| || ||||| || |||",
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 16,
                      color: role.color.withOpacity(0.5),
                      fontWeight: FontWeight.w100,
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
}