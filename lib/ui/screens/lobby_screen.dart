import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Dev: from project root (pubspec.yaml), run:
//   flutter pub get
//   flutter devices
//   flutter run -d <deviceId>
//   flutter build apk --release  // -> build/app/outputs/flutter-apk/app-release.apk

import '../../logic/game_engine.dart';
import '../../models/role.dart';
import '../../models/player.dart';
import '../../utils/input_validator.dart';
import '../../utils/role_validator.dart';
import '../../utils/game_exceptions.dart';
import '../styles.dart';
import '../utils/player_sort.dart';
import '../widgets/role_assignment_dialog.dart';
import '../widgets/role_avatar_widget.dart';
import '../widgets/player_tile.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final GameEngine gameEngine;

  const LobbyScreen({super.key, required this.gameEngine});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _hostNameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Role? _selectedRole;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPreviousNamesExpanded = false;

  late final TabController _setupTabController;
  final Set<int> _visitedSetupTabs = {0};
  GameMode _selectedGameMode = GameMode.custom;

  @override
  void initState() {
    super.initState();
    widget.gameEngine.addListener(_onGameEngineChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _setupTabController = TabController(length: 3, vsync: this);
    _setupTabController.addListener(() {
      if (_setupTabController.indexIsChanging) return;
      if (_visitedSetupTabs.add(_setupTabController.index)) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.gameEngine.removeListener(_onGameEngineChanged);
    _hostNameController.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _setupTabController.dispose();
    super.dispose();
  }

  void _onGameEngineChanged() {
    if (mounted) setState(() {});
  }

  void _addPlayer({String? name}) {
    final playerName = (name ?? _nameController.text).trim();
    final validation = InputValidator.validatePlayerName(playerName);

    if (validation.isInvalid) {
      _showError(validation.error ?? 'Invalid name');
      return;
    }

    try {
      if (_selectedRole != null) {
        final roleValidation = RoleValidator.canAssignRole(
          _selectedRole,
          '',
          widget.gameEngine.players,
        );
        if (!roleValidation.isValid) {
          _showError(roleValidation.error!);
          return;
        }
      }

      widget.gameEngine.addPlayer(playerName, role: _selectedRole);
      _nameController.clear();
      setState(() => _selectedRole = null);
      HapticFeedback.lightImpact();

      // Auto-scroll to show the newly added guest
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } on GameException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString().replaceFirst('Invalid argument(s): ', ''));
    }
  }

  void _addHost() {
    final hostName = _hostNameController.text.trim();
    final validation = InputValidator.validatePlayerName(hostName);

    if (validation.isInvalid) {
      _showError(validation.error ?? 'Invalid name');
      return;
    }

    try {
      final hostRole = widget.gameEngine.roleRepository.roles.firstWhere(
        (r) => r.id == 'host',
        orElse: () => Role(
          id: 'host',
          name: 'Host',
          alliance: 'Neutral',
          type: 'Host',
          description: 'The Game Master',
          nightPriority: 0,
          assetPath: 'Icons/host.png',
          colorHex: '#FFFFFF',
        ),
      );

      widget.gameEngine.addPlayer(hostName, role: hostRole);
      _hostNameController.clear();
      HapticFeedback.mediumImpact();
    } on GameException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString().replaceFirst('Invalid argument(s): ', ''));
    }
  }

  Future<void> _createTestGame() async {
    try {
      // 1. Generate test data
      await widget.gameEngine.createTestGame();

      // 2. Validate setup generated (ensure min counts)
      final setupError = _validateRoleCompositionForGameStart();
      if (setupError != null) {
        // Test game generator should result in valid game, but just in case
        _showError("Test game generation failed: $setupError");
        return;
      }

      // 3. Start
      await widget.gameEngine.startGame();

      // 4. Go
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(gameEngine: widget.gameEngine),
        ),
      );
    } on GameException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    // Replaced Toast with Dialog for errors
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Input Error',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /* Unused method removed: _randomizePlayerRole */

  void _showHistoryDialog() => setState(() => _isPreviousNamesExpanded = true);
  void _closeHistoryDialog() =>
      setState(() => _isPreviousNamesExpanded = false);

  void _startGame() {
    try {
      final validation = InputValidator.validatePlayerCount(
        widget.gameEngine.players.length,
      );
      if (validation.isInvalid) {
        _showError(validation.error!);
        return;
      }

      HapticFeedback.heavyImpact();
      _showRoleAssignmentDialog(startAfterConfirm: true);
    } on GameException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to start game: $e');
    }
  }

  void _showRoleAssignmentDialog({required bool startAfterConfirm}) {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RoleAssignmentDialog(
        gameEngine: widget.gameEngine,
        players: widget.gameEngine.players,
        initialMode: _selectedGameMode,
        onConfirm: () async {
          navigator.pop();

          if (!startAfterConfirm) {
            if (mounted) setState(() {});
            return;
          }

          try {
            final setupError = _validateRoleCompositionForGameStart();
            if (setupError != null) {
              await _showInvalidSetupDialog(setupError);
              return;
            }
            widget.gameEngine.startGame();
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(gameEngine: widget.gameEngine),
              ),
            );
          } on GameException catch (e) {
            if (mounted) _showError(e.message);
          } catch (e) {
            if (mounted) _showError(e.toString());
          }
        },
        onCancel: () => navigator.pop(),
      ),
    );
  }

  String? _validateRoleCompositionForGameStart() {
    final validation = RoleValidator.validateGameSetup(
      widget.gameEngine.guests,
    );
    if (!validation.isValid) return validation.error ?? 'Setup invalid.';

    final counts = _roleCountsForSetup();
    if (counts.dealers > (counts.enabled - counts.dealers)) {
      return 'Dealers have majority (${counts.dealers}/${counts.enabled}). Remove some criminals.';
    }
    return null;
  }

  ({int enabled, int dealers, int partyAligned, int medics, int bouncers})
  _roleCountsForSetup() {
    final enabledPlayers = widget.gameEngine.guests
        .where((p) => p.isEnabled)
        .toList();
    int dealers = 0, partyAligned = 0, medics = 0, bouncers = 0;

    for (final p in enabledPlayers) {
      final r = p.role;
      final roleId = r.id.toLowerCase();
      if (roleId == 'dealer') dealers++;
      if (roleId == 'medic') medics++;
      if (roleId == 'bouncer') bouncers++;
      // Check alliance safely
      if (r.alliance.toLowerCase().contains('party') ||
          roleId.contains('party')) {
        partyAligned++;
      }
    }
    return (
      enabled: enabledPlayers.length,
      dealers: dealers,
      partyAligned: partyAligned,
      medics: medics,
      bouncers: bouncers,
    );
  }

  Future<void> _showInvalidSetupDialog(String message) async {
    final counts = _roleCountsForSetup();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ClubBlackoutTheme.neonRed),
        ),
        title: Text(
          'INVALID SETUP',
          style: TextStyle(
            color: ClubBlackoutTheme.neonRed,
            fontFamily: 'Hyperwave',
            fontSize: 28,
          ),
        ),
        content: Text(
          '$message\n\nDealers: ${counts.dealers}\nMedics: ${counts.medics}\nBouncers: ${counts.bouncers}',
          style: const TextStyle(color: Colors.white70),
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
              Navigator.pop(context);
              // Bypass validation and start game directly
              widget.gameEngine.startGame();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GameScreen(gameEngine: widget.gameEngine),
                ),
              );
            },
            style: ClubBlackoutTheme.neonButtonStyle(
              ClubBlackoutTheme.neonPink,
            ),
            child: const Text('PROCEED ANYWAY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPlayers = sortedPlayersByDisplayName(widget.gameEngine.players);
    Player? hostPlayer;
    try {
      hostPlayer = allPlayers.firstWhere((p) => p.role.id == 'host');
    } catch (_) {
      hostPlayer = null;
    }

    final players = allPlayers.where((p) => p.role.id != 'host').toList();
    final playerCount = players.length;
    // Updated max count as per request (allow up to 30)
    final minPlayers = 4;
    final canStart = playerCount >= minPlayers;
    final hostExists = hostPlayer != null;

    final setupTabsCompleted = _visitedSetupTabs.length == 3;

    return Stack(
      children: [
        // Club Wallpaper
        Positioned.fill(
          child: Image.asset(
            "Backgrounds/Club Blackout App Background.png",
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.black),
          ),
        ),

        // Main Interface
        Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: _isPreviousNamesExpanded
                  ? ClubBlackoutTheme.centeredConstrained(
                      maxWidth: 760,
                      child: _PreviousNamesPanel(
                        gameEngine: widget.gameEngine,
                        onAddPlayers: (names) {
                          _addPlayersBatch(names);
                          _closeHistoryDialog();
                        },
                        onClose: _closeHistoryDialog,
                      ),
                    )
                  : Column(
                      children: [
                        // Space for MainScreen AppBar (transparent) + a clean setup header
                        const SizedBox(height: 84),

                        // Setup Tabs
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClubBlackoutTheme.centeredConstrained(
                            maxWidth: 760,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: ClubBlackoutTheme.glassmorphism(
                                color: Colors.black,
                                borderColor: Colors.white10,
                                opacity: 0.28,
                                borderRadius: 18,
                              ),
                              child: TabBar(
                                controller: _setupTabController,
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: Colors.black,
                                unselectedLabelColor: Colors.white70,
                                indicator: BoxDecoration(
                                  color: ClubBlackoutTheme.neonBlue,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ClubBlackoutTheme.neonBlue
                                          .withOpacity(0.35),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                tabs: const [
                                  Tab(text: 'GUESTS'),
                                  Tab(text: 'STYLE'),
                                  Tab(text: 'ROLES'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: TabBarView(
                            controller: _setupTabController,
                            children: [
                              _buildGuestsTab(
                                hostPlayer: hostPlayer,
                                hostExists: hostExists,
                                players: players,
                                canStart: canStart,
                              ),
                              _buildStyleTab(),
                              _buildRolesTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),

        // Final Action
        if (!_isPreviousNamesExpanded && setupTabsCompleted)
          _buildStartButton(playerCount, minPlayers, canStart),
      ],
    );
  }

  Widget _buildGuestsTab({
    required Player? hostPlayer,
    required bool hostExists,
    required List<Player> players,
    required bool canStart,
  }) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        ClubBlackoutTheme.centeredConstrained(
          maxWidth: 760,
          child: Column(
            children: [
              // Test Game Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton.icon(
                  onPressed: _createTestGame,
                  icon: const Icon(Icons.bug_report, color: Colors.white38),
                  label: const Text(
                    'LOAD TEST GAME',
                    style: TextStyle(color: Colors.white38),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (!hostExists) _buildHostInputSection(),
              if (hostPlayer != null) ...[
                _buildHostVipCard(hostPlayer),
                const SizedBox(height: 12),
              ],
              _buildGuestInputSection(canStart),
              if (players.isNotEmpty) ...[
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people,
                        color: ClubBlackoutTheme.neonPink,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'GUEST LIST',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ClubBlackoutTheme.neonPink,
                          letterSpacing: 2,
                          shadows: ClubBlackoutTheme.textGlow(
                            ClubBlackoutTheme.neonPink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ...players.asMap().entries.map(
                (e) => _buildPlayerCard(e.value, e.key),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStyleTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        ClubBlackoutTheme.centeredConstrained(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSetupSectionHeader(
                title: 'GAME STYLE',
                subtitle:
                    'Choose a default role distribution style. You can still tweak roles in the next step.',
                icon: Icons.tune,
                color: ClubBlackoutTheme.neonOrange,
              ),
              const SizedBox(height: 16),
              _buildGameStyleOption(
                mode: GameMode.bloodbath,
                title: 'Bloodbath',
                description: 'High aggression. More Offensive roles.',
                icon: Icons.whatshot_rounded,
                color: ClubBlackoutTheme.neonRed,
              ),
              const SizedBox(height: 12),
              _buildGameStyleOption(
                mode: GameMode.politicalNightmare,
                title: 'Political Nightmare',
                description: 'High deception. More Defensive/Intel roles.',
                icon: Icons.psychology_rounded,
                color: ClubBlackoutTheme.neonPurple,
              ),
              const SizedBox(height: 12),
              _buildGameStyleOption(
                mode: GameMode.freeForAll,
                title: 'Free For All',
                description: 'Chaotic mix. Balanced randomness.',
                icon: Icons.casino_rounded,
                color: ClubBlackoutTheme.neonBlue,
              ),
              const SizedBox(height: 12),
              _buildGameStyleOption(
                mode: GameMode.custom,
                title: 'Custom',
                description: 'Manual control. You decide everything.',
                icon: Icons.handyman_rounded,
                color: ClubBlackoutTheme.neonGreen,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: ClubBlackoutTheme.glassmorphism(
                  color: Colors.black,
                  borderColor: Colors.white10,
                  opacity: 0.25,
                  borderRadius: 18,
                ),
                child: Text(
                  'Start is unlocked after you open all setup tabs (Guests → Style → Roles).',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRolesTab() {
    final allRoles =
        widget.gameEngine.roleRepository.roles
            .where((r) => r.id != 'host' && r.id != 'temp')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final setupError = _validateRoleCompositionForGameStart();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        ClubBlackoutTheme.centeredConstrained(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSetupSectionHeader(
                title: 'ROLES',
                subtitle:
                    'Preview the roster and optionally pre-assign roles before starting.',
                icon: Icons.badge,
                color: ClubBlackoutTheme.neonPink,
              ),
              const SizedBox(height: 12),
              if (setupError == null)
                _buildStatusBanner(
                  text: 'Current setup looks valid (based on assigned roles).',
                  color: ClubBlackoutTheme.neonGreen,
                  icon: Icons.check_circle_rounded,
                )
              else
                _buildStatusBanner(
                  text: setupError,
                  color: ClubBlackoutTheme.neonOrange,
                  icon: Icons.warning_amber_rounded,
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showRoleAssignmentDialog(startAfterConfirm: false);
                },
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('ASSIGN / EDIT ROLES'),
                style: ClubBlackoutTheme.neonButtonStyle(
                  ClubBlackoutTheme.neonPink,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: ClubBlackoutTheme.glassmorphism(
                  color: Colors.black,
                  borderColor: Colors.white10,
                  opacity: 0.25,
                  borderRadius: 18,
                ),
                child: Text(
                  'Quick requirements: Dealer, Party Animal, Wallflower, and Medic and/or Bouncer. Dealers must not start with majority.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ROLE GALLERY',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: allRoles.length,
                itemBuilder: (context, index) {
                  final role = allRoles[index];
                  return InkWell(
                    onTap: () => _showRolePreview(role),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: role.color.withOpacity(0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RoleAvatarWidget(role: role, size: 52),
                          const SizedBox(height: 10),
                          Text(
                            role.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.8,
                    shadows: ClubBlackoutTheme.textGlow(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStyleOption({
    required GameMode mode,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedGameMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _selectedGameMode = mode);
        HapticFeedback.selectionClick();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.18),
                border: Border.all(color: color.withOpacity(0.6)),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      shadows: isSelected
                          ? ClubBlackoutTheme.textGlow(color)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? color : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  void _showRolePreview(Role role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: role.color.withOpacity(0.6), width: 2),
        ),
        title: Text(
          role.name.toUpperCase(),
          style: TextStyle(
            color: role.color,
            fontFamily: 'Hyperwave',
            fontSize: 26,
            shadows: ClubBlackoutTheme.textGlow(role.color),
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleAvatarWidget(role: role, size: 72),
              const SizedBox(height: 16),
              Text(
                role.description,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
                textAlign: TextAlign.center,
              ),
              if (role.ability != null && role.ability!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  role.ability!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildHostInputSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFF9933).withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9933).withOpacity(0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Color(0xFFFF9933), size: 32),
              const SizedBox(width: 12),
              Text(
                'HOST SETUP',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9933),
                  letterSpacing: 2,
                  shadows: ClubBlackoutTheme.textGlow(const Color(0xFFFF9933)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostNameController,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Enter Host Name...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(
                Icons.person_outline,
                color: Color(0xFFFF9933),
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.arrow_circle_right,
                  color: Color(0xFFFF9933),
                  size: 36,
                ),
                tooltip: 'Add Host',
                onPressed: _addHost,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: const Color(0xFFFF9933).withOpacity(0.3),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFFF9933)),
              ),
            ),
            onSubmitted: (_) => _addHost(),
          ),
        ],
      ),
    );
  }

  Widget _buildHostVipCard(Player host) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ClubBlackoutTheme.neonOrange.withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ClubBlackoutTheme.neonOrange.withOpacity(0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
        gradient: LinearGradient(
          colors: [
            ClubBlackoutTheme.neonOrange.withOpacity(0.12),
            Colors.black.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ClubBlackoutTheme.neonOrange, width: 2),
              boxShadow: ClubBlackoutTheme.boxGlow(
                ClubBlackoutTheme.neonOrange,
                intensity: 0.8,
              ),
            ),
            child: const Icon(
              Icons.stars,
              color: ClubBlackoutTheme.neonOrange,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  host.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VIP Host',
                  style: TextStyle(
                    color: ClubBlackoutTheme.neonOrange,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Chip(
            backgroundColor: ClubBlackoutTheme.neonOrange.withOpacity(0.15),
            label: Text(
              'Not counted as guest',
              style: TextStyle(
                color: ClubBlackoutTheme.neonOrange,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            side: BorderSide(
              color: ClubBlackoutTheme.neonOrange.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestInputSection(bool canStart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ClubBlackoutTheme.cardDecoration(
        glowColor: ClubBlackoutTheme.neonBlue,
        glowIntensity: canStart ? 1.2 : 0.6,
        borderRadius: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRoleDropdown(),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Guest Name',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(
                Icons.person_add,
                color: ClubBlackoutTheme.neonBlue,
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: ClubBlackoutTheme.neonBlue,
                  size: 36,
                ),
                tooltip: 'Add Guest',
                onPressed: () => _addPlayer(),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) => _addPlayer(),
          ),
          const Divider(color: Colors.white12, height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _showHistoryDialog,
              icon: const Icon(Icons.history, color: Colors.white38, size: 18),
              label: const Text(
                'PREVIOUS NAMES',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    final availableRoles = RoleValidator.getAvailableRoles(
      widget.gameEngine.roleRepository.roles,
      'new_player',
      widget.gameEngine.guests,
    );

    final allOptions = <DropdownMenuEntry<Role?>>[
      DropdownMenuEntry<Role?>(value: null, label: 'Random Role'),
      ...availableRoles.map(
        (role) => DropdownMenuEntry<Role?>(value: role, label: role.name),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<Role?>(
          initialSelection: _selectedRole,
          hintText: 'Assign Role (Optional)',
          dropdownMenuEntries: allOptions,
          onSelected: (v) => setState(() => _selectedRole = v),
          width: constraints.maxWidth,
          inputDecorationTheme: InputDecorationTheme(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _selectedRole?.color.withOpacity(0.5) ?? Colors.white12,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _selectedRole?.color.withOpacity(0.5) ?? Colors.white12,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _selectedRole?.color ?? Colors.white,
                width: 2,
              ),
            ),
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.grey[900]),
            surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(Player player, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(player.id),
        onDismissed: (_) {
          HapticFeedback.lightImpact();
          widget.gameEngine.removePlayer(player.id);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_forever, color: Colors.white70),
        ),
        child: PlayerTile(
          player: player,
          gameEngine: widget.gameEngine,
          onTap: player.role.id == 'host'
              ? null
              : () => _editPlayerRole(player.id, player.role),
        ),
      ),
    );
  }

  Widget _buildStartButton(int playerCount, int minPlayers, bool canStart) {
    // Calculate progress (clamped 0.0 - 1.0)
    final double progress = (playerCount / minPlayers).clamp(0.0, 1.0);
    // Determine status color
    final Color statusColor = canStart
        ? ClubBlackoutTheme.neonGreen
        : ClubBlackoutTheme.neonPink;

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: canStart ? _pulseAnimation.value : 1.0,
              child: GestureDetector(
                onTap: canStart
                    ? () {
                        HapticFeedback.lightImpact();
                        _startGame();
                      }
                    : null,
                child: Container(
                  height: 70,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(35),
                    border: Border.all(
                      color: canStart ? statusColor : Colors.white10,
                      width: 2,
                    ),
                    boxShadow: canStart
                        ? [
                            BoxShadow(
                              color: statusColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      33,
                    ), // Slightly less than container
                    child: Stack(
                      children: [
                        // Animated Progress Bar Background
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          width:
                              MediaQuery.of(context).size.width *
                              progress, // Fills based on progress
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: canStart
                                  ? [
                                      ClubBlackoutTheme.neonPink,
                                      ClubBlackoutTheme.neonPurple,
                                    ] // Start active colors
                                  : [
                                      statusColor.withOpacity(0.1),
                                      statusColor.withOpacity(0.05),
                                    ], // Waiting colors
                            ),
                          ),
                        ),

                        // Text Content
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  canStart
                                      ? Icons.play_arrow
                                      : Icons.person_add,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8), // Reduced gap
                                Flexible(
                                  child: Text(
                                    canStart
                                        ? "START GAME"
                                        : "ROSTER STATUS ($playerCount/$minPlayers)",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16, // Reduced font size
                                      fontWeight: FontWeight.bold,
                                      letterSpacing:
                                          1.5, // Reduced letter spacing
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addPlayersBatch(List<String> names) {
    if (names.isEmpty) return;
    int added = 0;
    for (final name in names) {
      if (!widget.gameEngine.players.any(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
      )) {
        widget.gameEngine.addPlayer(name);
        added++;
      }
    }
    if (added > 0) {
      // Toast removed
      HapticFeedback.mediumImpact();
    }
  }

  void _editPlayerRole(String playerId, Role? currentRole) {
    Role? tempSelected = currentRole;
    final availableRoles = RoleValidator.getAvailableRoles(
      widget.gameEngine.roleRepository.roles,
      playerId,
      widget.gameEngine.players,
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: ClubBlackoutTheme.neonPink, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ASSIGN ROLE",
                  style: TextStyle(
                    color: ClubBlackoutTheme.neonPink,
                    fontSize: 28,
                    fontFamily: 'Hyperwave',
                    shadows: ClubBlackoutTheme.textGlow(
                      ClubBlackoutTheme.neonPink,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildRoleTile(
                        null,
                        tempSelected == null,
                        () => setDialogState(() => tempSelected = null),
                      ),
                      ...availableRoles.map(
                        (role) => _buildRoleTile(
                          role,
                          tempSelected?.id == role.id,
                          () => setDialogState(() => tempSelected = role),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "CANCEL",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: ClubBlackoutTheme.neonButtonStyle(
                          ClubBlackoutTheme.neonPink,
                        ),
                        onPressed: () {
                          widget.gameEngine.updatePlayerRole(
                            playerId,
                            tempSelected,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text("SAVE"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTile(Role? role, bool isSelected, VoidCallback onTap) {
    final color = role?.color ?? Colors.white54;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? color : Colors.transparent),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
            boxShadow: isSelected
                ? ClubBlackoutTheme.circleGlow(color, intensity: 0.6)
                : null,
          ),
          child: Center(
            child: Icon(
              role == null ? Icons.casino : Icons.person,
              color: color,
              size: 16,
            ),
          ),
        ),
        title: Text(
          role?.name.toUpperCase() ?? "RANDOM ROLE",
          style: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: color, size: 20)
            : null,
      ),
    );
  }
}

class _PreviousNamesPanel extends StatefulWidget {
  final GameEngine gameEngine;
  final Function(List<String>) onAddPlayers;
  final VoidCallback onClose;

  const _PreviousNamesPanel({
    required this.gameEngine,
    required this.onAddPlayers,
    required this.onClose,
  });

  @override
  State<_PreviousNamesPanel> createState() => _PreviousNamesPanelState();
}

class _PreviousNamesPanelState extends State<_PreviousNamesPanel> {
  final Set<String> _selectedNames = {};
  final TextEditingController _searchController = TextEditingController();

  void _toggleSelectAll(List<String> visibleNames) {
    setState(() {
      if (_selectedNames.containsAll(visibleNames)) {
        _selectedNames.removeAll(visibleNames);
      } else {
        _selectedNames.addAll(visibleNames);
      }
    });
  }

  void _deleteSelected() {
    if (_selectedNames.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Names?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove ${_selectedNames.length} names from history?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              widget.gameEngine.removeNamesFromHistory(_selectedNames.toList());
              setState(() => _selectedNames.clear());
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.gameEngine.nameHistory.toList()..sort();
    final filtered = history
        .where(
          (n) => n.toLowerCase().contains(_searchController.text.toLowerCase()),
        )
        .toList();
    final allSelected =
        filtered.isNotEmpty && _selectedNames.containsAll(filtered);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: ClubBlackoutTheme.neonBlue.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ClubBlackoutTheme.neonBlue.withOpacity(0.1),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.history,
                color: ClubBlackoutTheme.neonBlue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PREVIOUS GUESTS',
                  style: TextStyle(
                    color: ClubBlackoutTheme.neonBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: ClubBlackoutTheme.textGlow(
                      ClubBlackoutTheme.neonBlue,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white54),
                tooltip: 'Close History',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search history...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: ClubBlackoutTheme.neonBlue,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: filtered.isEmpty
                    ? null
                    : () => _toggleSelectAll(filtered),
                icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                tooltip: allSelected ? 'Deselect All' : 'Select All',
              ),
              IconButton.filledTonal(
                onPressed: _selectedNames.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                ),
                tooltip: 'Delete Selected',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final name = filtered[index];
                final isSelected = _selectedNames.contains(name);
                final alreadyAdded = widget.gameEngine.players.any(
                  (p) => p.name.toLowerCase() == name.toLowerCase(),
                );

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: alreadyAdded
                      ? null
                      : (v) => setState(
                          () => v!
                              ? _selectedNames.add(name)
                              : _selectedNames.remove(name),
                        ),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: alreadyAdded ? Colors.white24 : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  activeColor: ClubBlackoutTheme.neonBlue,
                  checkColor: Colors.black,
                  subtitle: alreadyAdded
                      ? const Text(
                          'ALREADY IN THE CLUB',
                          style: TextStyle(
                            color: Colors.white12,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: _selectedNames.isEmpty
                  ? null
                  : () => widget.onAddPlayers(_selectedNames.toList()),
              style:
                  ClubBlackoutTheme.neonButtonStyle(
                    ClubBlackoutTheme.neonBlue,
                  ).copyWith(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
              child: const Text(
                'ADD SELECTED GUESTS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
