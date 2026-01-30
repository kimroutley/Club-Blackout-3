import 'dart:convert';

import '../logic/game_dashboard_stats.dart';
import '../logic/game_engine.dart';
import '../logic/host_insights.dart';
import '../logic/story_exporter.dart';

enum AiCommentaryStyle {
  pg,
  rude,
  hardR,
}

extension AiCommentaryStyleUi on AiCommentaryStyle {
  String get label {
    switch (this) {
      case AiCommentaryStyle.pg:
        return 'PG';
      case AiCommentaryStyle.rude:
        return 'RUDE';
      case AiCommentaryStyle.hardR:
        // “Hard-R” is interpreted here as “hard Rated-R”.
        // Prompts still explicitly forbid slurs/hate.
        return 'HARD-R';
    }
  }

  String get shortGuidance {
    switch (this) {
      case AiCommentaryStyle.pg:
        return 'Family-friendly, playful, no swearing.';
      case AiCommentaryStyle.rude:
        return 'Edgy and sassy, light swearing allowed, no slurs.';
      case AiCommentaryStyle.hardR:
        return 'Rated-R energy, strong language allowed, no slurs/hate.';
    }
  }
}

/// Builds a structured JSON payload intended to be pasted into an AI
/// (Gemini/GPT/etc) for analysis and a detailed game overview.
Map<String, dynamic> buildAiGameStatsExport(GameEngine engine) {
  final snapshot = engine.exportStorySnapshot();

  final dashboard = GameDashboardStats.fromEngine(engine);
  final live = dashboard.live;
  final voting = dashboard.voting;
  final odds = dashboard.odds;

  final host = HostInsightsSnapshot.fromEngine(engine);

  return <String, dynamic>{
    'schema': 'club_blackout.ai_game_stats.v1',
    'exportedAt': DateTime.now().toIso8601String(),
    'game': snapshot.toJson(),
    'derived': {
      'phase': engine.currentPhase.name,
      'dayCount': engine.dayCount,
      'script': {
        'currentIndex': engine.currentScriptIndex,
        'totalSteps': engine.scriptQueue.length,
        'progress': host.scriptProgress,
        'activeStep': host.activeScriptStep?.toJson(),
      },
      'liveStats': {
        'totalPlayers': live.totalPlayers,
        'aliveCount': live.aliveCount,
        'deadCount': live.deadCount,
        'allianceCounts': live.allianceCounts,
        'roleCounts': live.roleCounts,
        'dealerAliveCount': live.dealerAliveCount,
        'partyAliveCount': live.partyAliveCount,
        'neutralAliveCount': live.neutralAliveCount,
        'dealerPercentage': live.dealerPercentage,
        'partyPercentage': live.partyPercentage,
        'neutralPercentage': live.neutralPercentage,
      },
      'voting': {
        'day': voting.day,
        'votesCastToday': voting.votesCastToday,
        'totalVoteActions': voting.totalVoteActions,
        'currentBreakdown': voting.currentBreakdown
            .map(
              (b) => {
                'targetId': b.targetId,
                'targetName': b.targetName,
                'voteCount': b.voteCount,
                'voterIds': b.voterIds,
                'voterNames': b.voterNames,
              },
            )
            .toList(growable: false),
        'topVoters': voting.topVoters
            .map(
              (v) => {
                'voterId': v.voterId,
                'voterName': v.voterName,
                'voteActions': v.voteActions,
                'changes': v.changes,
              },
            )
            .toList(growable: false),
        'mostTargetedAllTime': voting.mostTargetedAllTime
            .map(
              (t) => {
                'targetId': t.targetId,
                'targetName': t.targetName,
                'voteCount': t.voteCount,
              },
            )
            .toList(growable: false),
      },
      'odds': {
        'note': odds.note,
        'odds': odds.odds,
        'sortedDesc': odds.sortedDesc
            .map((e) => {'winner': e.key, 'probability': e.value})
            .toList(growable: false),
      },
      'roleChips': dashboard.roleChips
          .map((c) => {
                'roleId': c.roleId,
                'roleName': c.roleName,
                'aliveCount': c.aliveCount,
              })
          .toList(growable: false),
      'lastNight': {
        'hostRecapLines': host.lastNightRecapLines,
        'stats': host.lastNightStats,
      },
      'hostFlavor': {
        'commentary': host.commentary,
      },
    },
    'suggestedInstructions': {
      'goal':
          'Produce a detailed overview of the game, turning points, vote dynamics, and likely win trajectory.',
      'outputFormat': {
        'include': [
          'Executive summary (5-10 bullets)',
          'Phase/day timeline highlights',
          'Key eliminations and night actions (from logs)',
          'Voting analysis (today + all-time)',
          'Odds interpretation',
          'Notable player arcs',
          'What to watch next',
        ],
      },
    },
  };
}

