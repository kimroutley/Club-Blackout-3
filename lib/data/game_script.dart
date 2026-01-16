import '../models/script_step.dart';

class GameScript {
  
  static const List<ScriptStep> intro = [
    ScriptStep(
      id: 'intro_party_time',
      title: 'PARTY TIME!',
      readAloudText: "IT'S PARTY TIME! The music is loud, the drinks are flowing, and the club is packed. Everyone, close your eyes and let the night take over.",
      instructionText: "Ensure everyone has their eyes closed. Transitioning immediately to setup or night actions.",
      isNight: true,
    ),
  ];

  static const List<ScriptStep> night1 = [
    ScriptStep(
      id: 'n1_murder_wake',
      title: '1. The Murder',
      readAloudText: "Dealers, open your eyes.\nWhore, open your eyes.\nWallflower, open your eyes.",
      instructionText: "Pause after each line.",
      roleId: 'dealer',
    ),
    ScriptStep(
      id: 'n1_murder_act',
      title: '1. The Murder',
      readAloudText: "Dealers, choose your victim.",
      instructionText: "Wait for them to point. Tap the chosen victim if playing with touch rules, or note it down.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'dealer',
    ),
    ScriptStep(
      id: 'n1_murder_sleep',
      title: '1. The Murder',
      readAloudText: "Dealers, Whore, and Wallflower, close your eyes.",
      instructionText: "",
    ),
    
    // Medic
    ScriptStep(
      id: 'n1_medic_wake',
      title: '2. The Medic',
      readAloudText: "Medic, open your eyes.\nDo you choose Option 1 (Revive later) or Option 2 (Protect daily)?",
      instructionText: "Wait for signal. Note down their choice.",
      roleId: 'medic',
    ),
    ScriptStep(
      id: 'n1_medic_act',
      title: '2. The Medic',
      readAloudText: "Please select a player if you wish to use your ability on them now.",
      instructionText: "Wait for point. Note it down.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'medic',
    ),
    ScriptStep(
      id: 'n1_medic_sleep',
      title: '2. The Medic',
      readAloudText: "Medic, close your eyes.",
      instructionText: "",
      roleId: 'medic',
    ),

    // Bouncer
    ScriptStep(
      id: 'n1_bouncer_wake',
      title: '3. The ID Check',
      readAloudText: "Bouncer and Ally Cat, open your eyes.",
      instructionText: "Wait.",
      roleId: 'bouncer',
    ),
    ScriptStep(
      id: 'n1_bouncer_act',
      title: '3. The ID Check',
      readAloudText: "Bouncer, select a player you'd like to I.D.",
      instructionText: "Wait for point. Nod your head if the target is a Dealer. Shake your head if they are not.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'bouncer',
    ),
    ScriptStep(
      id: 'n1_bouncer_sleep',
      title: '3. The ID Check',
      readAloudText: "Bouncer and Ally Cat, close your eyes.",
      instructionText: "",
      roleId: 'bouncer',
    ),

    // Lightweight
    ScriptStep(
      id: 'n1_lightweight_wake',
      title: '4. The Taboo Name',
      readAloudText: "Lightweight, open your eyes.",
      instructionText: "Wait.",
      roleId: 'lightweight',
    ),
    ScriptStep(
      id: 'n1_lightweight_act',
      title: '4. The Taboo Name',
      readAloudText: "Lightweight, look at the person I am pointing to. You can no longer call them by their name.",
      instructionText: "Point to one random player. Write down the taboo name.",
      actionType: ScriptActionType.selectPlayer, // Host selects purely for tracking
      roleId: 'lightweight',
    ),
    ScriptStep(
      id: 'n1_lightweight_sleep',
      title: '4. The Taboo Name',
      readAloudText: "Lightweight, close your eyes.",
      instructionText: "",
      roleId: 'lightweight',
    ),

    // Roofi
    ScriptStep(
      id: 'n1_roofi_wake',
      title: '5. The Roofi',
      readAloudText: "Roofi, open your eyes. Select a player to Roofi.",
      instructionText: "Wait for point.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'roofi',
    ),
    ScriptStep(
      id: 'n1_roofi_tap',
      title: '5. The Roofi',
      readAloudText: "You have been Roofi'd. You are paralyzed this round and cannot move or speak.",
      instructionText: "Tap the Roofi'd player on the shoulder.",
      roleId: 'roofi',
    ),
    ScriptStep(
      id: 'n1_roofi_sleep',
      title: '5. The Roofi',
      readAloudText: "Roofi, close your eyes.",
      instructionText: "",
      roleId: 'roofi',
    ),

    // Clinger
     ScriptStep(
      id: 'n1_clinger_wake',
      title: '6. The Obsession',
      readAloudText: "Clinger, open your eyes. Select the player you wish to be obsessed over.",
      instructionText: "Wait for point. Write down the partner.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'clinger',
    ),
    ScriptStep(
      id: 'n1_clinger_sleep',
      title: '6. The Obsession',
      readAloudText: "Clinger, close your eyes.",
      instructionText: "",
      roleId: 'clinger',
    ),

    // Manager
    ScriptStep(
      id: 'n1_manager_wake',
      title: '7. The Exposure',
      readAloudText: "Club Manager, open your eyes. Select a player to expose.",
      instructionText: "Wait for point.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'club_manager',
    ),
    ScriptStep(
      id: 'n1_manager_reveal',
      title: '7. The Exposure',
      readAloudText: "You have been selected. Keep your eyes closed, but hold your card up for 5 seconds.",
      instructionText: "Tap the selected player. Wait 5 seconds while Manager looks.",
      roleId: 'club_manager',
    ),
    ScriptStep(
      id: 'n1_manager_sleep',
      title: '7. The Exposure',
      readAloudText: "Club Manager, close your eyes.",
      instructionText: "",
       roleId: 'club_manager',
    ),

    // End Night
    ScriptStep(
      id: 'n1_wakeup',
      title: '8. Wake Up',
      readAloudText: "Everyone, open your eyes. The club is closed.",
      instructionText: "Announce who died. If someone was saved/protected, say 'There was no death last night.'",
      isNight: false,
    ),
  ];

