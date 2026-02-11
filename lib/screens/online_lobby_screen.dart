import 'dart:async';
import 'package:flutter/material.dart';
import '../services/game_room_service.dart';
import '../services/auth_service.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'bot_game_screen.dart';
import 'online_game_screen.dart';
import 'profile_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen>
    with SingleTickerProviderStateMixin {
  final _gameRoomService = GameRoomService();
  final _authService = AuthService();

  // Lobby state
  int _waitingPlayerCount = 0;
  Timer? _countTimer;

  // Matchmaking state
  bool _isSearching = false;
  GameRoom? _waitingRoom;
  StreamSubscription<GameRoom>? _roomSubscription;
  Timer? _searchTimer;
  int _searchElapsed = 0; // seconds spent searching
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _refreshPlayerCount();
    // Poll player count every 3 seconds
    _countTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshPlayerCount();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countTimer?.cancel();
    _searchTimer?.cancel();
    _roomSubscription?.cancel();
    // Clean up waiting room if we leave while searching
    if (_waitingRoom != null) {
      _gameRoomService.leaveRoom(_waitingRoom!.id);
    }
    super.dispose();
  }

  Future<void> _refreshPlayerCount() async {
    try {
      final count = await _gameRoomService.getWaitingPlayerCount();
      if (mounted) setState(() => _waitingPlayerCount = count);
    } catch (_) {}
  }

  Future<void> _startQuickMatch() async {
    setState(() {
      _isSearching = true;
      _searchElapsed = 0;
    });

    // Tick the search timer for the UI
    _searchTimer?.cancel();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _searchElapsed++);
    });

    try {
      final result = await _gameRoomService.quickMatch(
        avoidOpponentId: _gameRoomService.lastOpponentId,
      );

      if (!mounted) return;

      // Check for bot match first
      if (result.isBotMatch) {
        _cleanupSearch(cancelRoom: false);
        _navigateToBotGame(result);
        return;
      }

      if (result.isMatched && result.room != null) {
        // Matched immediately — go to game
        _cleanupSearch(cancelRoom: false);
        _navigateToGame(result.room!, isHost: false);
        return;
      }

      if (result.isWaiting && result.room != null) {
        // We created a room — wait for opponent
        setState(() => _waitingRoom = result.room);
        _listenForOpponent(result.room!.id);
        return;
      }

      // Error
      _cleanupSearch(cancelRoom: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppStyles.errorSnackBar(result.message ?? 'Matchmaking failed'),
        );
      }
    } catch (e) {
      _cleanupSearch(cancelRoom: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(AppStyles.errorSnackBar('Error: $e'));
      }
    }
  }

  void _listenForOpponent(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _gameRoomService
        .subscribeToRoom(roomId)
        .listen(
          (room) {
            if (room.isPlaying && mounted) {
              _cleanupSearch(cancelRoom: false);
              _navigateToGame(room, isHost: true);
            }
          },
          onError: (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(AppStyles.errorSnackBar('Connection error: $e'));
            }
          },
        );
  }

  void _cancelSearch() {
    _cleanupSearch(cancelRoom: true);
  }

  void _cleanupSearch({required bool cancelRoom}) {
    _searchTimer?.cancel();
    _searchTimer = null;
    _roomSubscription?.cancel();
    _roomSubscription = null;
    if (cancelRoom && _waitingRoom != null) {
      _gameRoomService.leaveRoom(_waitingRoom!.id);
    }
    if (mounted) {
      setState(() {
        _isSearching = false;
        _waitingRoom = null;
        _searchElapsed = 0;
      });
    }
  }

  void _navigateToGame(GameRoom room, {required bool isHost}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OnlineGameScreen(room: room, isHost: isHost),
      ),
    );
  }

  void _navigateToBotGame(QuickMatchResult result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BotGameScreen(
          botId: result.botId!,
          botUsername: result.botUsername!,
          botRank: result.botRank,
          botDifficulty: result.botDifficulty ?? 'medium',
        ),
      ),
    );
  }

  String _formatSearchTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = _authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppStyles.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppStyles.burgundy.withValues(alpha: 0.8),
        elevation: 0,
        foregroundColor: AppStyles.cream,
        iconTheme: const IconThemeData(color: AppStyles.cream),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            tooltip: 'Profile',
          ),
        ],
      ),
      drawer: const GameDrawer(showGameControls: false),
      body: Stack(
        children: [
          // Tavern background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tavern.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Parchment overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage(
                  'assets/DD Grunge Texture 90878_DD-Grunge-Texture-90878-Preview.jpg',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.7),
                  BlendMode.dstIn,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isSearching
                        ? _buildSearchingView()
                        : _buildLobbyView(userEmail),
                  ),
                ),
                const AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyView(String userEmail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppStyles.cream.withValues(alpha: 0.9),
        ),
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Online Play', style: AppStyles.headingLarge),
            const SizedBox(height: 10),
            Text(
              'Signed in as $userEmail',
              style: const TextStyle(
                color: AppStyles.textSecondary,
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),

            // Players online indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppStyles.darkBrown.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppStyles.darkBrown.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _waitingPlayerCount > 0
                          ? AppStyles.green
                          : AppStyles.darkBrown.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _waitingPlayerCount == 0
                        ? 'No players waiting'
                        : _waitingPlayerCount == 1
                        ? '1 player waiting'
                        : '$_waitingPlayerCount players waiting',
                    style: const TextStyle(
                      color: AppStyles.darkBrown,
                      fontFamily: AppStyles.fontBody,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Quick Match button
            SizedBox(
              width: 220,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startQuickMatch,
                icon: const Icon(Icons.flash_on, size: 22),
                label: const Text('Quick Match', style: AppStyles.buttonText),
                style: AppStyles.primaryButtonStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppStyles.cream.withValues(alpha: 0.9),
        ),
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Finding Opponent', style: AppStyles.headingLarge),
            const SizedBox(height: 40),

            // Animated searching indicator
            FadeTransition(
              opacity: Tween<double>(
                begin: 0.4,
                end: 1.0,
              ).animate(_pulseController),
              child: const Icon(
                Icons.person_search,
                color: AppStyles.darkBrown,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),

            // Search time
            Text(
              'Searching... ${_formatSearchTime(_searchElapsed)}',
              style: const TextStyle(
                color: AppStyles.darkBrown,
                fontFamily: AppStyles.fontBody,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _waitingRoom != null
                  ? 'Waiting for another player to join'
                  : 'Looking for available opponents',
              style: TextStyle(
                color: AppStyles.textSecondary.withValues(alpha: 0.7),
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),

            // Cancel button
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _cancelSearch,
                style: AppStyles.primaryButtonStyle,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
