import 'dart:io';

Future<void> main(List<String> args) async {
  final quality = _readIntArg(args, '--quality') ?? 85;
  final deletePng = args.contains('--delete-png');

  final cwebp = await _findCwebp();
  if (cwebp == null) {
    stderr.writeln(
        'ERROR: Could not find cwebp.exe on PATH or in WinGet packages.');
    stderr.writeln('Install it with: winget install -e --id Google.Libwebp');
    exitCode = 1;
    return;
  }

  final pngAssets = <String>[
    'Backgrounds/Club Blackout App Background.png',
    'Backgrounds/Club Blackout Home Menu Screen CORRECT.png',
    'Icons/Icon-No text-Ally Cat-Lemon.png',
    'Icons/Icon-No text-Bartender-Indigo.png',
    'Icons/Icon-No text-Bouncer-Blue.png',
    'Icons/Icon-No text-Clinger-Yellow.png',
    'Icons/Icon-No text-Club Manager-Taupe.png',
    'Icons/Icon-No text-Creep-Purple.png',
    'Icons/Icon-No text-Dealer-Fuschia.png',
    'Icons/Icon-No text-Drama Queen-Navy.png',
    'Icons/Icon-No text-Lightweight-Orange.png',
    'Icons/Icon-No text-Medic-Red.png',
    'Icons/Icon-No text-Messy Bitch-Lavender.png',
    'Icons/Icon-No text-Minor-White.png',
    'Icons/Icon-No text-Party Animal-Peach.png',
    'Icons/Icon-No text-Predator-Grey.png',
    'Icons/Icon-No text-Roofi-Green.png',
    'Icons/Icon-No text-Seasoned Drinker-Mint.png',
    'Icons/Icon-No text-Second Wind-Cherry.png',
    'Icons/Icon-No text-Silver Fox-Olive.png',
    'Icons/Icon-No text-Sober-Lime.png',
    'Icons/Icon-No text-Tea Spiller-Gold.png',
    'Icons/Icon-No text-Wallflower-Pink.png',
    'Icons/Icon-No text-Whore-Teal.png',
  ];

  stdout.writeln('Using cwebp: $cwebp');
  stdout.writeln('Converting ${pngAssets.length} PNG assets to WebP...');
  stdout.writeln('quality=$quality deletePng=$deletePng');

  var converted = 0;
  var skipped = 0;

  for (final rel in pngAssets) {
    final input = File(rel);
    if (!input.existsSync()) {
      stderr.writeln('MISSING: $rel');
      skipped++;
      continue;
    }

    final outPath =
        rel.replaceAll(RegExp(r'\.png$', caseSensitive: false), '.webp');
    final output = File(outPath);

    if (output.existsSync() &&
        output.lastModifiedSync().isAfter(input.lastModifiedSync())) {
      stdout.writeln('SKIP (up-to-date): $rel');
      skipped++;
      continue;
    }

    final result = await Process.run(
      cwebp,
      [
        '-quiet',
        '-q',
        '$quality',
        '-m',
        '6',
        '-alpha_q',
        '100',
        input.path,
        '-o',
        output.path,
      ],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      stderr.writeln('FAILED: $rel');
      stderr.writeln(result.stderr);
      skipped++;
      continue;
    }

    final inMb = input.lengthSync() / (1024 * 1024);
    final outMb = output.lengthSync() / (1024 * 1024);
    final pct = inMb <= 0 ? 0 : (100 * (1 - (outMb / inMb)));
    stdout.writeln(
        'OK  ${_fmtMb(inMb)} -> ${_fmtMb(outMb)}  (${pct.toStringAsFixed(1)}% smaller)  $rel');

    if (deletePng) {
      input.deleteSync();
    }

    converted++;
  }

  stdout.writeln('Done. converted=$converted skipped=$skipped');
}

Future<String?> _findCwebp() async {
  final envOverride = Platform.environment['CWEBP_PATH'];
  if (envOverride != null && envOverride.trim().isNotEmpty) {
    final f = File(envOverride.trim());
    if (f.existsSync()) return f.path;
  }

  // Try PATH first.
  try {
    final where =
        await Process.run('where.exe', ['cwebp.exe'], runInShell: true);
    if (where.exitCode == 0) {
      final lines = (where.stdout as String).trim().split(RegExp(r'\r?\n'));
      final first =
          lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      if (first.isNotEmpty && File(first).existsSync()) return first;
    }
  } catch (_) {
    // ignore
  }

  // Fallback: WinGet packages location.
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null) return null;
  final base = Directory('$localAppData\\Microsoft\\WinGet\\Packages');
  if (!base.existsSync()) return null;

  final matches = <File>[];
  for (final entity in base.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.toLowerCase().endsWith('\\cwebp.exe')) {
      matches.add(entity);
    }
  }
  if (matches.isEmpty) return null;

  matches.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return matches.first.path;
}

int? _readIntArg(List<String> args, String name) {
  final idx = args.indexOf(name);
  if (idx == -1) return null;
  if (idx + 1 >= args.length) return null;
  return int.tryParse(args[idx + 1]);
}

String _fmtMb(double mb) => '${mb.toStringAsFixed(2)}MB';