String _buildGeminiRecapPrompt({
  int minWords = 250,
  int maxWords = 450,
}) {
  return '''You are an expert commentator writing a concise recap of a live session of the social deduction game “Club Blackout”.

This is a COMMENTARY RECAP, not a novel, not a first-person drama, and not a slow cinematic short story.
Write in THIRD PERSON and in PAST TENSE. Do not use first person (no “I/me/my”) and do not write inner monologues.
Treat the JSON as ground truth. Do not invent events, characters, motivations, or outcomes that are not supported by the script steps / snapshot.

Tone: sharp, witty, and fast-paced—like a post-game recap or sports desk commentary.
Keep it tight: short paragraphs, punchy sentences, and clear headings.

IMPORTANT: If any ScriptStep includes readAloudText, embed it verbatim as host narration using exactly: Read aloud: "...".
Do not paraphrase those lines.

Allowed: strong language (Rated-R vibe) if it fits.
Strictly forbidden: slurs/hate, sexual violence, explicit sex acts, minors, or graphic gore.

Output format:

1) HEADLINE (one line)

2) QUICK RECAP (5–10 bullets)

3) KEY MOMENTS (Night / Day): 4–8 bullets total

4) WHO PLAYED THEMSELVES? (2–4 bullets: misreads, bluffs, betrayals)

5) NEXT UP (1–2 sentences prediction)

TARGET LENGTH: $minWords–$maxWords words. HARD CAP: Do not exceed $maxWords words.''';
}

/// Builds a structured JSON payload intended to be pasted into an AI
/// for generating a concise recap/commentary (NOT an analysis).
Map<String, dynamic> buildAiStoryExport(
  GameEngine engine, {
  int minWords = 250,
  int maxWords = 450,
}) {
  final snapshot = engine.exportStorySnapshot();
  final prompt = _buildGeminiRecapPrompt(
    minWords: minWords,
    maxWords: maxWords,
  );

  return <String, dynamic>{
    'schema': 'club_blackout.ai_story_export.v1',
    'exportedAt': DateTime.now().toIso8601String(),
    'geminiPastePrompt': prompt,
    'story': {
      'goal': 'Concise third-person recap/commentary (not a novel).',
      'tense': 'past',
      'voice': 'third_person',
      'wordCount': {'min': minWords, 'max': maxWords},
    },
    'game': snapshot.toJson(),
    'script': {
      'phase': engine.currentPhase.name,
      'dayCount': engine.dayCount,
      'currentIndex': engine.currentScriptIndex,
      'totalSteps': engine.scriptQueue.length,
      'steps':
          engine.scriptQueue.map((s) => s.toJson()).toList(growable: false),
    },
  };
}

String buildAiCommentaryPrompt({
  required AiCommentaryStyle style,
  required Map<String, dynamic> gameStatsExport,
}) {
  final jsonText = const JsonEncoder.withIndent('  ').convert(gameStatsExport);

  final styleRules = _styleRules(style);

  return [
    'You are an expert commentator analyzing a live session of the social deduction game “Club Blackout”.',
    '',
    '## Game Context (Club Blackout Lore)',
    '- **Setting**: A neon-lit nightclub where the lights go out, and murders happen.',
    '- **The Party (Good Team)**: Innocent clubgoers trying to identify the killers and vote them out during the Day.',
    '- **The Dealers (Evil Team)**: The hidden Mafia group who kill at Night and try to blend in during the Day.',
    '- **Mechanics**:',
    '  - **Night Phase**: Special roles use abilities (Murder, Save, Inspect, Block).',
    '  - **Day Phase**: Everyone discusses and votes to "bounce" (eliminate) one suspect.',
    '  - **Roles**: "The Whore" blocks players; "The Drama Queen" causes chaos (swaps roles) if eliminated; "The Tea Spiller" exposes a voter if eliminated; "The Lookout" inspects roles; "The Medic" saves lives.',
    '',
    '## Task',
    'Analyze the provided JSON game state and write a commentary/recap of the current situation.',
    '- Rely heavily on the "derived" stats, "voting" patterns, and "lastNight" events.',
    '- Identify who is controlling the vote (the "loudest" voices).',
    '- Highlight any ironies (e.g., a Medic saving a Killer, or the Village voting out their own best player).',
    '',
    '## Selected Persona & Style: ${style.label}',
    ...styleRules,
    '',
    '## Safety Guidelines (Strict)',
    '- No hate speech, slurs, or discrimination.',
    '- No sexual violence.',
    '- Keep the "violence" thematic to the game (e.g., "murdered in the VIP lounge", "dragged out by bouncers").',
    '',
    '## Output Format',
    '1. **The Vibe Check (Input)**: A short, punchy intro setting the mood based on the current Phase and Odds.',
    '2. **The Receipts (Timeline)**: Bullet points of the most recent critical events (Deaths, Saves, Key Votes).',
    '3. **The Tea (Analysis)**: Who is acting suspicious? Who is being a "sheep"? Who is making 200IQ plays?',
    '4. **The Odds**: Interpret the win probability. Is the Party doomed? Are the Dealers sweating?',
    '5. **Next Move**: One bold prediction for the next turn.',
    '',
    '## Game Data JSON',
    '```json',
    jsonText,
    '```',
  ].join('\n');
}

