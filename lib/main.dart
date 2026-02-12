import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'utils/app_styles.dart';
import 'services/audio_service.dart';
import 'services/ai_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase with persistent session storage
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await AudioService().init();
  await AIService().loadDifficulty();
  runApp(const NineMensMorrisApp());
}

class NineMensMorrisApp extends StatefulWidget {
  const NineMensMorrisApp({super.key});

  @override
  State<NineMensMorrisApp> createState() => _NineMensMorrisAppState();
}

class _NineMensMorrisAppState extends State<NineMensMorrisApp>
    with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();
  bool _wasMusicPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - pause music
      _wasMusicPlaying = _audioService.isMusicEnabled;
      _audioService.stopMusic();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground - resume music if it was playing
      if (_wasMusicPlaying && _audioService.isMusicEnabled) {
        _audioService.playMusic();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nine Men\'s Morris',
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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
