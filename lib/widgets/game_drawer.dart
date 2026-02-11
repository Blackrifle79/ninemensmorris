import 'package:flutter/material.dart';
import '../utils/app_styles.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/performance_screen.dart';
import '../screens/home_screen.dart';
import '../screens/how_to_play_screen.dart';
import '../screens/strategy_guide_screen.dart';
import '../screens/history_screen.dart';
import '../services/auth_service.dart';

/// Shared drawer widget for use in home screen and game screen
class GameDrawer extends StatelessWidget {
  final bool showGameControls;
  final VoidCallback? onNewGame;
  final VoidCallback? onBackToHome;

  /// If provided, this is called when Home is tapped during a game.
  /// The callback should show a forfeit confirmation dialog.
  final VoidCallback? onHomePressed;

  const GameDrawer({
    super.key,
    this.showGameControls = false,
    this.onNewGame,
    this.onBackToHome,
    this.onHomePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppStyles.cream.withValues(alpha: 0.92),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Home (always first)
            ListTile(
              leading: const Icon(Icons.home, color: AppStyles.darkBrown),
              title: const Text('Home', style: AppStyles.bodyTextBold),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer first
                if (onHomePressed != null) {
                  // In a game - let the screen handle forfeit logic
                  onHomePressed!();
                } else {
                  // Not in a game - go directly home
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),

            // My Profile
            ListTile(
              leading: const Icon(Icons.person, color: AppStyles.darkBrown),
              title: const Text('My Profile', style: AppStyles.bodyTextBold),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            const Divider(color: AppStyles.mediumBrown),

            // Game controls (only shown during gameplay)
            if (showGameControls) ...[
              ListTile(
                leading: const Icon(Icons.refresh, color: AppStyles.darkBrown),
                title: const Text('New Game', style: AppStyles.bodyTextBold),
                onTap: () {
                  Navigator.of(context).pop();
                  onNewGame?.call();
                },
              ),
              const Divider(color: AppStyles.mediumBrown),
            ],

            // Performance
            ListTile(
              leading: const Icon(Icons.insights, color: AppStyles.darkBrown),
              title: const Text('Performance', style: AppStyles.bodyTextBold),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PerformanceScreen(),
                  ),
                );
              },
            ),

            const Divider(color: AppStyles.mediumBrown),

            // How to Play
            ListTile(
              leading: const Icon(
                Icons.help_outline,
                color: AppStyles.darkBrown,
              ),
              title: const Text('How to Play', style: AppStyles.bodyTextBold),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HowToPlayScreen(),
                  ),
                );
              },
            ),

            // Strategy Guide
            ListTile(
              leading: const Icon(
                Icons.lightbulb_outline,
                color: AppStyles.darkBrown,
              ),
              title: const Text(
                'Strategy Guide',
                style: AppStyles.bodyTextBold,
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StrategyGuideScreen(),
                  ),
                );
              },
            ),

            // History of the Game
            ListTile(
              leading: const Icon(
                Icons.history_edu,
                color: AppStyles.darkBrown,
              ),
              title: const Text('History', style: AppStyles.bodyTextBold),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(),
                  ),
                );
              },
            ),

            const Divider(color: AppStyles.mediumBrown),

            // Leaderboard (last in its own section)
            ListTile(
              leading: const Icon(
                Icons.leaderboard,
                color: AppStyles.darkBrown,
              ),
              title: const Text('Leaderboard', style: AppStyles.bodyTextBold),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
            ),

            const Spacer(),

            const Divider(color: AppStyles.mediumBrown),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: AppStyles.darkBrown),
              title: const Text('Logout', style: AppStyles.bodyTextBold),
              onTap: () => _confirmSignOut(context),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
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
              const Text('Sign Out', style: AppStyles.headingMedium),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to sign out?',
                style: AppStyles.bodyText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: AppStyles.primaryButtonStyle,
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: AppStyles.primaryButtonStyle,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm == true && context.mounted) {
      final auth = AuthService();
      await auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }
}
