import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import '../widgets/game_drawer.dart';
import 'home_screen.dart';
import 'privacy_policy_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final AuthResult result;
    if (_isLogin) {
      result = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      result = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : null,
      );
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.successSnackBar(result.message));
      if (_isLogin) {
        // Always navigate to home screen after successful login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        // Switch to login after successful registration
        setState(() => _isLogin = true);
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.errorSnackBar(result.message));
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.infoSnackBar('Please enter your email first'));
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.resetPassword(email);
    setState(() => _isLoading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      result.isSuccess
          ? AppStyles.successSnackBar(result.message)
          : AppStyles.errorSnackBar(result.message),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final result = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.successSnackBar(result.message));
      // Always navigate to home screen after successful login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppStyles.errorSnackBar(result.message));
    }
  }

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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            },
            tooltip: 'Sign In',
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
            child: Column(
              children: [
                // Main content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Title
                            Text(
                              _isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(
                                fontFamily: AppStyles.fontHeadline,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.darkBrown,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Card with form contents
                            Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppStyles.cream.withValues(alpha: 0.9),
                                borderRadius: AppStyles.sharpBorder,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                            // Username field (only for registration)
                            if (!_isLogin) ...[
                              SizedBox(
                                width: 280,
                                child: TextFormField(
                                  controller: _usernameController,
                                  style: const TextStyle(
                                    color: AppStyles.darkBrown,
                                    fontFamily: AppStyles.fontBody,
                                    fontSize: 16,
                                  ),
                                  decoration: _inputDecoration(
                                    label: 'Username (optional)',
                                    icon: Icons.person,
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email field
                            SizedBox(
                              width: 280,
                              child: TextFormField(
                                controller: _emailController,
                                style: const TextStyle(
                                  color: AppStyles.darkBrown,
                                  fontFamily: AppStyles.fontBody,
                                  fontSize: 16,
                                ),
                                decoration: _inputDecoration(
                                  label: 'Email',
                                  icon: Icons.email,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value.trim())) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            SizedBox(
                              width: 280,
                              child: TextFormField(
                                controller: _passwordController,
                                style: const TextStyle(
                                  color: AppStyles.darkBrown,
                                  fontFamily: AppStyles.fontBody,
                                  fontSize: 16,
                                ),
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  icon: Icons.lock,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppStyles.mediumBrown,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (!_isLogin && value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                            ),

                            // Forgot password (only for login)
                            if (_isLogin) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppStyles.darkBrown,
                                    fontFamily: AppStyles.fontBody,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppStyles.darkBrown,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit button
                            SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: AppStyles.primaryButtonStyle,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppStyles.cream,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? 'Sign In' : 'Create Account',
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Google Sign-In button (only on supported platforms)
                            if (_isLogin &&
                                _authService.isGoogleSignInSupported) ...[
                              const Text(
                                'or',
                                style: TextStyle(
                                  color: AppStyles.darkBrown,
                                  fontFamily: AppStyles.fontBody,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 280,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _signInWithGoogle,
                                  icon: const Icon(Icons.g_mobiledata),
                                  label: const Text('Sign in with Google'),
                                  style: AppStyles.primaryButtonStyle,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Toggle login/register
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin
                                      ? 'Don\'t have an account?'
                                      : 'Already have an account?',
                                  style: const TextStyle(
                                    color: AppStyles.darkBrown,
                                    fontFamily: AppStyles.fontBody,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _isLogin = !_isLogin;
                                            _formKey.currentState?.reset();
                                          });
                                        },
                                  child: Text(
                                    _isLogin ? 'Sign Up' : 'Sign In',
                                    style: const TextStyle(
                                      color: AppStyles.darkBrown,
                                      fontFamily: AppStyles.fontBody,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppStyles.darkBrown,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Privacy Policy link
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const PrivacyPolicyScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Privacy Policy',
                                style: AppStyles.labelText.copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppStyles.textSecondary,
                                ),
                              ),
                            ),
                                ],
                              ),
                            ),
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppStyles.mediumBrown),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppStyles.cream,
      border: const OutlineInputBorder(
        borderRadius: AppStyles.sharpBorder,
        borderSide: BorderSide(color: AppStyles.darkBrown, width: 2),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppStyles.sharpBorder,
        borderSide: BorderSide(color: AppStyles.darkBrown, width: 2),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppStyles.sharpBorder,
        borderSide: BorderSide(color: AppStyles.darkBrown, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppStyles.sharpBorder,
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppStyles.sharpBorder,
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      labelStyle: const TextStyle(
        color: AppStyles.mediumBrown,
        fontFamily: AppStyles.fontBody,
        fontSize: 16,
      ),
      errorStyle: const TextStyle(
        color: Colors.red,
        fontFamily: AppStyles.fontBody,
        fontSize: 14,
      ),
    );
  }
}
