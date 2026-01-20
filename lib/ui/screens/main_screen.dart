import 'package:flutter/material.dart';
import '../../logic/game_engine.dart';
import '../screens/home_screen.dart';
import '../screens/lobby_screen.dart';
import '../screens/guides_screen.dart';
import '../widgets/game_drawer.dart';
import '../styles.dart';

class MainScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const MainScreen({super.key, required this.gameEngine});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

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
    String title = 'CLUB BLACKOUT';
    Color titleColor = ClubBlackoutTheme.neonBlue;

    switch (_selectedIndex) {
      case 1:
        title = 'GUEST LIST';
        titleColor = ClubBlackoutTheme.neonPink;
        break;
      case 2:
        title = 'GUIDES';
        titleColor = ClubBlackoutTheme.neonOrange;
        break;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Hyperwave',
            fontSize: 29,
            color: titleColor,
            shadows: ClubBlackoutTheme.textGlow(titleColor),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
      ),
      drawer: GameDrawer(
        gameEngine: widget.gameEngine,
        onNavigate: _onItemTapped,
        selectedIndex: _selectedIndex,
      ),
      body: _getPage(_selectedIndex),
    );
  }
}
