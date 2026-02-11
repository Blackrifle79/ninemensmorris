import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/position.dart';
import '../models/piece.dart';
import '../widgets/game_board.dart';
import '../widgets/game_drawer.dart';
import '../utils/app_styles.dart';
import '../services/training_stats_service.dart';
import 'profile_screen.dart';

/// Game-theoretic evaluation based on the mathematically solved database (Gasser 1996)
/// Key insights from perfect play:
/// 1. Mobility advantage is decisive - the player with more moves wins
/// 2. Double mills (shuttle mills) are usually game-winning
/// 3. Intersection control (even-numbered points) is strategically crucial
/// 4. In 3v3 flying phase, perfect play results in a draw
/// 5. Mill threats force defensive play, creating tempo advantages

/// Represents the result of evaluating a move
class MoveEvaluation {
  final int score; // 0 to 100
  final String rating;
  final String explanation;
  final Color ratingColor;

  MoveEvaluation({
    required this.score,
    required this.rating,
    required this.explanation,
    required this.ratingColor,
  });

  factory MoveEvaluation.fromScore(int score, String explanation) {
    String rating;
    Color color;
    if (score >= 90) {
      rating = 'Excellent!';
      color = const Color(0xFF2E7D32); // Solid green - good
    } else if (score >= 70) {
      rating = 'Great Move';
      color = const Color(0xFF388E3C); // Solid green - good
    } else if (score >= 50) {
      rating = 'Good';
      color = const Color(0xFF5D4037); // Solid brown - okay
    } else if (score >= 30) {
      rating = 'Okay';
      color = const Color(0xFF6D4C41); // Solid brown - okay
    } else if (score >= 10) {
      rating = 'Weak';
      color = const Color(0xFF8B0000); // Solid dark red - bad
    } else {
      rating = 'Blunder';
      color = const Color(0xFFB71C1C); // Solid red - bad
    }
    return MoveEvaluation(
      score: score,
      rating: rating,
      explanation: explanation,
      ratingColor: color,
    );
  }
}

/// Strategic position values based on game-theoretic analysis
/// Intersections (even points) can belong to 2 mills, corners (odd points) only 1
class PositionStrategicValue {
  /// Calculate the strategic value of a board position
  /// Higher values indicate more strategically important positions
  static int getValue(Position pos) {
    // Intersections (even points) are part of 2 potential mills
    if (pos.point % 2 == 0) {
      // Middle ring intersections are slightly more valuable (central control)
      if (pos.ring == 1) return 4;
      return 3;
    }
    // Corner positions (odd points) are part of only 1 mill
    // Middle ring corners have slightly better adjacency
    if (pos.ring == 1) return 2;
    return 1;
  }

