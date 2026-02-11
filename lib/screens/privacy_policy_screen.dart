import 'package:flutter/material.dart';
import '../utils/app_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
        title: const Text('Privacy Policy', style: AppStyles.headingMediumLight),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: AppStyles.cream.withValues(alpha: 0.95),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last updated: February 11, 2026',
                        style: AppStyles.labelText.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        'Introduction',
                        'Nine Men\'s Morris ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.',
                      ),
                      _buildSection(
                        'Information We Collect',
                        '''When you create an account, we collect:
• Email address (for account authentication)
• Username (displayed publicly on leaderboards)
• Game statistics (wins, losses, scores)

If you sign in with Google, we receive your email address and display name from Google's authentication service.''',
                      ),
                      _buildSection(
                        'How We Use Your Information',
                        '''We use your information to:
• Create and manage your account
• Display your username on leaderboards
• Track your game statistics and progress
• Match you with opponents for online play
• Improve our game and services''',
                      ),
                      _buildSection(
                        'Data Storage',
                        'Your data is stored securely using Supabase, a cloud database service. We implement appropriate security measures to protect your personal information against unauthorized access, alteration, or destruction.',
                      ),
                      _buildSection(
                        'Third-Party Services',
                        '''We use the following third-party services:
• Supabase - Database and authentication
• Google Sign-In - Optional authentication method

These services have their own privacy policies governing the use of your information.''',
                      ),
                      _buildSection(
                        'Data Sharing',
                        'We do not sell, trade, or otherwise transfer your personal information to outside parties. Your username and game statistics are visible to other players on leaderboards.',
                      ),
                      _buildSection(
                        'Children\'s Privacy',
                        'Our app does not knowingly collect personal information from children under 13.',
                      ),
                      _buildSection(
                        'Your Rights',
                        '''You have the right to:
• Access your personal data
• Request deletion of your account and data
• Update your account information

To exercise these rights, use the account management features in the app.''',
                      ),
                      _buildSection(
                        'Changes to This Policy',
                        'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app. You are advised to review this Privacy Policy periodically for any changes.',
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          style: AppStyles.primaryButtonStyle,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppStyles.bodyTextBold.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppStyles.bodyText.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
