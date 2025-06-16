import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FirebaseHelper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user safely
  static User? get currentUser => _auth.currentUser;
  static String? get currentUserId => _auth.currentUser?.uid;

  // Initialize app
  static Future<void> initializeApp() async {
    try {
      print('🔄 Initializing Firebase Helper...');

      // Check if user is already signed in
      final user = _auth.currentUser;
      if (user != null) {
        print('✅ User already signed in: ${user.email}');
        await updateOnlineStatus(true);
      } else {
        print('ℹ️ No user currently signed in');
      }
    } catch (e) {
      print('⚠️ Firebase initialization error: $e');
    }
  }

  // Sign in with email and password
  static Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔄 Attempting sign in for: $email');

      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        print('✅ Sign in successful: ${user.email}');

        // Update online status
        await updateOnlineStatus(true);

        // Sync profile data
        await syncProfileFromFirestore();

        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ General sign in error: $e');
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  // Create account with email and password
  static Future<User?> createUserWithEmailAndPassword(String email, String password, String name) async {
    try {
      print('🔄 Creating account for: $email');

      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        print('✅ Account created successfully: ${user.email}');

        // Update display name
        await user.updateDisplayName(name);

        // Create initial user document in Firestore
        await _createUserDocument(user, name);

        // Update online status
        await updateOnlineStatus(true);

        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ General account creation error: $e');
      throw Exception('Account creation failed: ${e.toString()}');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      print('🔄 Signing out user...');

      // Update online status before signing out
      await updateOnlineStatus(false);

      // Sign out from Firebase
      await _auth.signOut();

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Sign out error: $e');
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Update online status - Made public and static
  static Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ Online status updated: $isOnline');
      }
    } catch (e) {
      print('⚠️ Error updating online status: $e');
    }
  }

  // Get user profile from Firestore
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user signed in for profile fetch');
        return null;
      }

      print('🔄 Fetching user profile from Firestore...');

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        print('✅ Profile fetched from Firestore');
        return data;
      } else {
        print('ℹ️ No profile document found in Firestore');
        return null;
      }
    } catch (e) {
      print('⚠️ Error fetching user profile: $e');
      return null;
    }
  }

  // Sync profile to Firestore
  static Future<void> syncProfileToFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user signed in for profile sync');
        return;
      }

      // Get profile from local storage
      final prefs = await SharedPreferences.getInstance();
      final profileData = prefs.getString('userProfile');

      if (profileData == null) {
        print('⚠️ No local profile data to sync');
        return;
      }

      final profile = json.decode(profileData) as Map<String, dynamic>;

      // Add metadata
      profile['userId'] = user.uid;
      profile['email'] = user.email;
      profile['lastSyncAt'] = FieldValue.serverTimestamp();

      print('🔄 Syncing profile to Firestore...');

      await _firestore.collection('users').doc(user.uid).set(
        profile,
        SetOptions(merge: true),
      );

      print('✅ Profile synced to Firestore successfully');
    } catch (e) {
      print('⚠️ Error syncing profile to Firestore: $e');
      rethrow;
    }
  }

  // Sync profile from Firestore to local
  static Future<void> syncProfileFromFirestore() async {
    try {
      final profile = await getUserProfile();
      if (profile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userProfile', json.encode(profile));
        print('✅ Profile synced from Firestore to local storage');
      }
    } catch (e) {
      print('⚠️ Error syncing profile from Firestore: $e');
    }
  }

  // Get suggested connections
  static Future<List<Map<String, dynamic>>> getSuggestedConnections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🔄 Fetching suggested connections...');

      // Get users excluding current user
      final querySnapshot = await _firestore
          .collection('users')
          .where('userId', isNotEqualTo: user.uid)
          .limit(10)
          .get();

      final connections = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['userId'] = doc.id;

        // Calculate match percentage based on skills
        data['matchPercentage'] = _calculateMatchPercentage(data);

        return data;
      }).toList();

      print('✅ Found ${connections.length} suggested connections');
      return connections;
    } catch (e) {
      print('⚠️ Error fetching suggested connections: $e');
      return [];
    }
  }

  // Get mentorship opportunities
  static Future<List<Map<String, dynamic>>> getMentorshipOpportunities() async {
    try {
      print('🔄 Fetching mentorship opportunities...');

      final querySnapshot = await _firestore
          .collection('mentorship_requests')
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final opportunities = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('✅ Found ${opportunities.length} mentorship opportunities');
      return opportunities;
    } catch (e) {
      print('⚠️ Error fetching mentorship opportunities: $e');
      return [];
    }
  }

  // Send connection request
  static Future<bool> sendConnectionRequest(String targetUserId, String message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('🔄 Sending connection request to $targetUserId...');

      await _firestore.collection('connection_requests').add({
        'fromUserId': user.uid,
        'toUserId': targetUserId,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Connection request sent successfully');
      return true;
    } catch (e) {
      print('❌ Error sending connection request: $e');
      return false;
    }
  }

  // Get notification count
  static Future<int> getNotificationCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final querySnapshot = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('⚠️ Error getting notification count: $e');
      return 0;
    }
  }

  // Get user connections
  static Future<List<Map<String, dynamic>>> getUserConnections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🔄 Fetching user connections...');

      // Get accepted connection requests where user is either sender or receiver
      final sentConnections = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final receivedConnections = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      List<Map<String, dynamic>> connections = [];

      // Process sent connections
      for (var doc in sentConnections.docs) {
        final data = doc.data();
        final otherUserId = data['toUserId'];

        // Get other user's profile
        final userDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          connections.add({
            'connectionId': doc.id,
            'otherUserId': otherUserId,
            'name': userData['name'] ?? 'Unknown User',
            'profileImage': userData['profileImage'],
            'isOnline': userData['isOnline'] ?? false,
            'lastMessage': '', // You can implement this later
            'unreadCount': 0, // You can implement this later
          });
        }
      }

      // Process received connections
      for (var doc in receivedConnections.docs) {
        final data = doc.data();
        final otherUserId = data['fromUserId'];

        // Get other user's profile
        final userDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          connections.add({
            'connectionId': doc.id,
            'otherUserId': otherUserId,
            'name': userData['name'] ?? 'Unknown User',
            'profileImage': userData['profileImage'],
            'isOnline': userData['isOnline'] ?? false,
            'lastMessage': '', // You can implement this later
            'unreadCount': 0, // You can implement this later
          });
        }
      }

      print('✅ Found ${connections.length} connections');
      return connections;
    } catch (e) {
      print('⚠️ Error fetching connections: $e');
      return [];
    }
  }

  // Accept connection request
  static Future<bool> acceptConnectionRequest(String requestId) async {
    try {
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Connection request accepted');
      return true;
    } catch (e) {
      print('❌ Error accepting connection request: $e');
      return false;
    }
  }

  // Update mentorship streak
  static Future<void> updateMentorshipStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = prefs.getInt('mentorStreak') ?? 0;
      await prefs.setInt('mentorStreak', currentStreak + 1);

      // Also update in Firestore
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'mentorStreak': currentStreak + 1,
          'lastMentorActivity': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('⚠️ Error updating mentorship streak: $e');
    }
  }

  // Debug all data
  static Future<void> debugAllData() async {
    try {
      print('🐛 === FIREBASE DEBUG START ===');

      final user = _auth.currentUser;
      print('🐛 Current user: ${user?.email}');
      print('🐛 Current user ID: ${user?.uid}');

      if (user != null) {
        final profile = await getUserProfile();
        print('🐛 Profile data: $profile');
      }

      print('🐛 === FIREBASE DEBUG END ===');
    } catch (e) {
      print('🐛 Debug error: $e');
    }
  }

  // Private helper methods
  static Future<void> _createUserDocument(User user, String name) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'email': user.email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'profileComplete': false,
      });
      print('✅ User document created in Firestore');
    } catch (e) {
      print('⚠️ Error creating user document: $e');
    }
  }

  static int _calculateMatchPercentage(Map<String, dynamic> userData) {
    // Simple match calculation - you can enhance this
    if (userData['skillsOffered'] != null && userData['skillsWanted'] != null) {
      return 75 + (userData.hashCode % 25); // Random but consistent percentage
    }
    return 50;
  }

  static Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email address');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'email-already-in-use':
        return Exception('An account already exists with this email address');
      case 'weak-password':
        return Exception('Password is too weak');
      case 'invalid-email':
        return Exception('Please enter a valid email address');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many failed attempts. Please try again later');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection');
      default:
        return Exception(e.message ?? 'Authentication failed');
    }
  }
}