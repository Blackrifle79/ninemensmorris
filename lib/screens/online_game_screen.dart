import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/game_score.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../services/audio_service.dart';
import '../services/game_room_service.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/scoring_service.dart';
import '../utils/app_styles.dart';
import '../utils/constants.dart';
import '../widgets/game_board.dart';
import '../widgets/game_drawer.dart';
import '../widgets/game_status.dart';
import '../widgets/piece_counter.dart';
import 'game_result_screen.dart';
import 'profile_screen.dart';

class OnlineGameScreen extends StatefulWidget {
  final GameRoom room;
  final bool isHost;

  const OnlineGameScreen({super.key, required this.room, required this.isHost});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final _gameRoomService = GameRoomService();
  final AudioService _audioService = AudioService();
  late StreamSubscription<GameRoom> _roomSubscription;
  late GameRoom _room;

  // Game state
  final GameModel _gameModel = GameModel();
  bool _waitingForCapture = false;
  bool _isMyTurn = false;

  // Color assignment: randomized when the host creates the game
  PieceType _hostColor = PieceType.white;

  // Track whether *this* player initiated the leave so we don't
  // accidentally show the "opponent left" dialog to ourselves.
  bool _isLeavingRoom = false;

  // Track whether the game has ended (timeout, forfeit, etc.) so UI
  // can skip the "are you sure?" confirmation on leave.
  bool _gameIsOver = false;

  // Prevent multiple dialogs from stacking
  bool _dialogShowing = false;

  // Scoring
  final ScoringService _scoringService = ScoringService();
  GameScore? _myGameScore;
  GameScore? _opponentGameScore;
  double? _myOldRating;
  double? _myNewRating;
  int? _myNewRank;

  // Move tracking and timer (20 seconds per move)
  final List<Map<String, dynamic>> _moveHistory = [];
  DateTime? _turnStartedAt;
  Timer? _moveTimer;
  double _remainingSeconds = 20.0;
  bool _timerActive = false;

