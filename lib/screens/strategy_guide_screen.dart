import 'package:flutter/material.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'profile_screen.dart';

class StrategyGuideScreen extends StatelessWidget {
  const StrategyGuideScreen({super.key});

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
          'Strategy Guide',
          style: AppStyles.headingMediumLight,
        ),
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
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSection(
                              'Opening Strategy',
                              'Focus on placing pieces in versatile locations rather than rushing to form mills. Pieces at midpoints (where lines connect the three squares) are more valuable than corners because they access more potential mills. Spread your pieces across the board to keep your options open.',
                            ),
                            _buildSection(
                              'The Double Mill',
                              'The most powerful position in Nine Men\'s Morris is the double mill - two mills sharing a single piece. By moving that shared piece back and forth, you capture a piece every turn. Setting up a double mill almost always leads to victory because your opponent cannot defend fast enough.',
                            ),
                            _buildSection(
                              'Key Positions',
                              'The intersections where lines meet from multiple directions are the most valuable. The midpoints connecting the three squares give you access to six different potential mills. Control these positions to dominate the board.',
                            ),
                            _buildSection(
                              'Defensive Play',
                              'Always watch for your opponent\'s two-in-a-row formations and consider blocking the third position. However, pure defense loses games. The best players balance blocking threats with advancing their own mill setups.',
                            ),
                            _buildSection(
                              'Piece Distribution',
                              'Avoid clustering all your pieces in one area. Well-distributed pieces are harder to block and create mill opportunities across the entire board. A trapped cluster of pieces is useless even if you have more total pieces.',
                            ),
                            _buildSection(
                              'Endgame Strategy',
                              'When ahead in pieces, focus on trapping your opponent\'s remaining pieces and limiting their movement options. When reduced to 3 pieces and able to fly, use your mobility to set up surprise mills and escape traps. Flying pieces are extremely dangerous - a skilled player can often win from this position.',
                            ),
                            _buildSection(
                              'Perfect Play',
                              'Nine Men\'s Morris was mathematically solved in 1996 - with perfect play from both sides, the game ends in a draw. However, the complexity means human games rarely see perfect play. Good strategy gives you a significant advantage over opponents who play casually.',
                            ),
                            const SizedBox(height: 16),
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

  Widget _buildSection(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.8),
        borderRadius: AppStyles.sharpBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppStyles.darkBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: AppStyles.bodyText),
        ],
      ),
    );
  }
}
