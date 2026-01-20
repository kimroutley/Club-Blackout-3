import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../../logic/game_engine.dart';
import '../../logic/game_state.dart';
import '../../utils/app_version.dart';
import '../screens/game_screen.dart';
import '../screens/host_overview_screen.dart';
import '../styles.dart';
import 'package:intl/intl.dart';

class GameDrawer extends StatelessWidget {
  final int selectedIndex;
  final GameEngine? gameEngine;
  final Function(int) onNavigate;
  final VoidCallback? onGameLogTap;

  const GameDrawer({
    super.key,
    this.selectedIndex = 0,
    this.gameEngine,
    required this.onNavigate,
    this.onGameLogTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Background with blur
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        const Color(0xFF0a0a0a).withOpacity(0.9),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                    border: Border(
                      right: BorderSide(
                        color: ClubBlackoutTheme.neonBlue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: ClubBlackoutTheme.neonPink.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        ClubBlackoutTheme.neonPink.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ClubBlackoutTheme.neonPink,
                                width: 2,
                              ),
                              boxShadow: ClubBlackoutTheme.circleGlow(
                                ClubBlackoutTheme.neonPink,
                              ),
                            ),
                            child: ClipOval(
                              /*child: Image.asset(
                                'Icons/Club Blackout App BLACK icon.png',
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) => Icon(
                                  Icons.shield,
                                  color: ClubBlackoutTheme.neonPink,
                                  size: 28,
                                ),
                              ),*/
                              child: Icon(
                                Icons.nightlife,
                                color: ClubBlackoutTheme.neonPink,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'CLUB\nBLACKOUT',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                  color: ClubBlackoutTheme.neonPink,
                                  shadows: ClubBlackoutTheme.textGlow(
                                    ClubBlackoutTheme.neonPink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (gameEngine != null &&
                          gameEngine!.players.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: ClubBlackoutTheme.neonBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ClubBlackoutTheme.neonBlue.withOpacity(
                                0.5,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                color: ClubBlackoutTheme.neonBlue,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${gameEngine!.players.length} Players',
                                  style: TextStyle(
                                    color: ClubBlackoutTheme.neonBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today,
                                color: ClubBlackoutTheme.neonGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${gameEngine!.currentPhase == GamePhase.day ? "Day" : "Night"} ${gameEngine!.dayCount}',
                                  style: TextStyle(
                                    color: ClubBlackoutTheme.neonGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Navigation items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _buildNavItem(
                        context: context,
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'Home',
                        color: ClubBlackoutTheme.neonBlue,
                        isSelected: selectedIndex == 0,
                        onTap: () {
                          Navigator.pop(context);
                          onNavigate(0);
                        },
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people,
                        label: 'Lobby',
                        color: ClubBlackoutTheme.neonPink,
                        isSelected: selectedIndex == 1,
                        onTap: () {
                          Navigator.pop(context);
                          onNavigate(1);
                        },
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.style_outlined,
                        selectedIcon: Icons.style,
                        label: 'Guides',
                        color: ClubBlackoutTheme.neonOrange,
                        isSelected: selectedIndex == 2,
                        onTap: () {
                          Navigator.pop(context);
                          onNavigate(2);
                        },
                      ),

                      // Game Log navigation item
                      if (gameEngine != null && onGameLogTap != null)
                        _buildActionItem(
                          context: context,
                          icon: Icons.receipt_long,
                          label: 'Game Log',
                          color: ClubBlackoutTheme.neonBlue,
                          onTap: () {
                            Navigator.pop(context);
                            onGameLogTap!();
                          },
                        ),

                      // Host Overview navigation item
                      if (gameEngine != null)
                        _buildActionItem(
                          context: context,
                          icon: Icons.visibility,
                          label: 'Host Overview',
                          color: ClubBlackoutTheme.neonGreen,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    HostOverviewScreen(gameEngine: gameEngine!),
                              ),
                            );
                          },
                        ),

                      // Game controls section
                      if (gameEngine != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: Row(
                            children: [
                              Container(
                                height: 1.5,
                                width: 30,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      ClubBlackoutTheme.neonGreen.withOpacity(
                                        0.5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'GAME CONTROLS',
                                style: TextStyle(
                                  color: ClubBlackoutTheme.neonGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 1.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        ClubBlackoutTheme.neonGreen.withOpacity(
                                          0.5,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _buildActionItem(
                          context: context,
                          icon: Icons.play_arrow,
                          label: 'Resume Game',
                          color: ClubBlackoutTheme.neonGreen,
                          onTap: () {
                            Navigator.pop(context);
                            if (gameEngine!.players.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GameScreen(gameEngine: gameEngine!),
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.black,
                                  title: const Text(
                                    'No Active Game',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'Start a new game from the Lobby.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                        _buildActionItem(
                          context: context,
                          icon: Icons.save,
                          label: 'Save Game',
                          color: ClubBlackoutTheme.neonBlue,
                          onTap: () async {
                            Navigator.pop(context);
                            await _showSaveGameDialog(context);
                          },
                        ),
                        _buildActionItem(
                          context: context,
                          icon: Icons.file_upload,
                          label: 'Load Game',
                          color: const Color(0xFF9D4EDD),
                          onTap: () async {
                            Navigator.pop(context);
                            await _showLoadGameDialog(context);
                          },
                        ),
                        _buildActionItem(
                          context: context,
                          icon: Icons.restart_alt,
                          label: 'New Game / Reset',
                          color: Colors.amber,
                          onTap: () {
                            _showResetConfirmation(context);
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Footer - Clickable Version
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showChangelog(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: ClubBlackoutTheme.neonBlue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: ClubBlackoutTheme.neonBlue.withOpacity(0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Club Blackout v${AppVersion.version}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ClubBlackoutTheme.neonBlue.withOpacity(0.5),
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: ClubBlackoutTheme.neonBlue.withOpacity(0.3),
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
              )
            : null,
        border: isSelected
            ? Border.all(color: color.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : Colors.white.withOpacity(0.1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected ? color : Colors.white70,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : Colors.white70,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color.withOpacity(0.5),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Reset Game?',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will end the current game and return to the home screen. All unsaved progress will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () {
              gameEngine!.resetGame();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close drawer
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                Colors.amber.withOpacity(0.2),
              ),
              foregroundColor: MaterialStateProperty.all(Colors.amber),
              side: MaterialStateProperty.all(
                const BorderSide(color: Colors.amber, width: 1.5),
              ),
            ),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  void _showChangelog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'CHANGELOG',
          style: ClubBlackoutTheme.headingStyle.copyWith(
            color: ClubBlackoutTheme.neonBlue,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: const [
              Text(
                '- **v1.2.0 (Jan 2026)**: Interactive Gameplay Script, Enhanced Lobby UI.',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                '- **v1.1.0 (Dec 2025)**: Added Messy Bitch & Clinger Abilities, Game Log, Save/Load Feature (Beta).',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 12),
              Text(
                '- **v1.0.0 (Nov 2025)**: Initial Release with core game mechanics and 10+ roles.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CLOSE',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveGameDialog(BuildContext context) async {
    final gameEngine =
        this.gameEngine; // Use a local variable to avoid nullable checks
    if (gameEngine == null) return;

    String saveName = '';
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'SAVE GAME',
          style: ClubBlackoutTheme.headingStyle.copyWith(
            color: ClubBlackoutTheme.neonBlue,
          ),
        ),
        content: TextField(
          controller: controller,
          onChanged: (value) => saveName = value,
          decoration: InputDecoration(
            hintText: 'Enter save name',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: ClubBlackoutTheme.neonBlue.withOpacity(0.5),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: ClubBlackoutTheme.neonBlue),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ClubBlackoutTheme.neonBlue,
            ),
            onPressed: () async {
              if (saveName.isNotEmpty) {
                await gameEngine.saveGame(saveName);
                if (context.mounted) {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact(); // Feedback
                }
              }
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoadGameDialog(BuildContext context) async {
    final gameEngine = this.gameEngine;
    if (gameEngine == null) return;

    final saves = await gameEngine.getSavedGames();
    saves.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'LOAD GAME',
          style: ClubBlackoutTheme.headingStyle.copyWith(
            color: ClubBlackoutTheme.neonPurple,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: saves.isEmpty
              ? Center(
                  child: Text(
                    'No saved games found.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: saves.length,
                  itemBuilder: (context, index) {
                    final save = saves[index];
                    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
                    final dateStr = dateFormat.format(save.savedAt);

                    return Dismissible(
                      key: Key(save.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) async {
                        await gameEngine.deleteSavedGame(save.id);
                        if (context.mounted) {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          _showLoadGameDialog(context);
                        }
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        color: Colors.black.withOpacity(0.7),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            save.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${save.alivePlayers}/${save.totalPlayers} Players Alive - Day ${save.dayCount} (${save.currentPhase})',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: ClubBlackoutTheme.neonPurple,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            final loaded = await gameEngine.loadGame(save.id);
                            if (context.mounted && loaded) {
                              HapticFeedback.mediumImpact();
                              if (ModalRoute.of(context)?.settings.name !=
                                  '/game') {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GameScreen(gameEngine: gameEngine),
                                    settings: const RouteSettings(
                                      name: '/game',
                                    ),
                                  ),
                                );
                              }
                            } else if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.black,
                                  title: const Text(
                                    'Error',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  content: const Text(
                                    'Failed to load game data.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          // TEST GAME BUTTON (Hidden in Load Game Menu)
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              HapticFeedback.heavyImpact();
              await gameEngine.createTestGame(fullRoster: true);

              if (context.mounted) {
                // Return to lobby to see the new roster
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
              }
            },
            child: Text(
              'TEST',
              style: TextStyle(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CLOSE',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }
}
