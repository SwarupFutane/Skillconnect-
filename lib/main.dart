import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'LoginPage.dart';
import 'firebase_options.dart';
import 'homepage.dart';
import 'profilesetuppage.dart';
import 'firebase_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");


    try {
      await FirebaseHelper.initializeApp();
      print("✅ Firebase helper initialized");
    } catch (e) {
      print("⚠️ Firebase helper initialization error: $e");

    }
  } catch (e) {
    print("❌ Critical Firebase initialization error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkillConnect',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/profile-setup': (context) => ProfileSetupPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
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
    super.didChangeAppLifecycleState(state);

    try {
      switch (state) {
        case AppLifecycleState.resumed:
          FirebaseHelper.updateOnlineStatus(true);
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
          FirebaseHelper.updateOnlineStatus(false);
          break;
        case AppLifecycleState.hidden:

          break;
      }
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('🔍 Auth State: ${snapshot.connectionState}');
        print('🔍 Has Data: ${snapshot.hasData}');
        print('🔍 User: ${snapshot.data?.uid}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E21),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF667eea),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'SkillConnect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ Auth Stream Error: ${snapshot.error}');
          return _buildErrorState(snapshot.error.toString());
        }


        if (snapshot.hasData && snapshot.data != null) {
          print('✅ User logged in: ${snapshot.data!.uid}');
          // User is logged in, check if profile is complete
          return FutureBuilder<bool>(
            future: _checkProfileComplete(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0A0E21),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF667eea),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Setting up your profile...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (profileSnapshot.hasError) {
                print('❌ Profile Check Error: ${profileSnapshot.error}');
                return _buildErrorState('Profile check failed: ${profileSnapshot.error}');
              }

              if (profileSnapshot.data == true) {
                print('✅ Profile complete, going to homepage');
                // Profile is complete, go to home
                return const HomePage();
              } else {
                print('⚠️ Profile incomplete, going to profile setup');
                return ProfileSetupPage();
              }
            },
          );
        }

        print('ℹ️ No user logged in, showing login page');
        return const LoginPage();
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: $error',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Force restart the auth check
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) setState(() {});
                    } catch (e) {
                      print('Error signing out: $e');
                    }
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _checkProfileComplete() async {
    try {
      print('🔍 Checking profile completion...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return false;
      }


      await Future.delayed(const Duration(milliseconds: 500));


      print('🔍 Checking Firebase profile...');
      try {
        final firebaseProfile = await FirebaseHelper.getUserProfile()
            .timeout(const Duration(seconds: 10));

        print('☁️ Firebase profile exists: ${firebaseProfile != null}');

        if (firebaseProfile != null) {
          print('☁️ Firebase profile data keys: ${firebaseProfile.keys}');

          final isComplete = firebaseProfile['profileComplete'] == true &&
              firebaseProfile['name'] != null &&
              firebaseProfile['name'].toString().isNotEmpty;

          print('☁️ Firebase profile complete: $isComplete');

          if (isComplete) {
            print('✅ Firebase profile complete, updating local storage...');
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('userProfile', json.encode(firebaseProfile));
              await FirebaseHelper.updateOnlineStatus(true);
              print('✅ Profile synced successfully');
            } catch (syncError) {
              print('⚠️ Sync failed but profile is complete: $syncError');
            }
            return true;
          }
        }
      } on Exception catch (e) {
        print('⚠️ Firebase profile check failed: $e');

        // Check if it's a permission error
        if (e.toString().contains('permission-denied')) {
          print('🔐 Permission denied - user might need to re-authenticate');

        }

      }


      print('🔍 Checking local storage as fallback...');
      try {
        final prefs = await SharedPreferences.getInstance();
        final profileData = prefs.getString('userProfile');

        print('📱 Local profile data exists: ${profileData != null}');

        if (profileData != null) {
          final profile = json.decode(profileData);
          print('📱 Local profile keys: ${profile.keys}');

          final isComplete = profile['profileComplete'] == true &&
              profile['name'] != null &&
              profile['name'].toString().isNotEmpty;

          print('📱 Local profile complete: $isComplete');

          if (isComplete) {
            print('✅ Local profile is complete');

            try {
              await FirebaseHelper.syncProfileToFirestore();
              await FirebaseHelper.updateOnlineStatus(true);
              print('✅ Synced with Firebase successfully');
            } catch (e) {
              print('⚠️ Firebase sync failed but continuing: $e');
            }
            return true;
          }
        }
      } catch (e) {
        print('⚠️ Error checking local storage: $e');
      }

      print('❌ Profile not complete - redirecting to setup');
      return false;

    } catch (e) {
      print('❌ Critical error checking profile: $e');
      return false;
    }
  }
}