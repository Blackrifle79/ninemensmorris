import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/training_stats_service.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'auth_screen.dart';

class TrainingStatsScreen extends StatefulWidget {
  const TrainingStatsScreen({super.key});

  @override
  State<TrainingStatsScreen> createState() => _TrainingStatsScreenState();
}

class _TrainingStatsScreenState extends State<TrainingStatsScreen> {
  final TrainingStatsService _statsService = TrainingStatsService();
  bool _isLoading = true;

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
          _loadStats();
        } else {
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _statsService.init();
    setState(() {
      _isLoading = false;
    });
  }

  void _confirmResetStats() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppStyles.sharpBorder,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppStyles.dialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reset Statistics?',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will permanently erase all your training progress. This action cannot be undone.',
                style: AppStyles.bodyText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppStyles.primaryButtonStyle,
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _statsService.resetStats();
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.burgundy,
                      foregroundColor: AppStyles.cream,
                      side: const BorderSide(color: AppStyles.cream, width: 2),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppStyles.sharpBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        centerTitle: true,
        title: const Text(
          'Training Statistics',
          style: AppStyles.headingMediumLight,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
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
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Combined Stats Card
                              _buildCombinedStatsCard(),
                              const SizedBox(height: 24),

                              // Reset Button
                              if (_statsService.totalPuzzles > 0)
                                ElevatedButton.icon(
                                  onPressed: _confirmResetStats,
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppStyles.cream,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Reset All Statistics',
                                    style: AppStyles.buttonText,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppStyles.burgundy,
                                    foregroundColor: AppStyles.cream,
                                    side: const BorderSide(
                                      color: AppStyles.cream,
                                      width: 2,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: AppStyles.sharpBorder,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                            ],
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

  Widget _buildCombinedStatsCard() {
    final rating = _statsService.getSkillRating();
    // Total moves = sum of all quality categories
    final total =
        _statsService.perfectMoves +
        _statsService.excellentMoves +
        _statsService.goodMoves +
        _statsService.okayMoves +
        _statsService.poorMoves;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.9),
        borderRadius: AppStyles.sharpBorder,
      ),
      child: Column(
        children: [
          // Skill Rating
          Text(
            rating,
            style: const TextStyle(
              fontFamily: AppStyles.fontHeadline,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppStyles.darkBrown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _statsService.totalPuzzles < 10
                ? 'Complete ${10 - _statsService.totalPuzzles} more puzzles to earn a rank'
                : 'Your current skill rating',
            style: const TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: AppStyles.mediumBrown,
            ),
          ),

          const SizedBox(height: 24),
          Container(
            height: 1,
            color: AppStyles.darkBrown.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),

          // Overview Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Puzzles',
                  _statsService.totalPuzzles.toString(),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Average',
                  _statsService.totalPuzzles > 0
                      ? _statsService.averageScore.toStringAsFixed(1)
                      : '-',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            height: 1,
            color: AppStyles.darkBrown.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),

          // Move Quality
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Move Quality',
              style: TextStyle(
                fontFamily: AppStyles.fontHeadline,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppStyles.darkBrown,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildQualityBar(
            'Perfect (95-100)',
            _statsService.perfectMoves,
            total,
            Colors.green,
          ),
          const SizedBox(height: 10),
          _buildQualityBar(
            'Excellent (80-94)',
            _statsService.excellentMoves,
            total,
            Colors.lightGreen,
          ),
          const SizedBox(height: 10),
          _buildQualityBar(
            'Good (60-79)',
            _statsService.goodMoves,
            total,
            Colors.amber,
          ),
          const SizedBox(height: 10),
          _buildQualityBar(
            'Okay (40-59)',
            _statsService.okayMoves,
            total,
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _buildQualityBar(
            'Poor (0-39)',
            _statsService.poorMoves,
            total,
            Colors.red,
          ),

          const SizedBox(height: 24),
          Container(
            height: 1,
            color: AppStyles.darkBrown.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),

          // Streaks
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Streaks',
              style: TextStyle(
                fontFamily: AppStyles.fontHeadline,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppStyles.darkBrown,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Consecutive excellent or perfect moves',
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                color: AppStyles.mediumBrown,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStreakItem(
                  'Current',
                  _statsService.currentStreak,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStreakItem(
                  'Best',
                  _statsService.bestStreak,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppStyles.fontBody,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppStyles.darkBrown,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQualityBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppStyles.mediumBrown,
              ),
            ),
            Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 14,
                color: AppStyles.darkBrown,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppStyles.darkBrown.withValues(alpha: 0.15),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(decoration: BoxDecoration(color: color)),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontFamily: AppStyles.fontBody,
            fontSize: 32,
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
}
