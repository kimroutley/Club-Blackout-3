import 'package:flutter/material.dart';
import '../styles.dart';

class PlayerGuideScreen extends StatelessWidget {
  const PlayerGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Player guide",
          style: TextStyle(
            fontSize: 29,
            color: ClubBlackoutTheme.neonPink,
            fontWeight: FontWeight.bold,
            shadows: ClubBlackoutTheme.textGlow(ClubBlackoutTheme.neonPink),
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: const PlayerGuideBody(),
    );
  }
}

class PlayerGuideBody extends StatelessWidget {
  const PlayerGuideBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage(
            "Backgrounds/Club Blackout App Background.png",
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.85),
            BlendMode.darken,
          ),
        ),
      ),
      child: SafeArea(
        child: ClubBlackoutTheme.centeredConstrained(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
            _buildSectionCard(
              title: "Welcome to Club Blackout",
              children: [
                _buildParagraph(
                  "Club Blackout is a high-energy social deduction game where players are guests at a nightclub. Hidden among the innocent \"Party Animals\" are the \"Dealers,\" who are looking to eliminate the guests one by one.\n\nThe game requires you to lie, betray, trust your gut, and survive the night.",
                ),
              ],
            ),
            _buildSectionCard(
              title: "The Golden Rules",
              children: [
                _buildBulletPoint(
                  "Eyes Shut",
                  "When the Host calls for sleep, keep your eyes closed unless your specific role is called.",
                ),
                _buildBulletPoint(
                  "Silence is Golden",
                  "If you are \"Roofi'd\" or dead, you cannot speak, point, or influence the game in any way, other than eye contact.",
                ),
                _buildBulletPoint(
                  "Dead Men Tell No Tales",
                  "Eliminated players cannot help their team; they can only watch the chaos.",
                ),
                _buildBulletPoint(
                  "No Flashing",
                  "Keep your card hidden unless a specific ability (like the Silver Fox) forces you to reveal it.",
                ),
              ],
            ),
            _buildSectionCard(
              title: "How to Win",
              children: [
                _buildBulletPoint(
                  "The Dealers",
                  "Eliminate all Party Animals until you hold the majority.",
                ),
                _buildBulletPoint(
                  "The Party Animals",
                  "Identify and vote out all the Dealers before everyone dies.",
                ),
                _buildBulletPoint(
                  "Chaos Roles",
                  "Roles like The Messy Bitch, Club Manager, or Clinger have their own unique agendas for survival.",
                ),
              ],
            ),
            _buildSectionCard(
              title: "The Game Loop",
              children: [
                _buildParagraph(
                  "The game cycles between two distinct phases: The Night (The Bender) and The Day (The Morning After).",
                ),
                const SizedBox(height: 16),
                _buildSubTitle("Phase 1: The Night (The Bender)"),
                _buildParagraph(
                  "This is where the secret actions happen. Players close their eyes, and the Host wakes up specific roles to perform actions.",
                ),
                _buildBulletPoint("The Murder", "Dealers choose a victim."),
                _buildBulletPoint(
                  "The Help",
                  "Roles like the Medic and Bouncer protect players or check IDs.",
                ),
                _buildBulletPoint(
                  "The Sabotage",
                  "The Roofi paralyzes players, and the Lightweight is given a forbidden word.",
                ),
                _buildBulletPoint(
                  "The Intel",
                  "The Wallflower and Ally Cat try to peek at what is happening.",
                ),
                const SizedBox(height: 16),
                _buildSubTitle("Phase 2: The Day (The Morning After)"),
                _buildBulletPoint(
                  "The Reveal",
                  "The Host announces who died or was saved.",
                ),
                _buildBulletPoint(
                  "The Discussion",
                  "You have a set time (e.g., 5 minutes) to discuss, lie, accuse, or share information.",
                ),
                _buildBulletPoint(
                  "The Accusation",
                  "A player can accuse someone of being a Dealer. This requires a \"second\" to proceed to a vote.",
                ),
                _buildBulletPoint(
                  "The Vote",
                  "If a majority votes \"Guilty,\" the accused is eliminated.",
                ),
              ],
            ),
            _buildSectionCard(
              title: "The Roles",
              children: [
                _buildSubTitle("The Host"),
                _buildBulletPoint(
                  "Objective",
                  "Neutral facilitator. Ensures rules are followed and sets the tone.",
                ),
                _buildBulletPoint(
                  "Ability",
                  "Can put players to sleep to refresh memory.",
                ),
                const SizedBox(height: 16),
                _buildSubTitle("The Bad Guys (The Dealers & Allies)"),
                _buildBulletPoint(
                  "The Dealer",
                  "The killers. They wake up at night to murder Party Animals.",
                ),
                _buildBulletPoint(
                  "The Whore",
                  "Innocent of murder but aligned with the Dealers. She acts as a distraction and tries to save them.",
                ),
                const SizedBox(height: 16),
                _buildSubTitle("The Good Guys (The Party Animals)"),
                _buildBulletPoint(
                  "Party Animal",
                  "The innocent guests. Their goal is simply to survive and vote out Dealers.",
                ),
                _buildBulletPoint(
                  "The Bouncer",
                  "Can check one player's ID per night to see if they are a Dealer or not. Risk: If he checks the Roofi and is wrong, he loses his power.",
                ),
                _buildBulletPoint(
                  "The Medic",
                  "Chooses at setup (Night 0) to either REVIVE one dead player during any day phase OR PROTECT one player every night. This choice is PERMANENT for the entire game.",
                ),
                _buildBulletPoint(
                  "The Wallflower",
                  "Can open their eyes to watch the murder but must not get caught.",
                ),
                _buildBulletPoint(
                  "The Roofi",
                  "Can paralyze one player per night (preventing them from speaking/acting). If a Dealer is Roofi'd, they are paralyzed for the next night too.",
                ),
                _buildBulletPoint(
                  "The Lightweight",
                  "Given a \"taboo\" name by the Host each night. If they say that name the next day, they die.",
                ),
                _buildBulletPoint(
                  "The Tea Spiller",
                  "If they die, they get to expose one player's role (Dealer or Not) to the group.",
                ),
                _buildBulletPoint(
                  "The Minor",
                  "Cannot be killed by Dealers until the Bouncer has checked her ID.",
                ),
                _buildBulletPoint(
                  "The Seasoned Drinker",
                  "Has extra lives. It takes Dealers twice as many attempts to kill them.",
                ),
                _buildBulletPoint(
                  "The Drama Queen",
                  "If killed, she can swap two players' devices and look at them.",
                ),
                _buildBulletPoint(
                  "The Ally Cat",
                  "Can open eyes when the Bouncer checks IDs but can only communicate by saying \"Meow\".",
                ),
                _buildBulletPoint(
                  "The Sober",
                  "Can send one player \"home\" (protecting them) once per game. If a Dealer is sent home, no murder happens.",
                ),
                _buildBulletPoint(
                  "The Silver Fox",
                  "Once per game, can force a player to reveal their device to the room by \"plying them with alcohol\".",
                ),
                _buildBulletPoint(
                  "The Predator",
                  "If voted out, they choose one person who voted for them to die as well.",
                ),
                _buildBulletPoint(
                  "The Creep",
                  "Pretends to be another Party Animal role at the start; dies if the original role dies.",
                ),
                const SizedBox(height: 16),
                _buildSubTitle("The Wild Cards (Neutral/Chaos)"),
                _buildBulletPoint(
                  "The Messy Bitch",
                  "No alliance. Her goal is to survive by causing chaos and blaming others.",
                ),
                _buildBulletPoint(
                  "The Club Manager",
                  "No alliance. She cares only about profits/survival. Can look at one player's device each night.",
                ),
                _buildBulletPoint(
                  "The Clinger",
                  "Alliance is to their partner only. They must vote exactly how their partner votes. If their obsession calls them 'controller', they become an attack dog and can kill immediately.",
                ),
                _buildBulletPoint(
                  "The Second Wind",
                  "Starts as a Party Animal. If killed by Dealers, she can convince them to convert her, bringing her back to life as a Dealer. If Dealers accept, no one dies that night.",
                ),
              ],
            ),
            _buildSectionCard(
              title: "Survival Strategy Guide",
              children: [
                _buildBulletPoint(
                  "Spotting The Clinger",
                  "Watch the voting patterns. If two people always vote exactly the same way, they might be the Clinger and their partner.",
                ),
                _buildBulletPoint(
                  "Protecting The Bouncer",
                  "If you are the Bouncer, do not reveal yourself early. If Dealers know who you are, you will be the first target.",
                ),
                _buildBulletPoint(
                  "Multiple Lives",
                  "Seasoned Drinker has lives equal to the number of Dealers. Ally Cat has 9 lives. Each murder attempt removes one life. The host will announce when they're attacked but survive.",
                ),
                _buildBulletPoint(
                  "Dealer Tactics",
                  "Use \"The Whore\" as a shield. If they are willing to take the heat during the day, let them distract the Party Animals.",
                ),
                _buildBulletPoint(
                  "Lightweight Warning",
                  "Listen carefully to the Host. If you say the forbidden name, you are out instantly.",
                ),
              ],
            ),
          ],
        ),
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
            padding: const EdgeInsets.only(top: 6.0),
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
