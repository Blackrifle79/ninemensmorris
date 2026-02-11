import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'utils/app_styles.dart';
import 'services/audio_service.dart';
import 'services/ai_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with persistent session storage
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await AudioService().init();
  await AIService().loadDifficulty();
  runApp(const NineMensMorrisApp());
}

class NineMensMorrisApp extends StatelessWidget {
  const NineMensMorrisApp({super.key});

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
