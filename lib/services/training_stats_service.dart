import 'package:shared_preferences/shared_preferences.dart';

/// Service to track and persist all-time training mode statistics
class TrainingStatsService {
  static final TrainingStatsService _instance =
      TrainingStatsService._internal();
  factory TrainingStatsService() => _instance;
  TrainingStatsService._internal();

  static const String _keyTotalPuzzles = 'training_total_puzzles';
  static const String _keyTotalScore = 'training_total_score';
  static const String _keyBestScore = 'training_best_score';
  static const String _keyPerfectMoves = 'training_perfect_moves';
  static const String _keyExcellentMoves = 'training_excellent_moves';
  static const String _keyGoodMoves = 'training_good_moves';
  static const String _keyOkayMoves = 'training_okay_moves';
  static const String _keyPoorMoves = 'training_poor_moves';
  static const String _keyCurrentStreak = 'training_current_streak';
  static const String _keyBestStreak = 'training_best_streak';

  // Training stats are local-only, so use a fixed prefix
  String _getKey(String key) => 'local_$key';

  int _totalPuzzles = 0;
  int _totalScore = 0;
  int _bestScore = 0;
  int _perfectMoves = 0;
  int _excellentMoves = 0;
  int _goodMoves = 0;
  int _okayMoves = 0;
  int _poorMoves = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;

  bool _isInitialized = false;

  // Getters
  int get totalPuzzles => _totalPuzzles;
  int get totalScore => _totalScore;
  int get bestScore => _bestScore;
  int get perfectMoves => _perfectMoves;
  int get excellentMoves => _excellentMoves;
  int get goodMoves => _goodMoves;
  int get okayMoves => _okayMoves;
  int get poorMoves => _poorMoves;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;

  double get averageScore =>
      _totalPuzzles > 0 ? _totalScore / _totalPuzzles : 0.0;

  /// Initialize the service and load saved stats
  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _totalPuzzles = prefs.getInt(_getKey(_keyTotalPuzzles)) ?? 0;
    _totalScore = prefs.getInt(_getKey(_keyTotalScore)) ?? 0;
    _bestScore = prefs.getInt(_getKey(_keyBestScore)) ?? 0;
    _perfectMoves = prefs.getInt(_getKey(_keyPerfectMoves)) ?? 0;
    _excellentMoves = prefs.getInt(_getKey(_keyExcellentMoves)) ?? 0;
    _goodMoves = prefs.getInt(_getKey(_keyGoodMoves)) ?? 0;
    _okayMoves = prefs.getInt(_getKey(_keyOkayMoves)) ?? 0;
    _poorMoves = prefs.getInt(_getKey(_keyPoorMoves)) ?? 0;
    _currentStreak = prefs.getInt(_getKey(_keyCurrentStreak)) ?? 0;
    _bestStreak = prefs.getInt(_getKey(_keyBestStreak)) ?? 0;

    _isInitialized = true;
  }

  Future<void> recordPuzzle(int score) async {
    _totalPuzzles++;
    _totalScore += score;

    if (score > _bestScore) {
      _bestScore = score;
    }

    // Categorize the move
    if (score >= 95) {
      _perfectMoves++;
      _currentStreak++;
    } else if (score >= 80) {
      _excellentMoves++;
      _currentStreak++;
    } else if (score >= 60) {
      _goodMoves++;
      _currentStreak = 0;
    } else if (score >= 40) {
      _okayMoves++;
      _currentStreak = 0;
    } else {
      _poorMoves++;
      _currentStreak = 0;
    }

    if (_currentStreak > _bestStreak) {
      _bestStreak = _currentStreak;
    }

    await _save();
  }

  /// Reset all statistics
  Future<void> resetStats() async {
    _totalPuzzles = 0;
    _totalScore = 0;
    _bestScore = 0;
    _perfectMoves = 0;
    _excellentMoves = 0;
    _goodMoves = 0;
    _okayMoves = 0;
    _poorMoves = 0;
    _currentStreak = 0;
    _bestStreak = 0;

    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getKey(_keyTotalPuzzles), _totalPuzzles);
    await prefs.setInt(_getKey(_keyTotalScore), _totalScore);
    await prefs.setInt(_getKey(_keyBestScore), _bestScore);
    await prefs.setInt(_getKey(_keyPerfectMoves), _perfectMoves);
    await prefs.setInt(_getKey(_keyExcellentMoves), _excellentMoves);
    await prefs.setInt(_getKey(_keyGoodMoves), _goodMoves);
    await prefs.setInt(_getKey(_keyOkayMoves), _okayMoves);
    await prefs.setInt(_getKey(_keyPoorMoves), _poorMoves);
    await prefs.setInt(_getKey(_keyCurrentStreak), _currentStreak);
    await prefs.setInt(_getKey(_keyBestStreak), _bestStreak);
  }

  /// Get a skill rating based on average score
  String getSkillRating() {
    if (_totalPuzzles < 10) return 'Novice';
    final avg = averageScore;
    if (avg >= 90) return 'Grandmaster';
    if (avg >= 80) return 'Master';
    if (avg >= 70) return 'Expert';
    if (avg >= 60) return 'Advanced';
    if (avg >= 50) return 'Intermediate';
    if (avg >= 40) return 'Apprentice';
    return 'Beginner';
  }
}
