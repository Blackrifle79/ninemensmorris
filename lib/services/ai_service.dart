import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../models/position.dart';
import '../models/piece.dart';

/// AI difficulty levels
/// - Beginner: Makes random moves most of the time, rarely blocks
/// - Easy: Sometimes makes good moves, often misses opportunities
/// - Medium: Balanced play, occasionally makes mistakes
/// - Hard: Strong play, rarely makes mistakes
/// - Expert: Optimal play, always makes the best move
enum AIDifficulty { beginner, easy, medium, hard, expert }

extension AIDifficultyExtension on AIDifficulty {
  String get displayName {
    switch (this) {
      case AIDifficulty.beginner:
        return 'Beginner';
      case AIDifficulty.easy:
        return 'Easy';
      case AIDifficulty.medium:
        return 'Medium';
      case AIDifficulty.hard:
        return 'Hard';
      case AIDifficulty.expert:
        return 'Expert';
    }
  }

  String get description {
    switch (this) {
      case AIDifficulty.beginner:
        return 'Learning the ropes';
      case AIDifficulty.easy:
        return 'Casual play';
      case AIDifficulty.medium:
        return 'Balanced challenge';
      case AIDifficulty.hard:
        return 'Tough opponent';
      case AIDifficulty.expert:
        return 'Master tactician';
    }
  }

  /// Chance (0-100) that AI will make the optimal move (heuristic path only)
  int get optimalMoveChance {
    switch (this) {
      case AIDifficulty.beginner:
        return 10;
      case AIDifficulty.easy:
        return 30;
      case AIDifficulty.medium:
        return 70;
      case AIDifficulty.hard:
        return 100;
      case AIDifficulty.expert:
        return 100;
    }
  }

  /// Chance (0-100) that AI will block an opponent's mill (heuristic path only)
  int get blockChance {
    switch (this) {
      case AIDifficulty.beginner:
        return 10;
      case AIDifficulty.easy:
        return 40;
      case AIDifficulty.medium:
        return 80;
      case AIDifficulty.hard:
        return 100;
      case AIDifficulty.expert:
        return 100;
    }
  }

  /// Minimax search depth (0 = heuristic only)
  int get searchDepth {
    switch (this) {
      case AIDifficulty.beginner:
        return 0;
      case AIDifficulty.easy:
        return 0;
      case AIDifficulty.medium:
        return 0;
      case AIDifficulty.hard:
        return 3;
      case AIDifficulty.expert:
        return 4;
    }
  }

  /// Whether this difficulty uses minimax search
  bool get usesSearch => searchDepth > 0;
}

// ============================================
// LIGHTWEIGHT TYPES FOR MINIMAX SEARCH
// ============================================

/// Lightweight board state for minimax search.
/// Positions are indexed 0-23: index = ring * 8 + point.
/// Board values: 0 = empty, 1 = white, 2 = black.
class _SearchState {
  final List<int> board;
  int currentPlayer; // 1 = white, 2 = black
  int whitePiecesToPlace;
  int blackPiecesToPlace;

  _SearchState({
    required this.board,
    required this.currentPlayer,
    required this.whitePiecesToPlace,
    required this.blackPiecesToPlace,
  });

  bool get isPlacingPhase => whitePiecesToPlace > 0 || blackPiecesToPlace > 0;

  int get currentPiecesToPlace =>
      currentPlayer == 1 ? whitePiecesToPlace : blackPiecesToPlace;

  _SearchState clone() => _SearchState(
    board: List<int>.from(board),
    currentPlayer: currentPlayer,
    whitePiecesToPlace: whitePiecesToPlace,
    blackPiecesToPlace: blackPiecesToPlace,
  );
}

/// A complete move in the search tree (place/move + optional capture).
class _SearchMove {
  final int? from; // null during placing phase
  final int to;
  final int? capture; // null if no mill formed

  const _SearchMove({this.from, required this.to, this.capture});
}

