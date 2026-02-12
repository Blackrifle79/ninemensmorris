import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/ai_service.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'privacy_policy_screen.dart';
import 'profile_screen.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final AudioService _audioService = AudioService();
  final AIService _aiService = AIService();
  late bool _musicEnabled;
  late double _volume;
  late AIDifficulty _selectedDifficulty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _musicEnabled = _audioService.isMusicEnabled;
    _volume = _audioService.volume;
    _selectedDifficulty = AIDifficulty.medium;
    _loadDifficulty();
  }

  Future<void> _loadDifficulty() async {
    await _aiService.loadDifficulty();
    if (mounted) {
      setState(() {
        _selectedDifficulty = _aiService.difficulty;
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
        centerTitle: true,
        title: const Text('Options', style: AppStyles.headingMediumLight),
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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: AppStyles.cream.withValues(alpha: 0.9),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppStyles.darkBrown,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // AI Difficulty section
                                  const Text(
                                    'AI Difficulty',
                                    style: AppStyles.bodyTextBold,
                                  ),
                                  const SizedBox(height: 12),
                                  ...AIDifficulty.values.map(
                                    (difficulty) =>
                                        _buildDifficultyOption(difficulty),
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(color: AppStyles.mediumBrown),
                                  const SizedBox(height: 16),

                                  // Music toggle
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Music',
                                        style: AppStyles.bodyTextBold,
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _musicEnabled = !_musicEnabled;
                                          });
                                          _audioService.setMusicEnabled(
                                            _musicEnabled,
                                          );
                                        },
                                        child: Container(
                                          width: 48,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: _musicEnabled
                                                ? AppStyles.green
                                                : AppStyles.lightCream,
                                            border: Border.all(
                                              color: AppStyles.darkBrown,
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              _musicEnabled ? 'ON' : 'OFF',
                                              style: TextStyle(
                                                fontFamily: AppStyles.fontBody,
                                                color: _musicEnabled
                                                    ? AppStyles.cream
                                                    : AppStyles.darkBrown,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Volume slider
                                  const Text(
                                    'Volume',
                                    style: AppStyles.bodyTextBold,
                                  ),
                                  const SizedBox(height: 8),
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10,
                                      ),
                                      activeTrackColor: AppStyles.green,
                                      inactiveTrackColor: AppStyles.mediumBrown
                                          .withValues(alpha: 0.4),
                                      thumbColor: AppStyles.darkBrown,
                                      overlayColor: AppStyles.green.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    child: Slider(
                                      value: _volume,
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: _musicEnabled
                                          ? (value) {
                                              setState(() {
                                                _volume = value;
                                              });
                                              _audioService.setVolume(value);
                                            }
                                          : null,
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(color: AppStyles.mediumBrown),
                                  const SizedBox(height: 16),

                                  // Privacy Policy link
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PrivacyPolicyScreen(),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Privacy Policy',
                                          style: AppStyles.bodyTextBold,
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppStyles.mediumBrown,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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

  Widget _buildDifficultyOption(AIDifficulty difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedDifficulty = difficulty;
        });
        await _aiService.setDifficulty(difficulty);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppStyles.burgundy.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppStyles.cream : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppStyles.cream : AppStyles.mediumBrown,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 16,
                        weight: 900,
                        color: AppStyles.burgundy,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.displayName,
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppStyles.cream : AppStyles.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    difficulty.description,
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 14,
                      color: isSelected
                          ? AppStyles.cream.withValues(alpha: 0.8)
                          : AppStyles.mediumBrown,
                    ),
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
