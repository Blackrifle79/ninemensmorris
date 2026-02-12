import 'dart:io' show Platform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/supabase_config.dart';

/// Service for handling authentication with Supabase
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Get the current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get auth state stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'username': username} : null,
      );

      if (response.user != null) {
        return AuthResult.success(
          message: 'Account created! Please check your email to verify.',
        );
      } else {
        return AuthResult.failure('Failed to create account');
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return AuthResult.success(message: 'Welcome back!');
      } else {
        return AuthResult.failure('Failed to sign in');
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    // Google Sign-In is not supported on Windows/Linux desktop
    if (Platform.isWindows || Platform.isLinux) {
      return AuthResult.failure(
        'Google sign-in is only available on Android and iOS. Please use email sign-in.',
      );
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: SupabaseConfig.googleWebClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        return AuthResult.failure(
          'Failed to get Google authentication token. Please check your Google Sign-In configuration.',
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        return AuthResult.success(message: 'Welcome!');
      } else {
        return AuthResult.failure('Failed to sign in with Google');
      }
    } on PlatformException catch (e) {
      // Platform-specific error - usually SHA-1/package name misconfiguration
      return AuthResult.failure(
        'Google sign-in configuration error: ${e.code} - ${e.message}',
      );
    } catch (e) {
      return AuthResult.failure('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Check if Google Sign-In is supported on this platform
  bool get isGoogleSignInSupported => !Platform.isWindows && !Platform.isLinux;

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult.success(
        message: 'Password reset email sent! Check your inbox.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Get user-friendly error messages
  String _getErrorMessage(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password';
      case 'Email not confirmed':
        return 'Please verify your email before signing in';
      case 'User already registered':
        return 'An account with this email already exists';
      default:
        return e.message;
    }
  }
}

/// Result class for auth operations
class AuthResult {
  final bool isSuccess;
  final String message;

  AuthResult._({required this.isSuccess, required this.message});

  factory AuthResult.success({required String message}) {
    return AuthResult._(isSuccess: true, message: message);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(isSuccess: false, message: message);
  }
}
