import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logic/game_engine.dart';
import 'data/role_repository.dart';
import 'ui/styles.dart';
import 'ui/screens/main_screen.dart';
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

  final roleRepository = RoleRepository();
  try {
    await roleRepository.loadRoles();
    GameLogger.info('Loaded ${roleRepository.roles.length} roles', context: 'Main');
  } catch (e, stackTrace) {
    GameLogger.error('Failed to load roles', 
        context: 'Main', error: e, stackTrace: stackTrace);
    // Continue with empty roles - app will use temp roles
  }

  final gameEngine = GameEngine(roleRepository: roleRepository);
  GameLogger.info('Game engine initialized', context: 'Main');

  runApp(ClubBlackoutApp(gameEngine: gameEngine));
}

class ClubBlackoutApp extends StatelessWidget {
  final GameEngine gameEngine;

  const ClubBlackoutApp({super.key, required this.gameEngine});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Club Blackout',
          theme: ClubBlackoutTheme.createTheme(darkDynamic),
          darkTheme: ClubBlackoutTheme.createTheme(darkDynamic),
          themeMode: ThemeMode.dark,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
            scrollbars: false,
          ),
          home: MainScreen(gameEngine: gameEngine),
        );
      },
    );
  }
}
