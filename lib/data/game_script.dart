import '../models/script_step.dart';

class GameScript {
  static const List<ScriptStep> intro = [
    ScriptStep(
      id: 'intro_party_time',
      title: 'Start',
      readAloudText:
          "Read aloud: It's party time. The music is loud, the drinks are flowing, and the club is packed.\n\nEveryone, close your eyes.\nHeads down. Don't lose your head... yet.\nNo peeking!",
      instructionText:
          'Host: Wait for 10-15 seconds of silence. Transition immediately to setup or night actions.\n\nVoice: Deep, clear, and authoritative.\nPacing: Slow down. Silence creates tension.',
      isNight: true,
    ),
  ];
}
