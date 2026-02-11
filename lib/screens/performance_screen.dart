import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/scoring_service.dart';
import '../services/leaderboard_service.dart';
import '../services/training_stats_service.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final TrainingStatsService _statsService = TrainingStatsService();
  bool _isLoading = true;

  // Score data
  double _avgScore = 0;
  double _onlineScore = 0;
  double _offlineScore = 0;
  int _onlineGames = 0;
  int _offlineGames = 0;

  // Leaderboard rank
  int? _rank;
  int _totalPlayers = 0;

  // Win/loss/draw
  int _wins = 0;
  int _losses = 0;
  int _draws = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    if (AuthService().currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final loggedIn = await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => const AuthScreen()));
        if (!mounted) return;
        if (loggedIn == true) {
          _loadData();
        } else {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final user = AuthService().currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Load training stats
    await _statsService.init();

    final scoring = ScoringService();
    final scores = await scoring.getPlayerScores(user.id);

    // Fetch leaderboard rank using proper ranking API
    int? rank;
    int totalPlayers = 0;
    try {
      final leaderboardService = LeaderboardService();
      // Get total player count
      totalPlayers = await leaderboardService.getTotalCount();
      // Get player's rank directly
      final ranking = await leaderboardService.getPlayerRanking(user.id);
      rank = ranking['rank'] as int?;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _avgScore = (scores['avg_score'] as double?) ?? 0;
        _onlineScore = (scores['online_score'] as double?) ?? 0;
        _offlineScore = (scores['offline_score'] as double?) ?? 0;
        _onlineGames = (scores['online_games'] as int?) ?? 0;
        _offlineGames = (scores['offline_games'] as int?) ?? 0;
        _rank = rank;
        _totalPlayers = totalPlayers;
        // Get wins/losses/draws from scoring service (includes offline games)
        _wins = (scores['wins'] as int?) ?? 0;
        _losses = (scores['losses'] as int?) ?? 0;
        _draws = (scores['draws'] as int?) ?? 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppStyles.burgundy.withValues(alpha: 0.8),
        elevation: 0,
        foregroundColor: AppStyles.cream,
        iconTheme: const IconThemeData(color: AppStyles.cream),
        title: const Text('Performance', style: AppStyles.headingMediumLight),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppStyles.cream,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Column(
                                  children: [
                                    // Overall score card
                                    _buildOverallCard(),
                                    const SizedBox(height: 16),
                                    // Online / Offline breakdown
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildScoreCard(
                                            'Online',
                                            _onlineScore,
                                            _onlineGames,
                                            AppStyles.burgundy,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildScoreCard(
                                            'Offline',
                                            _offlineScore,
                                            _offlineGames,
                                            AppStyles.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Match history summary
                                    _buildRecordCard(),
                                    const SizedBox(height: 16),
                                    // Training stats
                                    _buildTrainingStatsCard(),
                                  ],
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildOverallCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.8),
        borderRadius: AppStyles.sharpBorder,
      ),
      child: Column(
        children: [
          const Text('Overall Score', style: AppStyles.labelText),
          const SizedBox(height: 12),
          // Score circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _avgScore / 100,
                    strokeWidth: 8,
                    backgroundColor: AppStyles.darkBrown.withValues(
                      alpha: 0.15,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppStyles.green,
                    ),
                  ),
                ),
                Text(
                  _avgScore.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: AppStyles.fontBody,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.darkBrown,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Rank
          if (_rank != null)
            Text(
              'Online Rank #$_rank of #$_totalPlayers',
              style: const TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                color: AppStyles.mediumBrown,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
    String label,
    double score,
    int games,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.8),
        borderRadius: AppStyles.sharpBorder,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // Score ring
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    backgroundColor: AppStyles.darkBrown.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
                Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: AppStyles.fontBody,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.darkBrown,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$games game${games == 1 ? '' : 's'}',
            style: const TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: AppStyles.mediumBrown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard() {
    final total = _wins + _losses + _draws;
    final winRate = total > 0 ? (_wins / total * 100) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.8),
        borderRadius: AppStyles.sharpBorder,
      ),
      child: Column(
        children: [
          const Text(
            'Match Record',
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: AppStyles.mediumBrown,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _recordItem('Wins', _wins, AppStyles.green),
              _recordItem('Losses', _losses, AppStyles.burgundy),
              _recordItem('Draws', _draws, AppStyles.mediumBrown),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: AppStyles.darkBrown.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            Text(
              'Win Rate: ${winRate.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.darkBrown,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recordItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontFamily: AppStyles.fontBody,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppStyles.fontBody,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppStyles.mediumBrown,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingStatsCard() {
    final rating = _statsService.getSkillRating();
    // Total moves = sum of all quality categories
    final total = _statsService.perfectMoves +
        _statsService.excellentMoves +
        _statsService.goodMoves +
        _statsService.okayMoves +
        _statsService.poorMoves;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.8),
        borderRadius: AppStyles.sharpBorder,
      ),
      child: Column(
        children: [
          const Text(
            'Training',
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: AppStyles.mediumBrown,
            ),
          ),
          const SizedBox(height: 16),

          // Skill Rating
          Text(
            rating,
            style: const TextStyle(
              fontFamily: AppStyles.fontHeadline,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppStyles.darkBrown,
            ),
          ),
          const SizedBox(height: 4),
          if (_statsService.totalPuzzles < 10)
            Text(
              'Complete ${10 - _statsService.totalPuzzles} more puzzles to earn a rank',
              style: const TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                color: AppStyles.mediumBrown,
              ),
            ),

          const SizedBox(height: 20),
          Container(
            height: 1,
            color: AppStyles.darkBrown.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 20),

          // Puzzles and Average
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _statsService.totalPuzzles.toString(),
                      style: const TextStyle(
                        fontFamily: AppStyles.fontBody,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.darkBrown,
                      ),
                    ),
                    const Text(
                      'Puzzles',
                      style: TextStyle(
                        fontFamily: AppStyles.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.mediumBrown,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _statsService.totalPuzzles > 0
                          ? _statsService.averageScore.toStringAsFixed(1)
                          : '-',
                      style: const TextStyle(
                        fontFamily: AppStyles.fontBody,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.darkBrown,
                      ),
                    ),
                    const Text(
                      'Average',
                      style: TextStyle(
                        fontFamily: AppStyles.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.mediumBrown,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (total > 0) ...[
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: AppStyles.darkBrown.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),

            // Move Quality
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Move Quality',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildQualityBar(
              'Perfect',
              _statsService.perfectMoves,
              total,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildQualityBar(
              'Excellent',
              _statsService.excellentMoves,
              total,
              Colors.lightGreen,
            ),
            const SizedBox(height: 8),
            _buildQualityBar(
              'Good',
              _statsService.goodMoves,
              total,
              Colors.amber,
            ),
            const SizedBox(height: 8),
            _buildQualityBar(
              'Okay',
              _statsService.okayMoves,
              total,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildQualityBar(
              'Poor',
              _statsService.poorMoves,
              total,
              Colors.red,
            ),

            const SizedBox(height: 20),
            Container(
              height: 1,
              color: AppStyles.darkBrown.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 20),

            // Streaks
            const Center(
              child: Text(
                'Streaks',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Consecutive excellent or perfect moves',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 14,
                  color: AppStyles.mediumBrown,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _statsService.currentStreak.toString(),
                        style: const TextStyle(
                          fontFamily: AppStyles.fontBody,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.green,
                        ),
                      ),
                      const Text(
                        'Current',
                        style: TextStyle(
                          fontFamily: AppStyles.fontBody,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.mediumBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _statsService.bestStreak.toString(),
                        style: const TextStyle(
                          fontFamily: AppStyles.fontBody,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.burgundy,
                        ),
                      ),
                      const Text(
                        'Best',
                        style: TextStyle(
                          fontFamily: AppStyles.fontBody,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.mediumBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: AppStyles.mediumBrown,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppStyles.darkBrown.withValues(alpha: 0.12),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(decoration: BoxDecoration(color: color)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text(
            '${(percentage * 100).toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppStyles.darkBrown,
            ),
          ),
        ),
      ],
    );
  }
}