/// AI Service for Nine Men's Morris
///
/// The AI follows these strategic principles for Nine Men's Morris:
///
/// === PLACING PHASE STRATEGY ===
/// 1. PRIORITY: Form mills - look for positions that complete a row of 3
/// 2. BLOCK OPPONENT MILLS - prevent opponent from forming mills
/// 3. CREATE DOUBLE MILL OPPORTUNITIES - place pieces to set up positions where
///    moving one piece can form mills in two directions alternately
/// 4. CONTROL INTERSECTIONS - midpoints (positions 0,2,4,6) are more valuable
///    as they connect to adjacent rings, providing more movement options
/// 5. AVOID CORNERS EARLY - corners (positions 1,3,5,7) have fewer connections
///
/// === MOVING PHASE STRATEGY ===
/// 1. FORM MILLS - always prioritize completing a mill
/// 2. OPEN MILLS - if you have a mill, break it to reform it next turn (mill cycling)
/// 3. BLOCK OPPONENT - prevent opponent from forming mills
/// 4. MAINTAIN MOBILITY - keep pieces connected, avoid isolated pieces
/// 5. CONTROL THE CENTER - inner ring positions provide better board control
/// 6. SET UP DOUBLE MILLS - position pieces so moving one creates a mill,
///    then moving back creates another mill
///
/// === FLYING PHASE STRATEGY ===
/// When reduced to 3 pieces, the player can "fly" (move to any empty position)
/// 1. AGGRESSIVE MILL FORMING - use mobility to form mills quickly
/// 2. DEFENSIVE BLOCKING - use mobility to block opponent mills
/// 3. AVOID BEING TRAPPED - keep options open
///
/// === CAPTURE STRATEGY ===
/// When capturing an opponent's piece after forming a mill:
/// 1. BREAK OPPONENT'S POTENTIAL MILLS - capture pieces that are part of
///    potential mill formations
/// 2. REDUCE OPPONENT'S MOBILITY - capture pieces at intersections
/// 3. AVOID CAPTURING FROM MILLS - pieces in mills are protected unless
///    all opponent pieces are in mills
/// 4. TARGET ISOLATED PIECES - pieces with fewer adjacent allies
///
/// === GENERAL PRINCIPLES ===
/// - The game is about controlling space and limiting opponent options
/// - Mills are the key tactical element - forming them and preventing opponent mills
/// - Double mills (being able to open and close a mill repeatedly) often win games
/// - In the endgame, trapping the opponent (no legal moves) is a win condition
class AIService {
  // Singleton pattern
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final Random _random = Random();
  static AIDifficulty _difficulty = AIDifficulty.medium;
  static bool _difficultyLoaded = false;
  static const String _difficultyKey = 'ai_difficulty';

  // Cached search result for coordinating from/to/capture across calls
  _SearchMove? _cachedSearchMove;

  AIDifficulty get difficulty => _difficulty;

