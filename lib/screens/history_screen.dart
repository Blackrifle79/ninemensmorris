import 'package:flutter/material.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'profile_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
        title: const Text('History', style: AppStyles.headingMediumLight),
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
                              'Ancient Origins',
                              'Nine Men\'s Morris is one of the oldest known board games, with evidence dating back over 2,000 years. The game has been played across countless civilizations, from ancient Egypt to the Roman Empire and beyond.',
                            ),
                            _buildSection(
                              'Egyptian Artifacts',
                              'Some of the earliest known boards were found carved into roofing slabs at the temple of Kurna in Egypt. While their exact date remains debated among historians, these carvings demonstrate the game\'s ancient presence in the region.',
                            ),
                            _buildSection(
                              'Roman Popularity',
                              'The Roman poet Ovid mentioned the game around 8 CE in his work "Ars Amatoria." The game was particularly popular among Roman soldiers, who likely spread it throughout the empire via trade routes and military campaigns.',
                            ),
                            _buildSection(
                              'Medieval Peak',
                              'The game reached its height of popularity in medieval England. Boards have been found carved into cloister seats at Canterbury, Gloucester, Norwich, and Salisbury cathedrals, as well as Westminster Abbey - perhaps carved by monks seeking entertainment between prayers. Giant outdoor boards were cut into village greens, and Shakespeare referenced this in "A Midsummer Night\'s Dream" when Titania says: "The nine men\'s morris is filled up with mud."',
                            ),
                            _buildSection(
                              'The Name',
                              'Despite appearances, "morris" has nothing to do with Morris dancing. It derives from the Latin word "merellus," meaning a counter or gaming piece. The game goes by many names: Mill, Merels, Merrills, and in North America, sometimes "Cowboy Checkers."',
                            ),
                            _buildSectionWithBullets(
                              'Global Variations',
                              'Variations of the game exist worldwide:',
                              [
                                'Three Men\'s Morris - a simpler version with fewer pieces',
                                'Six Men\'s Morris - popular in medieval Italy and France',
                                'Twelve Men\'s Morris (Morabaraba) - popular in South Africa and now an official sport',
                                'Lasker Morris - invented by chess world champion Emanuel Lasker, featuring 10 pieces per player',
                              ],
                            ),
                            _buildSection(
                              'Symbolic Meaning',
                              'In some European cultures, the board design held special significance as a symbol of protection. The concentric squares were thought to represent the universe, with the center being a place of power and cosmic importance.',
                            ),
                            _buildSection(
                              'Modern Era',
                              'In 1996, mathematician Ralph Gasser used computer analysis to "solve" the game, proving that with perfect play from both sides, every game ends in a draw. Despite this mathematical certainty, the game remains enjoyable because achieving perfect play is extraordinarily difficult for human minds.',
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

  Widget _buildSectionWithBullets(
    String title,
    String intro,
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
          const SizedBox(height: 8),
          Text(intro, style: AppStyles.bodyText),
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
