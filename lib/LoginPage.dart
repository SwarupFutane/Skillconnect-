import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _ensureCleanState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Ensure clean authentication state
  Future<void> _ensureCleanState() async {
    try {
      print('🔄 Ensuring clean authentication state...');

      // Clear any existing auth state
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('⚠️ Found existing user, signing out...');
        try {
          // Reload user data first if user exists
          await currentUser.reload();
        } catch (e) {
          print('⚠️ Error reloading user (continuing): $e');
        }
        await _auth.signOut();
      }

      // Clear all local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Wait a moment to ensure everything is cleared
      await Future.delayed(const Duration(milliseconds: 300));

      print('✅ Clean state ensured');
    } catch (e) {
      print('⚠️ Error ensuring clean state: $e');
      // Continue anyway
    }
  }

  Future<void> _emailPasswordAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('🔄 Starting authentication process...');

      // Ensure we start with a clean state
      await _ensureCleanState();

      // Add a small delay to ensure state is fully cleared
      await Future.delayed(const Duration(milliseconds: 500));

      UserCredential? userCredential;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      print('📧 Email: $email');
      print('🔒 Mode: ${_isLoginMode ? "Login" : "Sign Up"}');

      if (_isLoginMode) {
        print('🔄 Attempting sign in...');

        // Try to sign in with additional error handling
        try {
          userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ Sign in successful');
        } on FirebaseAuthException catch (e) {
          print('❌ Firebase Auth Exception during sign in: ${e.code} - ${e.message}');
          throw e;
        } catch (e) {
          print('❌ General error during sign in: $e');
          print('❌ Error type: ${e.runtimeType}');

          // If there's a type cast error, try to recover
          if (e.toString().contains('PigeonUserDetails') || e.toString().contains('type cast')) {
            print('🔄 Detected type cast error, attempting recovery...');

            // Force sign out and try again
            await _auth.signOut();
            await Future.delayed(const Duration(seconds: 1));

            try {
              userCredential = await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              print('✅ Recovery sign in successful');
            } catch (recoveryError) {
              print('❌ Recovery attempt failed: $recoveryError');
              throw Exception('Authentication failed. Please try again or restart the app.');
            }
          } else {
            throw e;
          }
        }
      } else {
        print('🔄 Attempting account creation...');

        try {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          print('✅ Account creation successful');
        } on FirebaseAuthException catch (e) {
          print('❌ Firebase Auth Exception during sign up: ${e.code} - ${e.message}');
          throw e;
        } catch (e) {
          print('❌ General error during sign up: $e');
          throw e;
        }
      }

      // Verify we have a valid user
      if (userCredential?.user == null) {
        throw Exception('Authentication failed - no user returned');
      }

      final user = userCredential!.user!;
      print('✅ User authenticated: ${user.uid}');
      print('📧 User email: ${user.email}');

      try {
        // Initialize Firebase Helper and set online status
        print('🔄 Initializing Firebase Helper...');
        await FirebaseHelper.initializeApp();

        print('🔄 Setting online status...');
        await FirebaseHelper.updateOnlineStatus(true);

        print('✅ Firebase helper initialized successfully');
      } catch (helperError) {
        print('⚠️ Firebase helper error (continuing): $helperError');
        // Don't block login for Firebase helper errors
      }

      // Show success message
      if (mounted) {
        _showSuccess();
        print('✅ Login process completed successfully');
      }

    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      _showError(_getErrorMessage(e));
    } catch (e) {
      print('❌ Login error: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Provide more specific error messages
      String errorMessage;
      if (e.toString().contains('PigeonUserDetails') || e.toString().contains('type cast')) {
        errorMessage = 'Authentication error detected. Please restart the app and try again.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Login failed: ${e.toString()}';
      }

      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      default:
        print('Firebase Auth Error: ${e.code} - ${e.message}');
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            // Allow user to retry
          },
        ),
      ),
    );
  }

  void _showSuccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLoginMode
            ? 'Welcome back to SkillConnect! 🚀'
            : 'Welcome to SkillConnect! 🚀'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Add method to handle app restart suggestion
  void _showRestartAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Authentication Issue',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'There seems to be an authentication state issue. Please restart the app and try again.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _ensureCleanState();
            },
            child: const Text('Try Again', style: TextStyle(color: Color(0xFF667eea))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, you might use exit(0) or restart functionality
              _ensureCleanState();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // App Logo & Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                      ),
                      child: const Icon(
                        Icons.connect_without_contact,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SkillConnect',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect. Learn. Grow.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Toggle between Login/Sign Up
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLoginMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _isLoginMode
                                  ? const Color(0xFF667eea)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _isLoginMode ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLoginMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: !_isLoginMode
                                  ? const Color(0xFF667eea)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Sign Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: !_isLoginMode ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.grey,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2D3A),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF667eea),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1D1E33),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.grey,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2D3A),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF667eea),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1D1E33),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (!_isLoginMode && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _emailPasswordAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          disabledBackgroundColor: const Color(0xFF667eea).withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          _isLoginMode ? 'Login' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Troubleshooting button
                    if (_isLoginMode) ...[
                      TextButton(
                        onPressed: _ensureCleanState,
                        child: const Text(
                          'Having trouble signing in? Tap to reset',
                          style: TextStyle(
                            color: Color(0xFF667eea),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Coming Soon - Google Sign In
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text(
                          'Google Sign-In (Coming Soon)',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Footer text
              Center(
                child: Text(
                  _isLoginMode
                      ? 'New to SkillConnect? Tap Sign Up above'
                      : 'Already have an account? Tap Login above',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}