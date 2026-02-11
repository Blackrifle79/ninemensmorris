import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_styles.dart';
import '../widgets/app_footer.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _playerName = '';
  String _email = '';
  String? _originalEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoad() async {
    final authService = AuthService();
    if (authService.currentUser == null) {
      // Not logged in, redirect to login screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      });
    } else {
      await _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final authService = AuthService();
    final user = authService.currentUser;
    String? supabaseName;
    String? supabaseEmail;
    if (user != null) {
      supabaseEmail = user.email;
      // Try to get username from Supabase 'profiles' table
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();
        supabaseName = profile?['username'] ?? '';
      } catch (_) {
        supabaseName = '';
      }
    }
    setState(() {
      _playerName = supabaseName?.isNotEmpty == true
          ? supabaseName!
          : (prefs.getString('playerName') ?? '');
      _email = supabaseEmail ?? (prefs.getString('playerEmail') ?? '');
      _originalEmail = _email;
      _nameController.text = _playerName;
      _emailController.text = _email;
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('playerName', _playerName);
      await prefs.setString('playerEmail', _email);

      final authService = AuthService();
      final user = authService.currentUser;
      String? errorMsg;
      if (user != null) {
        // Update username in Supabase 'profiles' table
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'username': _playerName})
              .eq('id', user.id);
        } catch (e) {
          errorMsg = 'Failed to update name on server.';
        }
        // Update email in Supabase auth if changed
        if (_email != _originalEmail && _email.isNotEmpty) {
          try {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(email: _email),
            );
          } catch (e) {
            errorMsg = 'Failed to update email on server.';
          }
        }
      }
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          errorMsg != null
              ? AppStyles.errorSnackBar(errorMsg)
              : AppStyles.successSnackBar('Profile updated!'),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_email.isEmpty) {
      _showMessage('No email available for password reset.');
      return;
    }
    setState(() => _isLoading = true);
    final auth = AuthService();
    final result = await auth.resetPassword(_email);
    setState(() => _isLoading = false);
    _showMessage(result.message);
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    await auth.signOut();
    setState(() => _isLoading = false);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  Future<void> _confirmSignOut() async {
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
    if (confirm == true) await _signOut();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(AppStyles.infoSnackBar(message));
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
        title: const Text('My Profile', style: AppStyles.headingMediumLight),
      ),
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
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: AppStyles.cream.withValues(alpha: 0.9),
                        ),
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppStyles.green,
                                    child: Text(
                                      (_playerName.isNotEmpty
                                          ? _playerName[0].toUpperCase()
                                          : (_email.isNotEmpty
                                                ? _email[0].toUpperCase()
                                                : '?')),
                                      style: const TextStyle(
                                        color: AppStyles.cream,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _playerName.isNotEmpty
                                              ? _playerName
                                              : 'Player',
                                          style: AppStyles.bodyTextBold,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _email.isNotEmpty
                                              ? _email
                                              : 'Not signed in',
                                          style: AppStyles.bodyText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Editable fields
                              Text('Player Name', style: AppStyles.labelText),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _nameController,
                                style: AppStyles.bodyText,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppStyles.lightCream,
                                  border: OutlineInputBorder(
                                    borderRadius: AppStyles.sharpBorder,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: AppStyles.mediumBrown,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter a name'
                                    : null,
                                onSaved: (value) => _playerName = value ?? '',
                                onChanged: (value) =>
                                    setState(() => _playerName = value),
                              ),
                              const SizedBox(height: 16),
                              Text('Email Address', style: AppStyles.labelText),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _emailController,
                                style: AppStyles.bodyText,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppStyles.lightCream,
                                  border: OutlineInputBorder(
                                    borderRadius: AppStyles.sharpBorder,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: AppStyles.mediumBrown,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter an email'
                                    : null,
                                onSaved: (value) => _email = value ?? '',
                                onChanged: (value) =>
                                    setState(() => _email = value),
                              ),
                              const SizedBox(height: 24),
                              _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: AppStyles.cream,
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: AppStyles.primaryButtonStyle,
                                      onPressed: _saveProfile,
                                      child: const Text(
                                        'Save changes',
                                        style: AppStyles.buttonText,
                                      ),
                                    ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _resetPassword,
                                style: AppStyles.primaryButtonStyle,
                                child: const Text(
                                  'Reset password',
                                  style: AppStyles.buttonText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _confirmSignOut,
                                style: AppStyles.primaryButtonStyle,
                                child: const Text(
                                  'Sign out',
                                  style: AppStyles.buttonText,
                                ),
                              ),
                            ],
                          ),
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
}