  void _startTurnTimer() {
    _moveTimer?.cancel();
    _turnStartedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _timerActive = true;
        _remainingSeconds = 20.0;
      });
    }
    _moveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) {
        _moveTimer?.cancel();
        _moveTimer = null;
        return;
      }
      if (_turnStartedAt == null) return;
      final elapsed =
          DateTime.now().difference(_turnStartedAt!).inMilliseconds / 1000.0;
      final remaining = (20.0 - elapsed).clamp(0.0, 20.0);
      setState(() => _remainingSeconds = remaining);
      if (remaining <= 0) {
        _moveTimer?.cancel();
        _moveTimer = null;
        _handleTimeout();
      }
    });
  }

  void _stopTurnTimer() {
    _moveTimer?.cancel();
    _moveTimer = null;
    _turnStartedAt = null;
    if (mounted) {
      setState(() {
        _remainingSeconds = 20.0;
        _timerActive = false;
      });
    }
  }

  void _recordMove({
    required String type,
    Position? from,
    Position? to,
    bool capture = false,
  }) {
    final auth = AuthService();
    final userId = auth.currentUser?.id ?? 'unknown';
    final now = DateTime.now();
    final durationMs = _turnStartedAt != null
        ? now.difference(_turnStartedAt!).inMilliseconds
        : 0;

    _moveHistory.add({
      'player_id': userId,
      'type': type,
      'from': from?.toString(),
      'to': to?.toString(),
      'duration_ms': durationMs,
      'capture': capture,
      'timestamp': now.toIso8601String(),
    });

    // Reset turn timer for next player
    _turnStartedAt = now;

    // Reset warning state when moves happen (especially after captures)
    _drawWarningShown = false;
  }

  Future<void> _handleTimeout() async {
    // Guard: only handle timeout if it's actually my turn and game is still playing
    if (_gameIsOver ||
        !_isMyTurn ||
        _gameModel.gameState == GameState.gameOver) {
      _stopTurnTimer();
      return;
    }

    // I timed out, so my opponent wins
    final opponentId = widget.isHost ? _room.guestId : _room.hostId;
    // Double-check: opponent ID must exist
    if (opponentId == null) return;

    _stopTurnTimer();
    _gameIsOver = true;
    _dialogShowing = true; // Block subscription from showing wrong dialog
    await _computeGameSummaryAndReport(opponentId);
    if (mounted) {
      _showTimeoutForfeitDialog();
    }
  }

  void _showTimeoutForfeitDialog() {
    if (!mounted) return;
    // _dialogShowing already set by _handleTimeout before the async call

    final myName = widget.isHost
        ? _room.hostUsername
        : (_room.guestUsername ?? 'You');
    final opponentName = widget.isHost
        ? (_room.guestUsername ?? 'Opponent')
        : _room.hostUsername;

    final score =
        _myGameScore ??
        GameScore(
          outcome: 'loss',
          piecesRemaining: 0,
          opponentPiecesRemaining: 0,
          terminationReason: 'timeout',
        );

    // Track opponent for matchmaking variety
    final opponentId = widget.isHost ? _room.guestId : _room.hostId;
    _gameRoomService.setLastOpponent(opponentId);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameResultScreen(
          score: score,
          playerName: myName,
          opponentScore: _opponentGameScore,
          opponentName: opponentName,
          showNewGameButton: false,
          winnerColor: _myPieceType == PieceType.white
              ? 'black'
              : 'white', // opponent wins timeout
          oldRating: _myOldRating,
          newRating: _myNewRating,
          oldRank: _myRank,
          newRank: _myNewRank,
          onBackToMenu: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _computeGameSummaryAndReport(String? winnerId) async {
    final auth = AuthService();
    final myId = auth.currentUser?.id ?? '';
    final opponentId = widget.isHost ? _room.guestId : _room.hostId;
    final bool isDraw = winnerId == null;
    final String? terminationReason = _gameModel.terminationReason;
    final terminationDetails = _gameModel.getTerminationDetails();

    // Count pieces on the board for each player
    int myPieces = 0;
    int oppPieces = 0;
    for (final entry in _gameModel.board.entries) {
      if (entry.value.type == _myPieceType) {
        myPieces++;
      } else {
        oppPieces++;
      }
    }

    // Count moves per player from history
    int myMoveCount = 0;
    int oppMoveCount = 0;
    for (final m in _moveHistory) {
      final pid = m['player_id'] as String;
      if (pid == myId) {
        myMoveCount++;
      } else {
        oppMoveCount++;
      }
    }

    // Fetch current ratings for both players
    final myScores = await _scoringService.getPlayerScores(myId);
    final oppScores = opponentId != null
        ? await _scoringService.getPlayerScores(opponentId)
        : {'avg_score': 50.0};

    final myRating = (myScores['avg_score'] as double?) ?? 50.0;
    final oppRating = (oppScores['avg_score'] as double?) ?? 50.0;

    // Compute game scores for both players
    _myGameScore = _scoringService.computeScore(
      playerId: myId,
      winnerId: winnerId,
      isDraw: isDraw,
      playerPiecesRemaining: myPieces,
      opponentPiecesRemaining: oppPieces,
      playerRating: myRating,
      opponentRating: oppRating,
      isOnline: true,
      totalMoves: myMoveCount,
      terminationReason: terminationReason,
    );

    if (opponentId != null) {
      _opponentGameScore = _scoringService.computeScore(
        playerId: opponentId,
        winnerId: winnerId,
        isDraw: isDraw,
        playerPiecesRemaining: oppPieces,
        opponentPiecesRemaining: myPieces,
        playerRating: oppRating,
        opponentRating: myRating,
        isOnline: true,
        totalMoves: oppMoveCount,
        terminationReason: terminationReason,
      );
    }

    // Get usernames for leaderboard
    String myUsername = widget.isHost
        ? _room.hostUsername
        : (_room.guestUsername ?? 'Player');
    String oppUsername = widget.isHost
        ? (_room.guestUsername ?? 'Guest')
        : _room.hostUsername;

    // Record scores to leaderboard and capture rating changes
    if (_myGameScore != null) {
      final ratingResult = await _scoringService.recordScore(
        playerId: myId,
        username: myUsername,
        score: _myGameScore!,
        isOnline: true,
      );
      _myOldRating = ratingResult['oldRating'];
      _myNewRating = ratingResult['newRating'];
      
      // Get new ranking
      final rankResult = await LeaderboardService().getPlayerRanking(myId);
      _myNewRank = rankResult['rank'];
    }
    if (_opponentGameScore != null && opponentId != null) {
      await _scoringService.recordScore(
        playerId: opponentId,
        username: oppUsername,
        score: _opponentGameScore!,
        isOnline: true,
      );
    }

    // Also persist legacy game summary to game_rooms
    final Map<String, Map<String, dynamic>> perPlayer = {};
    for (final m in _moveHistory) {
      final pid = m['player_id'] as String;
      final duration = (m['duration_ms'] as int?) ?? 0;
      perPlayer.putIfAbsent(
        pid,
        () => {'moves': 0, 'total_time_ms': 0, 'captures': 0},
      );
      perPlayer[pid]!['moves'] = (perPlayer[pid]!['moves'] as int) + 1;
      perPlayer[pid]!['total_time_ms'] =
          (perPlayer[pid]!['total_time_ms'] as int) + duration;
      if (m['capture'] == true) {
        perPlayer[pid]!['captures'] = (perPlayer[pid]!['captures'] as int) + 1;
      }
    }

    // Add computed scores to summary
    if (_myGameScore != null) {
      perPlayer.putIfAbsent(
        myId,
        () => {'moves': 0, 'total_time_ms': 0, 'captures': 0},
      );
      perPlayer[myId]!['game_score'] = _myGameScore!.totalScore;
      perPlayer[myId]!['winner'] = winnerId == myId;
    }
    if (opponentId != null && _opponentGameScore != null) {
      perPlayer.putIfAbsent(
        opponentId,
        () => {'moves': 0, 'total_time_ms': 0, 'captures': 0},
      );
      perPlayer[opponentId]!['game_score'] = _opponentGameScore!.totalScore;
      perPlayer[opponentId]!['winner'] = winnerId == opponentId;
    }

    final gameSummary = {
      'per_player': perPlayer,
      'moves': _moveHistory,
      'is_draw': isDraw,
      'termination_reason': terminationReason,
      'termination_details': terminationDetails,
    };

    await _gameRoomService.endGame(
      _room.id,
      winnerId,
      gameSummary: gameSummary,
    );
  }

  // Mill highlight state
  Set<Position>? _millHighlight;
  Position? _captureHighlight;
  bool _highlightingMill = false;

  // Sync tracking to prevent race conditions
  bool _isSyncing = false;

  // Debounce timer to prevent rapid state updates from causing visual glitches
  Timer? _debounceTimer;
  GameRoom? _pendingRoom;
  static const _debounceMs = 100; // Wait 100ms for state to settle

  // Player ranks (fetched on init)
  int? _myRank;
  int? _opponentRank;

  // Draw warning tracking
  bool _drawWarningShown = false;
  int _lastNoCaptureMoves = 0;
  Map<String, int> _lastStateOccurrences = {};

  // My piece color: determined by hostColor assignment
  PieceType get _myPieceType {
    if (widget.isHost) return _hostColor;
    return _hostColor == PieceType.white ? PieceType.black : PieceType.white;
  }

  /// Show mill highlight then transition to capture mode
  void _showMillHighlight(Position millPosition) {
    final millPositions = _gameModel.findFormedMill(millPosition);
    setState(() {
      _millHighlight = millPositions;
      _highlightingMill = true;
    });

    // Brief pause to show the mill, then allow capture (keep highlight visible)
    Future.delayed(GameConstants.millHighlightDuration, () {
      if (mounted) {
        setState(() {
          // Keep _millHighlight visible - don't clear it
          _highlightingMill = false;
          _waitingForCapture = true;
        });
        _syncGameState();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _subscribeToRoom();

    // Load existing game state if any, otherwise initialize fresh game
    if (_room.gameState != null && _room.gameState!.isNotEmpty) {
      _gameModel.loadFromJson(_room.gameState!);
      _waitingForCapture =
          _room.gameState!['waitingForCapture'] as bool? ?? false;
      // Read the host color assignment from the game state
      final hostColorStr = _room.gameState!['hostColor'] as String?;
      if (hostColorStr != null) {
        _hostColor = hostColorStr == 'white'
            ? PieceType.white
            : PieceType.black;
      }
      // If a turn start timestamp exists, pick it up
      final meta = _room.gameState!['meta'] as Map<String, dynamic>?;
      if (meta != null && meta['turn_started_at'] != null) {
        try {
          _turnStartedAt = DateTime.parse(meta['turn_started_at']);
        } catch (_) {
          _turnStartedAt = DateTime.now();
        }
      }
    } else {
      // Host initializes the game with a random color assignment
      if (widget.isHost) {
        _hostColor = Random().nextBool() ? PieceType.white : PieceType.black;
      }
      _turnStartedAt = DateTime.now();
      _syncGameState();
    }
    _isMyTurn = _gameModel.currentPlayer == _myPieceType;
    // Always start the timer for whoever is white (always goes first)
    // and ensure it ticks immediately when the screen loads
    if (_isMyTurn) {
      _turnStartedAt = _turnStartedAt ?? DateTime.now();
      _startTurnTimer();
    }

    // Fetch ranks asynchronously (non-blocking)
    _fetchPlayerRanks();
  }

  Future<void> _fetchPlayerRanks() async {
    try {
      final lbService = LeaderboardService();
      final myId = AuthService().currentUser!.id;
      final opponentId = widget.isHost ? _room.guestId : _room.hostId;

      final myRanking = await lbService.getPlayerRanking(myId);
      Map<String, dynamic>? oppRanking;
      if (opponentId != null) {
        oppRanking = await lbService.getPlayerRanking(opponentId);
      }

      if (mounted) {
        setState(() {
          _myRank = myRanking['rank'] as int?;
          _opponentRank = oppRanking?['rank'] as int?;
        });
      }
    } catch (_) {
      // Non-critical — silently ignore
    }
  }

  void _subscribeToRoom() {
    _roomSubscription = _gameRoomService.subscribeToRoom(_room.id).listen((
      room,
    ) {
      // Skip if room is finished but we just started (stale data)
      if (room.isFinished &&
          _gameModel.whitePiecesToPlace == 9 &&
          _gameModel.blackPiecesToPlace == 9) {
        return;
      }

      // Skip updates while we're actively syncing to prevent race conditions
      if (_isSyncing) {
        return;
      }

      // Debounce rapid updates - store pending room and process after delay
      // This prevents visual glitches when realtime + polling fire together
      _pendingRoom = room;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
        if (!mounted || _pendingRoom == null) return;
        _applyRoomUpdate(_pendingRoom!);
        _pendingRoom = null;
      });
    });
  }

  void _applyRoomUpdate(GameRoom room) {
    final newGameState = room.gameState;
    if (newGameState != null && newGameState.isNotEmpty) {
      // Snapshot old state for diffing (detect opponent moves)
      final oldBoard = Map<Position, Piece>.from(_gameModel.board);
      final bool oldWaitingForCapture = _waitingForCapture;

      // Always apply server state - trust the server as the source of truth
      setState(() {
        _gameModel.loadFromJson(newGameState);
        _waitingForCapture =
            newGameState['waitingForCapture'] as bool? ?? false;
        // Read host color from server state
        final hostColorStr = newGameState['hostColor'] as String?;
        if (hostColorStr != null) {
          _hostColor = hostColorStr == 'white'
              ? PieceType.white
              : PieceType.black;
        }

        // Recalculate whose turn it is based on server state
        _isMyTurn = _gameModel.currentPlayer == _myPieceType;

        // Parse meta (turn start and move history) if present
        final meta = newGameState['meta'] as Map<String, dynamic>?;
        if (meta != null) {
          final tsa = meta['turn_started_at'] as String?;
          if (tsa != null) {
            try {
              _turnStartedAt = DateTime.parse(tsa);
            } catch (_) {
              // If parse fails and it's my turn, ensure we have a start time
              if (_isMyTurn) _turnStartedAt ??= DateTime.now();
            }
          } else if (_isMyTurn) {
            // No turn_started_at in meta but it's my turn — start fresh
            _turnStartedAt ??= DateTime.now();
          }
        } else if (_isMyTurn) {
          // No meta at all (very first sync) — ensure timer can start
          _turnStartedAt ??= DateTime.now();
        }

        if (meta != null) {
          final mh = meta['move_history'] as List<dynamic>?;
          if (mh != null) {
            _moveHistory.clear();
            for (final item in mh) {
              if (item is Map<String, dynamic>) {
                _moveHistory.add(item);
              } else if (item is Map) {
                _moveHistory.add(Map<String, dynamic>.from(item));
              }
            }
          }
        }

        // Start/stop timer depending on whose turn it is
        if (_gameIsOver) {
          _stopTurnTimer();
        } else if (_isMyTurn) {
          _startTurnTimer();
        } else {
          _stopTurnTimer();
        }

        // Check for draw warnings (no-capture or repetition) and show a snackbar
        _maybeShowDrawWarnings();
      });

      // --- Detect opponent moves and play sounds / show highlights ---
      _handleRemoteBoardChange(oldBoard, oldWaitingForCapture);
    }

    _room = room;

    // Detect opponent forfeit (room finished but game wasn't over locally).
    // Skip if *we* are the one who triggered the leave or timeout.
    if (room.isFinished &&
        _gameModel.gameState != GameState.gameOver &&
        !_isLeavingRoom &&
        !_gameIsOver) {
      _stopTurnTimer();
      _showOpponentLeftDialog(room.winnerId);
      return;
    }

    if (room.isFinished && _gameModel.gameState == GameState.gameOver) {
      // Derive winner from game state (more reliable than room.winnerId
      // which may be null due to FK constraints on bot IDs)
      String? winnerId;
      if (_gameModel.winner == null) {
        winnerId = null; // draw
      } else {
        final winnerIsHost = _gameModel.winner == _hostColor;
        winnerId = winnerIsHost ? _room.hostId : _room.guestId;
      }
      // Ensure scores AND ratings are computed before showing dialog
      if (_myGameScore == null || _myOldRating == null) {
        _computeGameSummaryAndReport(winnerId).then((_) {
          if (mounted && !_dialogShowing) _showGameOverDialog();
        });
      } else {
        _showGameOverDialog();
      }
    }
  }

  /// Detect changes from a remote state update and play sound effects /
  /// show the appropriate mill / capture highlights locally.
  void _handleRemoteBoardChange(
    Map<Position, Piece> oldBoard,
    bool oldWaitingForCapture,
  ) {
    final newBoard = _gameModel.board;

    // Find pieces that were added (placed or moved-to)
    final List<Position> added = [];
    for (final pos in newBoard.keys) {
      if (!oldBoard.containsKey(pos)) {
        added.add(pos);
      }
    }

    // Find pieces that were removed (moved-from or captured)
    final List<Position> removed = [];
    for (final pos in oldBoard.keys) {
      if (!newBoard.containsKey(pos)) {
        removed.add(pos);
      }
    }

    // No board change at all — skip
    if (added.isEmpty && removed.isEmpty) return;

    // Play piece sound for any new or removed piece
    _audioService.playPieceSound();

    // --- Compute highlights locally ---

    // Case 1: Opponent formed a mill (waitingForCapture just turned on)
    // The opponent placed/moved and now it's still their turn to capture.
    if (_waitingForCapture && !oldWaitingForCapture && added.isNotEmpty) {
      // The added position is where the mill was formed
      final millPos = added.first;
      final millPositions = _gameModel.findFormedMill(millPos);
      if (millPositions.isNotEmpty) {
        setState(() {
          _millHighlight = millPositions;
          _highlightingMill = true;
        });
        // After a brief pause, clear the highlight. The capture will come
        // as a separate state update from the opponent.
        Future.delayed(GameConstants.millHighlightDuration, () {
          if (mounted) {
            setState(() {
              _highlightingMill = false;
            });
          }
        });
      }
      return;
    }

    // Case 2: Opponent just captured (waitingForCapture went from true to false
    // and a piece was removed)
    if (!_waitingForCapture && oldWaitingForCapture && removed.isNotEmpty) {
      // Show a brief red highlight on the captured position
      final capturedPos = removed.first;
      setState(() {
        _captureHighlight = capturedPos;
        _millHighlight = null; // Clear mill highlight after capture
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _captureHighlight = null;
          });
        }
      });
      return;
    }

    // Case 3: Normal place/move by opponent (no mill) — clear any stale highlights
    if (!_waitingForCapture) {
      setState(() {
        _millHighlight = null;
        _captureHighlight = null;
        _highlightingMill = false;
      });
    }
  }

  Future<void> _syncGameState() async {
    final gameState = _gameModel.toJson();
    gameState['waitingForCapture'] = _waitingForCapture;
    // Always include host color assignment so both sides stay in sync
    gameState['hostColor'] = _hostColor == PieceType.white ? 'white' : 'black';

    // Include move meta (turn start + move history)
    gameState['meta'] = gameState['meta'] ?? {};
    if (_turnStartedAt != null) {
      gameState['meta']['turn_started_at'] = _turnStartedAt!.toIso8601String();
    }
    gameState['meta']['move_history'] = _moveHistory;

    debugPrint(
      'Syncing game state: currentPlayer=${gameState['currentPlayer']}',
    );

    _isSyncing = true;

    try {
      await _gameRoomService.updateGameState(_room.id, gameState);
      debugPrint('Game state synced successfully');
      // Always reload the latest state from server after syncing
      await _forceReloadRoom();
    } catch (e) {
      debugPrint('Error syncing game state: $e');
    } finally {
      // Small delay to allow server to process before accepting updates
      await Future.delayed(const Duration(milliseconds: 300));
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _moveTimer?.cancel();
    _moveTimer = null;
    _roomSubscription.cancel();
    super.dispose();
  }

  void _showGameOverDialog() {
    if (!mounted || _dialogShowing) return;
    _dialogShowing = true;

    final myUsername = widget.isHost
        ? _room.hostUsername
        : (_room.guestUsername ?? 'You');
    final oppUsername = widget.isHost
        ? (_room.guestUsername ?? 'Guest')
        : _room.hostUsername;

    // If we don't have scores, create a default one
    final score =
        _myGameScore ??
        GameScore(
          outcome: _room.winnerId == null
              ? 'draw'
              : ((widget.isHost && _room.winnerId == _room.hostId) ||
                    (!widget.isHost && _room.winnerId == _room.guestId))
              ? 'win'
              : 'loss',
          piecesRemaining: 0,
          opponentPiecesRemaining: 0,
        );

    // Track opponent for matchmaking variety
    final opponentId = widget.isHost ? _room.guestId : _room.hostId;
    _gameRoomService.setLastOpponent(opponentId);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameResultScreen(
          score: score,
          playerName: myUsername,
          opponentScore: _opponentGameScore,
          opponentName: oppUsername,
          showNewGameButton: false,
          winnerColor: _gameModel.winner?.name, // null for draw
          oldRating: _myOldRating,
          newRating: _myNewRating,
          oldRank: _myRank,
          newRank: _myNewRank,
          onBackToMenu: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showOpponentLeftDialog(String? winnerId) {
    if (!mounted || _dialogShowing) return;
    _dialogShowing = true;

    final myId = widget.isHost ? _room.hostId : _room.guestId;
    final iWin = winnerId == myId;
    final opponentName = widget.isHost
        ? (_room.guestUsername ?? 'Your opponent')
        : _room.hostUsername;
    final myName = widget.isHost
        ? _room.hostUsername
        : (_room.guestUsername ?? 'You');

    // Compute forfeit scores (opponent forfeited)
    _computeForfeitScores(winnerId).then((_) {
      if (!mounted) return;

      // Create a score if we don't have one
      final score =
          _myGameScore ??
          GameScore(
            outcome: iWin ? 'win' : 'loss',
            piecesRemaining: 0,
            opponentPiecesRemaining: 0,
            terminationReason: 'forfeit',
          );

      // Track opponent for matchmaking variety
      final oppId = widget.isHost ? _room.guestId : _room.hostId;
      _gameRoomService.setLastOpponent(oppId);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultScreen(
            score: score,
            playerName: myName,
            opponentScore: _opponentGameScore,
            opponentName: opponentName,
            showNewGameButton: false,
            winnerColor: _myPieceType.name, // I win, opponent left
            oldRating: _myOldRating,
            newRating: _myNewRating,
            oldRank: _myRank,
            newRank: _myNewRank,
            onBackToMenu: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    });
  }

  /// Compute scores for a forfeit scenario (opponent left).
  Future<void> _computeForfeitScores(String? winnerId) async {
    final auth = AuthService();
    final myId = auth.currentUser?.id ?? '';
    final opponentId = widget.isHost ? _room.guestId : _room.hostId;

    int myPieces = 0;
    int oppPieces = 0;
    for (final entry in _gameModel.board.entries) {
      if (entry.value.type == _myPieceType) {
        myPieces++;
      } else {
        oppPieces++;
      }
    }

    // Count moves per player
    int myMoveCount = 0;
    for (final m in _moveHistory) {
      if (m['player_id'] == myId) myMoveCount++;
    }

    final myScores = await _scoringService.getPlayerScores(myId);
    final oppScores = opponentId != null
        ? await _scoringService.getPlayerScores(opponentId)
        : {'avg_score': 50.0};

    final myRating = (myScores['avg_score'] as double?) ?? 50.0;
    final oppRating = (oppScores['avg_score'] as double?) ?? 50.0;

    _myGameScore = _scoringService.computeScore(
      playerId: myId,
      winnerId: winnerId,
      isDraw: false,
      playerPiecesRemaining: myPieces,
      opponentPiecesRemaining: oppPieces,
      playerRating: myRating,
      opponentRating: oppRating,
      isOnline: true,
      totalMoves: myMoveCount,
      terminationReason: 'forfeit',
    );

    final myUsername = widget.isHost
        ? _room.hostUsername
        : (_room.guestUsername ?? 'Player');

    final ratingResult = await _scoringService.recordScore(
      playerId: myId,
      username: myUsername,
      score: _myGameScore!,
      isOnline: true,
    );
    _myOldRating = ratingResult['oldRating'];
    _myNewRating = ratingResult['newRating'];
    
    // Get new ranking
    final rankResult = await LeaderboardService().getPlayerRanking(myId);
    _myNewRank = rankResult['rank'];
  }

  void _handlePositionTap(Position position) {
    // Block input during mill highlight animation
    if (_highlightingMill) return;

    // Only allow moves on my turn
    if (!_isMyTurn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.infoSnackBar("Wait for your opponent's turn"));
      return;
    }

    // Handle capture mode
    if (_waitingForCapture) {
      _handleCapture(position);
      return;
    }

    // Handle based on game phase
    if (_gameModel.gamePhase == GamePhase.placing) {
      _handlePlacement(position);
    } else {
      _handleMovement(position);
    }
  }

  void _handlePlacement(Position position) {
    // Check if position is already occupied
    if (_gameModel.board.containsKey(position)) {
      return;
    }

    final placed = _gameModel.placePiece(position);
    if (!placed) return;

    _audioService.playPieceSound();

    // Check if a mill was formed (current player didn't change means waiting for capture)
    final formedMill = _gameModel.currentPlayer == _myPieceType;

    if (formedMill) {
      // Record placement (capture will follow)
      _recordMove(type: 'place', to: position);
      // Sync immediately so opponent sees the piece, then show mill highlight
      _syncGameState();
      _showMillHighlight(position);
    } else {
      // Piece was placed successfully, turn switched
      _recordMove(type: 'place', to: position);
      _turnStartedAt = DateTime.now();
      _syncGameState();
      _checkGameEnd();
    }
  }

  void _handleMovement(Position position) {
    if (_gameModel.selectedPosition == null) {
      // Select a piece to move
      if (_gameModel.board.containsKey(position) &&
          _gameModel.board[position]!.type == _myPieceType) {
        setState(() {
          _gameModel.selectPosition(position);
        });
      }
    } else {
      // Try to move to the tapped position
      if (position == _gameModel.selectedPosition) {
        // Deselect
        setState(() {
          _gameModel.selectPosition(null);
        });
      } else if (_gameModel.board.containsKey(position) &&
          _gameModel.board[position]!.type == _myPieceType) {
        // Select different piece
        setState(() {
          _gameModel.selectPosition(position);
        });
      } else {
        // Try to move
        final fromPos = _gameModel.selectedPosition!;

        final moved = _gameModel.movePiece(fromPos, position);

        if (!moved) return;

        _audioService.playPieceSound();

        // Check if a mill was formed (current player didn't change means waiting for capture)
        final formedMill = _gameModel.currentPlayer == _myPieceType;

        if (formedMill) {
          setState(() {
            _gameModel.selectPosition(null);
          });
          // Record the move (capture will follow)
          _recordMove(type: 'move', from: fromPos, to: position);

          // Sync immediately so opponent sees the move, then show mill highlight
          _syncGameState();
          _showMillHighlight(position);
        } else {
          // Move was successful, record and start opponent timer
          setState(() {
            _gameModel.selectPosition(null);
          });
          _recordMove(type: 'move', from: fromPos, to: position);
          _turnStartedAt = DateTime.now();

          _syncGameState();
          _checkGameEnd();
        }
      }
    }
  }

  void _handleCapture(Position position) {
    if (_gameModel.capturePiece(position)) {
      _audioService.playPieceSound();
      // After capture, turn switches to opponent
      setState(() {
        _waitingForCapture = false;
        _millHighlight = null; // Clear mill highlight after capture
      });

      // Record capture (duration since turn start)
      _recordMove(type: 'capture', to: position, capture: true);

      // Start opponent timer
      _turnStartedAt = DateTime.now();

      _syncGameState();
      _checkGameEnd();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.errorSnackBar('Cannot capture that piece'));
    }
  }

  // Force reload the latest room state from server
  Future<void> _forceReloadRoom() async {
    final latestRoom = await _gameRoomService.getRoom(_room.id);
    if (latestRoom != null && latestRoom.gameState != null) {
      setState(() {
        _gameModel.loadFromJson(latestRoom.gameState!);
        _waitingForCapture =
            latestRoom.gameState!['waitingForCapture'] as bool? ?? false;
        // Read host color from reloaded state
        final hostColorStr = latestRoom.gameState!['hostColor'] as String?;
        if (hostColorStr != null) {
          _hostColor = hostColorStr == 'white'
              ? PieceType.white
              : PieceType.black;
        }
        _isMyTurn = _gameModel.currentPlayer == _myPieceType;
      });
    }
  }

  void _checkGameEnd() {
    if (_gameModel.gameState == GameState.gameOver) {
      // Determine winner ID (null means draw)
      String? winnerId;
      if (_gameModel.winner == null) {
        winnerId = null;
      } else {
        // Map game winner color to player ID using the hostColor assignment
        final winnerIsHost = _gameModel.winner == _hostColor;
        winnerId = winnerIsHost ? _room.hostId : _room.guestId;
      }
      // Compute per-game summary and report to server so leaderboard can be updated
      _computeGameSummaryAndReport(winnerId).then((_) {
        // Show game over dialog after scores are computed
        if (mounted && !_dialogShowing) {
          _showGameOverDialog();
        }
      });
    }
  }

  Future<void> _leaveGame() async {
    // If game is already over, show result screen instead of just popping
    if (_gameIsOver ||
        _room.isFinished ||
        _gameModel.gameState == GameState.gameOver) {
      // Ensure scores/ratings are computed if not already
      if (_myGameScore == null || _myOldRating == null) {
        String? winnerId;
        if (_gameModel.winner == null) {
          winnerId = null;
        } else {
          final winnerIsHost = _gameModel.winner == _hostColor;
          winnerId = winnerIsHost ? _room.hostId : _room.guestId;
        }
        await _computeGameSummaryAndReport(winnerId);
      }
      if (mounted && !_dialogShowing) {
        _showGameOverDialog();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppStyles.sharpBorder,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: AppStyles.dialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Leave Game?',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'If you leave, you will forfeit the game.',
                style: AppStyles.bodyText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: AppStyles.primaryButtonStyle.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      child: const Text('Stay'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: AppStyles.primaryButtonStyle.copyWith(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      child: const Text('Leave'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      _isLeavingRoom = true;
      _gameIsOver = true;
      _dialogShowing = true; // Prevent stream handler from interfering
      _stopTurnTimer();

      // Cancel subscription before any async work to prevent race conditions
      _roomSubscription.cancel();

      try {
        await _gameRoomService.leaveRoom(_room.id);
      } catch (e) {
        debugPrint('Error leaving room: $e');
      }

      if (!mounted) return;

      // The opponent wins because we left
      final opponentId = widget.isHost ? _room.guestId : _room.hostId;
      final winnerId = opponentId; // opponent wins

      // Compute forfeit scores (we lose) - wrap in try-catch to ensure navigation
      try {
        await _computeForfeitScores(winnerId);
      } catch (e) {
        debugPrint('Error computing forfeit scores: $e');
      }

      if (!mounted) return;

      final myName = widget.isHost
          ? _room.hostUsername
          : (_room.guestUsername ?? 'You');
      final opponentName = widget.isHost
          ? (_room.guestUsername ?? 'Opponent')
          : _room.hostUsername;

      final score =
          _myGameScore ??
          GameScore(
            outcome: 'loss',
            piecesRemaining: 0,
            opponentPiecesRemaining: 0,
            terminationReason: 'forfeit',
          );

      // Track opponent for matchmaking variety
      _gameRoomService.setLastOpponent(opponentId);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultScreen(
            score: score,
            playerName: myName,
            opponentScore: _opponentGameScore,
            opponentName: opponentName,
            showNewGameButton: false,
            winnerColor: _myPieceType == PieceType.white
                ? 'black'
                : 'white', // opponent wins, I forfeit
            oldRating: _myOldRating,
            newRating: _myNewRating,
            oldRank: _myRank,
            newRank: _myNewRank,
            onBackToMenu: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }

  void _maybeShowDrawWarnings() {
    // Draw detection only applies after placement phase
    if (_gameModel.gamePhase == GamePhase.placing) return;

    // No-capture warning
    final currentNoCapture = _gameModel.noCaptureMoves;
    if (currentNoCapture < _lastNoCaptureMoves) _drawWarningShown = false;
    final remaining = GameConstants.noCaptureThreshold - currentNoCapture;
    if (remaining > 0 &&
        remaining <= GameConstants.noCaptureWarningThreshold &&
        !_drawWarningShown) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppStyles.infoSnackBar(
          'Draw approaching: $remaining moves without capture left',
        ),
      );
      _drawWarningShown = true;
    }

    // Repetition warning
    final occurrences = _gameModel.stateOccurrences;
    for (final e in occurrences.entries) {
      final key = e.key;
      final count = e.value;
      final prev = _lastStateOccurrences[key] ?? 0;
      if (count >= GameConstants.repetitionWarningThreshold &&
          count < GameConstants.repetitionThreshold &&
          count > prev &&
          !_drawWarningShown) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppStyles.infoSnackBar(
            'Position repeated $count times — one more repetition will cause a draw',
          ),
        );
        _drawWarningShown = true;
        break;
      }
    }

    _lastNoCaptureMoves = currentNoCapture;
    _lastStateOccurrences = Map.from(occurrences);
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = widget.isHost ? _room.hostUsername : _room.guestUsername;
    final opponentUsername = widget.isHost
        ? _room.guestUsername
        : _room.hostUsername;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveGame();
        }
      },
      child: Scaffold(
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
              icon: const Icon(Icons.exit_to_app),
              onPressed: _leaveGame,
              tooltip: 'Leave Game',
            ),
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              tooltip: 'Profile',
            ),
          ],
        ),
        drawer: GameDrawer(showGameControls: false, onHomePressed: _leaveGame),
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
                  const SizedBox(height: 8),
                  // Status at top (matches offline screen)
                  GameStatus(
                    gameModel: _gameModel,
                    waitingForCapture: _waitingForCapture,
                    message: _isMyTurn ? 'Your turn' : "Opponent's turn",
                  ),
                  const SizedBox(height: 8),

                  // Game board
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: GameBoard(
                            gameModel: _gameModel,
                            onPositionTapped: _handlePositionTap,
                            millHighlight: _millHighlight,
                            captureHighlight: _captureHighlight,
                            waitingForCapture: _waitingForCapture,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Turn timer with visible countdown
                  if (_timerActive)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hourglass_bottom,
                            size: 20,
                            color: _remainingSeconds <= 5
                                ? AppStyles.burgundy
                                : AppStyles.mediumBrown,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_remainingSeconds.ceil()}s',
                            style: TextStyle(
                              fontFamily: AppStyles.fontBody,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _remainingSeconds <= 5
                                  ? AppStyles.burgundy
                                  : AppStyles.darkBrown,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_remainingSeconds / 20.0).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: AppStyles.darkBrown.withValues(
                                  alpha: 0.2,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _remainingSeconds <= 5
                                      ? AppStyles.burgundy
                                      : AppStyles.green,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 36), // Reserve space when not my turn

                  // Bottom bar with player names and piece info
                  PieceCounter(
                    gameModel: _gameModel,
                    whiteName: _myPieceType == PieceType.white
                        ? (myUsername ?? 'You')
                        : (opponentUsername ?? 'Opponent'),
                    blackName: _myPieceType == PieceType.black
                        ? (myUsername ?? 'You')
                        : (opponentUsername ?? 'Opponent'),
                    whiteRank: _myPieceType == PieceType.white
                        ? _myRank
                        : _opponentRank,
                    blackRank: _myPieceType == PieceType.black
                        ? _myRank
                        : _opponentRank,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
