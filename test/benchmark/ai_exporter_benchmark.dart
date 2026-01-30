// ignore_for_file: avoid_print

import 'package:club_blackout/logic/ai_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Benchmark buildAiCommentaryPrompt', () async {
    // 1. Generate a large dummy data structure
    final Map<String, dynamic> largeStats = {
      'game': {
        'id': 'test_game',
        'players': List.generate(
            20,
            (i) => {
                  'id': 'player_$i',
                  'name': 'Player $i',
                  'role': 'Villager',
                  'isAlive': i % 2 == 0,
                }),
        'log': List.generate(
            1000,
            (i) => {
                  'type': 'vote',
                  'day': i ~/ 10,
                  'message':
                      'Player ${i % 20} voted for Player ${(i + 1) % 20}',
                }),
      },
      'derived': {
        'complexStats': List.generate(
            500,
            (i) => {
                  'stat': 'stat_$i',
                  'value': i * 3.14,
                  'history': List.generate(50, (j) => j),
                }),
      }
    };

    // 2. Measure execution time
    final stopwatch = Stopwatch()..start();

    final result = await buildAiCommentaryPrompt(
      style: AiCommentaryStyle.rude,
      gameStatsExport: largeStats,
    );

    stopwatch.stop();

    print('Execution time: ${stopwatch.elapsedMilliseconds} ms');
    print('Result length: ${result.length}');
  });
}
