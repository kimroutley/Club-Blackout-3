import 'package:flutter/material.dart';
import '../styles.dart';
import '../../logic/game_engine.dart';
import 'player_guide_screen.dart';
import 'character_cards_screen.dart';

class GuidesScreen extends StatelessWidget {
  final GameEngine? gameEngine;
  const GuidesScreen({super.key, this.gameEngine});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                "Backgrounds/Club Blackout App Background.png",
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(color: Colors.black),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
              // TabBar at the top of the content area
              Container(
                margin: const EdgeInsets.only(
                  top: 100,
                ), // Spacing for MainScreen AppBar
                color: Colors.black.withOpacity(0.5),
                child: TabBar(
                  indicatorColor: ClubBlackoutTheme.neonOrange,
                  labelColor: ClubBlackoutTheme.neonOrange,
                  unselectedLabelColor: Colors.white54,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.mic, size: 20), text: "HOST"),
                    Tab(icon: Icon(Icons.person, size: 20), text: "PLAYER"),
                    Tab(icon: Icon(Icons.style, size: 20), text: "CARDS"),
                    Tab(icon: Icon(Icons.gavel, size: 20), text: "RULES"),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildHostGuide(context),
                    ClubBlackoutTheme.centeredConstrained(
                      maxWidth: 760,
                      child: PlayerGuideBody(),
                    ),
                    ClubBlackoutTheme.centeredConstrained(
                      maxWidth: 920,
                      child: CharacterCardsScreen(
                        roles: gameEngine?.roleRepository.roles ?? [],
                      ),
                    ),
                    _buildRulesGuide(context),
                  ],
                ),
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostGuide(BuildContext context) {
    return ClubBlackoutTheme.centeredConstrained(
      maxWidth: 920,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildSectionCard(
            title: "PART 1: GAME PREPARATION",
            children: [
              _buildSubTitle("1. Build the Deck"),
              _buildParagraph(
                "Select the roles based on your player count. You must always include:",
              ),
              _buildBulletPoint(
                "Dealers",
                "Only role that can repeat. Recommended: 1 Dealer per 7 total players.",
              ),
              _buildBulletPoint(
                "Unique Roles",
                "Every other character can only appear once in a game.",
              ),
              _buildBulletPoint("1 Medic and/or 1 Bouncer", ""),
              const SizedBox(height: 16),
              _buildSubTitle("2. The Setup"),
              _buildBulletPoint(
                "Shuffle & Deal",
                "Distribute cards randomly and keep them hidden.",
              ),
              _buildBulletPoint(
                "Initial Read",
                "Tell players: \"Everyone has 10 seconds to read their role description and conditions. Do not let anyone know your identity.\"",
              ),
              _buildBulletPoint(
                "Role Call (Internal)",
                "Ask everyone to close their eyes and hold up their cards so you (The Host) can see who is who and prepare your notes.",
              ),
              const SizedBox(height: 16),
              _buildSubTitle("3. Timer Rules"),
              _buildBulletPoint(
                "Calculation",
                "Allow 30 seconds of discussion time per player (e.g., 4 players = 2 minutes).",
              ),
              _buildBulletPoint(
                "Adjustment",
                "For every death, reduce the total time by 30 seconds.",
              ),
            ],
          ),
          _buildSectionCard(
            title: "PART 2: THE HOST NOTEPAD",
            children: [
              _buildParagraph(
                "Social deduction games get messy. Keep a physical notepad or phone note to track the following specific states:",
              ),
              const SizedBox(height: 12),
              _buildBulletPoint(
                "The Medic's Choice",
                "Did they choose REVIVE (one-time use) or PROTECT (nightly use)? (Decided Night 1).",
              ),
              _buildBulletPoint(
                "The Clinger's Obsession",
                "Who is their partner? (If the partner dies, the Clinger dies).",
              ),
              _buildBulletPoint(
                "The Lightweight's Taboo List",
                "Write down every name pointed to. The list grows cumulatively; if the Lightweight says any of the names on the list, they die.",
              ),
              _buildBulletPoint(
                "The Creep's Role",
                "Which Party Animal are they pretending to be?",
              ),
              _buildBulletPoint(
                "The Bouncer",
                "Did they lose their powers by suspecting the Roofi?",
              ),
              _buildBulletPoint(
                "Status Effects",
                "Who is currently Roofi'd (Paralyzed) or Protected (by Medic/Sober).",
              ),
            ],
          ),
          _buildSectionCard(
            title: "PART 3: THE SCRIPT (NIGHT 1)",
            children: [
              _buildParagraph(
                "Read this script exactly as written for the FIRST night only. This night includes special one-time setups.",
              ),
              const SizedBox(height: 12),
              _buildParagraph(
                "\"Everyone, close your eyes. The night has begun.\"",
              ),
              const SizedBox(height: 16),
              _buildSubTitle("1. The Murder"),
              _buildBulletPoint("", "\"Dealers, open your eyes.\" (Pause)"),
              _buildBulletPoint(
                "",
                "\"Whore, open your eyes.\" (Pause - let them see the Dealers)",
              ),
              _buildBulletPoint("", "\"Wallflower, open your eyes.\" (Pause)"),
              _buildBulletPoint(
                "",
                "\"Dealers, choose your victim.\" (Wait for them to point. Note the victim).",
              ),
              _buildBulletPoint("", "\"Everyone, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("2. The Medic's Decision"),
              _buildBulletPoint("", "\"Medic, open your eyes.\""),
              _buildBulletPoint(
                "",
                "\"Do you choose Option 1 (Revive later) or Option 2 (Protect nightly)?\" (Wait for signal. Note this down).",
              ),
              _buildBulletPoint(
                "",
                "\"Please select a player if you wish to use your ability now.\" (Wait for point).",
              ),
              _buildBulletPoint("", "\"Medic, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("3. The Identification"),
              _buildBulletPoint(
                "",
                "\"Bouncer and Ally Cat, open your eyes.\"",
              ),
              _buildBulletPoint(
                "",
                "\"Bouncer, select a player you'd like to I.D.\" (Wait for point).",
              ),
              _buildBulletPoint(
                "Action",
                "Nod your head if the target is a Dealer. Shake your head if they are not.",
              ),
              _buildBulletPoint(
                "Note",
                "The Ally Cat is watching this happen.",
              ),
              _buildBulletPoint(
                "",
                "\"Bouncer and Ally Cat, close your eyes.\"",
              ),
              const SizedBox(height: 16),
              _buildSubTitle("4. The Sabotage"),
              _buildBulletPoint("", "\"Lightweight, open your eyes.\""),
              _buildBulletPoint("Action", "Point to a random player."),
              _buildBulletPoint(
                "",
                "\"Lightweight, look at the person I am pointing to. You can no longer call them by their name.\"",
              ),
              _buildBulletPoint("", "\"Lightweight, close your eyes.\""),
              _buildBulletPoint(
                "",
                "\"Roofi, open your eyes. Select a player to Roofi.\" (Wait for point).",
              ),
              _buildBulletPoint(
                "Action",
                "Tap the Roofi'd player to alert them. \"You are paralyzed and cannot speak or move this round.\".",
              ),
              _buildBulletPoint("", "\"Roofi, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("5. The Obsession (Night 1 Only)"),
              _buildBulletPoint(
                "",
                "\"Clinger, open your eyes. Select the player you wish to be obsessed over.\" (Wait for point. Note this down - their fates are now linked).",
              ),
              _buildBulletPoint("", "\"Clinger, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("6. The Exposure"),
              _buildBulletPoint(
                "",
                "\"Club Manager, open your eyes. Select a player to expose.\" (Wait for point).",
              ),
              _buildBulletPoint(
                "Action",
                "Tap the selected player. \"You have been selected. Keep your eyes closed, but hold your card up for 5 seconds.\"",
              ),
              _buildBulletPoint("", "\"Club Manager, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("7. Wake Up"),
              _buildBulletPoint(
                "",
                "\"Everyone, open your eyes. The club is closed.\"",
              ),
              _buildBulletPoint(
                "Announcement",
                "Announce who died. If the Medic/Sober saved them, announce: \"There was no death last night.\"",
              ),
            ],
          ),
          _buildSectionCard(
            title: "PART 4: THE SCRIPT (FUTURE NIGHTS)",
            children: [
              _buildParagraph(
                "Before starting the script, look for raised hands. The Sober or Silver Fox must raise their hands BEFORE Dealers wake up to use their once-per-game abilities.",
              ),
              const SizedBox(height: 12),
              _buildParagraph("\"Everyone, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("1. The Murder"),
              _buildBulletPoint("", "\"Dealers, open your eyes.\""),
              _buildBulletPoint("", "\"Whore, open your eyes.\""),
              _buildBulletPoint("", "\"Wallflower, open your eyes.\""),
              _buildBulletPoint(
                "",
                "\"Dealers, choose your victim.\" (Wait for point).",
              ),
              _buildBulletPoint("", "\"Everyone, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("2. The Protection"),
              _buildBulletPoint("", "\"Medic, open your eyes.\""),
              _buildBulletPoint(
                "",
                "\"Please select a player if you wish to use your ability.\" (If they chose Protect, they point. If they chose Revive, they can use it now if someone is dead).",
              ),
              _buildBulletPoint("", "\"Medic, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("3. The Identification"),
              _buildBulletPoint(
                "",
                "\"Bouncer and Ally Cat, open your eyes.\"",
              ),
              _buildBulletPoint(
                "",
                "\"Bouncer, select a player you'd like to I.D.\" (Wait for point -> Nod/Shake Head).",
              ),
              _buildBulletPoint(
                "",
                "\"Bouncer and Ally Cat, close your eyes.\"",
              ),
              const SizedBox(height: 16),
              _buildSubTitle("4. The Sabotage"),
              _buildBulletPoint("", "\"Lightweight, open your eyes.\""),
              _buildBulletPoint(
                "Action",
                "Point to a NEW player. Add this name to the previous list of taboo names.",
              ),
              _buildBulletPoint(
                "",
                "\"Lightweight, look at the person I am pointing to. You can no longer call them by their name.\"",
              ),
              _buildBulletPoint("", "\"Lightweight, close your eyes.\""),
              _buildBulletPoint(
                "",
                "\"Roofi, open your eyes. Select a player to Roofi.\" (Wait for point -> Tap player).",
              ),
              _buildBulletPoint(
                "",
                "\"You are paralyzed and cannot speak or move this round.\"",
              ),
              _buildBulletPoint("", "\"Roofi, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("5. The Exposure"),
              _buildBulletPoint(
                "",
                "\"Club Manager, open your eyes. Select a player to expose.\" (Wait for point -> Tap player).",
              ),
              _buildBulletPoint("", "\"Hold your card up for 5 seconds.\""),
              _buildBulletPoint("", "\"Club Manager, close your eyes.\""),
              const SizedBox(height: 16),
              _buildSubTitle("6. Wake Up"),
              _buildBulletPoint("", "\"Everyone, open your eyes.\""),
              _buildBulletPoint(
                "Announcement",
                "Announce who died (or if no one died). Do not reveal the Role of the dead player, only their name.",
              ),
            ],
          ),
          _buildSectionCard(
            title: "PART 5: THE DAY PHASE (Voting)",
            children: [
              _buildBulletPoint(
                "Start the Timer",
                "30 seconds x Number of Players.",
              ),
              _buildBulletPoint(
                "Discussion",
                "Players discuss, lie, and share intel. Note: The Roofi'd player cannot speak. Note: If the Lightweight says a taboo name, they die immediately.",
              ),
              _buildBulletPoint(
                "Accusation",
                "A player can accuse another. They need a \"second\" to proceed.",
              ),
              _buildBulletPoint(
                "The Vote",
                "Facilitate a vote. Majority rules. The player is \"dealt with\" (eliminated).",
              ),
              _buildBulletPoint(
                "Death Triggers",
                "If a player dies, check their role device: Tea Spiller (reveal one person's role), Drama Queen (can swap two devices), Second Wind (if killed by Dealers, she might convert to a Dealer), Predator (if voted out, they take a voter with them).",
              ),
            ],
          ),
          _buildSectionCard(
            title: "PART 6: GAME END",
            children: [
              _buildBulletPoint(
                "Dealers Win",
                "When they eliminate all Party Animals (or hold the majority).",
              ),
              _buildBulletPoint(
                "Party Animals Win",
                "When all Dealers are eliminated.",
              ),
              _buildBulletPoint(
                "Neutrals Win",
                "The Messy Bitch or Club Manager win if they survive to the end.",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesGuide(BuildContext context) {
    return ClubBlackoutTheme.centeredConstrained(
      maxWidth: 920,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildSectionCard(
            title: "General Rules",
            children: [
              _buildBulletPoint("Respect the Host", "The Host's word is law."),
              _buildBulletPoint(
                "No Cheating",
                "Do not open your eyes during the night phase unless instructed.",
              ),
            ],
          ),
          _buildSectionCard(
            title: "Voting",
            children: [
              _buildParagraph(
                "During the day, players discuss and vote to eliminate a suspect. A majority vote is required.",
              ),
            ],
          ),
          _buildSectionCard(
            title: "Winning",
            children: [
              _buildParagraph(
                "Party Animals win by eliminating all Dealers. Dealers win by equalling or outnumbering the Party Animals.",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    Color? color,
  }) {
    final themeColor = color ?? ClubBlackoutTheme.neonBlue;
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: themeColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Hyperwave',
                fontSize: 24,
                color: themeColor,
                shadows: ClubBlackoutTheme.textGlow(themeColor),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSubTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ClubBlackoutTheme.neonOrange,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white70,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String boldText, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Icon(
              Icons.circle,
              size: 6,
              color: ClubBlackoutTheme.neonPink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                  height: 1.5,
                ),
                children: [
                  if (boldText.isNotEmpty)
                    TextSpan(
                      text: '$boldText: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