  /// Load difficulty from persistent storage
  Future<void> loadDifficulty() async {
    if (_difficultyLoaded) return; // Already loaded
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_difficultyKey) ?? AIDifficulty.medium.index;
    _difficulty =
        AIDifficulty.values[index.clamp(0, AIDifficulty.values.length - 1)];
    _difficultyLoaded = true;
  }

  /// Set and persist difficulty
  Future<void> setDifficulty(AIDifficulty newDifficulty) async {
    _difficulty = newDifficulty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_difficultyKey, newDifficulty.index);
  }

  /// Check if AI should make the optimal move based on difficulty
  bool _shouldMakeOptimalMove() {
    return _random.nextInt(100) < _difficulty.optimalMoveChance;
  }

  /// Check if AI should block based on difficulty
  bool _shouldBlock() {
    return _random.nextInt(100) < _difficulty.blockChance;
  }

  /// Get the AI's move for the current game state
  /// Returns the position to act on (place, move to, or capture)
  Future<Position?> getAIMove(
    GameModel gameModel, {
    bool isCapture = false,
  }) async {
    // Add a small delay to make AI feel more natural
    await Future.delayed(const Duration(milliseconds: 500));

    if (isCapture) {
      // For search difficulties, return cached capture if available
      if (_difficulty.usesSearch && _cachedSearchMove?.capture != null) {
        final cIdx = _cachedSearchMove!.capture!;
        _cachedSearchMove = null; // consumed
        return _indexToPosition(cIdx);
      }
      return _selectCapture(gameModel);
    }

    // Placing phase with search
    if (_difficulty.usesSearch && gameModel.gamePhase == GamePhase.placing) {
      final move = _findBestMoveWithSearch(gameModel);
      if (move != null) {
        _cachedSearchMove = move; // cache for potential capture
        return _indexToPosition(move.to);
      }
    }

    // Moving/flying phase with search: return cached destination
    if (_difficulty.usesSearch &&
        gameModel.gamePhase != GamePhase.placing &&
        _cachedSearchMove != null) {
      final toIdx = _cachedSearchMove!.to;
      // Keep the cache — capture may still be needed
      final tempMove = _cachedSearchMove!;
      _cachedSearchMove = tempMove.capture != null ? tempMove : null;
      return _indexToPosition(toIdx);
    }

    // Heuristic path (Beginner / Easy / Medium)
    switch (gameModel.gamePhase) {
      case GamePhase.placing:
        return _selectPlacingPosition(gameModel);
      case GamePhase.moving:
      case GamePhase.flying:
        return _selectMove(gameModel);
    }
  }

  /// Get the position to move FROM (for moving/flying phases)
  Future<Position?> getAIMoveFrom(GameModel gameModel) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // For search difficulties, compute full move and cache it
    if (_difficulty.usesSearch) {
      final move = _findBestMoveWithSearch(gameModel);
      if (move != null && move.from != null) {
        _cachedSearchMove = move;
        return _indexToPosition(move.from!);
      }
    }

    return _selectPieceToMove(gameModel);
  }

  // ============================================
  // PLACING PHASE
  // ============================================

  Position? _selectPlacingPosition(GameModel gameModel) {
    List<Position> emptyPositions = _getEmptyPositions(gameModel);
    if (emptyPositions.isEmpty) return null;

    // Priority 1: Complete a mill (always try this if possible)
    Position? millPosition = _findMillCompletingPosition(
      gameModel,
      gameModel.currentPlayer,
    );
    if (millPosition != null && _shouldMakeOptimalMove()) {
      return millPosition;
    }

    // Priority 2: Block opponent's mill (based on difficulty)
    PieceType opponent = gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;
    Position? blockPosition = _findMillCompletingPosition(gameModel, opponent);
    if (blockPosition != null && _shouldBlock()) {
      return blockPosition;
    }

    // Priority 3: Create mill opportunities (two pieces in a potential mill line)
    if (_shouldMakeOptimalMove()) {
      Position? setupPosition = _findMillSetupPosition(gameModel);
      if (setupPosition != null) {
        return setupPosition;
      }
    }

    // Priority 3.5: Double mill setup — find positions at the junction of
    // two potential mill lines (Medium+ strategic play)
    if (_shouldMakeOptimalMove()) {
      Position? doubleMill = _findDoubleMIllSetupPosition(gameModel);
      if (doubleMill != null) {
        return doubleMill;
      }
    }

    // Priority 4: Prefer intersection positions (midpoints) - based on difficulty
    if (_shouldMakeOptimalMove()) {
      List<Position> intersections = emptyPositions
          .where((p) => p.point % 2 == 0)
          .toList();
      if (intersections.isNotEmpty) {
        return intersections[_random.nextInt(intersections.length)];
      }
    }

    // Fallback: Random empty position
    return emptyPositions[_random.nextInt(emptyPositions.length)];
  }

  // ============================================
  // MOVING/FLYING PHASE
  // ============================================

  Position? _selectPieceToMove(GameModel gameModel) {
    List<Position> aiPieces = gameModel.board.entries
        .where((e) => e.value.type == gameModel.currentPlayer)
        .map((e) => e.key)
        .toList();

    if (aiPieces.isEmpty) return null;

    // Get all pieces that have valid moves
    List<Position> movablePieces = aiPieces
        .where((p) => _getValidMovesFrom(gameModel, p).isNotEmpty)
        .toList();

    if (movablePieces.isEmpty) return null;

    // For lower difficulties, sometimes just pick a random movable piece
    if (!_shouldMakeOptimalMove()) {
      return movablePieces[_random.nextInt(movablePieces.length)];
    }

    // Check each piece for mill-forming potential
    for (Position piece in aiPieces) {
      List<Position> validMoves = _getValidMovesFrom(gameModel, piece);
      for (Position target in validMoves) {
        if (_wouldFormMill(gameModel, piece, target)) {
          return piece;
        }
      }
    }

    // Find pieces that can block opponent mills
    if (_shouldBlock()) {
      PieceType opponent = gameModel.currentPlayer == PieceType.white
          ? PieceType.black
          : PieceType.white;
      Position? blockingMove = _findBlockingMoveFrom(gameModel, opponent);
      if (blockingMove != null) return blockingMove;
    }

    // Sort by number of valid moves (descending) - pick piece with most mobility
    movablePieces.sort(
      (a, b) => _getValidMovesFrom(
        gameModel,
        b,
      ).length.compareTo(_getValidMovesFrom(gameModel, a).length),
    );

    return movablePieces.first;
  }

  Position? _selectMove(GameModel gameModel) {
    Position? selectedPiece = gameModel.selectedPosition;
    if (selectedPiece == null) return null;

    List<Position> validMoves = _getValidMovesFrom(gameModel, selectedPiece);
    if (validMoves.isEmpty) return null;

    // For lower difficulties, sometimes just pick a random move
    if (!_shouldMakeOptimalMove()) {
      return validMoves[_random.nextInt(validMoves.length)];
    }

    // Priority 1: Move that forms a mill
    for (Position target in validMoves) {
      if (_wouldFormMill(gameModel, selectedPiece, target)) {
        return target;
      }
    }

    // Priority 2: Move that blocks opponent mill (based on difficulty)
    if (_shouldBlock()) {
      PieceType opponent = gameModel.currentPlayer == PieceType.white
          ? PieceType.black
          : PieceType.white;
      for (Position target in validMoves) {
        if (_wouldBlockMill(gameModel, target, opponent)) {
          return target;
        }
      }
    }

    // Priority 3: Move toward intersection positions
    List<Position> intersectionMoves = validMoves
        .where((p) => p.point % 2 == 0)
        .toList();
    if (intersectionMoves.isNotEmpty) {
      return intersectionMoves[_random.nextInt(intersectionMoves.length)];
    }

    // Fallback: Random valid move
    return validMoves[_random.nextInt(validMoves.length)];
  }

  // ============================================
  // CAPTURE SELECTION
  // ============================================

  Position? _selectCapture(GameModel gameModel) {
    PieceType opponent = gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    List<Position> opponentPieces = gameModel.board.entries
        .where((e) => e.value.type == opponent)
        .map((e) => e.key)
        .toList();

    if (opponentPieces.isEmpty) return null;

    // Filter out pieces in mills (unless all are in mills)
    List<Position> capturablePieces = opponentPieces
        .where((p) => !_isInMill(gameModel, p))
        .toList();

    if (capturablePieces.isEmpty) {
      capturablePieces = opponentPieces; // All in mills, can capture any
    }

    // For lower difficulties, sometimes just capture randomly
    if (!_shouldMakeOptimalMove()) {
      return capturablePieces[_random.nextInt(capturablePieces.length)];
    }

    // Priority 1: Capture pieces that are part of potential mills
    for (Position piece in capturablePieces) {
      if (_isPartOfPotentialMill(gameModel, piece, opponent)) {
        return piece;
      }
    }

    // Priority 2: Capture intersection pieces (more valuable)
    List<Position> intersectionPieces = capturablePieces
        .where((p) => p.point % 2 == 0)
        .toList();
    if (intersectionPieces.isNotEmpty) {
      return intersectionPieces[_random.nextInt(intersectionPieces.length)];
    }

    // Fallback: Random capturable piece
    return capturablePieces[_random.nextInt(capturablePieces.length)];
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  List<Position> _getEmptyPositions(GameModel gameModel) {
    return GameModel.getAllPositions()
        .where((p) => !gameModel.board.containsKey(p))
        .toList();
  }

  List<Position> _getValidMovesFrom(GameModel gameModel, Position from) {
    // Flying is per-player: only the player with exactly 3 pieces can fly
    int pieceCount = gameModel.board.values
        .where((p) => p.type == gameModel.currentPlayer)
        .length;
    bool canFly = pieceCount == 3 && gameModel.gamePhase != GamePhase.placing;

    if (canFly) {
      // Can move to any empty position
      return _getEmptyPositions(gameModel);
    } else {
      // Can only move to adjacent empty positions
      return gameModel
          .getAdjacentPositions(from)
          .where((p) => !gameModel.board.containsKey(p))
          .toList();
    }
  }

  Position? _findMillCompletingPosition(GameModel gameModel, PieceType player) {
    List<Position> emptyPositions = _getEmptyPositions(gameModel);

    for (Position pos in emptyPositions) {
      if (_wouldCompleteMill(gameModel, pos, player)) {
        return pos;
      }
    }
    return null;
  }

  bool _wouldCompleteMill(
    GameModel gameModel,
    Position position,
    PieceType player,
  ) {
    // Temporarily place piece and check for mill
    List<List<Position>> mills = _getMillsContaining(position);

    for (List<Position> mill in mills) {
      int playerCount = 0;

      for (Position p in mill) {
        if (p == position) {
          playerCount++; // This would be the new piece
        } else if (gameModel.board.containsKey(p) &&
            gameModel.board[p]!.type == player) {
          playerCount++;
        }
      }

      if (playerCount == 3) return true;
    }
    return false;
  }

  Position? _findMillSetupPosition(GameModel gameModel) {
    List<Position> emptyPositions = _getEmptyPositions(gameModel);
    PieceType player = gameModel.currentPlayer;

    for (Position pos in emptyPositions) {
      List<List<Position>> mills = _getMillsContaining(pos);

      for (List<Position> mill in mills) {
        int playerCount = 0;
        int emptyCount = 0;

        for (Position p in mill) {
          if (p == pos) {
            emptyCount++;
          } else if (gameModel.board.containsKey(p) &&
              gameModel.board[p]!.type == player) {
            playerCount++;
          } else if (!gameModel.board.containsKey(p)) {
            emptyCount++;
          }
        }

        // Two pieces of ours + one empty (would be our placement)
        if (playerCount == 1 && emptyCount == 2) {
          return pos;
        }
      }
    }
    return null;
  }

  /// Find a position that sits at the junction of two potential mill lines.
  /// This sets up a "double mill" or "pendulum" — the strongest tactic in the game.
  Position? _findDoubleMIllSetupPosition(GameModel gameModel) {
    List<Position> emptyPositions = _getEmptyPositions(gameModel);
    PieceType player = gameModel.currentPlayer;

    Position? bestPos;
    int bestScore = 0;

    for (Position pos in emptyPositions) {
      List<List<Position>> mills = _getMillsContaining(pos);
      int strongLines = 0; // lines with at least 1 of our pieces + no opponents

      for (List<Position> mill in mills) {
        int playerCount = 0;
        int opponentCount = 0;

        for (Position p in mill) {
          if (p == pos) continue;
          if (gameModel.board.containsKey(p)) {
            if (gameModel.board[p]!.type == player) {
              playerCount++;
            } else {
              opponentCount++;
            }
          }
        }

        // A line with at least one of our pieces and no opponents
        if (playerCount >= 1 && opponentCount == 0) {
          strongLines++;
        }
      }

      if (strongLines >= 2 && strongLines > bestScore) {
        bestScore = strongLines;
        bestPos = pos;
      }
    }

    return bestPos;
  }

  bool _wouldFormMill(GameModel gameModel, Position from, Position to) {
    // Simulate the move
    PieceType player = gameModel.board[from]!.type;
    List<List<Position>> mills = _getMillsContaining(to);

    for (List<Position> mill in mills) {
      int playerCount = 0;

      for (Position p in mill) {
        if (p == to) {
          playerCount++; // The piece moving here
        } else if (p == from) {
          // Don't count the piece at 'from' as it's moving away
          continue;
        } else if (gameModel.board.containsKey(p) &&
            gameModel.board[p]!.type == player) {
          playerCount++;
        }
      }

      if (playerCount == 3) return true;
    }
    return false;
  }

  bool _wouldBlockMill(
    GameModel gameModel,
    Position position,
    PieceType opponent,
  ) {
    List<List<Position>> mills = _getMillsContaining(position);

    for (List<Position> mill in mills) {
      int opponentCount = 0;
      int emptyCount = 0;

      for (Position p in mill) {
        if (p == position) {
          emptyCount++;
        } else if (gameModel.board.containsKey(p) &&
            gameModel.board[p]!.type == opponent) {
          opponentCount++;
        } else if (!gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }

      // Opponent has 2 pieces and this is the blocking position
      if (opponentCount == 2 && emptyCount == 1) {
        return true;
      }
    }
    return false;
  }

  Position? _findBlockingMoveFrom(GameModel gameModel, PieceType opponent) {
    List<Position> aiPieces = gameModel.board.entries
        .where((e) => e.value.type == gameModel.currentPlayer)
        .map((e) => e.key)
        .toList();

    for (Position piece in aiPieces) {
      List<Position> validMoves = _getValidMovesFrom(gameModel, piece);
      for (Position target in validMoves) {
        if (_wouldBlockMill(gameModel, target, opponent)) {
          return piece;
        }
      }
    }
    return null;
  }

  bool _isInMill(GameModel gameModel, Position position) {
    if (!gameModel.board.containsKey(position)) return false;

    PieceType player = gameModel.board[position]!.type;
    List<List<Position>> mills = _getMillsContaining(position);

    for (List<Position> mill in mills) {
      bool allSamePlayer = mill.every(
        (p) =>
            gameModel.board.containsKey(p) &&
            gameModel.board[p]!.type == player,
      );
      if (allSamePlayer) return true;
    }
    return false;
  }

  bool _isPartOfPotentialMill(
    GameModel gameModel,
    Position position,
    PieceType player,
  ) {
    List<List<Position>> mills = _getMillsContaining(position);

    for (List<Position> mill in mills) {
      int playerCount = 0;
      int emptyCount = 0;

      for (Position p in mill) {
        if (gameModel.board.containsKey(p) &&
            gameModel.board[p]!.type == player) {
          playerCount++;
        } else if (!gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }

      // Two pieces with one empty = potential mill
      if (playerCount == 2 && emptyCount == 1) {
        return true;
      }
    }
    return false;
  }

  /// Get all possible mill combinations that include this position
  List<List<Position>> _getMillsContaining(Position position) {
    List<List<Position>> mills = [];
    int ring = position.ring;
    int point = position.point;

    // Mills along the same ring (each side of the square)
    if (point == 0 || point == 1 || point == 7) {
      mills.add([
        Position(ring: ring, point: 7),
        Position(ring: ring, point: 0),
        Position(ring: ring, point: 1),
      ]);
    }
    if (point == 1 || point == 2 || point == 3) {
      mills.add([
        Position(ring: ring, point: 1),
        Position(ring: ring, point: 2),
        Position(ring: ring, point: 3),
      ]);
    }
    if (point == 3 || point == 4 || point == 5) {
      mills.add([
        Position(ring: ring, point: 3),
        Position(ring: ring, point: 4),
        Position(ring: ring, point: 5),
      ]);
    }
    if (point == 5 || point == 6 || point == 7) {
      mills.add([
        Position(ring: ring, point: 5),
        Position(ring: ring, point: 6),
        Position(ring: ring, point: 7),
      ]);
    }

    // Mills between rings (only at midpoints)
    if (point % 2 == 0) {
      mills.add([
        Position(ring: 0, point: point),
        Position(ring: 1, point: point),
        Position(ring: 2, point: point),
      ]);
    }

    return mills;
  }

  // ============================================
  // MINIMAX SEARCH ENGINE (Hard / Expert)
  // ============================================

  // --- Precomputed board topology ---

  /// All 16 mill lines as index triples (index = ring * 8 + point).
  static const List<List<int>> _allMillLines = [
    // Ring 0 sides
    [7, 0, 1],
    [1, 2, 3],
    [3, 4, 5],
    [5, 6, 7],
    // Ring 1 sides
    [15, 8, 9],
    [9, 10, 11],
    [11, 12, 13],
    [13, 14, 15],
    // Ring 2 sides
    [23, 16, 17],
    [17, 18, 19],
    [19, 20, 21],
    [21, 22, 23],
    // Cross-ring at midpoints
    [0, 8, 16],
    [2, 10, 18],
    [4, 12, 20],
    [6, 14, 22],
  ];

  /// For each of the 24 positions, the indices into [_allMillLines] it belongs to.
  static final List<List<int>> _millIndicesForPos = List.generate(24, (pos) {
    return [
      for (int m = 0; m < _allMillLines.length; m++)
        if (_allMillLines[m].contains(pos)) m,
    ];
  });

  /// Adjacency list for each of the 24 positions.
  static final List<List<int>> _adjacencyList = List.generate(24, (i) {
    final int ring = i ~/ 8;
    final int point = i % 8;
    final List<int> adj = [
      ring * 8 + (point + 7) % 8,
      ring * 8 + (point + 1) % 8,
    ];
    if (point % 2 == 0) {
      if (ring > 0) adj.add((ring - 1) * 8 + point);
      if (ring < 2) adj.add((ring + 1) * 8 + point);
    }
    return adj;
  });

  // --- Conversion helpers ---

  static int _positionToIndex(Position p) => p.ring * 8 + p.point;

  static Position _indexToPosition(int i) =>
      Position(ring: i ~/ 8, point: i % 8);

  _SearchState _gameModelToSearchState(GameModel gm) {
    final board = List<int>.filled(24, 0);
    for (final entry in gm.board.entries) {
      board[_positionToIndex(entry.key)] = entry.value.type == PieceType.white
          ? 1
          : 2;
    }
    return _SearchState(
      board: board,
      currentPlayer: gm.currentPlayer == PieceType.white ? 1 : 2,
      whitePiecesToPlace: gm.whitePiecesToPlace,
      blackPiecesToPlace: gm.blackPiecesToPlace,
    );
  }

  // --- Mill detection on search state ---

  /// Would placing / moving a piece TO [pos] form a mill?
  /// [vacated] is the index the piece left (-1 for placing).
  bool _formsMillAtSearch(
    _SearchState s,
    int pos,
    int player, {
    int vacated = -1,
  }) {
    for (final mi in _millIndicesForPos[pos]) {
      final line = _allMillLines[mi];
      bool complete = true;
      for (final p in line) {
        if (p == pos) continue; // piece being placed/moved here
        if (p == vacated) {
          complete = false;
          break;
        } // vacated square
        if (s.board[p] != player) {
          complete = false;
          break;
        }
      }
      if (complete) return true;
    }
    return false;
  }

  /// Is [pos] currently part of a complete mill for [player]?
  bool _isInMillSearch(_SearchState s, int pos, int player) {
    for (final mi in _millIndicesForPos[pos]) {
      final line = _allMillLines[mi];
      bool complete = true;
      for (final p in line) {
        if (s.board[p] != player) {
          complete = false;
          break;
        }
      }
      if (complete) return true;
    }
    return false;
  }

  /// Get opponent pieces eligible for capture in [state] by [player].
  List<int> _capturableOpponents(_SearchState state, int player) {
    final int opp = 3 - player;
    final List<int> all = [];
    final List<int> nonMill = [];
    for (int i = 0; i < 24; i++) {
      if (state.board[i] != opp) continue;
      all.add(i);
      if (!_isInMillSearch(state, i, opp)) nonMill.add(i);
    }
    return nonMill.isNotEmpty ? nonMill : all;
  }

  // --- Move generation ---

  List<_SearchMove> _generateSearchMoves(_SearchState state) {
    final int player = state.currentPlayer;
    final List<_SearchMove> moves = [];

    if (state.isPlacingPhase &&
        (player == 1 ? state.whitePiecesToPlace : state.blackPiecesToPlace) >
            0) {
      // Placing phase
      for (int to = 0; to < 24; to++) {
        if (state.board[to] != 0) continue;
        if (_formsMillAtSearch(state, to, player)) {
          // Temporarily place to determine capturable pieces
          state.board[to] = player;
          final caps = _capturableOpponents(state, player);
          state.board[to] = 0;
          if (caps.isEmpty) {
            moves.add(_SearchMove(to: to));
          } else {
            for (final c in caps) {
              moves.add(_SearchMove(to: to, capture: c));
            }
          }
        } else {
          moves.add(_SearchMove(to: to));
        }
      }
    } else {
      // Moving / flying phase
      int pieceCount = 0;
      for (int i = 0; i < 24; i++) {
        if (state.board[i] == player) pieceCount++;
      }
      final bool canFly = pieceCount == 3 && !state.isPlacingPhase;

      for (int from = 0; from < 24; from++) {
        if (state.board[from] != player) continue;

        final Iterable<int> destinations = canFly
            ? [
                for (int i = 0; i < 24; i++)
                  if (state.board[i] == 0) i,
              ]
            : _adjacencyList[from].where((i) => state.board[i] == 0);

        for (final int to in destinations) {
          if (_formsMillAtSearch(state, to, player, vacated: from)) {
            // Temporarily move to determine capturable pieces
            state.board[from] = 0;
            state.board[to] = player;
            final caps = _capturableOpponents(state, player);
            state.board[to] = 0;
            state.board[from] = player;
            if (caps.isEmpty) {
              moves.add(_SearchMove(from: from, to: to));
            } else {
              for (final c in caps) {
                moves.add(_SearchMove(from: from, to: to, capture: c));
              }
            }
          } else {
            moves.add(_SearchMove(from: from, to: to));
          }
        }
      }
    }

    // Move ordering: captures first (better alpha-beta pruning)
    moves.sort(
      (a, b) => (b.capture != null ? 1 : 0) - (a.capture != null ? 1 : 0),
    );

    return moves;
  }

  /// Apply [move] to [state] in place.
  void _applySearchMove(_SearchState state, _SearchMove move) {
    final int player = state.currentPlayer;

    if (move.from != null) {
      state.board[move.from!] = 0;
    } else {
      // Placing
      if (player == 1) {
        state.whitePiecesToPlace--;
      } else {
        state.blackPiecesToPlace--;
      }
    }
    state.board[move.to] = player;

    if (move.capture != null) {
      state.board[move.capture!] = 0;
    }

    state.currentPlayer = 3 - player;
  }

  // --- Board evaluation ---

  int _countMovesForPlayer(_SearchState state, int player) {
    int count = 0;
    int pieceCount = 0;
    for (int i = 0; i < 24; i++) {
      if (state.board[i] == player) pieceCount++;
    }
    if (pieceCount == 3 && !state.isPlacingPhase) {
      // Can fly to any empty position
      int emptyCount = 0;
      for (int i = 0; i < 24; i++) {
        if (state.board[i] == 0) emptyCount++;
      }
      return pieceCount * emptyCount;
    }
    for (int i = 0; i < 24; i++) {
      if (state.board[i] != player) continue;
      for (final adj in _adjacencyList[i]) {
        if (state.board[adj] == 0) count++;
      }
    }
    return count;
  }

  /// Evaluate the board from [aiPlayer]'s perspective.
  /// Positive = good for AI, negative = bad.
  double _evaluateState(_SearchState state, int aiPlayer) {
    final int opponent = 3 - aiPlayer;

    int aiOnBoard = 0, oppOnBoard = 0;
    for (int i = 0; i < 24; i++) {
      if (state.board[i] == aiPlayer) {
        aiOnBoard++;
      } else if (state.board[i] == opponent) {
        oppOnBoard++;
      }
    }

    final int aiToPlace = aiPlayer == 1
        ? state.whitePiecesToPlace
        : state.blackPiecesToPlace;
    final int oppToPlace = opponent == 1
        ? state.whitePiecesToPlace
        : state.blackPiecesToPlace;
    final int aiTotal = aiOnBoard + aiToPlace;
    final int oppTotal = oppOnBoard + oppToPlace;

    // Terminal checks
    if (!state.isPlacingPhase) {
      if (oppOnBoard < 3) return 10000.0;
      if (aiOnBoard < 3) return -10000.0;
      final int oppMoves = _countMovesForPlayer(state, opponent);
      if (oppMoves == 0 && oppOnBoard >= 3) return 10000.0;
      final int aiMoves = _countMovesForPlayer(state, aiPlayer);
      if (aiMoves == 0 && aiOnBoard >= 3) return -10000.0;
    }

    double score = 0;

    // Material advantage
    score += (aiTotal - oppTotal) * 100;

    // Mill line analysis
    int aiMills = 0, oppMills = 0;
    int aiPotentialMills = 0, oppPotentialMills = 0;

    for (final line in _allMillLines) {
      int ac = 0, oc = 0, ec = 0;
      for (final p in line) {
        if (state.board[p] == aiPlayer) {
          ac++;
        } else if (state.board[p] == opponent) {
          oc++;
        } else {
          ec++;
        }
      }
      if (ac == 3) aiMills++;
      if (oc == 3) oppMills++;
      if (ac == 2 && ec == 1) aiPotentialMills++;
      if (oc == 2 && ec == 1) oppPotentialMills++;
    }

    score += (aiMills - oppMills) * 50;
    score += (aiPotentialMills - oppPotentialMills) * 20;

    // Double mill positions (piece at junction of 2+ strong lines)
    int aiDoubleMill = 0, oppDoubleMill = 0;
    for (int i = 0; i < 24; i++) {
      if (state.board[i] == 0) continue;
      final int owner = state.board[i];
      int strongLines = 0;
      for (final mi in _millIndicesForPos[i]) {
        final line = _allMillLines[mi];
        int ownerCount = 0;
        bool blocked = false;
        for (final p in line) {
          if (state.board[p] == owner) {
            ownerCount++;
          } else if (state.board[p] != 0) {
            blocked = true;
            break;
          }
        }
        if (!blocked && ownerCount >= 2) strongLines++;
      }
      if (strongLines >= 2) {
        if (owner == aiPlayer) {
          aiDoubleMill++;
        } else {
          oppDoubleMill++;
        }
      }
    }

    score += (aiDoubleMill - oppDoubleMill) * 40;

    // Mobility (moving phase)
    if (!state.isPlacingPhase) {
      final int aiMob = _countMovesForPlayer(state, aiPlayer);
      final int oppMob = _countMovesForPlayer(state, opponent);
      score += (aiMob - oppMob) * 8;
    }

    // Intersection control (midpoints are more valuable)
    for (int ring = 0; ring < 3; ring++) {
      for (int point = 0; point < 8; point += 2) {
        final int idx = ring * 8 + point;
        if (state.board[idx] == aiPlayer) {
          score += 3;
        } else if (state.board[idx] == opponent) {
          score -= 3;
        }
      }
    }

    return score;
  }

  // --- Minimax with alpha-beta pruning ---

  double _minimax(
    _SearchState state,
    int depth,
    double alpha,
    double beta,
    bool maximizing,
    int aiPlayer,
  ) {
    // Terminal / depth-0: evaluate
    if (depth <= 0) return _evaluateState(state, aiPlayer);

    final moves = _generateSearchMoves(state);
    if (moves.isEmpty) {
      // Current player has no moves → they lose
      return state.currentPlayer == aiPlayer
          ? -10000.0 + depth
          : 10000.0 - depth;
    }

    if (maximizing) {
      double best = -double.infinity;
      for (final move in moves) {
        final child = state.clone();
        _applySearchMove(child, move);
        final eval = _minimax(child, depth - 1, alpha, beta, false, aiPlayer);
        if (eval > best) best = eval;
        if (best > alpha) alpha = best;
        if (beta <= alpha) break;
      }
      return best;
    } else {
      double best = double.infinity;
      for (final move in moves) {
        final child = state.clone();
        _applySearchMove(child, move);
        final eval = _minimax(child, depth - 1, alpha, beta, true, aiPlayer);
        if (eval < best) best = eval;
        if (best < beta) beta = best;
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  /// Find the best move using minimax search.
  _SearchMove? _findBestMoveWithSearch(GameModel gameModel) {
    final state = _gameModelToSearchState(gameModel);
    final int aiPlayer = state.currentPlayer;

    // Adaptive depth: reduce by 1 in placing phase (higher branching factor)
    int depth = _difficulty.searchDepth;
    if (state.isPlacingPhase && depth > 2) depth--;

    final moves = _generateSearchMoves(state);
    if (moves.isEmpty) return null;

    _SearchMove? bestMove;
    double bestScore = -double.infinity;

    for (final move in moves) {
      final child = state.clone();
      _applySearchMove(child, move);
      // AI just moved, so the next level is the opponent (minimizing)
      final score = _minimax(
        child,
        depth - 1,
        -double.infinity,
        double.infinity,
        false,
        aiPlayer,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }
}
