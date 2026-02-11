import 'position.dart';
import 'piece.dart';
import '../utils/constants.dart';

/// Represents the different phases of the game
enum GamePhase { placing, moving, flying }

/// Represents the current state of the game
enum GameState { playing, gameOver }

/// Main game model that handles all game logic
class GameModel {
  // Board state - maps positions to pieces
  final Map<Position, Piece> _board = {};

  // Current player
  PieceType _currentPlayer;

  // Game phase and state
  GamePhase _gamePhase = GamePhase.placing;
  GameState _gameState = GameState.playing;

  // Remaining pieces to place
  int _whitePiecesToPlace = 9;
  int _blackPiecesToPlace = 9;

  // Winner (if any)
  PieceType? _winner;

  // Selected position for moves
  Position? _selectedPosition;

  // Draw / repetition detection
  int _noCaptureMoves = 0; // consecutive moves without a capture
  final List<String> _stateHistory =
      []; // recent board hashes for repetition detection

  // If the game ends as a draw or for an unusual reason, this describes why
  String? _terminationReason;

  /// Create a new game model. White always goes first per standard rules.
  /// Pass [startingPlayer] to override (e.g. for online games that manage
  /// starting player separately).
  GameModel({PieceType startingPlayer = PieceType.white})
    : _currentPlayer = startingPlayer;

  /// Readable reason for why the game ended (may be null)
  String? get terminationReason => _terminationReason;

  /// Number of consecutive non-capture moves so far
  int get noCaptureMoves => _noCaptureMoves;