  static const List<ScriptStep> day = [
    ScriptStep(
      id: 'day_discuss',
      title: '1. The Discussion',
      readAloudText: "You have [X] minutes to discuss.",
      instructionText: "Calculate Time: 30 seconds x Number of Players.",
      actionType: ScriptActionType.showTimer,
      isNight: false,
    ),
    ScriptStep(
      id: 'day_vote',
      title: '2. The Vote',
      readAloudText: "Time is up. I need a vote. Who do you believe is a Dealer?",
      instructionText: "Majority vote wins. The player is removed.",
      actionType: ScriptActionType.selectPlayer, // To execute
      isNight: false,
    ),
  ];

  static const List<ScriptStep> nightLoop = [
    ScriptStep(
      id: 'n_precheck',
      title: 'Pre-Night Check',
      readAloudText: "",
      instructionText: "Look for hands raised by The Sober or Silver Fox before starting.",
      isNight: true,
    ),
     ScriptStep(
      id: 'n_murder_wake',
      title: '1. The Murder',
      readAloudText: "Dealers, open your eyes.\nWhore, open your eyes.\nWallflower, open your eyes.",
      instructionText: "Pause after each line.",
      roleId: 'dealer',
    ),
    ScriptStep(
      id: 'n_murder_act',
      title: '1. The Murder',
      readAloudText: "Dealers, choose your victim.",
      instructionText: "Wait. Tap victim or note down.",
       actionType: ScriptActionType.selectPlayer,
      roleId: 'dealer',
    ),
    ScriptStep(
      id: 'n_murder_sleep',
      title: '1. The Murder',
      readAloudText: "Dealers, Whore, and Wallflower, close your eyes.",
      instructionText: "",
    ),

    // Medic
    ScriptStep(
      id: 'n_medic_wake',
      title: '2. The Medic',
      readAloudText: "Medic, open your eyes.\nSelect a player if you wish to use your ability.",
      instructionText: "Wait for point.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'medic',
    ),
    ScriptStep(
      id: 'n_medic_sleep',
      title: '2. The Medic',
      readAloudText: "Medic, close your eyes.",
      instructionText: "",
      roleId: 'medic',
    ),

    // Bouncer
    ScriptStep(
      id: 'n_bouncer_wake',
      title: '3. The ID Check',
      readAloudText: "Bouncer and Ally Cat, open your eyes.",
      instructionText: "Wait.",
      roleId: 'bouncer',
    ),
    ScriptStep(
      id: 'n_bouncer_act',
      title: '3. The ID Check',
      readAloudText: "Bouncer, select a player you'd like to I.D.",
      instructionText: "Wait. Nod/Shake Head.",
       actionType: ScriptActionType.selectPlayer,
      roleId: 'bouncer',
    ),
    ScriptStep(
      id: 'n_bouncer_sleep',
      title: '3. The ID Check',
      readAloudText: "Bouncer and Ally Cat, close your eyes.",
      instructionText: "",
      roleId: 'bouncer',
    ),

    // Lightweight
    ScriptStep(
      id: 'n_lightweight_wake',
      title: '4. The Taboo Name',
      readAloudText: "Lightweight, open your eyes.\nLightweight, look at the person I am pointing to. You can no longer call them by their name.",
      instructionText: "Point to a NEW player. Write down name.",
       actionType: ScriptActionType.selectPlayer,
      roleId: 'lightweight',
    ),
    ScriptStep(
      id: 'n_lightweight_sleep',
      title: '4. The Taboo Name',
      readAloudText: "Lightweight, close your eyes.",
      instructionText: "",
      roleId: 'lightweight',
    ),

    // Roofi
    ScriptStep(
      id: 'n_roofi_wake',
      title: '5. The Roofi',
      readAloudText: "Roofi, open your eyes. Select a player to Roofi.",
      instructionText: "Wait for point. Then tap the selected player and tell them they are paralyzed this round.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'roofi',
    ),
    ScriptStep(
      id: 'n_roofi_sleep',
      title: '5. The Roofi',
      readAloudText: "Roofi, close your eyes.",
      instructionText: "",
      roleId: 'roofi',
    ),

    // Manager
    ScriptStep(
      id: 'n_manager_wake',
      title: '6. The Exposure',
      readAloudText: "Club Manager, open your eyes. Select a player to expose.",
      instructionText: "Wait for point. Then tap the selected player and have them hold up their card for 5 seconds.",
      actionType: ScriptActionType.selectPlayer,
      roleId: 'club_manager',
    ),
    ScriptStep(
      id: 'n_manager_sleep',
      title: '6. The Exposure',
      readAloudText: "Club Manager, close your eyes.",
      instructionText: "",
      roleId: 'club_manager',
    ),

    // Wake
    ScriptStep(
      id: 'n_wakeup',
      title: '7. Wake Up',
      readAloudText: "Everyone, open your eyes. The club is closed.",
      instructionText: "Announce the death/survival.",
      isNight: false,
    ),
  ];
}
