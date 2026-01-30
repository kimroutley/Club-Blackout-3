import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'data/role_repository.dart';
import 'logic/game_engine.dart';
import 'logic/games_night_service.dart';
import 'ui/screens/main_screen.dart';
import 'ui/scroll_behavior.dart';
import 'ui/styles.dart';
import 'utils/game_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pixel 10 Pro Edge-to-Edge Design
  try {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    GameLogger.info('System UI initialized', context: 'Main');
  } catch (e, stackTrace) {
    GameLogger.error('System chrome initialization failed',
        context: 'Main', error: e, stackTrace: stackTrace);
  }

  try {
    await GamesNightService.instance.loadFromPrefs();
    GameLogger.info('Games Night session restored (if present)', context: 'Main');
  } catch (e, stackTrace) {
    GameLogger.error(
      'Games Night restore failed (continuing)',
      context: 'Main',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Request high refresh rate (120Hz+) if supported by device
  try {
    await FlutterDisplayMode.setHighRefreshRate();
    GameLogger.info('High refresh rate requested', context: 'Main');
  } catch (e) {
    GameLogger.error('Failed to set high refresh rate', context: 'Main', error: e);
  }

  runApp(const ClubBlackoutApp());
}

class ClubBlackoutApp extends StatefulWidget {
  const ClubBlackoutApp({super.key});

  @override
  State<ClubBlackoutApp> createState() => _ClubBlackoutAppState();
}

class _ClubBlackoutAppState extends State<ClubBlackoutApp> {
  final RoleRepository _roleRepo = RoleRepository();
  GameEngine? _engine;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      GameLogger.info('Init started', context: 'Main');
      await _roleRepo.loadRoles();
      GameLogger.info('Creating GameEngine', context: 'Main');
      setState(() => _engine = GameEngine(roleRepository: _roleRepo));
      GameLogger.info('Init complete', context: 'Main');
    } catch (e) {
      GameLogger.error('Init failed', context: 'Main', error: e);
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: ClubBlackoutTheme.neonPurple,
              brightness: Brightness.light,
            );

        final darkScheme = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: ClubBlackoutTheme.neonPurple,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Club Blackout',
          theme: ClubBlackoutTheme.createTheme(lightScheme),
          darkTheme: ClubBlackoutTheme.createTheme(darkScheme),
          themeMode: ThemeMode.dark,
          scrollBehavior: const ClubBlackoutScrollBehavior(),
          home: _error != null
              ? Scaffold(body: Center(child: Text('Init error: $_error')))
              : engine == null
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()))
                  : MainScreen(gameEngine: engine),
        );
      },
    );
  }
}