  /// Count occurrences of each board state seen recently
  Map<String, int> get stateOccurrences {
    final Map<String, int> counts = {};
    for (final k in _stateHistory) {
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }

  /// If the game ended by repetition, return helpful data including repeated positions
  Map<String, dynamic>? getTerminationDetails() {
    if (_terminationReason == null) return null;

    if (_terminationReason == 'threefold_repetition') {
      final counts = stateOccurrences;
      final repeated = counts.entries
          .where((e) => e.value >= GameConstants.repetitionThreshold)
          .map((e) => {'position_key': e.key, 'count': e.value})
          .toList();
      return {'reason': _terminationReason, 'repeated_positions': repeated};
    }

    return {'reason': _terminationReason};
  }

  // Getters
  Map<Position, Piece> get board => Map.unmodifiable(_board);
  PieceType get currentPlayer => _currentPlayer;
  GamePhase get gamePhase => _gamePhase;
  GameState get gameState => _gameState;
  int get whitePiecesToPlace => _whitePiecesToPlace;
  int get blackPiecesToPlace => _blackPiecesToPlace;
  PieceType? get winner => _winner;
  Position? get selectedPosition => _selectedPosition;

  /// Get all valid positions on the board
  /// The board has 24 positions: 8 on each of 3 concentric squares
  /// Points 0,2,4,6 are midpoints of sides (top, right, bottom, left)
  /// Points 1,3,5,7 are corners (top-right, bottom-right, bottom-left, top-left)
  static List<Position> getAllPositions() {
    List<Position> positions = [];
    for (int ring = 0; ring < 3; ring++) {
      // All 3 rings have all 8 points (4 corners + 4 midpoints)
      for (int point = 0; point < 8; point++) {
        positions.add(Position(ring: ring, point: point));
      }
    }
    return positions;
  }

  /// Check if a position is valid
  static bool isValidPosition(Position position) {
    if (position.ring < 0 || position.ring > 2) return false;
    if (position.point < 0 || position.point > 7) return false;
    return true;
  }

  /// Get adjacent positions for movement
  /// Movement is along the lines of the board only
  List<Position> getAdjacentPositions(Position position) {
    List<Position> adjacent = [];

    // Movement along the same ring (around the square)
    int prevPoint = (position.point + 7) % 8;
    int nextPoint = (position.point + 1) % 8;
    adjacent.add(Position(ring: position.ring, point: prevPoint));
    adjacent.add(Position(ring: position.ring, point: nextPoint));

    // Movement between rings (only at midpoints - even points 0,2,4,6)
    // The connecting lines only exist at midpoints, not corners
    if (position.point % 2 == 0) {
      if (position.ring > 0) {
        adjacent.add(Position(ring: position.ring - 1, point: position.point));
      }
      if (position.ring < 2) {
        adjacent.add(Position(ring: position.ring + 1, point: position.point));
      }
    }

    return adjacent.where(isValidPosition).toList();
  }

  /// Place a piece on the board
  bool placePiece(Position position) {
    if (_gameState != GameState.playing || _gamePhase != GamePhase.placing) {
      return false;
    }

    if (!isValidPosition(position) || _board.containsKey(position)) {
      return false;
    }

    _board[position] = Piece(type: _currentPlayer);

    if (_currentPlayer == PieceType.white) {
      _whitePiecesToPlace--;
    } else {
      _blackPiecesToPlace--;
    }

    // Check for mill formation and handle capture
    if (_checkMill(position)) {
      // Player can capture an opponent's piece - don't increment no-capture counter yet
      _recordState();
      return true; // Wait for capture before switching turns
    }

    _switchTurns();
    _updateGamePhase();

    // Non-capture move completed -> count towards inactivity draw
    _noCaptureMoves++;
    _recordState();

    return true;
  }

  /// Move a piece from one position to another
  bool movePiece(Position from, Position to) {
    if (_gameState != GameState.playing || _gamePhase == GamePhase.placing) {
      return false;
    }

    if (!_board.containsKey(from) || _board[from]!.type != _currentPlayer) {
      return false;
    }

    if (_board.containsKey(to)) {
      return false;
    }

    // Check if move is valid based on game phase
    // Flying is per-player: only the player with exactly 3 pieces can fly
    bool canFly = _getPieceCount(_currentPlayer) == 3;
    if (!canFly) {
      if (!getAdjacentPositions(from).contains(to)) {
        return false;
      }
    }
    // If canFly is true, player can move to any empty position

    // Move the piece
    Piece piece = _board.remove(from)!;
    _board[to] = piece;

    // Check for mill formation
    if (_checkMill(to)) {
      // Only allow capture if this is a NEW mill, not just rearranging
      // pieces within the same mill line
      if (!_isRearrangementNotNewMill(to, from)) {
        _recordState();
        return true; // Wait for capture - this is a new mill!
      }
    }

    _switchTurns();

    // Non-capture move -> increment non-capture counter and record state
    _noCaptureMoves++;
    _recordState();

    _checkGameEnd();
    return true;
  }

  /// Check if moving from 'from' to 'to' would NOT create a new mill
  /// (i.e., the piece was already part of this same mill line at 'from')
  /// Returns true if the mill at 'to' is just a rearrangement of the same mill line
  bool _isRearrangementNotNewMill(Position to, Position from) {
    // Get all mills that the destination 'to' is part of
    List<List<Position>> millsAtTo = _getMillsContaining(to);

    for (List<Position> mill in millsAtTo) {
      // Check if this mill is complete (all 3 positions have our pieces)
      bool isCompleteMill = mill.every(
        (p) => _board.containsKey(p) && _board[p]!.type == _currentPlayer,
      );

      if (!isCompleteMill) continue;

      // This mill at 'to' is complete. Now check if 'from' was part of this same mill line.
      // If so, we're just sliding within the line (not forming a NEW mill).
      if (mill.contains(from)) {
        return true; // This is a rearrangement, not a new mill
      }
    }
    return false; // No complete mill at 'to' has 'from' in it, so this is a new mill
  }

  /// Select a position (for UI feedback)
  void selectPosition(Position? position) {
    _selectedPosition = position;
  }

  /// Capture an opponent's piece
  bool capturePiece(Position position) {
    if (!_board.containsKey(position)) return false;

    Piece piece = _board[position]!;
    if (piece.type == _currentPlayer) return false;

    // Cannot capture a piece that's part of a mill (unless all pieces are in mills)
    if (_checkMill(position) && !_allPiecesInMills(piece.type)) {
      return false;
    }

    _board.remove(position);

    // Reset no-capture counter because a capture just happened
    _noCaptureMoves = 0;
    _switchTurns();
    _updateGamePhase();
    _recordState();
    _checkGameEnd();
    return true;
  }

  /// Check if a position forms a mill
  /// Mills are 3 pieces in a row along the lines of the board
  bool _checkMill(Position position) {
    if (!_board.containsKey(position)) return false;

    PieceType pieceType = _board[position]!.type;

    // Get all possible mills that include this position
    List<List<Position>> possibleMills = _getMillsContaining(position);

    // Check if any mill is complete
    for (List<Position> mill in possibleMills) {
      if (mill.every(
        (pos) => _board.containsKey(pos) && _board[pos]!.type == pieceType,
      )) {
        return true;
      }
    }

    return false;
  }

  // Serialize board into a canonical string for repetition detection
  String _boardKey() {
    final buffer = StringBuffer();
    for (final pos in GameModel.getAllPositions()) {
      final piece = _board[pos];
      if (piece == null) {
        buffer.write('.');
      } else {
        buffer.write(piece.type == PieceType.white ? 'W' : 'B');
      }
    }
    return buffer.toString();
  }

  void _recordState() {
    final key = _boardKey();
    _stateHistory.add(key);
    if (_stateHistory.length > 200) _stateHistory.removeAt(0);

    final occurrences = _stateHistory.where((k) => k == key).length;
    if (occurrences >= GameConstants.repetitionThreshold) {
      // Threefold repetition -> draw
      _terminationReason = 'threefold_repetition';
      _winner = null;
      _gameState = GameState.gameOver;
      return;
    }

    if (_noCaptureMoves >= GameConstants.noCaptureThreshold) {
      // Long sequence without captures -> draw
      _terminationReason = 'no_capture_threshold';
      _winner = null;
      _gameState = GameState.gameOver;
      return;
    }
  }

  /// Public method to check if a position is part of a mill
  bool isInMill(Position position) {
    return _checkMill(position);
  }

  /// Public method to get all mill combinations containing a position
  /// Used by UI to highlight mills
  List<List<Position>> getMillsContaining(Position position) {
    return _getMillsContaining(position);
  }

  /// Find the completed mill that includes this position
  /// Returns empty set if no mill is formed
  Set<Position> findFormedMill(Position position) {
    if (!_board.containsKey(position)) return {};

    final pieceType = _board[position]!.type;
    final mills = _getMillsContaining(position);

    for (final mill in mills) {
      bool isCompleteMill = mill.every(
        (p) => _board.containsKey(p) && _board[p]!.type == pieceType,
      );
      if (isCompleteMill) {
        return mill.toSet();
      }
    }
    return {};
  }

  /// Get all possible mill combinations that include this position
  List<List<Position>> _getMillsContaining(Position position) {
    List<List<Position>> mills = [];
    int ring = position.ring;
    int point = position.point;

    // Mills along the same ring (each side of the square)
    // Points are arranged: 0=top, 1=top-right corner, 2=right, 3=bottom-right corner,
    // 4=bottom, 5=bottom-left corner, 6=left, 7=top-left corner
    //
    // Side mills: (7,0,1), (1,2,3), (3,4,5), (5,6,7)
    // Each side has a midpoint (even) and two corners (odd)

    // Determine which side of the ring this position belongs to
    // and add the corresponding mill
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

    // Mills between rings (only at midpoints - even points 0,2,4,6)
    // These are vertical lines connecting all 3 rings at the same midpoint
    if (point % 2 == 0) {
      mills.add([
        Position(ring: 0, point: point),
        Position(ring: 1, point: point),
        Position(ring: 2, point: point),
      ]);
    }

    return mills;
  }

  /// Check if all pieces of a type are in mills
  bool _allPiecesInMills(PieceType pieceType) {
    for (Position position in _board.keys) {
      if (_board[position]!.type == pieceType && !_checkMill(position)) {
        return false;
      }
    }
    return true;
  }

  /// Switch to the other player
  void _switchTurns() {
    _currentPlayer = _currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;
  }

  /// Update the game phase based on pieces placed
  void _updateGamePhase() {
    if (_whitePiecesToPlace == 0 && _blackPiecesToPlace == 0) {
      // Once all pieces are placed, we're in the moving phase
      // Flying is determined per-player in movePiece() based on piece count
      _gamePhase = GamePhase.moving;
    }
  }

  /// Get the number of pieces of a specific type on the board
  int _getPieceCount(PieceType type) {
    return _board.values.where((piece) => piece.type == type).length;
  }

  /// Check if the game has ended
  void _checkGameEnd() {
    int whitePieces = _getPieceCount(PieceType.white);
    int blackPieces = _getPieceCount(PieceType.black);

    // Game ends if a player has less than 3 pieces (and placing phase is over)
    if (_gamePhase != GamePhase.placing) {
      if (whitePieces < 3) {
        _winner = PieceType.black;
        _terminationReason = 'insufficient_pieces';
        _gameState = GameState.gameOver;
        return;
      }
      if (blackPieces < 3) {
        _winner = PieceType.white;
        _terminationReason = 'insufficient_pieces';
        _gameState = GameState.gameOver;
        return;
      }
    }

    // Check if current player can make any moves
    if (_gamePhase != GamePhase.placing && !_canPlayerMove(_currentPlayer)) {
      _winner = _currentPlayer == PieceType.white
          ? PieceType.black
          : PieceType.white;
      _terminationReason = 'no_moves';
      _gameState = GameState.gameOver;
    }
  }

  /// Check if a player can make any legal moves
  bool _canPlayerMove(PieceType player) {
    int pieceCount = _getPieceCount(player);
    bool canFly = pieceCount == 3;

    for (Position position in _board.keys) {
      if (_board[position]!.type == player) {
        if (canFly) {
          // With exactly 3 pieces, can move to any empty position
          for (Position pos in getAllPositions()) {
            if (!_board.containsKey(pos)) return true;
          }
        } else {
          // Otherwise, check adjacent positions
          for (Position adjacent in getAdjacentPositions(position)) {
            if (!_board.containsKey(adjacent)) return true;
          }
        }
      }
    }
    return false;
  }

  /// Reset the game
  void resetGame() {
    _board.clear();
    _currentPlayer = PieceType.white;
    _gamePhase = GamePhase.placing;
    _gameState = GameState.playing;
    _whitePiecesToPlace = 9;
    _blackPiecesToPlace = 9;
    _winner = null;
    _selectedPosition = null;
    _noCaptureMoves = 0;
    _stateHistory.clear();
    _terminationReason = null;
  }

  /// Serialize the game state to JSON for online sync
  Map<String, dynamic> toJson() {
    final boardData = <String, String>{};
    _board.forEach((position, piece) {
      final key = '${position.ring}_${position.point}';
      boardData[key] = piece.type == PieceType.white ? 'white' : 'black';
    });

    return {
      'board': boardData,
      'currentPlayer': _currentPlayer == PieceType.white ? 'white' : 'black',
      'gamePhase': _gamePhase.name,
      'gameState': _gameState.name,
      'whitePiecesToPlace': _whitePiecesToPlace,
      'blackPiecesToPlace': _blackPiecesToPlace,
      'winner': _winner?.name,
      'waitingForCapture': false, // Will be set by caller if needed
      'terminationReason': _terminationReason,
      'noCaptureMoves': _noCaptureMoves,
      'stateOccurrences': stateOccurrences,
    };
  }

  /// Load game state from JSON (for online sync)
  void loadFromJson(Map<String, dynamic> json) {
    _board.clear();

    final boardData = json['board'] as Map<String, dynamic>? ?? {};
    boardData.forEach((key, value) {
      final parts = key.split('_');
      if (parts.length == 2) {
        final ring = int.tryParse(parts[0]) ?? 0;
        final point = int.tryParse(parts[1]) ?? 0;
        final position = Position(ring: ring, point: point);
        final pieceType = value == 'white' ? PieceType.white : PieceType.black;
        _board[position] = Piece(type: pieceType);
      }
    });

    final currentPlayerStr = json['currentPlayer'] as String? ?? 'white';
    _currentPlayer = currentPlayerStr == 'white'
        ? PieceType.white
        : PieceType.black;

    final gamePhaseStr = json['gamePhase'] as String? ?? 'placing';
    _gamePhase = GamePhase.values.firstWhere(
      (e) => e.name == gamePhaseStr,
      orElse: () => GamePhase.placing,
    );

    final gameStateStr = json['gameState'] as String? ?? 'playing';
    _gameState = GameState.values.firstWhere(
      (e) => e.name == gameStateStr,
      orElse: () => GameState.playing,
    );

    _whitePiecesToPlace = json['whitePiecesToPlace'] as int? ?? 9;
    _blackPiecesToPlace = json['blackPiecesToPlace'] as int? ?? 9;

    final winnerStr = json['winner'] as String?;
    if (winnerStr != null) {
      _winner = winnerStr == 'white' ? PieceType.white : PieceType.black;
    } else {
      _winner = null;
    }

    _selectedPosition = null;

    // Restore draw detection state
    _terminationReason = json['terminationReason'] as String?;
    _noCaptureMoves = json['noCaptureMoves'] as int? ?? 0;

    // Restore state history from occurrence counts
    final occurrences = json['stateOccurrences'] as Map<String, dynamic>?;
    if (occurrences != null) {
      _stateHistory.clear();
      occurrences.forEach((key, value) {
        final count = (value is int) ? value : (value as num).toInt();
        for (int i = 0; i < count; i++) {
          _stateHistory.add(key);
        }
      });
    }
  }
}