String buildGamesNightRecapPrompt({
  required AiCommentaryStyle style,
  required String gamesNightSessionJson,
}) {
  final styleRules = _styleRules(style);

  return [
    'You are the ultimate hype-caster writing a retrospective for a full "Games Night" session of Club Blackout.',
    '',
    '## Game Context',
    '- **Club Blackout**: A social deduction game (like Mafia/Werewolf) set in a nightclub.',
    '- **Teams**: The Party (Good) vs The Dealers (Evil) vs Neutrals.',
    '- **Goal**: Summarize the narrative arc of the entire evening across multiple matches.',
    '',
    '## Task',
    'Read the session JSON containing multiple game logs and stats.',
    '- Identify the MVPs (most wins, best plays).',
    '- Identify the "Feeder" (first to die, worst plays).',
    '- Spot rivalries: Players who constantly vote for or kill each other.',
    '- Track the "Meta": Did the group favor voting recklessly? Were the Dealers dominant?',
    '',
    '## Selected Persona & Style: ${style.label}',
    ...styleRules,
    '',
    '## Safety Guidelines (Strict)',
    '- No hate speech, slurs, or discrimination.',
    '- Keep it fun and competitive.',
    '',
    '## Output Format',
    '1. **Headline**: A catchy title for the night (e.g., "The Night of a Thousand Stabs").',
    '2. **Scorecard**: Who won the most? Which team dominated?',
    '3. **Hall of Fame / Shame**: Awards for Best Player, Worst Luck, Most Chaos, and Biggest Betrayal.',
    '4. **The Drama**: A narrative summary of the wildest moments.',
    '5. **Final Verdict**: A 1-10 rating of the group\'s skill level.',
    '',
    '## Session Data JSON',
    '```json',
    gamesNightSessionJson.trim(),
    '```',
  ].join('\n');
}

List<String> _styleRules(AiCommentaryStyle style) {
  switch (style) {
    case AiCommentaryStyle.pg:
      return const [
        '- **Tone**: Family-friendly, energetic Gameshow Host.',
        '- **Constraints**: No swearing, no crude humor. Keep it lighthearted and silly.',
        '- **Vocabulary**: Use words like "bounced", "eliminated", "oopsie", "shenanigans".',
      ];
    case AiCommentaryStyle.rude:
      return const [
        '- **Tone**: Sassy Reality TV Judge or Roast Comic.',
        '- **Constraints**: Mild swearing allowed (damn, hell, crap). No slurs.',
        '- **Behavior**: Be judgmental. Mock bad plays mercilessly. Call people "sheep" or "clowns" if they voted poorly.',
        '- **Flavor**: "Oh honey, that vote was a choice..."',
      ];
    case AiCommentaryStyle.hardR:
      return const [
        '- **Tone**: Gritty Crime Thriller or Uncensored Late-Night HBO.',
        '- **Constraints**: Strong language allowed (F-bombs, etc). NO HATE SPEECH/SLURS.',
        '- **Behavior**: High stakes, aggressive, intense. Emphasize the betrayal and the blood.',
        '- **Flavor**: "They brutally stabbed him in the back. Absolute carnage."',
      ];
  }
}
