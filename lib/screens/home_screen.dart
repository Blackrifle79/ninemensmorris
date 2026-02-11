import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'game_screen.dart';
import 'auth_screen.dart';
import 'online_lobby_screen.dart';
import 'training_screen.dart';
import 'profile_screen.dart';
import 'options_screen.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import '../services/auth_service.dart';

/// Game mode for offline play
enum OfflineGameMode { passAndPlay, vsAI }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  late StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes to update the logout button
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _authService.isLoggedIn;

    return Scaffold(
      backgroundColor: AppStyles.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppStyles.burgundy.withValues(alpha: 0.8),
        elevation: 0,
        foregroundColor: AppStyles.cream,
        iconTheme: const IconThemeData(color: AppStyles.cream),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: AppStyles.cream),
            onPressed: () {
              if (isLoggedIn) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
              }
            },
            tooltip: isLoggedIn ? 'Profile' : 'Sign In',
          ),
        ],
      ),
      drawer: const GameDrawer(showGameControls: false),
      body: Stack(
        children: [
          // Tavern background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tavern.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Parchment overlay at 30% opacity
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
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    // Game logo
                    Image.asset(
                      'assets/nmm_logo.png',
                      width: 280,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // Play Offline button
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          _showOfflineModeDialog(context);
                        },
                        style: AppStyles.primaryButtonStyle,
                        child: const Text('Play Offline'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Play Online button
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          _showComingSoonDialog(context);
                        },
                        style: AppStyles.primaryButtonStyle,
                        child: const Text('Play Online'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Training Mode button
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TrainingScreen(),
                            ),
                          );
                        },
                        style: AppStyles.primaryButtonStyle,
                        child: const Text('Training Mode'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options button
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OptionsScreen(),
                            ),
                          );
                        },
                        style: AppStyles.primaryButtonStyle,
                        child: const Text('Options'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Footer
          const Positioned(left: 0, right: 0, bottom: 0, child: AppFooter()),
        ],
      ),
    );
  }

  void _showOfflineModeDialog(BuildContext context) {
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
                'Select Game Mode',
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
              const SizedBox(height: 24),

              // Pass and Play option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(isVsAI: false),
                      ),
                    );
                  },
                  style: AppStyles.primaryButtonStyle,
                  child: const Text('Pass and Play'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Two players on the same device',
                style: AppStyles.labelText,
              ),
              const SizedBox(height: 24),

              // Play vs AI option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(isVsAI: true),
                      ),
                    );
                  },
                  style: AppStyles.primaryButtonStyle,
                  child: const Text('Play vs AI'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Challenge the computer', style: AppStyles.labelText),
              const SizedBox(height: 24),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppStyles.primaryButtonStyle,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context) {
    final authService = AuthService();

    // Check if user is logged in
    if (authService.isLoggedIn) {
      // User is logged in, go to online lobby
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const OnlineLobbyScreen()),
      );
    } else {
      // User not logged in, navigate to auth screen and handle result
      _navigateToAuthAndThenLobby();
    }
  }

  Future<void> _navigateToAuthAndThenLobby() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => const AuthScreen()));

    if (result == true && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const OnlineLobbyScreen()),
      );
    }
  }
}
