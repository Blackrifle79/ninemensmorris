import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'utils/app_styles.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'config/supabase_config.dart';

/// Test entry point for online multiplayer testing.
///
/// Accepts dart-define parameters:
///   --dart-define=TEST_EMAIL=player1@test.com
///   --dart-define=TEST_PASSWORD=password123
///   --dart-define=TEST_PLAYER=1
///
/// The TEST_PLAYER value (1 or 2) is used to:
///   - Set the window title so you can tell the windows apart
///   - Use a deterministic session storage key (instead of random)
///     so sessions persist across restarts
///
/// Usage: see .vscode/launch.json "Online Test (Dual)" compound config.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read test configuration from dart-define
  const testEmail = String.fromEnvironment('TEST_EMAIL');
  const testPassword = String.fromEnvironment('TEST_PASSWORD');
  const testPlayer = String.fromEnvironment('TEST_PLAYER', defaultValue: '1');

  // Use a deterministic storage key per test player so sessions persist
  final storageKey = 'supabase_session_test_player_$testPlayer';

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SharedPreferencesLocalStorage(
        persistSessionKey: storageKey,
      ),
    ),
  );

  await AudioService().init();

  runApp(
    _TestApp(
      testEmail: testEmail,
      testPassword: testPassword,
      testPlayer: testPlayer,
    ),
  );
}

class _TestApp extends StatefulWidget {
  final String testEmail;
  final String testPassword;
  final String testPlayer;

  const _TestApp({
    required this.testEmail,
    required this.testPassword,
    required this.testPlayer,
  });

  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp> {
  bool _autoLoginAttempted = false;
  bool _autoLoginInProgress = false;
  String? _autoLoginError;

  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    // Skip if no test credentials provided or already logged in
    if (widget.testEmail.isEmpty || widget.testPassword.isEmpty) {
      setState(() => _autoLoginAttempted = true);
      return;
    }

    final authService = AuthService();
    if (authService.isLoggedIn) {
      setState(() => _autoLoginAttempted = true);
      return;
    }

    setState(() => _autoLoginInProgress = true);

    final result = await authService.signIn(
      email: widget.testEmail,
      password: widget.testPassword,
    );

    setState(() {
      _autoLoginInProgress = false;
      _autoLoginAttempted = true;
      if (!result.isSuccess) {
        _autoLoginError = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerLabel = 'Player ${widget.testPlayer}';

    return MaterialApp(
      title: 'Nine Men\'s Morris — $playerLabel',
      theme: ThemeData(
        scaffoldBackgroundColor: AppStyles.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppStyles.background,
          foregroundColor: AppStyles.textPrimary,
          titleTextStyle: TextStyle(
            fontFamily: AppStyles.fontHeadline,
            color: AppStyles.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppStyles.textPrimary),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: _buildHome(playerLabel),
    );
  }

  Widget _buildHome(String playerLabel) {
    // Show a brief loading screen while auto-login is in progress
    if (!_autoLoginAttempted || _autoLoginInProgress) {
      return Scaffold(
        backgroundColor: AppStyles.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppStyles.burgundy),
              const SizedBox(height: 16),
              Text(
                'Signing in as $playerLabel…',
                style: const TextStyle(
                  fontFamily: AppStyles.fontBody,
                  color: AppStyles.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error banner if auto-login failed, but still show the app
    if (_autoLoginError != null) {
      return _AutoLoginErrorBanner(
        error: _autoLoginError!,
        playerLabel: playerLabel,
        child: const HomeScreen(),
      );
    }

    return const HomeScreen();
  }
}

/// Wraps the home screen with a persistent error banner when auto-login fails.
class _AutoLoginErrorBanner extends StatelessWidget {
  final String error;
  final String playerLabel;
  final Widget child;

  const _AutoLoginErrorBanner({
    required this.error,
    required this.playerLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppStyles.burgundy,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppStyles.cream,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$playerLabel auto-login failed: $error',
                      style: const TextStyle(
                        color: AppStyles.cream,
                        fontFamily: AppStyles.fontBody,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
