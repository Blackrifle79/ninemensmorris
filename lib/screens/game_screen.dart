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
import '../services/scoring_service.dart';
import 'game_result_screen.dart';
import 'profile_screen.dart';

class GameScreen extends StatefulWidget {
  final bool isVsAI;

  const GameScreen({super.key, this.isVsAI = false});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameModel _gameModel;
  late AIService _aiService;
  final AudioService _audioService = AudioService();
  final ScoringService _scoringService = ScoringService();
  bool _waitingForCapture = false;
  bool _aiIsThinking = false;
  String _lastMessage = '';

  // Move tracking for scoring
  final List<Map<String, dynamic>> _moveHistory = [];
  DateTime? _turnStartedAt;

  // Track which color the AI plays (only relevant in vs AI mode)
  PieceType _aiColor = PieceType.black;
  PieceType get _humanColor =>
      _aiColor == PieceType.white ? PieceType.black : PieceType.white;

  // Mill highlight state
  Set<Position>? _millHighlight;
  Position? _captureHighlight;
  bool _highlightingMill = false;

  @override
  void initState() {
    super.initState();
    _gameModel = GameModel();
    _aiService = AIService();
    _aiService.loadDifficulty(); // Load saved AI difficulty
    _turnStartedAt = DateTime.now();
    if (widget.isVsAI) {
      // Randomly assign which color the AI plays (50/50 white or black)
      // Use secure random for better entropy
      _aiColor = Random.secure().nextBool() ? PieceType.white : PieceType.black;
      // If AI goes first, trigger its turn after build
      if (_isAITurn) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _executeAITurn());
      }
    }
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
        drawer: GameDrawer(
          showGameControls: true,
          onNewGame: _resetGame,
          onHomePressed: _leaveGame,
        ),
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
            // Parchment overlay at 30% opacity
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
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isPortrait =
                          constraints.maxHeight > constraints.maxWidth;

                      if (isPortrait) {
                        return Column(
                          children: [
                            const SizedBox(height: 8),
                            // Status at top
                            GameStatus(
                              gameModel: _gameModel,
                              waitingForCapture: _waitingForCapture,
                              aiIsThinking: _aiIsThinking,
                              message: _lastMessage,
                            ),

                            // Game board - constrained to available space
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

                            // Piece counter at bottom
                            PieceCounter(
                              gameModel: _gameModel,
                              whiteName: widget.isVsAI
                                  ? (_humanColor == PieceType.white
                                        ? 'You'
                                        : 'AI')
                                  : 'White',
                              blackName: widget.isVsAI
                                  ? (_humanColor == PieceType.black
                                        ? 'You'
                                        : 'AI')
                                  : 'Black',
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            // Game board with counter below
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: GameBoard(
                                            gameModel: _gameModel,
                                            onPositionTapped:
                                                _handlePositionTap,
                                            millHighlight: _millHighlight,
                                            captureHighlight: _captureHighlight,
                                            waitingForCapture:
                                                _waitingForCapture,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  PieceCounter(
                                    gameModel: _gameModel,
                                    whiteName: widget.isVsAI
                                        ? (_humanColor == PieceType.white
                                              ? 'You'
                                              : 'AI')
                                        : 'White',
                                    blackName: widget.isVsAI
                                        ? (_humanColor == PieceType.black
                                              ? 'You'
                                              : 'AI')
                                        : 'Black',
                                  ),
                                ],
                              ),
                            ),

                            // Status on the side
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GameStatus(
                                      gameModel: _gameModel,
                                      waitingForCapture: _waitingForCapture,
                                      aiIsThinking: _aiIsThinking,
                                      message: _lastMessage,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isAITurn {
    return widget.isVsAI && _gameModel.currentPlayer == _aiColor;
  }

  void _recordMove({
    required String playerId,
    required String type,
    Position? from,
    Position? to,
    bool capture = false,
  }) {
    final now = DateTime.now();
    final durationMs = _turnStartedAt != null
        ? now.difference(_turnStartedAt!).inMilliseconds
        : 0;

    _moveHistory.add({
      'player_id': playerId,
      'type': type,
      'from': from?.toString(),
      'to': to?.toString(),
      'duration_ms': durationMs,
      'capture': capture,
      'timestamp': now.toIso8601String(),
    });

    // Reset turn timer for next player
    _turnStartedAt = DateTime.now();
  }

  void _handlePositionTap(Position position) {
    // Ignore taps if AI is thinking, it's AI's turn, or showing mill highlight
    if (_aiIsThinking || _isAITurn || _highlightingMill) return;

    setState(() {
      if (_waitingForCapture) {
        // Player must capture a piece
        if (_gameModel.capturePiece(position)) {
          _recordMove(
            playerId: _humanColor.name,
            type: 'capture',
            to: position,
            capture: true,
          );
          _lastMessage = '';
          _waitingForCapture = false;
          _millHighlight = null; // Clear mill highlight after capture
          _checkGameOverOrAITurn();
        }
      } else {
        switch (_gameModel.gamePhase) {
          case GamePhase.placing:
            // Store current player before placing piece
            PieceType placingPlayer = _gameModel.currentPlayer;
            if (_gameModel.placePiece(position)) {
              _audioService.playPieceSound();
              _recordMove(
                playerId: _humanColor.name,
                type: 'place',
                to: position,
              );
              // Check if mill was formed by seeing if current player didn't change
              // (placePiece doesn't switch turns if a mill is formed)
              bool formedMill = (_gameModel.currentPlayer == placingPlayer);
              if (formedMill) {
                _showMillHighlight(position);
              } else {
                _lastMessage = '';
                _checkGameOverOrAITurn();
              }
            }
            break;

          case GamePhase.moving:
          case GamePhase.flying:
            if (_gameModel.selectedPosition == null) {
              // Select a piece to move
              if (_gameModel.board.containsKey(position) &&
                  _gameModel.board[position]!.type ==
                      _gameModel.currentPlayer) {
                _gameModel.selectPosition(position);
              }
            } else {
              // Try to move the selected piece
              Position from = _gameModel.selectedPosition!;
              if (from == position) {
                // Deselect if tapping the same position
                _gameModel.selectPosition(null);
              } else {
                // Store current player before moving piece
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
                  // Check if mill was formed by seeing if current player didn't change
                  bool formedMill = (_gameModel.currentPlayer == movingPlayer);
                  if (formedMill) {
                    _showMillHighlight(position);
                  } else {
                    _lastMessage = '';
                    _checkGameOverOrAITurn();
                  }
                } else {
                  // Select a different piece if valid
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
    // Check for game over
    if (_gameModel.gameState == GameState.gameOver) {
      _showGameOverDialog();
    } else if (_isAITurn) {
      _executeAITurn();
    }
  }

  Future<void> _executeAITurn() async {
    if (!widget.isVsAI || _gameModel.currentPlayer != _aiColor) return;
    if (_gameModel.gameState == GameState.gameOver) return;

    setState(() {
      _aiIsThinking = true;
    });

    // Add a small delay to make AI moves feel more natural
    await Future.delayed(const Duration(milliseconds: 500));

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

    setState(() {
      _aiIsThinking = false;
    });

    // Check for game over after AI move
    if (_gameModel.gameState == GameState.gameOver) {
      _showGameOverDialog();
    }
  }

  Future<void> _executeAIPlacing() async {
    Position? targetPosition = await _aiService.getAIMove(_gameModel);
    if (targetPosition != null && mounted) {
      PieceType aiPlayer = _gameModel.currentPlayer;
      bool placed = _gameModel.placePiece(targetPosition);
      if (placed) {
        _audioService.playPieceSound();
        _recordMove(playerId: _aiColor.name, type: 'place', to: targetPosition);
        setState(() {});

        // Check if AI formed a mill
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
      // Set the selected position so AI can calculate target move
      _gameModel.selectPosition(fromPosition);
      Position? toPosition = await _aiService.getAIMove(_gameModel);
      _gameModel.selectPosition(null); // Clear selection
      if (toPosition != null && mounted) {
        PieceType aiPlayer = _gameModel.currentPlayer;
        bool moved = _gameModel.movePiece(fromPosition, toPosition);
        if (moved) {
          _audioService.playPieceSound();
          _recordMove(
            playerId: _aiColor.name,
            type: 'move',
            from: fromPosition,
            to: toPosition,
          );
          setState(() {});

          // Check if AI formed a mill
          bool formedMill = (_gameModel.currentPlayer == aiPlayer);
          if (formedMill) {
            await _showAIMillHighlightAndCapture(toPosition);
          }
        }
      }
    }
  }

  /// Show mill highlight for AI, then show capture highlight, then execute capture
  Future<void> _showAIMillHighlightAndCapture(Position millPosition) async {
    // Find and highlight the mill positions
    final millPositions = _gameModel.findFormedMill(millPosition);
    setState(() {
      _millHighlight = millPositions;
      _highlightingMill = true;
    });

    // Show mill highlight
    await Future.delayed(GameConstants.millHighlightDuration);
    if (!mounted) return;

    // Clear mill highlight
    setState(() {
      _millHighlight = null;
      _highlightingMill = false;
    });

    // Select capture target and show red highlight
    Position? capturePosition = _selectAICapture();
    if (capturePosition != null) {
      setState(() {
        _captureHighlight = capturePosition;
      });

      // Show capture highlight
      await Future.delayed(GameConstants.captureHighlightDuration);
      if (!mounted) return;

      // Execute capture and clear highlight
      _gameModel.capturePiece(capturePosition);
      _recordMove(
        playerId: _aiColor.name,
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
    // Use AI service for capture selection
    PieceType opponent = _humanColor;
    List<Position> opponentPieces = _gameModel.board.entries
        .where((e) => e.value.type == opponent)
        .map((e) => e.key)
        .toList();

    if (opponentPieces.isEmpty) return null;

    // Filter out pieces in mills (unless all are in mills)
    List<Position> capturablePieces = opponentPieces
        .where((pos) => !_gameModel.isInMill(pos))
        .toList();

    if (capturablePieces.isEmpty) {
      capturablePieces = opponentPieces; // All in mills, can capture any
    }

    // Check for pieces part of potential mills
    for (Position piece in capturablePieces) {
      if (_isPartOfPotentialMill(piece, opponent)) {
        return piece;
      }
    }

    // Check for intersection pieces
    List<Position> intersectionPieces = capturablePieces
        .where((p) => p.point % 2 == 0)
        .toList();
    if (intersectionPieces.isNotEmpty) {
      return intersectionPieces[Random().nextInt(intersectionPieces.length)];
    }

    // Fallback
    return capturablePieces[Random().nextInt(capturablePieces.length)];
  }

  /// Check if a piece is part of a potential mill for the given player
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
          _lastMessage = "Mill! Tap an opponent's piece to capture.";
        });
      }
    });
  }

  void _resetGame() {
    setState(() {
      _gameModel.resetGame();
      _waitingForCapture = false;
      _aiIsThinking = false;
      _millHighlight = null;
      _captureHighlight = null;
      _highlightingMill = false;
      _moveHistory.clear();
      _turnStartedAt = DateTime.now();
      if (widget.isVsAI) {
        // Re-randomize AI color on new game
        _aiColor = Random.secure().nextBool()
            ? PieceType.white
            : PieceType.black;
      }
    });
    // If AI goes first after reset, trigger its turn
    if (_isAITurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _executeAITurn());
    }
  }

  Future<void> _leaveGame() async {
    // If game is already over, just go back
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
      _showForfeitScoreAndLeave();
    }
  }

  void _showForfeitScoreAndLeave() {
    // Count pieces on the board
    int humanPieces = 0;
    int aiPieces = 0;
    int whitePieces = 0;
    int blackPieces = 0;
    for (final entry in _gameModel.board.entries) {
      if (entry.value.type == PieceType.white) whitePieces++;
      if (entry.value.type == PieceType.black) blackPieces++;
      if (widget.isVsAI) {
        if (entry.value.type == _humanColor) {
          humanPieces++;
        } else {
          aiPieces++;
        }
      }
    }

    GameScore playerScore;
    GameScore? opponentScore;
    String playerName;
    String? opponentName;

    if (widget.isVsAI) {
      // Human forfeits → AI wins
      playerName = 'You';
      opponentName = 'AI (${_aiService.difficulty.displayName})';

      playerScore = _scoringService.computeScore(
        playerId: _humanColor.name,
        winnerId: _aiColor.name,
        isDraw: false,
        playerPiecesRemaining: humanPieces,
        opponentPiecesRemaining: aiPieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: _aiService.difficulty.index,
        terminationReason: 'forfeit',
      );

      opponentScore = _scoringService.computeScore(
        playerId: _aiColor.name,
        winnerId: _aiColor.name,
        isDraw: false,
        playerPiecesRemaining: aiPieces,
        opponentPiecesRemaining: humanPieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: _aiService.difficulty.index,
        terminationReason: 'forfeit',
      );
    } else {
      // Local multiplayer — current player forfeits, other player wins
      final forfeitColor = _gameModel.currentPlayer;
      final winnerColor = forfeitColor == PieceType.white
          ? PieceType.black
          : PieceType.white;

      playerName = 'White';
      opponentName = 'Black';

      playerScore = _scoringService.computeScore(
        playerId: PieceType.white.name,
        winnerId: winnerColor.name,
        isDraw: false,
        playerPiecesRemaining: whitePieces,
        opponentPiecesRemaining: blackPieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: -1,
        terminationReason: 'forfeit',
      );

      opponentScore = _scoringService.computeScore(
        playerId: PieceType.black.name,
        winnerId: winnerColor.name,
        isDraw: false,
        playerPiecesRemaining: blackPieces,
        opponentPiecesRemaining: whitePieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: -1,
        terminationReason: 'forfeit',
      );
    }

    // Record the forfeit score
    _recordOfflineScore(playerScore);

    // Determine winner color from the forfeit
    String? winnerColorName;
    if (widget.isVsAI) {
      winnerColorName = _aiColor.name; // AI wins forfeit
    } else {
      final forfeitColor = _gameModel.currentPlayer;
      winnerColorName = forfeitColor == PieceType.white ? 'black' : 'white';
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameResultScreen(
          score: playerScore,
          playerName: playerName,
          opponentScore: opponentScore,
          opponentName: opponentName,
          showNewGameButton: true,
          winnerColor: winnerColorName,
          onNewGame: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => GameScreen(isVsAI: widget.isVsAI),
              ),
            );
          },
          onBackToMenu: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Compute scores for both sides and show the score card dialog.
  void _showGameOverDialog() {
    // Count pieces on the board
    int humanPieces = 0;
    int aiPieces = 0;
    int whitePieces = 0;
    int blackPieces = 0;
    for (final entry in _gameModel.board.entries) {
      if (entry.value.type == PieceType.white) {
        whitePieces++;
      } else {
        blackPieces++;
      }
      if (widget.isVsAI) {
        if (entry.value.type == _humanColor) {
          humanPieces++;
        } else {
          aiPieces++;
        }
      }
    }

    // Determine winner
    String? winnerId;
    final bool isDraw = _gameModel.winner == null;
    if (!isDraw) {
      if (widget.isVsAI) {
        winnerId = _gameModel.winner == _humanColor
            ? _humanColor.name
            : _aiColor.name;
      } else {
        winnerId = _gameModel.winner!.name;
      }
    }

    // Compute scores
    GameScore playerScore;
    GameScore? opponentScore;
    String playerName;
    String? opponentName;

    if (widget.isVsAI) {
      playerName = 'You';
      opponentName = 'AI (${_aiService.difficulty.displayName})';

      playerScore = _scoringService.computeScore(
        playerId: _humanColor.name,
        winnerId: winnerId,
        isDraw: isDraw,
        playerPiecesRemaining: humanPieces,
        opponentPiecesRemaining: aiPieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: _aiService.difficulty.index,
        terminationReason: _gameModel.terminationReason,
      );

      opponentScore = _scoringService.computeScore(
        playerId: _aiColor.name,
        winnerId: winnerId,
        isDraw: isDraw,
        playerPiecesRemaining: aiPieces,
        opponentPiecesRemaining: humanPieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: _aiService.difficulty.index,
        terminationReason: _gameModel.terminationReason,
      );
    } else {
      // Local multiplayer — show White's score
      playerName = 'White';
      opponentName = 'Black';

      playerScore = _scoringService.computeScore(
        playerId: PieceType.white.name,
        winnerId: winnerId,
        isDraw: isDraw,
        playerPiecesRemaining: whitePieces,
        opponentPiecesRemaining: blackPieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: -1,
        terminationReason: _gameModel.terminationReason,
      );

      opponentScore = _scoringService.computeScore(
        playerId: PieceType.black.name,
        winnerId: winnerId,
        isDraw: isDraw,
        playerPiecesRemaining: blackPieces,
        opponentPiecesRemaining: whitePieces,
        playerRating: 50.0,
        opponentRating: 50.0,
        isOnline: false,
        totalMoves: 0,
        aiDifficultyIndex: -1,
        terminationReason: _gameModel.terminationReason,
      );
    }

    // Record to leaderboard (offline score) if logged in
    _recordOfflineScore(playerScore);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameResultScreen(
          score: playerScore,
          playerName: playerName,
          opponentScore: opponentScore,
          opponentName: opponentName,
          showNewGameButton: true,
          winnerColor: _gameModel.winner?.name, // null for draw
          onNewGame: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => GameScreen(isVsAI: widget.isVsAI),
              ),
            );
          },
          onBackToMenu: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Record the offline game score to the leaderboard if user is logged in.
  Future<void> _recordOfflineScore(GameScore score) async {
    final auth = AuthService();
    final user = auth.currentUser;
    if (user == null) return; // not logged in, skip

    String username = 'Player';
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      username =
          profile?['username'] ?? user.email?.split('@').first ?? 'Player';
    } catch (_) {}

    await _scoringService.recordScore(
      playerId: user.id,
      username: username,
      score: score,
      isOnline: false,
    );
  }
}
