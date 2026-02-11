/// Supabase configuration
/// Replace these values with your actual Supabase project credentials
class SupabaseConfig {
  static const String supabaseUrl = 'https://kwvebnylvfykkxsczdrs.supabase.co';

  static const String supabaseAnonKey =
      'sb_secret_gHEb5aAIIZjGvI64ACAKyQ_WzB3MRAv';

  /// Google OAuth Web Client ID from Google Cloud Console
  /// Required for Google Sign-In to work with Supabase
  /// Get this from: Google Cloud Console > APIs & Services > Credentials > OAuth 2.0 Client IDs (Web application type)
  static const String googleWebClientId =
      '833823471464-aq6btbpc1ic095it6h3qh6bu3831592h.apps.googleusercontent.com';
}
