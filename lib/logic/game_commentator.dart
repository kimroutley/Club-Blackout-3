import 'dart:math';
import 'live_game_stats.dart';

class GameCommentator {
  static String generateCommentary(LiveGameStats stats, int dayCount) {
    final random = Random();
    final List<String> comments = [];

    // Analyze Game State
    final bool dealersDominaing = stats.dealerPercentage >= 0.6;
    final bool partyDominating = stats.partyPercentage >= 0.6;
    final bool nearlyExtinct = stats.aliveCount <= 3;
    final bool bloodbath = stats.aliveCount < (stats.totalPlayers / 2);
    final bool crowded = stats.aliveCount > (stats.totalPlayers * 0.8);

    // DAY 1 SPECIALS
    if (dayCount == 1) {
      comments.addAll([
        'Fresh meat on the dance floor. Try not to die before the bass drops.',
        'Welcome to Club Blackout. The drinks are watered down and the staff is homicidal.',
        "Look at all these beautiful faces. Shame half of you won't survive the night.",
        "Tonight's special: Paranoia with a twist of lime.",
      ]);
    }

    // HIGH DEATH COUNT
    if (bloodbath) {
      comments.addAll([
        "The janitor is charging double for tonight's cleanup. Stickier than the men's bathroom floor.",
        "Damn, this party is dying faster than my ex's libido.",
        'Is this a VIP room or a morgue? You guys are dropping like flies.',
        "We're running out of body bags faster than ice.",
        "This vibe is tragic. I've seen livelier funerals.",
      ]);
    }

    if (nearlyExtinct) {
      comments.addAll([
        "The music is louder than the heartbeat of this party. It's getting lonely.",
        "Last call for survival! Who's going home in a cab and who's going in a crate?",
        'Only a few of you left. Make it count, or make it quick.',
      ]);
    }
    // LOW DEATH COUNT / CROWDED
    else if (crowded && dayCount > 2) {
      comments.addAll([
        'Are you guys too scared to kill each other? Boring.',
        "It's getting crowded. Someone start throwing hands or I'm calling security.",
        'So much tension, so little action. Like high school prom all over again.',
      ]);
    }

    // FACTION DOMINANCE
    if (dealersDominaing) {
      comments.addAll([
        'The House always wins... and right now, the House is bending you over.',
        'Dealers are running this joint. Check your pockets, your drinks, and your dignity.',
        'More snakes in here than a reptile zoo. The Party Animals are getting played.',
        'The staff is serving ass-whoopings on the house tonight.',
      ]);
    } else if (partyDominating) {
      comments.addAll([
        'Party Animals are tearing it up! Finally, a crowd that knows how to rage.',
        'Chaos reigns! The Dealers are sweating like sinners in church.',
        'The inmates are running the asylum. Pure beautiful anarchy.',
        'This club belongs to the drunks now. Drink up, bitches!',
      ]);
    } else {
      // CLOSE GAME
      comments.addAll([
        "It's tighter than leather pants on a humid night. Anyone's game.",
        'Tensions are high. The air is thick with sweat, lies, and cheap cologne.',
        "Neck and neck. Or neck and knife. Whatever happens, it's gonna be messy.",
      ]);
    }

    // UNIVERSAL FILLERS (Anytime)
    comments.addAll([
      'Remember: What happens in the dark... usually leaves a stain.',
      'Someone in here smells like betrayal and cheap vodka.',
      "I've seen cleaner fights in a Waffle House parking lot.",
      "Trust no one. especially not the guy offering you 'free' shots.",
      "If you're not cheating, you're not trying to win.",
      'Keep your friends close, and your enemies... well, maybe just stab them.',
      'Caution: Floor feels slippery. Probably blood. Maybe glitter. Hopefully glitter.',
    ]);

    // Role Specific Teasers (if counts allow)
    if (stats.neutralAliveCount > 0) {
      comments.add(
        'The Neutrals are just watching the world burn and eating popcorn.',
      );
    }

    // Pick a random one
    return comments[random.nextInt(comments.length)];
  }
}
