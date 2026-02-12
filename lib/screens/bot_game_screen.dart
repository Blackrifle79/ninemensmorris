import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_model.dart';
import '../models/game_score.dart';
import '../models/position.dart';
import '../models/piece.dart';
import '../widgets/game_board.dart';
import '../widgets/game_status.dart';
import '../widgets/piece_counter.dart';
import '../widgets/game_drawer.dart';
import '../utils/app_styles.dart';
import '../utils/constants.dart';
import '../services/ai_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/game_room_service.dart';
import '../services/scoring_service.dart';
import '../services/leaderboard_service.dart';
import 'game_result_screen.dart';
import 'profile_screen.dart';

/// A game screen for playing against a bot that appears as an online opponent.
/// The game runs locally using AI, but updates the online leaderboard at the end.
class BotGameScreen extends StatefulWidget {
  final String botId;
  final String botUsername;
  final int? botRank;
  final String botDifficulty;

  const BotGameScreen({
    super.key,
    required this.botId,
    required this.botUsername,
    this.botRank,
    this.botDifficulty = 'medium',
  });

  @override
  State<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends State<BotGameScreen> {
  late GameModel _gameModel;
  late AIService _aiService;
  final AudioService _audioService = AudioService();
  final ScoringService _scoringService = ScoringService();
  bool _waitingForCapture = false;

  // Move tracking for scoring
  final List<Map<String, dynamic>> _moveHistory = [];
  DateTime? _turnStartedAt;

  // Rating tracking for result screen
  double? _myOldRating;
  double? _myNewRating;
  int? _myNewRank;

  // Turn timer for human player
  Timer? _moveTimer;
  double _remainingSeconds = 20.0;
  bool _timerActive = false;

  // Track which color the bot plays (randomized)
  PieceType _botColor = PieceType.black;
  PieceType get _humanColor =>
      _botColor == PieceType.white ? PieceType.black : PieceType.white;

  // Player info
  int? _myRank;
  String? _myUsername;

  // Mill highlight state
  Set<Position>? _millHighlight;
  Position? _captureHighlight;
  bool _highlightingMill = false;

  bool get _isAITurn =>
      _gameModel.currentPlayer == _botColor &&
      _gameModel.gameState != GameState.gameOver;

  @override
  void initState() {
    super.initState();
    _gameModel = GameModel();
    _aiService = AIService();

    // Set AI difficulty based on bot
    _setDifficultyFromBot();

    _turnStartedAt = DateTime.now();

    // Randomly assign which color the bot plays (50/50 white or black)
    // Use secure random for better entropy
    _botColor = Random.secure().nextBool() ? PieceType.white : PieceType.black;

    // Fetch player info
    _fetchPlayerInfo();

    // If bot goes first, trigger its turn after build
    // Otherwise start timer for human player
    if (_isAITurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _executeAITurn());
    } else {
      // Human goes first, start the timer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTurnTimer();
      });
    }
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
  }

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

  void _handleTimeout() {
    // Human ran out of time - forfeit the game
    _showGameOverDialog(forfeit: true);
  }

  void _setDifficultyFromBot() {
    switch (widget.botDifficulty) {
      case 'easy':
        _aiService.setDifficulty(AIDifficulty.easy);
        break;
      case 'hard':
        _aiService.setDifficulty(AIDifficulty.hard);
        break;
      case 'expert':
        _aiService.setDifficulty(AIDifficulty.expert);
        break;
      case 'medium':
      default:
        _aiService.setDifficulty(AIDifficulty.medium);
    }
  }

  Future<void> _fetchPlayerInfo() async {
    try {
      final auth = AuthService();
      final user = auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      _myUsername =
          profile?['username'] ?? user.email?.split('@').first ?? 'You';

      final ranking = await LeaderboardService().getPlayerRanking(user.id);
      if (mounted) {
        setState(() {
          _myRank = ranking['rank'] as int?;
        });
      }
    } catch (_) {}
  }

  void _recordMove({
    required String playerId,
    required String type,
    Position? from,
    Position? to,
    bool capture = false,
  }) {
    final now = DateTime.now();
    final duration = _turnStartedAt != null
        ? now.difference(_turnStartedAt!).inMilliseconds
        : 0;

    _moveHistory.add({
      'player_id': playerId,
      'type': type,
      'from': from?.toString(),
      'to': to?.toString(),
      'duration_ms': duration,
      'capture': capture,
      'timestamp': now.toIso8601String(),
    });

    _turnStartedAt = now;
  }

  @override
  Widget build(BuildContext context) {
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
            // Tavern background image
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
                  // Status at top
                  GameStatus(
                    gameModel: _gameModel,
                    waitingForCapture: _waitingForCapture,
                    aiIsThinking:
                        false, // Hide AI indicator to look like human opponent
                    message: _isAITurn ? "Opponent's turn" : 'Your turn',
                  ),

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

                  // Turn timer with visible countdown (only when it's human's turn)
                  if (_timerActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
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
                                value: (_remainingSeconds / 20.0).clamp(
                                  0.0,
                                  1.0,
                                ),
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
                    const SizedBox(height: 36), // Reserve space when AI's turn
                  // Piece counter with player names and ranks
                  PieceCounter(
                    gameModel: _gameModel,
                    whiteName: _humanColor == PieceType.white
                        ? (_myUsername ?? 'You')
                        : widget.botUsername,
                    blackName: _humanColor == PieceType.black
                        ? (_myUsername ?? 'You')
                        : widget.botUsername,
                    whiteRank: _humanColor == PieceType.white
                        ? _myRank
                        : widget.botRank,
                    blackRank: _humanColor == PieceType.black
                        ? _myRank
                        : widget.botRank,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePositionTap(Position position) {
    // Don't allow moves when it's the bot's turn, highlighting mill, or game is over
    if (_gameModel.currentPlayer == _botColor) return;
    if (_gameModel.gameState == GameState.gameOver) return;
    if (_highlightingMill) return;

    setState(() {
      if (_waitingForCapture) {
        // Handle capture - try to capture directly
        if (_gameModel.capturePiece(position)) {
          _audioService.playPieceSound();
          _recordMove(
            playerId: _humanColor.name,
            type: 'capture',
            to: position,
            capture: true,
          );
          setState(() {
            _waitingForCapture = false;
            _millHighlight = null;
            _captureHighlight = null;
          });
          _checkGameOverOrAITurn();
        }
      } else {
        switch (_gameModel.gamePhase) {
          case GamePhase.placing:
            PieceType placingPlayer = _gameModel.currentPlayer;
            if (_gameModel.placePiece(position)) {
              _audioService.playPieceSound();
              _recordMove(
                playerId: _humanColor.name,
                type: 'place',
                to: position,
              );
              bool formedMill = (_gameModel.currentPlayer == placingPlayer);
              if (formedMill) {
                _showMillHighlight(position);
              } else {
                _checkGameOverOrAITurn();
              }
            }
            break;

          case GamePhase.moving:
          case GamePhase.flying:
            if (_gameModel.selectedPosition == null) {
              if (_gameModel.board.containsKey(position) &&
                  _gameModel.board[position]!.type ==
                      _gameModel.currentPlayer) {
                _gameModel.selectPosition(position);
              }
            } else {
              Position from = _gameModel.selectedPosition!;
              if (from == position) {
                _gameModel.selectPosition(null);
              } else {
                PieceType movingPlayer = _gameModel.currentPlayer;
                if (_gameModel.movePiece(from, position)) {
                  _audioService.playPieceSound();
                  _recordMove(
                    playerId: _humanColor.name,
                    type: 'move',
                    from: from,
                    to: position,
                  );
                  _gameModel.selectPosition(null);
                  bool formedMill = (_gameModel.currentPlayer == movingPlayer);
                  if (formedMill) {
                    _showMillHighlight(position);
                  } else {
                    _checkGameOverOrAITurn();
                  }
                } else {
                  if (_gameModel.board.containsKey(position) &&
                      _gameModel.board[position]!.type ==
                          _gameModel.currentPlayer) {
                    _gameModel.selectPosition(position);
                  }
                }
              }
            }
            break;
        }
      }
    });
  }

  void _checkGameOverOrAITurn() {
    if (_gameModel.gameState == GameState.gameOver) {
      _stopTurnTimer();
      _showGameOverDialog();
    } else if (_isAITurn) {
      _stopTurnTimer();
      _executeAITurn();
    } else {
      // Human's turn - start timer
      _startTurnTimer();
    }
  }

  Future<void> _executeAITurn() async {
    if (_gameModel.currentPlayer != _botColor) return;
    if (_gameModel.gameState == GameState.gameOver) return;

    // Add a human-like delay (1.5 to 4 seconds, varying by game phase)
    final baseDelay = _gameModel.gamePhase == GamePhase.placing ? 1500 : 2000;
    final variance = Random().nextInt(2500);
    await Future.delayed(Duration(milliseconds: baseDelay + variance));

    if (!mounted) return;

    switch (_gameModel.gamePhase) {
      case GamePhase.placing:
        await _executeAIPlacing();
        break;
      case GamePhase.moving:
      case GamePhase.flying:
        await _executeAIMoving();
        break;
    }

    if (!mounted) return;

    // Check if game is over, otherwise start human's timer
    _checkGameOverOrAITurn();
  }

  Future<void> _executeAIPlacing() async {
    Position? targetPosition = await _aiService.getAIMove(_gameModel);
    if (targetPosition != null && mounted) {
      PieceType aiPlayer = _gameModel.currentPlayer;
      bool placed = _gameModel.placePiece(targetPosition);
      if (placed) {
        _audioService.playPieceSound();
        _recordMove(
          playerId: _botColor.name,
          type: 'place',
          to: targetPosition,
        );
        setState(() {});

        bool formedMill = (_gameModel.currentPlayer == aiPlayer);
        if (formedMill) {
          await _showAIMillHighlightAndCapture(targetPosition);
        }
      }
    }
  }

  Future<void> _executeAIMoving() async {
    Position? fromPosition = await _aiService.getAIMoveFrom(_gameModel);
    if (fromPosition != null && mounted) {
      _gameModel.selectPosition(fromPosition);
      Position? toPosition = await _aiService.getAIMove(_gameModel);
      _gameModel.selectPosition(null);
      if (toPosition != null && mounted) {
        PieceType aiPlayer = _gameModel.currentPlayer;
        bool moved = _gameModel.movePiece(fromPosition, toPosition);
        if (moved) {
          _audioService.playPieceSound();
          _recordMove(
            playerId: _botColor.name,
            type: 'move',
            from: fromPosition,
            to: toPosition,
          );
          setState(() {});

          bool formedMill = (_gameModel.currentPlayer == aiPlayer);
          if (formedMill) {
            await _showAIMillHighlightAndCapture(toPosition);
          }
        }
      }
    }
  }

  Future<void> _showAIMillHighlightAndCapture(Position millPosition) async {
    final millPositions = _gameModel.findFormedMill(millPosition);
    setState(() {
      _millHighlight = millPositions;
      _highlightingMill = true;
    });

    await Future.delayed(GameConstants.millHighlightDuration);
    if (!mounted) return;

    setState(() {
      _millHighlight = null;
      _highlightingMill = false;
    });

    Position? capturePosition = _selectAICapture();
    if (capturePosition != null) {
      setState(() {
        _captureHighlight = capturePosition;
      });

      await Future.delayed(GameConstants.captureHighlightDuration);
      if (!mounted) return;

      _gameModel.capturePiece(capturePosition);
      _recordMove(
        playerId: _botColor.name,
        type: 'capture',
        to: capturePosition,
        capture: true,
      );
      setState(() {
        _captureHighlight = null;
      });
    }
  }

  Position? _selectAICapture() {
    PieceType opponent = _humanColor;
    List<Position> opponentPieces = _gameModel.board.entries
        .where((e) => e.value.type == opponent)
        .map((e) => e.key)
        .toList();

    if (opponentPieces.isEmpty) return null;

    List<Position> capturablePieces = opponentPieces
        .where((pos) => !_gameModel.isInMill(pos))
        .toList();

    if (capturablePieces.isEmpty) {
      capturablePieces = opponentPieces;
    }

    // Prefer capturing pieces part of potential mills
    for (Position piece in capturablePieces) {
      if (_isPartOfPotentialMill(piece, opponent)) {
        return piece;
      }
    }

    // Prefer intersection pieces
    List<Position> intersectionPieces = capturablePieces
        .where((p) => p.point % 2 == 0)
        .toList();
    if (intersectionPieces.isNotEmpty) {
      return intersectionPieces[Random().nextInt(intersectionPieces.length)];
    }

    return capturablePieces[Random().nextInt(capturablePieces.length)];
  }

  bool _isPartOfPotentialMill(Position pos, PieceType player) {
    final mills = _gameModel.getMillsContaining(pos);
    for (final mill in mills) {
      int playerCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (_gameModel.board[p]?.type == player) {
          playerCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (playerCount >= 2 && emptyCount >= 1) return true;
    }
    return false;
  }

  void _showMillHighlight(Position millPosition) {
    final millPositions = _gameModel.findFormedMill(millPosition);
    setState(() {
      _millHighlight = millPositions;
      _highlightingMill = true;
    });

    Future.delayed(GameConstants.millHighlightDuration, () {
      if (mounted) {
        setState(() {
          _highlightingMill = false;
          _waitingForCapture = true;
        });
      }
    });
  }

  Future<void> _leaveGame() async {
    if (_gameModel.gameState == GameState.gameOver) {
      if (mounted) Navigator.of(context).pop();
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
      // Player forfeits - bot wins
      final ratingResult = await _recordOnlineScores(
        winnerId: widget.botId,
        isDraw: false,
        terminationReason: 'forfeit',
      );
      _myOldRating = (ratingResult['oldRating'] as num?)?.toDouble();
      _myNewRating = (ratingResult['newRating'] as num?)?.toDouble();
      _myNewRank = ratingResult['newRank'] as int?;

      if (!mounted) return;

      // Track this bot as last opponent for matchmaking variety
      final gameRoomService = GameRoomService();
      gameRoomService.setLastOpponent(widget.botId);

      // Show result screen instead of just popping
      final myUsername = _myUsername ?? 'Player';

      // Count pieces on the board
      int humanPieces = 0;
      int botPieces = 0;
      for (final entry in _gameModel.board.entries) {
        if (entry.value.type == _humanColor) {
          humanPieces++;
        } else {
          botPieces++;
        }
      }

      final playerScore = GameScore(
        outcome: 'loss',
        piecesRemaining: humanPieces,
        opponentPiecesRemaining: botPieces,
        terminationReason: 'forfeit',
      );

      final botScore = GameScore(
        outcome: 'win',
        piecesRemaining: botPieces,
        opponentPiecesRemaining: humanPieces,
        terminationReason: 'forfeit',
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultScreen(
            score: playerScore,
            playerName: myUsername,
            opponentScore: botScore,
            opponentName: widget.botUsername,
            showNewGameButton: false,
            winnerColor: _botColor.name, // bot wins forfeit
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

  Future<void> _showGameOverDialog({bool forfeit = false}) async {
    _stopTurnTimer();

    // Count pieces on the board
    int humanPieces = 0;
    int botPieces = 0;
    for (final entry in _gameModel.board.entries) {
      if (entry.value.type == _humanColor) {
        humanPieces++;
      } else {
        botPieces++;
      }
    }

    // Count moves per player from history
    int humanMoveCount = 0;
    int botMoveCount = 0;
    final auth = AuthService();
    final user = auth.currentUser;
    for (final m in _moveHistory) {
      final pid = m['player_id'] as String;
      if (pid == user?.id || pid == _humanColor.name) {
        humanMoveCount++;
      } else {
        botMoveCount++;
      }
    }

    // Determine winner - if forfeit, bot wins
    String? winnerId;
    PieceType? winnerColor;
    final bool isDraw;
    if (forfeit) {
      winnerId = widget.botId;
      winnerColor = _botColor;
      isDraw = false;
    } else {
      isDraw = _gameModel.winner == null;
      if (!isDraw) {
        winnerId = _gameModel.winner == _humanColor ? user?.id : widget.botId;
        winnerColor = _gameModel.winner;
      }
    }

    // Use forfeit termination reason if applicable
    final terminationReason = forfeit
        ? 'timeout'
        : _gameModel.terminationReason;

    // Compute scores
    GameScore playerScore = _scoringService.computeScore(
      playerId: _humanColor.name,
      winnerId: isDraw
          ? null
          : (winnerColor == _humanColor ? _humanColor.name : _botColor.name),
      isDraw: isDraw,
      playerPiecesRemaining: humanPieces,
      opponentPiecesRemaining: botPieces,
      playerRating: 50.0,
      opponentRating: 50.0,
      isOnline: true, // Treat as online game for scoring
      totalMoves: humanMoveCount,
      aiDifficultyIndex: -1,
      terminationReason: terminationReason,
    );

    GameScore botScore = _scoringService.computeScore(
      playerId: _botColor.name,
      winnerId: isDraw
          ? null
          : (winnerColor == _humanColor ? _humanColor.name : _botColor.name),
      isDraw: isDraw,
      playerPiecesRemaining: botPieces,
      opponentPiecesRemaining: humanPieces,
      playerRating: 50.0,
      opponentRating: 50.0,
      isOnline: true,
      totalMoves: botMoveCount,
      aiDifficultyIndex: -1,
      terminationReason: terminationReason,
    );

    // Record scores to online leaderboard and capture rating change
    final ratingResult = await _recordOnlineScores(
      winnerId: winnerId,
      isDraw: isDraw,
      terminationReason: terminationReason,
    );
    _myOldRating = (ratingResult['oldRating'] as num?)?.toDouble();
    _myNewRating = (ratingResult['newRating'] as num?)?.toDouble();
    _myNewRank = ratingResult['newRank'] as int?;

    if (!mounted) return;

    // Track this bot as last opponent for matchmaking variety
    GameRoomService().setLastOpponent(widget.botId);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameResultScreen(
          score: playerScore,
          playerName: _myUsername ?? 'You',
          opponentScore: botScore,
          opponentName: widget.botUsername,
          showNewGameButton: false, // Go back to lobby instead
          winnerColor: winnerColor?.name, // null for draw
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

  /// Record scores to the online leaderboard for both player and bot.
  /// Returns the player's rating change and new rank.
  Future<Map<String, dynamic>> _recordOnlineScores({
    String? winnerId,
    required bool isDraw,
    String? terminationReason,
  }) async {
    double oldRating = 50.0;
    double newRating = 50.0;

    final auth = AuthService();
    final user = auth.currentUser;
    if (user == null) {
      return {'oldRating': oldRating, 'newRating': newRating, 'newRank': null};
    }

    final client = Supabase.instance.client;

    // Count pieces
    int humanPieces = 0;
    int botPieces = 0;
    for (final entry in _gameModel.board.entries) {
      if (entry.value.type == _humanColor) {
        humanPieces++;
      } else {
        botPieces++;
      }
    }

    // Compute player score
    int humanMoveCount = 0;
    for (final m in _moveHistory) {
      final pid = m['player_id'] as String;
      if (pid == user.id || pid == _humanColor.name) humanMoveCount++;
    }

    final playerScore = _scoringService.computeScore(
      playerId: user.id,
      winnerId: winnerId,
      isDraw: isDraw,
      playerPiecesRemaining: humanPieces,
      opponentPiecesRemaining: botPieces,
      playerRating: 50.0,
      opponentRating: 50.0,
      isOnline: true,
      totalMoves: humanMoveCount,
      aiDifficultyIndex: -1,
      terminationReason: terminationReason,
    );

    // Record player's score and capture rating change
    try {
      final ratingResult = await _scoringService.recordScore(
        playerId: user.id,
        username: _myUsername ?? 'Player',
        score: playerScore,
        isOnline: true,
      );
      oldRating = ratingResult['oldRating'] ?? 50.0;
      newRating = ratingResult['newRating'] ?? 50.0;
    } catch (_) {}

    // Fetch updated ranking
    int? newRank;
    try {
      final rankResult = await LeaderboardService().getPlayerRanking(user.id);
      newRank = rankResult['rank'] as int?;
    } catch (_) {}

    // Update bot's leaderboard entry with ELO rating change
    try {
      final botLb = await client
          .from('leaderboard')
          .select('avg_score, online_score, online_games, wins, losses, draws')
          .eq('id', widget.botId)
          .maybeSingle();

      if (botLb != null) {
        final botOldRating = (botLb['avg_score'] as num?)?.toDouble() ?? 50.0;
        final oldGames = (botLb['online_games'] as int?) ?? 0;
        final oldWins = (botLb['wins'] as int?) ?? 0;
        final oldLosses = (botLb['losses'] as int?) ?? 0;
        final oldDraws = (botLb['draws'] as int?) ?? 0;

        // Calculate ELO rating change for the bot
        final botWon = winnerId == widget.botId;
        String botOutcome;
        if (isDraw) {
          botOutcome = 'draw';
        } else if (botWon) {
          botOutcome = 'win';
        } else {
          botOutcome = 'loss';
        }

        // ELO calculation: expected score
        final ratingDiff =
            oldRating - botOldRating; // Human's old rating - bot's rating
        final expectedScore = 1.0 / (1.0 + pow(10, ratingDiff / 25.0));

        // Actual score for bot
        double actualScore;
        switch (botOutcome) {
          case 'win':
            actualScore = 1.0;
            break;
          case 'draw':
            actualScore = 0.5;
            break;
          default:
            actualScore = 0.0;
        }

        // ELO formula
        const kFactor = 3.2; // Scaled K factor for 0-100 range
        final ratingChange = kFactor * (actualScore - expectedScore);
        final botNewRating = (botOldRating + ratingChange).clamp(0.0, 100.0);

        await client
            .from('leaderboard')
            .update({
              'avg_score': botNewRating,
              'score': botNewRating.round(), // legacy column
              'online_games': oldGames + 1,
              'games_played': oldGames + 1,
              'wins': oldWins + (botWon ? 1 : 0),
              'losses': oldLosses + (!isDraw && !botWon ? 1 : 0),
              'draws': oldDraws + (isDraw ? 1 : 0),
            })
            .eq('id', widget.botId);
      }
    } catch (_) {}

    return {'oldRating': oldRating, 'newRating': newRating, 'newRank': newRank};
  }
}