  /// Get all positions sorted by strategic value (descending)
  static List<Position> getPositionsByValue() {
    final positions = GameModel.getAllPositions().toList();
    positions.sort((a, b) => getValue(b).compareTo(getValue(a)));
    return positions;
  }
}

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late GameModel _gameModel;
  final Random _random = Random();
  final TrainingStatsService _statsService = TrainingStatsService();

  MoveEvaluation? _lastEvaluation;
  bool _waitingForCapture = false;
  bool _showingResult = false;
  int _puzzlesSolved = 0;
  int _totalScore = 0;

  // Highlight state for mill and capture animations
  Set<Position>? _millHighlight;
  Position? _captureHighlight;
  bool _highlightingMill = false;
  bool _highlightingCapture = false;

  @override
  void initState() {
    super.initState();
    _gameModel = GameModel();
    _initStats();
  }

  Future<void> _initStats() async {
    await _statsService.init();
    _generateRandomPosition();
  }

  void _generateRandomPosition() {
    _gameModel = GameModel();
    _lastEvaluation = null;
    _waitingForCapture = false;
    _showingResult = false;
    _millHighlight = null;
    _captureHighlight = null;
    _highlightingMill = false;
    _highlightingCapture = false;

    // Even distribution across three phases (~33% each)
    final phase = _random.nextInt(3);

    if (phase == 0) {
      // PLACING PHASE (~33%)
      final placingType = _random.nextInt(5);
      if (placingType < 2) {
        _generateMillOpportunityPuzzle(); // 40% of placing
      } else if (placingType < 3) {
        _generateBlockMillPuzzle(); // 20% of placing
      } else if (placingType < 4) {
        _generateForkPuzzle(); // 20% of placing
      } else {
        _generateDefensivePuzzle(); // 20% of placing
      }
    } else if (phase == 1) {
      // MOVING PHASE (~33%)
      final movingType = _random.nextInt(4);
      if (movingType < 2) {
        _generateTacticalMovingPuzzle(); // 50% of moving
      } else if (movingType < 3) {
        _generateMovingDefensivePuzzle(); // 25% of moving
      } else {
        _generateMovingForkPuzzle(); // 25% of moving
      }
    } else {
      // FLYING PHASE (~33%)
      final flyingType = _random.nextInt(4);
      if (flyingType < 2) {
        _generateFlyingPhase(); // 50% of flying
      } else if (flyingType < 3) {
        _generateFlyingDefensivePuzzle(); // 25% of flying
      } else {
        _generateFlyingForkPuzzle(); // 25% of flying
      }
    }

    setState(() {});
  }

  /// Generate a puzzle where the player can form a mill
  void _generateMillOpportunityPuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Pick a random mill line
    final allMills = _getAllPossibleMills();
    allMills.shuffle(_random);
    final targetMill = allMills.first;

    // Place 2 pieces of current player in the mill (leaving one empty for completion)
    final emptyIndex = _random.nextInt(3);
    for (int i = 0; i < 3; i++) {
      if (i != emptyIndex) {
        _placePieceDirectly(targetMill[i], player);
      }
    }

    // Add some opponent pieces (not blocking the mill)
    final usedPositions = targetMill.toSet();
    final availablePositions =
        GameModel.getAllPositions()
            .where((p) => !usedPositions.contains(p))
            .toList()
          ..shuffle(_random);

    final opponentPieces = 2 + _random.nextInt(4);
    for (int i = 0; i < opponentPieces && i < availablePositions.length; i++) {
      _placePieceDirectly(availablePositions[i], opponent);
      usedPositions.add(availablePositions[i]);
    }

    // Add some more player pieces for variety
    final extraPlayerPieces = 1 + _random.nextInt(3);
    final remainingPositions = availablePositions.skip(opponentPieces).toList();
    for (
      int i = 0;
      i < extraPlayerPieces && i < remainingPositions.length;
      i++
    ) {
      _placePieceDirectly(remainingPositions[i], player);
    }

    _setPiecesToPlace(5, 5);
    _setGamePhase(GamePhase.placing);
    _setCurrentPlayer(player);
  }

  /// Generate a puzzle where opponent is about to form a mill
  void _generateBlockMillPuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Pick a random mill line for opponent
    final allMills = _getAllPossibleMills();
    allMills.shuffle(_random);
    final threatMill = allMills.first;

    // Place 2 opponent pieces in the mill (threat)
    final emptyIndex = _random.nextInt(3);
    for (int i = 0; i < 3; i++) {
      if (i != emptyIndex) {
        _placePieceDirectly(threatMill[i], opponent);
      }
    }

    // Add player pieces elsewhere
    final usedPositions = threatMill.toSet();
    final availablePositions =
        GameModel.getAllPositions()
            .where((p) => !usedPositions.contains(p))
            .toList()
          ..shuffle(_random);

    final playerPieces = 2 + _random.nextInt(4);
    for (int i = 0; i < playerPieces && i < availablePositions.length; i++) {
      _placePieceDirectly(availablePositions[i], player);
      usedPositions.add(availablePositions[i]);
    }

    // Maybe add more opponent pieces
    final extraOpponent = _random.nextInt(3);
    final remainingPositions = availablePositions.skip(playerPieces).toList();
    for (int i = 0; i < extraOpponent && i < remainingPositions.length; i++) {
      _placePieceDirectly(remainingPositions[i], opponent);
    }

    _setPiecesToPlace(4, 4);
    _setGamePhase(GamePhase.placing);
    _setCurrentPlayer(player);
  }

  /// Generate a fork puzzle - player must create two mill threats at once
  /// This requires thinking ahead: find the position that threatens multiple mills
  void _generateForkPuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Find an intersection that can create a fork (two mill threats)
    final intersections =
        GameModel.getAllPositions().where((p) => p.point % 2 == 0).toList()
          ..shuffle(_random);

    for (final forkPoint in intersections) {
      final mills = _getMillsContaining(forkPoint);
      if (mills.length < 2) continue;

      // Try to set up two partial mills that share this intersection
      final mill1 = mills[0];
      final mill2 = mills[1];

      // We need 1 piece in each mill (not at intersection) to create the fork
      final mill1Positions = mill1.where((p) => p != forkPoint).toList();
      final mill2Positions = mill2.where((p) => p != forkPoint).toList();

      if (mill1Positions.length < 2 || mill2Positions.length < 2) continue;

      // Place one piece in each mill (creates two threats when fork point filled)
      final posInMill1 = mill1Positions[_random.nextInt(mill1Positions.length)];
      Position posInMill2;
      do {
        posInMill2 = mill2Positions[_random.nextInt(mill2Positions.length)];
      } while (posInMill2 == posInMill1);

      _placePieceDirectly(posInMill1, player);
      _placePieceDirectly(posInMill2, player);

      // Add opponent pieces (but not blocking the fork)
      final usedPositions = {forkPoint, posInMill1, posInMill2};
      final availablePositions =
          GameModel.getAllPositions()
              .where((p) => !usedPositions.contains(p))
              .toList()
            ..shuffle(_random);

      // Add some distracting positions (decoy mill setups)
      final opponentPieces = 3 + _random.nextInt(3);
      for (
        int i = 0;
        i < opponentPieces && i < availablePositions.length;
        i++
      ) {
        _placePieceDirectly(availablePositions[i], opponent);
        usedPositions.add(availablePositions[i]);
      }

      // Add more player pieces (some as decoys)
      final extraPlayer = 2 + _random.nextInt(2);
      final remaining = availablePositions.skip(opponentPieces).toList();
      for (int i = 0; i < extraPlayer && i < remaining.length; i++) {
        if (remaining[i] != forkPoint) {
          _placePieceDirectly(remaining[i], player);
        }
      }

      _setPiecesToPlace(3, 3);
      _setGamePhase(GamePhase.placing);
      _setCurrentPlayer(player);
      return;
    }

    // Fallback
    _generateMillOpportunityPuzzle();
  }

  /// Generate a defensive puzzle - player must find the only move that doesn't lose
  /// Multiple opponent threats require careful analysis
  void _generateDefensivePuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    final allMills = _getAllPossibleMills();
    allMills.shuffle(_random);

    // Find two mills that share exactly one empty position (the defensive move)
    for (int i = 0; i < allMills.length; i++) {
      for (int j = i + 1; j < allMills.length; j++) {
        final mill1 = allMills[i];
        final mill2 = allMills[j];

        // Find shared position between the two mills
        final shared = mill1.where((p) => mill2.contains(p)).toList();
        if (shared.length != 1) continue;

        final defensivePos = shared.first;

        // Place 2 opponent pieces in each mill (both threatening)
        final mill1Others = mill1.where((p) => p != defensivePos).toList();
        final mill2Others = mill2.where((p) => p != defensivePos).toList();

        // Check for overlap that would cause conflicts
        if (mill1Others.any((p) => mill2Others.contains(p))) continue;

        // Set up the threatening position
        for (final p in mill1Others) {
          _placePieceDirectly(p, opponent);
        }
        for (final p in mill2Others) {
          _placePieceDirectly(p, opponent);
        }

        // Add player pieces elsewhere
        final usedPositions = {...mill1, ...mill2};
        final availablePositions =
            GameModel.getAllPositions()
                .where((p) => !usedPositions.contains(p))
                .toList()
              ..shuffle(_random);

        final playerPieces = 3 + _random.nextInt(3);
        for (
          int k = 0;
          k < playerPieces && k < availablePositions.length;
          k++
        ) {
          _placePieceDirectly(availablePositions[k], player);
          usedPositions.add(availablePositions[k]);
        }

        _setPiecesToPlace(3, 3);
        _setGamePhase(GamePhase.placing);
        _setCurrentPlayer(player);
        return;
      }
    }

    // Fallback to block mill puzzle
    _generateBlockMillPuzzle();
  }

  /// Generate a tactical moving phase puzzle
  void _generateTacticalMovingPuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Find a mill opportunity that can be completed by moving
    final allMills = _getAllPossibleMills();
    allMills.shuffle(_random);

    for (final mill in allMills) {
      // Try to set up a position where moving creates a mill
      final emptyIndex = _random.nextInt(3);
      final emptyPos = mill[emptyIndex];

      // Find an adjacent position for the piece to move from
      final adjacentPositions = _gameModel.getAdjacentPositions(emptyPos);
      if (adjacentPositions.isEmpty) continue;

      adjacentPositions.shuffle(_random);
      final fromPos = adjacentPositions.first;

      // Place the piece at fromPos
      _placePieceDirectly(fromPos, player);

      // Place other two pieces of the mill
      for (int i = 0; i < 3; i++) {
        if (i != emptyIndex) {
          _placePieceDirectly(mill[i], player);
        }
      }

      // Add more player pieces
      final usedPositions = {...mill, fromPos};
      final availablePositions =
          GameModel.getAllPositions()
              .where((p) => !usedPositions.contains(p))
              .toList()
            ..shuffle(_random);

      final extraPlayer = 2 + _random.nextInt(3);
      for (int i = 0; i < extraPlayer && i < availablePositions.length; i++) {
        _placePieceDirectly(availablePositions[i], player);
        usedPositions.add(availablePositions[i]);
      }

      // Add opponent pieces
      final remainingPositions = availablePositions.skip(extraPlayer).toList();
      final opponentPieces = 4 + _random.nextInt(3);
      for (
        int i = 0;
        i < opponentPieces && i < remainingPositions.length;
        i++
      ) {
        _placePieceDirectly(remainingPositions[i], opponent);
      }

      _setPiecesToPlace(0, 0);
      _setGamePhase(GamePhase.moving);
      _setCurrentPlayer(player);
      return;
    }

    // Fallback to mill opportunity (placing phase)
    _generateMillOpportunityPuzzle();
  }

  /// Get all possible mill combinations
  List<List<Position>> _getAllPossibleMills() {
    List<List<Position>> mills = [];

    // Horizontal/ring mills
    for (int ring = 0; ring < 3; ring++) {
      mills.add([
        Position(ring: ring, point: 7),
        Position(ring: ring, point: 0),
        Position(ring: ring, point: 1),
      ]);
      mills.add([
        Position(ring: ring, point: 1),
        Position(ring: ring, point: 2),
        Position(ring: ring, point: 3),
      ]);
      mills.add([
        Position(ring: ring, point: 3),
        Position(ring: ring, point: 4),
        Position(ring: ring, point: 5),
      ]);
      mills.add([
        Position(ring: ring, point: 5),
        Position(ring: ring, point: 6),
        Position(ring: ring, point: 7),
      ]);
    }

    // Vertical/radial mills (through intersections)
    for (int point = 0; point < 8; point += 2) {
      mills.add([
        Position(ring: 0, point: point),
        Position(ring: 1, point: point),
        Position(ring: 2, point: point),
      ]);
    }

    return mills;
  }

  void _generateFlyingPhase() {
    // One side has exactly 3 pieces (flying), other has 4-6
    final flyingSide = _random.nextBool() ? PieceType.white : PieceType.black;
    final otherSide = flyingSide == PieceType.white
        ? PieceType.black
        : PieceType.white;
    final otherPieces = 4 + _random.nextInt(3);

    final allPositions = GameModel.getAllPositions().toList()..shuffle(_random);

    int flyingPlaced = 0;
    int otherPlaced = 0;

    for (final pos in allPositions) {
      if (flyingPlaced < 3) {
        _placePieceDirectly(pos, flyingSide);
        flyingPlaced++;
      } else if (otherPlaced < otherPieces) {
        _placePieceDirectly(pos, otherSide);
        otherPlaced++;
      }
      if (flyingPlaced >= 3 && otherPlaced >= otherPieces) break;
    }

    _setPiecesToPlace(0, 0);
    _setGamePhase(
      GamePhase.moving,
    ); // Flying is now per-player based on piece count
    // The player with 3 pieces gets to move (can fly)
    _setCurrentPlayer(flyingSide);
  }

  /// Generate a moving phase puzzle where player must block multiple threats
  void _generateMovingDefensivePuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    final allMills = _getAllPossibleMills();
    allMills.shuffle(_random);

    // Find a mill that can be blocked by moving a player piece
    for (final mill in allMills) {
      final emptyIndex = _random.nextInt(3);
      final emptyPos = mill[emptyIndex];

      // Check if player has a piece adjacent to the empty position
      final adjacentToEmpty = _gameModel.getAdjacentPositions(emptyPos);
      if (adjacentToEmpty.isEmpty) continue;

      // Place opponent pieces threatening the mill
      for (int i = 0; i < 3; i++) {
        if (i != emptyIndex) {
          _placePieceDirectly(mill[i], opponent);
        }
      }

      // Place a player piece adjacent to the threat (can move to block)
      final blockFromPos =
          adjacentToEmpty[_random.nextInt(adjacentToEmpty.length)];
      if (mill.contains(blockFromPos)) continue;

      _placePieceDirectly(blockFromPos, player);

      // Add more pieces for both sides
      final usedPositions = {...mill, blockFromPos};
      final availablePositions =
          GameModel.getAllPositions()
              .where((p) => !usedPositions.contains(p))
              .toList()
            ..shuffle(_random);

      // Add 4-5 more player pieces
      final extraPlayer = 4 + _random.nextInt(2);
      for (int i = 0; i < extraPlayer && i < availablePositions.length; i++) {
        _placePieceDirectly(availablePositions[i], player);
        usedPositions.add(availablePositions[i]);
      }

      // Add 3-4 more opponent pieces
      final remaining = availablePositions.skip(extraPlayer).toList();
      final extraOpponent = 3 + _random.nextInt(2);
      for (int i = 0; i < extraOpponent && i < remaining.length; i++) {
        _placePieceDirectly(remaining[i], opponent);
      }

      _setPiecesToPlace(0, 0);
      _setGamePhase(GamePhase.moving);
      _setCurrentPlayer(player);
      return;
    }

    // Fallback
    _generateTacticalMovingPuzzle();
  }

  /// Generate a moving phase fork puzzle - move to create two mill threats
  void _generateMovingForkPuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Find an intersection that can create a fork
    final intersections =
        GameModel.getAllPositions().where((p) => p.point % 2 == 0).toList()
          ..shuffle(_random);

    for (final forkPoint in intersections) {
      final mills = _getMillsContaining(forkPoint);
      if (mills.length < 2) continue;

      final mill1 = mills[0];
      final mill2 = mills[1];

      // Find adjacent position to move from
      final adjacentToFork = _gameModel.getAdjacentPositions(forkPoint);
      if (adjacentToFork.isEmpty) continue;

      // Pick a position to move from (not in either mill)
      Position? fromPos;
      for (final adj in adjacentToFork) {
        if (!mill1.contains(adj) && !mill2.contains(adj)) {
          fromPos = adj;
          break;
        }
      }
      if (fromPos == null) continue;

      // Place the piece to be moved
      _placePieceDirectly(fromPos, player);

      // Place one piece in each partial mill
      final mill1Positions = mill1.where((p) => p != forkPoint).toList();
      final mill2Positions = mill2.where((p) => p != forkPoint).toList();

      if (mill1Positions.isEmpty || mill2Positions.isEmpty) continue;

      final posInMill1 = mill1Positions[_random.nextInt(mill1Positions.length)];
      Position posInMill2;
      int attempts = 0;
      do {
        posInMill2 = mill2Positions[_random.nextInt(mill2Positions.length)];
        attempts++;
      } while (posInMill2 == posInMill1 && attempts < 10);
      if (posInMill2 == posInMill1) continue;

      _placePieceDirectly(posInMill1, player);
      _placePieceDirectly(posInMill2, player);

      // Add more pieces
      final usedPositions = {forkPoint, fromPos, posInMill1, posInMill2};
      final availablePositions =
          GameModel.getAllPositions()
              .where((p) => !usedPositions.contains(p))
              .toList()
            ..shuffle(_random);

      final extraPlayer = 3 + _random.nextInt(2);
      for (int i = 0; i < extraPlayer && i < availablePositions.length; i++) {
        _placePieceDirectly(availablePositions[i], player);
        usedPositions.add(availablePositions[i]);
      }

      final remaining = availablePositions.skip(extraPlayer).toList();
      final opponentPieces = 5 + _random.nextInt(2);
      for (int i = 0; i < opponentPieces && i < remaining.length; i++) {
        _placePieceDirectly(remaining[i], opponent);
      }

      _setPiecesToPlace(0, 0);
      _setGamePhase(GamePhase.moving);
      _setCurrentPlayer(player);
      return;
    }

    // Fallback
    _generateTacticalMovingPuzzle();
  }

  /// Generate a flying phase defensive puzzle
  void _generateFlyingDefensivePuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    final allMills = _getAllPossibleMills();
    allMills.shuffle(_random);

    // Set up an opponent mill threat that player must fly to block
    for (final mill in allMills) {
      final emptyIndex = _random.nextInt(3);
      final emptyPos = mill[emptyIndex];

      // Place 2 opponent pieces in the mill (threat)
      for (int i = 0; i < 3; i++) {
        if (i != emptyIndex) {
          _placePieceDirectly(mill[i], opponent);
        }
      }

      // Place exactly 3 player pieces (flying phase) away from the block position
      final usedPositions = mill.toSet();
      final availablePositions =
          GameModel.getAllPositions()
              .where((p) => !usedPositions.contains(p) && p != emptyPos)
              .toList()
            ..shuffle(_random);

      if (availablePositions.length < 3) continue;

      for (int i = 0; i < 3; i++) {
        _placePieceDirectly(availablePositions[i], player);
        usedPositions.add(availablePositions[i]);
      }

      // Add more opponent pieces (4-5 total)
      final remaining = availablePositions
          .skip(3)
          .where((p) => p != emptyPos)
          .toList();
      final extraOpponent = 2 + _random.nextInt(2);
      for (int i = 0; i < extraOpponent && i < remaining.length; i++) {
        _placePieceDirectly(remaining[i], opponent);
      }

      _setPiecesToPlace(0, 0);
      _setGamePhase(GamePhase.moving);
      _setCurrentPlayer(player);
      return;
    }

    // Fallback
    _generateFlyingPhase();
  }

  /// Generate a flying phase fork puzzle - fly to create two threats
  void _generateFlyingForkPuzzle() {
    final player = _random.nextBool() ? PieceType.white : PieceType.black;
    final opponent = player == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Find an intersection that can create a fork when flown to
    final intersections =
        GameModel.getAllPositions().where((p) => p.point % 2 == 0).toList()
          ..shuffle(_random);

    for (final forkPoint in intersections) {
      final mills = _getMillsContaining(forkPoint);
      if (mills.length < 2) continue;

      final mill1 = mills[0];
      final mill2 = mills[1];

      // Place one piece in each partial mill (not at intersection)
      final mill1Others = mill1.where((p) => p != forkPoint).toList();
      final mill2Others = mill2.where((p) => p != forkPoint).toList();

      if (mill1Others.isEmpty || mill2Others.isEmpty) continue;

      final posInMill1 = mill1Others[_random.nextInt(mill1Others.length)];
      Position posInMill2;
      int attempts = 0;
      do {
        posInMill2 = mill2Others[_random.nextInt(mill2Others.length)];
        attempts++;
      } while (posInMill2 == posInMill1 && attempts < 10);
      if (posInMill2 == posInMill1) continue;

      _placePieceDirectly(posInMill1, player);
      _placePieceDirectly(posInMill2, player);

      // Place the third player piece somewhere else (will fly to fork point)
      final usedPositions = {forkPoint, posInMill1, posInMill2};
      usedPositions.addAll(mill1);
      usedPositions.addAll(mill2);

      final availablePositions =
          GameModel.getAllPositions()
              .where((p) => !usedPositions.contains(p))
              .toList()
            ..shuffle(_random);

      if (availablePositions.isEmpty) continue;

      _placePieceDirectly(availablePositions.first, player);

      // Add opponent pieces (4-5)
      final remaining = availablePositions
          .skip(1)
          .where((p) => p != forkPoint)
          .toList();
      final opponentPieces = 4 + _random.nextInt(2);
      for (int i = 0; i < opponentPieces && i < remaining.length; i++) {
        _placePieceDirectly(remaining[i], opponent);
      }

      _setPiecesToPlace(0, 0);
      _setGamePhase(GamePhase.moving);
      _setCurrentPlayer(player);
      return;
    }

    // Fallback
    _generateFlyingPhase();
  }

  // Helper methods to directly manipulate game state for setup
  void _placePieceDirectly(Position pos, PieceType type) {
    final json = _gameModel.toJson();
    final board = Map<String, String>.from(json['board'] as Map);
    board['${pos.ring}_${pos.point}'] = type == PieceType.white
        ? 'white'
        : 'black';
    json['board'] = board;
    _gameModel.loadFromJson(json);
  }

  void _setPiecesToPlace(int white, int black) {
    final json = _gameModel.toJson();
    json['whitePiecesToPlace'] = white;
    json['blackPiecesToPlace'] = black;
    _gameModel.loadFromJson(json);
  }

  void _setGamePhase(GamePhase phase) {
    final json = _gameModel.toJson();
    json['gamePhase'] = phase.name;
    _gameModel.loadFromJson(json);
  }

  void _setCurrentPlayer(PieceType player) {
    final json = _gameModel.toJson();
    json['currentPlayer'] = player == PieceType.white ? 'white' : 'black';
    _gameModel.loadFromJson(json);
  }

  /// Calculate the raw tactical value of a placing move (used for comparison)
  int _calculatePlacingMoveValue(Position position) {
    int value = 0;
    final opponent = _gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Completing a mill is highest priority (+100)
    if (_wouldCompleteMill(position, _gameModel.currentPlayer)) {
      value += 100;
    }

    // Blocking opponent's mill is critical (+90)
    if (_wouldCompleteMill(position, opponent)) {
      value += 90;
    }

    // Double mill setup is very strong (+60)
    final millsSetUp = _countMillsSetUp(position);
    if (millsSetUp >= 2) {
      value += 60;
    } else if (millsSetUp == 1) {
      value += 25;
    }

    // Strategic position value (+5-20)
    final posValue = PositionStrategicValue.getValue(position);
    value += posValue * 5;

    // Mobility (+3-9)
    final adjacentEmpty = _gameModel
        .getAdjacentPositions(position)
        .where((p) => !_gameModel.board.containsKey(p))
        .length;
    value += adjacentEmpty * 3;

    // Blocking opponent's mill setup (+15)
    if (_blocksOpponentMillSetup(position, opponent)) {
      value += 15;
    }

    // Penalty for clustering without purpose (-10)
    final adjacentFriendly = _gameModel
        .getAdjacentPositions(position)
        .where((p) => _gameModel.board[p]?.type == _gameModel.currentPlayer)
        .length;
    if (adjacentFriendly >= 2 && !_setsUpMill(position)) {
      value -= 10;
    }

    return value;
  }

  /// Evaluate a placing move using relative scoring (best move = 100)
  MoveEvaluation _evaluatePlacingMove(Position position) {
    List<String> positiveReasons = [];
    List<String> negativeReasons = [];
    final opponent = _gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Calculate value of player's move
    final playerMoveValue = _calculatePlacingMoveValue(position);

    // Find all move values for more nuanced scoring
    final emptyPositions = GameModel.getAllPositions()
        .where((p) => !_gameModel.board.containsKey(p))
        .toList();

    final allMoveValues = <int>[];
    int bestMoveValue = playerMoveValue;
    Position? bestMove;
    for (final pos in emptyPositions) {
      final value = _calculatePlacingMoveValue(pos);
      allMoveValues.add(value);
      if (value > bestMoveValue) {
        bestMoveValue = value;
        bestMove = pos;
      }
    }

    // Calculate score with more granularity
    int score;
    final bool isBestMove =
        bestMove == null || bestMoveValue == playerMoveValue;

    if (isBestMove) {
      // Perfect score
      score = 100;
    } else {
      // More nuanced scoring based on how close to optimal
      final gap = bestMoveValue - playerMoveValue;
      final range =
          bestMoveValue -
          (allMoveValues.isEmpty
              ? 0
              : allMoveValues.reduce((a, b) => a < b ? a : b));

      if (range > 0) {
        // Score based on position in range, with some randomness for variety
        final baseScore = ((1 - gap / range) * 75 + 15).round();
        // Add small variance (-3 to +3) for non-round numbers
        final variance = _random.nextInt(7) - 3;
        score = (baseScore + variance).clamp(5, 99);
      } else {
        score = 50 + _random.nextInt(10);
      }
    }

    // Collect positive reasons
    if (_wouldCompleteMill(position, _gameModel.currentPlayer)) {
      positiveReasons.add('you formed a mill');
    }

    if (_wouldCompleteMill(position, opponent)) {
      positiveReasons.add('you blocked your opponent\'s mill');
    }

    final millsSetUp = _countMillsSetUp(position);
    if (millsSetUp >= 2) {
      positiveReasons.add('you created a powerful double mill threat');
    } else if (millsSetUp == 1 && positiveReasons.length < 2) {
      positiveReasons.add('you set up a future mill');
    }

    final posValue = PositionStrategicValue.getValue(position);
    if (posValue >= 4 && positiveReasons.length < 2) {
      positiveReasons.add('you control a prime intersection');
    } else if (posValue >= 3 && positiveReasons.length < 2) {
      positiveReasons.add('you secured a key intersection');
    }

    if (_blocksOpponentMillSetup(position, opponent) &&
        positiveReasons.length < 2) {
      positiveReasons.add('you disrupted your opponent\'s setup');
    }

    // Collect negative reasons (only if not a perfect score)
    if (score < 100) {
      if (bestMove != null &&
          _wouldCompleteMill(bestMove, _gameModel.currentPlayer) &&
          !_wouldCompleteMill(position, _gameModel.currentPlayer)) {
        negativeReasons.add('you missed completing a mill');
      }

      final urgentBlock = _findUrgentBlock(opponent);
      if (urgentBlock != null &&
          urgentBlock != position &&
          !_wouldCompleteMill(position, opponent)) {
        negativeReasons.add('you failed to block your opponent\'s mill threat');
      }

      final adjacentFriendly = _gameModel
          .getAdjacentPositions(position)
          .where((p) => _gameModel.board[p]?.type == _gameModel.currentPlayer)
          .length;
      if (adjacentFriendly >= 2 && !_setsUpMill(position)) {
        negativeReasons.add(
          'your pieces are clustered without forming a threat',
        );
      }
    }

    String explanation = _buildExplanationFromLists(
      positiveReasons,
      negativeReasons,
      score,
    );
    return MoveEvaluation.fromScore(score, explanation);
  }

  /// Count how many mills this position would set up
  int _countMillsSetUp(Position pos) {
    int count = 0;
    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int friendlyCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (p == pos) continue;
        if (_gameModel.board[p]?.type == _gameModel.currentPlayer) {
          friendlyCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (friendlyCount == 1 && emptyCount == 1) count++;
    }
    return count;
  }

  /// Check if placing here blocks opponent's mill setup
  bool _blocksOpponentMillSetup(Position pos, PieceType opponent) {
    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int opponentCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (p == pos) continue;
        if (_gameModel.board[p]?.type == opponent) {
          opponentCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (opponentCount == 1 && emptyCount == 1) return true;
    }
    return false;
  }

  /// Find position that urgently needs to be blocked
  Position? _findUrgentBlock(PieceType opponent) {
    final emptyPositions = GameModel.getAllPositions()
        .where((p) => !_gameModel.board.containsKey(p))
        .toList();

    for (final pos in emptyPositions) {
      if (_wouldCompleteMill(pos, opponent)) {
        return pos;
      }
    }
    return null;
  }

  /// Build explanation from separate positive/negative lists with score context
  String _buildExplanationFromLists(
    List<String> positive,
    List<String> negative,
    int score,
  ) {
    // Perfect score - only positive feedback with strategic insight
    if (score == 100) {
      if (positive.isEmpty) {
        // Generic excellent explanations for when no specific reason
        final excellentReasons = [
          'Optimal play - you identified the best move in this position.',
          'Perfect tactical awareness - this move maximizes your advantage.',
          'Strong strategic thinking - you found the critical move.',
          'Excellent board vision - this is precisely the right choice.',
          'Sharp calculation - you navigated this position flawlessly.',
        ];
        return excellentReasons[_random.nextInt(excellentReasons.length)];
      }
      // Combine positive reasons with enthusiastic framing
      String result = positive
          .map((r) => '${r[0].toUpperCase()}${r.substring(1)}')
          .join(' and ');
      return '$result - excellent move!';
    }

    // Good score (70-99) - mostly positive, maybe hint at better
    if (score >= 70) {
      if (positive.isNotEmpty) {
        String result = positive
            .map((r) => '${r[0].toUpperCase()}${r.substring(1)}')
            .join(' and ');
        if (negative.isNotEmpty && negative.length == 1) {
          result += ', though ${negative.first}';
        }
        return '$result.';
      } else if (negative.isNotEmpty) {
        return '${negative.first[0].toUpperCase()}${negative.first.substring(1)}, but still a reasonable move.';
      }
      return 'A solid move that keeps you in a good position.';
    }

    // Medium score (40-69) - balanced feedback
    if (score >= 40) {
      String result = '';
      if (positive.isNotEmpty) {
        result = positive
            .map((r) => '${r[0].toUpperCase()}${r.substring(1)}')
            .join(' and ');
        if (negative.isNotEmpty) {
          result += ', but ${negative.join(' and ')}';
        }
        return '$result.';
      } else if (negative.isNotEmpty) {
        return '${negative.first[0].toUpperCase()}${negative.first.substring(1)}. Look for stronger alternatives.';
      }
      return 'An acceptable move, but there are better options.';
    }

    // Low score (<40) - focus on what went wrong
    if (negative.isNotEmpty) {
      String result = negative
          .map((r) => '${r[0].toUpperCase()}${r.substring(1)}')
          .join(' and ');
      return '$result. Consider the position more carefully.';
    }
    if (positive.isNotEmpty) {
      return '${positive.first[0].toUpperCase()}${positive.first.substring(1)}, but a much stronger move was available.';
    }
    return 'This move misses key tactical opportunities. Look deeper!';
  }

  /// Calculate the raw tactical value of a moving move (used for comparison)
  int _calculateMovingMoveValue(Position from, Position to) {
    int value = 0;
    final opponent = _gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Forming a mill is highest priority (+100)
    if (_wouldFormMillAfterMove(from, to)) {
      value += 100;
    }

    // Blocking opponent mill (+85)
    if (_wouldBlockOpponentMill(to, opponent)) {
      value += 85;
    }

    // Shuttle mill setup (+70)
    if (_createsShuttleMill(from, to)) {
      value += 70;
    }

    // Double mill setup (+50)
    final millsAtTo = _countMillsSetUp(to);
    if (millsAtTo >= 2) {
      value += 50;
    }

    // Setting up a mill (+25)
    if (_setsUpMillAfterMove(from, to)) {
      value += 25;
    }

    // Moving to intersection (+15)
    if (to.point % 2 == 0) {
      value += 15;
    }

    // Leaving intersection (-10)
    if (from.point % 2 == 0 && to.point % 2 != 0) {
      value -= 10;
    }

    // Mobility change
    final oldMobility = _gameModel
        .getAdjacentPositions(from)
        .where((p) => !_gameModel.board.containsKey(p) || p == from)
        .length;
    final newMobility = _gameModel
        .getAdjacentPositions(to)
        .where((p) => !_gameModel.board.containsKey(p) || p == from)
        .length;
    value += (newMobility - oldMobility) * 5;

    // Creating threat (+15)
    if (_wouldCreateThreat(to)) {
      value += 15;
    }

    // Penalty for trapped position (-20), unless player can fly
    int pieceCount = _gameModel.board.values
        .where((p) => p.type == _gameModel.currentPlayer)
        .length;
    bool canFly = pieceCount == 3;
    if (newMobility <= 1 && !canFly) {
      value -= 20;
    }

    // Penalty for breaking mill setup (-15)
    if (_wasPartOfMillSetup(from) && !_wouldFormMillAfterMove(from, to)) {
      value -= 15;
    }

    // Penalty for abandoning defense (-10)
    if (_wasDefendingMill(from) && !_wouldFormMillAfterMove(from, to)) {
      value -= 10;
    }

    return value;
  }

  /// Evaluate a moving/flying move using relative scoring (best move = 100)
  MoveEvaluation _evaluateMovingMove(Position from, Position to) {
    List<String> positiveReasons = [];
    List<String> negativeReasons = [];
    final opponent = _gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // Calculate value of player's move
    final playerMoveValue = _calculateMovingMoveValue(from, to);

    // Find all move values for more nuanced scoring
    final pieces = _gameModel.board.entries
        .where((e) => e.value.type == _gameModel.currentPlayer)
        .map((e) => e.key)
        .toList();

    final allMoveValues = <int>[];
    int bestMoveValue = playerMoveValue;
    Position? bestFrom;
    Position? bestTo;

    for (final piece in pieces) {
      final moves = _getValidMoves(piece);
      for (final move in moves) {
        final value = _calculateMovingMoveValue(piece, move);
        allMoveValues.add(value);
        if (value > bestMoveValue) {
          bestMoveValue = value;
          bestFrom = piece;
          bestTo = move;
        }
      }
    }

    // Calculate score with more granularity
    int score;
    final bool isBestMove =
        bestFrom == null || bestMoveValue == playerMoveValue;

    if (isBestMove) {
      score = 100;
    } else {
      // More nuanced scoring based on how close to optimal
      final minValue = allMoveValues.isEmpty
          ? 0
          : allMoveValues.reduce((a, b) => a < b ? a : b);
      final gap = bestMoveValue - playerMoveValue;
      final range = bestMoveValue - minValue;

      if (range > 0) {
        final baseScore = ((1 - gap / range) * 75 + 15).round();
        // Add small variance for non-round numbers
        final variance = _random.nextInt(7) - 3;
        score = (baseScore + variance).clamp(5, 99);
      } else if (bestMoveValue == 0 && playerMoveValue == 0) {
        score = 82 + _random.nextInt(8); // Neutral moves when no great options
      } else {
        score = 45 + _random.nextInt(15);
      }
    }

    // Collect positive reasons
    if (_wouldFormMillAfterMove(from, to)) {
      positiveReasons.add('you formed a mill');
    }

    if (_wouldBlockOpponentMill(to, opponent)) {
      positiveReasons.add('you blocked your opponent\'s mill');
    }

    if (_createsShuttleMill(from, to)) {
      positiveReasons.add('you set up a devastating shuttle mill');
    }

    final millsAtTo = _countMillsSetUp(to);
    if (millsAtTo >= 2 && !_wouldFormMillAfterMove(from, to)) {
      positiveReasons.add('you positioned for a double mill threat');
    }

    if (_setsUpMillAfterMove(from, to) && positiveReasons.length < 2) {
      positiveReasons.add('you set up a future mill');
    }

    if (to.point % 2 == 0 &&
        from.point % 2 != 0 &&
        positiveReasons.length < 2) {
      positiveReasons.add('you gained control of an intersection');
    }

    // Collect negative reasons (only if not a perfect score)
    if (score < 100) {
      if (bestTo != null &&
          _wouldFormMillAfterMove(bestFrom!, bestTo) &&
          !_wouldFormMillAfterMove(from, to)) {
        negativeReasons.add('you missed forming a mill');
      }

      final newMobility = _gameModel
          .getAdjacentPositions(to)
          .where((p) => !_gameModel.board.containsKey(p) || p == from)
          .length;
      int currentPieceCount = _gameModel.board.values
          .where((p) => p.type == _gameModel.currentPlayer)
          .length;
      bool currentCanFly = currentPieceCount == 3;
      if (newMobility <= 1 && !currentCanFly) {
        negativeReasons.add('you moved into a trapped position');
      }

      if (_wasPartOfMillSetup(from) && !_wouldFormMillAfterMove(from, to)) {
        negativeReasons.add('you broke up your own mill setup');
      }
    }

    String explanation = _buildExplanationFromLists(
      positiveReasons,
      negativeReasons,
      score,
    );
    return MoveEvaluation.fromScore(score, explanation);
  }

  /// Check if moving to a position creates a mill threat (2 pieces in a line)
  bool _wouldCreateThreat(Position to) {
    final mills = _getMillsContaining(to);
    for (final mill in mills) {
      int friendlyCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (p == to) continue;
        if (_gameModel.board[p]?.type == _gameModel.currentPlayer) {
          friendlyCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (friendlyCount == 1 && emptyCount == 1) return true;
    }
    return false;
  }

  /// Check if a piece was defending against opponent's mill threat
  bool _wasDefendingMill(Position pos) {
    final opponent = _gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int opponentCount = 0;
      for (final p in mill) {
        if (p == pos) continue;
        if (_gameModel.board[p]?.type == opponent) opponentCount++;
      }
      if (opponentCount == 2) return true;
    }
    return false;
  }

  /// Check if this move creates a shuttle mill opportunity
  bool _createsShuttleMill(Position from, Position to) {
    // A shuttle mill is when a piece can move back and forth between two positions,
    // forming a mill each time
    if (!_wouldFormMillAfterMove(from, to)) return false;

    // Check if moving back would also form a mill
    // (The 'from' position would now be empty after the move)
    final millsAtFrom = _getMillsContaining(from);
    for (final mill in millsAtFrom) {
      int count = 0;
      for (final p in mill) {
        if (p == from) continue;
        if (p == to) continue; // The piece won't be at 'to' if it moves back
        if (_gameModel.board[p]?.type == _gameModel.currentPlayer) count++;
      }
      if (count == 2) return true;
    }
    return false;
  }

  /// Check if move sets up a mill
  bool _setsUpMillAfterMove(Position from, Position to) {
    final mills = _getMillsContaining(to);
    for (final mill in mills) {
      int friendlyCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (p == to) continue;
        if (p == from) {
          emptyCount++; // This will be empty after the move
        } else if (_gameModel.board[p]?.type == _gameModel.currentPlayer) {
          friendlyCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (friendlyCount == 1 && emptyCount == 1) return true;
    }
    return false;
  }

  /// Check if position was part of a mill setup
  bool _wasPartOfMillSetup(Position pos) {
    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int friendlyCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (p == pos) {
          friendlyCount++; // Count the piece being moved
        } else if (_gameModel.board[p]?.type == _gameModel.currentPlayer) {
          friendlyCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (friendlyCount == 2 && emptyCount == 1) return true;
    }
    return false;
  }

  // Helper methods for evaluation
  bool _wouldCompleteMill(Position pos, PieceType player) {
    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int count = 0;
      for (final p in mill) {
        if (p == pos) continue;
        if (_gameModel.board[p]?.type == player) count++;
      }
      if (count == 2) return true;
    }
    return false;
  }

  bool _setsUpMill(Position pos) {
    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int friendlyCount = 0;
      int emptyCount = 0;
      for (final p in mill) {
        if (p == pos) continue;
        if (_gameModel.board[p]?.type == _gameModel.currentPlayer) {
          friendlyCount++;
        } else if (!_gameModel.board.containsKey(p)) {
          emptyCount++;
        }
      }
      if (friendlyCount == 1 && emptyCount == 1) return true;
    }
    return false;
  }

  bool _wouldFormMillAfterMove(Position from, Position to) {
    // Simulate the move
    final mills = _getMillsContaining(to);
    for (final mill in mills) {
      int count = 0;
      for (final p in mill) {
        if (p == to) {
          count++;
        } else if (p != from &&
            _gameModel.board[p]?.type == _gameModel.currentPlayer) {
          count++;
        }
      }
      if (count == 3) return true;
    }
    return false;
  }

  bool _wouldBlockOpponentMill(Position pos, PieceType opponent) {
    final mills = _getMillsContaining(pos);
    for (final mill in mills) {
      int count = 0;
      for (final p in mill) {
        if (p == pos) continue;
        if (_gameModel.board[p]?.type == opponent) count++;
      }
      if (count == 2) return true;
    }
    return false;
  }

  List<Position> _getValidMoves(Position from) {
    // Flying is per-player: only the player with exactly 3 pieces can fly
    int pieceCount = _gameModel.board.values
        .where((p) => p.type == _gameModel.currentPlayer)
        .length;
    bool canFly = pieceCount == 3 && _gameModel.gamePhase != GamePhase.placing;

    if (canFly) {
      return GameModel.getAllPositions()
          .where((p) => !_gameModel.board.containsKey(p))
          .toList();
    }
    return _gameModel
        .getAdjacentPositions(from)
        .where((p) => !_gameModel.board.containsKey(p))
        .toList();
  }

  /// Get all mills containing a position - delegates to GameModel
  List<List<Position>> _getMillsContaining(Position pos) {
    return _gameModel.getMillsContaining(pos);
  }

  /// Find the mill that was just formed at the given position - delegates to GameModel
  Set<Position> _findFormedMill(Position pos) {
    return _gameModel.findFormedMill(pos);
  }

  void _handleTap(Position position) {
    if (_showingResult || _gameModel.gameState == GameState.gameOver) return;
    if (_highlightingMill || _highlightingCapture) {
      return; // Block input during highlights
    }

    setState(() {
      if (_waitingForCapture) {
        _handleCapture(position);
      } else if (_gameModel.gamePhase == GamePhase.placing) {
        _handlePlacing(position);
      } else {
        _handleMoving(position);
      }
    });
  }

  void _handlePlacing(Position position) {
    if (_gameModel.board.containsKey(position)) return;

    final evaluation = _evaluatePlacingMove(position);

    if (_gameModel.placePiece(position)) {
      _lastEvaluation = evaluation;
      _puzzlesSolved++;
      _totalScore += evaluation.score;
      _statsService.recordPuzzle(evaluation.score);

      // Check if a mill was formed
      if (_gameModel.isInMill(position)) {
        // Find and highlight the mill positions
        final millPositions = _findFormedMill(position);
        _millHighlight = millPositions;
        _highlightingMill = true;

        // Brief pause then allow capture (keep highlight visible)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              // Keep _millHighlight visible - don't clear it
              _highlightingMill = false;
              _waitingForCapture = true;
            });
          }
        });
      } else {
        _showingResult = true;
      }
    }
  }

  void _handleMoving(Position position) {
    if (_gameModel.selectedPosition == null) {
      // Select a piece
      if (_gameModel.board.containsKey(position) &&
          _gameModel.board[position]!.type == _gameModel.currentPlayer) {
        _gameModel.selectPosition(position);
      }
    } else {
      // Try to move
      if (position == _gameModel.selectedPosition) {
        _gameModel.selectPosition(null);
        return;
      }

      final from = _gameModel.selectedPosition!;
      final evaluation = _evaluateMovingMove(from, position);

      if (_gameModel.movePiece(from, position)) {
        _lastEvaluation = evaluation;
        _puzzlesSolved++;
        _totalScore += evaluation.score;
        _statsService.recordPuzzle(evaluation.score);
        _gameModel.selectPosition(null);

        // Check if a mill was formed
        if (_gameModel.isInMill(position)) {
          // Find and highlight the mill positions
          final millPositions = _findFormedMill(position);
          _millHighlight = millPositions;
          _highlightingMill = true;

          // Brief pause then allow capture (keep highlight visible)
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                // Keep _millHighlight visible - don't clear it
                _highlightingMill = false;
                _waitingForCapture = true;
              });
            }
          });
        } else {
          _showingResult = true;
        }
      } else {
        // Invalid move, try selecting the new position
        if (_gameModel.board.containsKey(position) &&
            _gameModel.board[position]!.type == _gameModel.currentPlayer) {
          _gameModel.selectPosition(position);
        }
      }
    }
  }

  void _handleCapture(Position position) {
    if (!_gameModel.board.containsKey(position)) return;
    if (_gameModel.board[position]!.type == _gameModel.currentPlayer) return;

    // Check if this is a valid capture (not in a mill, unless all are in mills)
    if (_gameModel.isInMill(position)) {
      // Check if there are any opponent pieces not in mills
      final opponent = _gameModel.currentPlayer == PieceType.white
          ? PieceType.black
          : PieceType.white;
      final hasNonMillPieces = _gameModel.board.entries
          .where((e) => e.value.type == opponent)
          .any((e) => !_gameModel.isInMill(e.key));
      if (hasNonMillPieces) {
        return; // Can't capture from mill if other pieces available
      }
    }

    // Show red highlight on the piece to be captured
    _captureHighlight = position;
    _highlightingCapture = true;
    _waitingForCapture = false;

    // After 2 seconds, actually capture the piece and show result
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _gameModel.capturePiece(position);
          _captureHighlight = null;
          _millHighlight = null; // Clear mill highlight after capture
          _highlightingCapture = false;
          _showingResult = true;
        });
      }
    });
  }

  String _getPhaseDescription() {
    switch (_gameModel.gamePhase) {
      case GamePhase.placing:
        return 'Placing Phase';
      case GamePhase.moving:
      case GamePhase.flying:
        // Check if current player can fly
        int pieceCount = _gameModel.board.values
            .where((p) => p.type == _gameModel.currentPlayer)
            .length;
        if (pieceCount == 3) {
          return 'Flying Phase';
        }
        return 'Moving Phase';
    }
  }

  Widget _buildPieceToken(PieceType type, double size) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MiniPiecePainter(
        isWhite: type == PieceType.white,
        radius: size / 2,
      ),
    );
  }

  Widget _buildInstructionRow() {
    final opponent = _gameModel.currentPlayer == PieceType.white
        ? PieceType.black
        : PieceType.white;

    // When showing result, show continue message (maintains layout)
    if (_showingResult) {
      return const Text(
        'Click Next Puzzle to continue',
        style: TextStyle(
          fontFamily: AppStyles.fontBody,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppStyles.mediumBrown,
        ),
      );
    }

    // During mill highlight, show mill formed message (maintains height)
    if (_highlightingMill) {
      return const Text(
        'Mill formed!',
        style: TextStyle(
          fontFamily: AppStyles.fontBody,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppStyles.mediumBrown,
        ),
      );
    }

    // During capture highlight, show capturing message (maintains height)
    if (_highlightingCapture) {
      return const Text(
        'Capturing...',
        style: TextStyle(
          fontFamily: AppStyles.fontBody,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppStyles.mediumBrown,
        ),
      );
    }

    if (_waitingForCapture) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Capture ',
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppStyles.mediumBrown,
            ),
          ),
          _buildPieceToken(opponent, 14),
        ],
      );
    }

    switch (_gameModel.gamePhase) {
      case GamePhase.placing:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Place ',
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.mediumBrown,
              ),
            ),
            _buildPieceToken(_gameModel.currentPlayer, 14),
            const Text(
              ' on an empty spot',
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.mediumBrown,
              ),
            ),
          ],
        );
      case GamePhase.moving:
      case GamePhase.flying:
        // Check if current player can fly (has exactly 3 pieces)
        int pieceCount = _gameModel.board.values
            .where((p) => p.type == _gameModel.currentPlayer)
            .length;
        bool canFly = pieceCount == 3;

        if (canFly) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Fly ',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.mediumBrown,
                ),
              ),
              _buildPieceToken(_gameModel.currentPlayer, 14),
              const Text(
                ' to any empty space',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.mediumBrown,
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Move ',
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.mediumBrown,
              ),
            ),
            _buildPieceToken(_gameModel.currentPlayer, 14),
            const Text(
              ' to an adjacent space',
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.mediumBrown,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerColor = _gameModel.currentPlayer == PieceType.white
        ? 'White'
        : 'Black';

    return Scaffold(
      backgroundColor: AppStyles.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppStyles.burgundy.withValues(alpha: 0.8),
        elevation: 0,
        foregroundColor: AppStyles.cream,
        iconTheme: const IconThemeData(color: AppStyles.cream),
        title: const Text('Training Mode', style: AppStyles.headingMediumLight),
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
      drawer: GameDrawer(
        showGameControls: false,
        onBackToHome: () => Navigator.of(context).pop(),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tavern.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
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
          // Content with overlay for full-width scoring
          Stack(
            children: [
              // Main content with SafeArea
              SafeArea(
                child: Column(
                  children: [
                    // Stats bar
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyles.cream.withValues(alpha: 0.92),
                        borderRadius: AppStyles.sharpBorder,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Puzzles',
                                style: TextStyle(
                                  fontFamily: AppStyles.fontBody,
                                  color: AppStyles.mediumBrown,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$_puzzlesSolved',
                                style: const TextStyle(
                                  color: AppStyles.darkBrown,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Avg Score',
                                style: TextStyle(
                                  fontFamily: AppStyles.fontBody,
                                  color: AppStyles.mediumBrown,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _puzzlesSolved > 0
                                    ? '${(_totalScore / _puzzlesSolved).round()}'
                                    : '-',
                                style: const TextStyle(
                                  color: AppStyles.darkBrown,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Phase and turn info
                    Container(
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 0,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppStyles.cream.withValues(alpha: 0.92),
                        borderRadius: AppStyles.sharpBorder,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPieceToken(_gameModel.currentPlayer, 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _showingResult
                                      ? 'Puzzle Complete!'
                                      : '$playerColor to move • ${_getPhaseDescription()}',
                                  style: const TextStyle(
                                    fontFamily: AppStyles.fontBody,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.darkBrown,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionRow(),
                        ],
                      ),
                    ),

                    // Game board
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 0,
                          bottom: 16,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: GameBoard(
                              gameModel: _gameModel,
                              onPositionTapped: _handleTap,
                              millHighlight: _millHighlight,
                              captureHighlight: _captureHighlight,
                              waitingForCapture: _waitingForCapture,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Full-width scoring overlay (outside SafeArea)
              if (_showingResult && _lastEvaluation != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppStyles.burgundy.withValues(alpha: 0.8),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _lastEvaluation!.ratingColor.withValues(
                              alpha: 0.8,
                            ),
                            border: Border.all(
                              color: AppStyles.cream,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${_lastEvaluation!.score}',
                              style: const TextStyle(
                                fontFamily: AppStyles.fontBody,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.cream,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            _lastEvaluation!.explanation,
                            style: const TextStyle(
                              fontFamily: AppStyles.fontBody,
                              fontSize: 14,
                              color: AppStyles.cream,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generateRandomPosition,
                          style: AppStyles.primaryButtonStyle,
                          child: const Text(
                            'Next Puzzle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for mini 3D pieces that match the game board
class _MiniPiecePainter extends CustomPainter {
  final bool isWhite;
  final double radius;

  _MiniPiecePainter({required this.isWhite, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Shadow underneath the piece
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      center + Offset(radius * 0.1, radius * 0.1),
      radius,
      shadowPaint,
    );

    // Base color gradient for 3D effect
    final baseGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: isWhite
          ? [Colors.white, const Color(0xFFE0E0E0), const Color(0xFFB0B0B0)]
          : [const Color(0xFF4A4A4A), const Color(0xFF2A2A2A), Colors.black],
      stops: const [0.0, 0.6, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, basePaint);

    // Highlight on top-left for shine
    final highlightGradient = RadialGradient(
      center: const Alignment(-0.5, -0.5),
      radius: 0.8,
      colors: isWhite
          ? [
              Colors.white.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.0),
            ]
          : [
              Colors.white.withValues(alpha: 0.3),
              Colors.white.withValues(alpha: 0.0),
            ],
      stops: const [0.0, 1.0],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: center, radius: radius * 0.7),
      );
    canvas.drawCircle(
      center + Offset(-radius * 0.2, -radius * 0.2),
      radius * 0.5,
      highlightPaint,
    );

    // Subtle rim/edge highlight
    final rimPaint = Paint()
      ..color = isWhite
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
