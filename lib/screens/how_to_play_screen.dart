import 'package:flutter/material.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'profile_screen.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

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
        title: const Text('How to Play', style: AppStyles.headingMediumLight),
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
                              'Objective',
                              'Reduce your opponent to only 2 pieces, making it impossible for them to form mills. Alternatively, block all their pieces so they have no legal moves.',
                            ),
                            _buildSection(
                              'The Board',
                              'The board has three concentric squares connected by lines at their midpoints, creating 24 intersection points where pieces can be placed. Each player starts with 9 pieces.',
                            ),
                            _buildSectionWithSubsections('Game Phases', [
                              (
                                'Phase 1: Placing',
                                'Players alternate placing one piece at a time on any empty intersection until all 18 pieces are on the board. During placement, try to set up mill opportunities while blocking your opponent\'s formations.',
                              ),
                              (
                                'Phase 2: Moving',
                                'Once all pieces are placed, players take turns sliding one piece along a line to an adjacent empty intersection. Pieces cannot jump over other pieces.',
                              ),
                              (
                                'Phase 3: Flying',
                                'When reduced to only 3 pieces, a player\'s pieces can "fly" to any empty intersection on the board, not just adjacent ones. This gives the disadvantaged player a fighting chance.',
                              ),
                            ]),
                            _buildSectionWithBullets(
                              'Forming Mills',
                              'A mill is three of your pieces in a straight line along one of the board\'s lines. When you form a mill, you must remove one of your opponent\'s pieces.',
                              [
                                'Pieces currently in a mill are protected and cannot be removed unless all opponent pieces are in mills.',
                                'You can break a mill by moving a piece out, then reform it on a later turn to capture again.',
                                'Strategic mill placement is key - try to create positions where you can repeatedly form and break mills.',
                              ],
                            ),
                            _buildSectionWithBullets(
                              'Winning',
                              'The game ends when one player wins:',
                              [
                                'Reduce your opponent to 2 pieces (they can no longer form mills)',
                                'Block all opponent pieces so they have no legal moves',
                              ],
                            ),
                            _buildSectionWithBullets('Tips for Beginners', null, [
                              'Control corner and center intersections where multiple lines meet',
                              'Create "double mills" - two potential mills that share one piece, guaranteeing a capture each turn',
                              'Spread your pieces across the board rather than clustering them',
                              'Watch for your opponent\'s mill threats and block them when possible',
                              'In the flying phase, mobility is your biggest advantage',
                            ]),
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

  Widget _buildSectionWithSubsections(
    String title,
    List<(String, String)> subsections,
  ) {
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
          const SizedBox(height: 12),
          ...subsections.map(
            (sub) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.$1,
                    style: const TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.mediumBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(sub.$2, style: AppStyles.bodyText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionWithBullets(
    String title,
    String? intro,
    List<String> bullets,
  ) {
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
          if (intro != null) ...[
            const SizedBox(height: 8),
            Text(intro, style: AppStyles.bodyText),
          ],
          const SizedBox(height: 8),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: AppStyles.bodyText),
                  Expanded(child: Text(bullet, style: AppStyles.bodyText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
