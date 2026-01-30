import 'package:flutter/material.dart';

import '../../logic/game_engine.dart';
import '../screens/game_screen.dart';
import '../screens/games_night_screen.dart';
import '../screens/guides_screen.dart';
import '../screens/home_screen.dart';
import '../screens/host_overview_screen.dart';
import '../screens/lobby_screen.dart';
import '../widgets/game_drawer.dart';

class MainScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const MainScreen({super.key, required this.gameEngine});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _hasPeeked = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Peek the drawer after a short delay on first entry
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _selectedIndex == 0 && !_hasPeeked) {
        _triggerPeek();
      }
    });
  }

  void _triggerPeek() {
    _scaffoldKey.currentState?.openDrawer();
    _hasPeeked = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Navigator.of(context).pop(); // Close the drawer - and handle navigation
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          gameEngine: widget.gameEngine,
          onNavigateToLobby: () => _onItemTapped(1),
          onNavigateToGuides: () => _onItemTapped(2),
        );
      case 1:
        return LobbyScreen(gameEngine: widget.gameEngine);
      case 2:
        return GuidesScreen(gameEngine: widget.gameEngine);
      case 3:
        return const GamesNightScreen();
      default:
        return HomeScreen(
          gameEngine: widget.gameEngine,
          onNavigateToLobby: () => _onItemTapped(1),
          onNavigateToGuides: () => _onItemTapped(2),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNight = widget.gameEngine.currentPhase == GamePhase.night;
    // GuidesScreen (index 2) and LobbyScreen (index 1) provide their own AppBars.
    final hideAppBar = isNight || _selectedIndex == 1 || _selectedIndex == 2;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: !isNight,
      appBar: hideAppBar
          ? null
          : AppBar(
              title: null,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: cs.onSurface, size: 26),
            ),
      drawer: GameDrawer(
        gameEngine: widget.gameEngine,
        onContinueGameTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GameScreen(gameEngine: widget.gameEngine),
            ),
          );
        },
        onHostDashboardTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HostOverviewScreen(gameEngine: widget.gameEngine),
            ),
          );
        },
        onNavigate: _onItemTapped,
        selectedIndex: _selectedIndex,
      ),
      body: _getPage(_selectedIndex),
    );
  }
}
