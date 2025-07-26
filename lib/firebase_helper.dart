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

  // Enhanced sign out method
  static Future<void> signOut() async {
    try {
      print('🔄 Starting comprehensive sign out...');

      final user = _auth.currentUser;
      if (user != null) {
        print('📋 Current user: ${user.email} (${user.uid})');

        // Step 1: Update online status before signing out
        try {
          await updateOnlineStatus(false);
          print('✅ Online status updated to offline');
        } catch (e) {
          print('⚠️ Error updating online status: $e');
          // Continue with sign out even if this fails
        }

        // Step 2: Clear any active typing status
        try {
          await _clearTypingStatus();
          print('✅ Typing status cleared');
        } catch (e) {
          print('⚠️ Error clearing typing status: $e');
        }

        // Step 3: Sign out from Firebase Auth
        await _auth.signOut();
        print('✅ Firebase Auth sign out completed');

        // Step 4: Clear all local storage
        await _clearAllLocalData();
        print('✅ Local data cleared');

        // Step 5: Verify sign out
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          print('✅ Sign out verification successful - no current user');
        } else {
          print('⚠️ Sign out verification failed - user still exists: ${currentUser.uid}');
          // Force sign out again
          await _auth.signOut();
        }

      } else {
        print('ℹ️ No user was signed in');
        // Still clear local data to be safe
        await _clearAllLocalData();
      }

      print('✅ Comprehensive sign out completed successfully');
    } catch (e) {
      print('❌ Error during sign out: $e');

      // Force clear everything even if there are errors
      try {
        await _auth.signOut();
        await _clearAllLocalData();
        print('✅ Force sign out completed');
      } catch (forceError) {
        print('❌ Force sign out also failed: $forceError');
      }

      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Clear typing status for all connections
  static Future<void> _clearTypingStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final typingDocs = await _firestore
          .collection('typing_status')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${user.uid}')
          .where(FieldPath.documentId, isLessThanOrEqualTo: '${user.uid}\uf8ff')
          .get();

      final batch = _firestore.batch();
      for (var doc in typingDocs.docs) {
        batch.delete(doc.reference);
      }

      if (typingDocs.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      print('⚠️ Error clearing typing status: $e');
    }
  }

  // Clear all local data
  static Future<void> _clearAllLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear all stored preferences
      await prefs.clear();

      print('✅ SharedPreferences cleared');

      // Additional cleanup if needed
      // You can add more specific clearing here if you have other local storage

    } catch (e) {
      print('⚠️ Error clearing local data: $e');
      throw e;
    }
  }

  // Sign in with email and password
  static Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔄 Attempting sign in for: $email');

      // Clear any existing data first
      await _clearAllLocalData();

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

  // ========== ENHANCED CONNECTION MANAGEMENT ==========

  // Create or get connection document with consistent ID generation
  static Future<String> createOrGetConnection(String otherUserId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userId = user.uid;

      // Create a consistent connection ID regardless of who initiates
      final connectionId = userId.compareTo(otherUserId) < 0
          ? '${userId}_$otherUserId'
          : '${otherUserId}_$userId';

      print('🔄 Creating/getting connection: $connectionId');

      // Check if connection document exists
      final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();

      if (!connectionDoc.exists) {
        // Create new connection document
        await _firestore.collection('connections').doc(connectionId).set({
          'participants': [userId, otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {
            userId: 0,
            otherUserId: 0,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Connection document created: $connectionId');
      } else {
        print('✅ Connection document already exists: $connectionId');
      }

      return connectionId;
    } catch (e) {
      print('❌ Error creating/getting connection: $e');
      rethrow;
    }
  }

  // Enhanced getUserConnections that creates proper connection documents
  static Future<List<Map<String, dynamic>>> getUserConnections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🔄 Fetching user connections...');

      // Method 1: Get connections from connections collection
      final connectionsQuery = await _firestore
          .collection('connections')
          .where('participants', arrayContains: user.uid)
          .orderBy('lastMessageTime', descending: true)
          .get();

      List<Map<String, dynamic>> connections = [];

      // Process existing connections
      for (var doc in connectionsQuery.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);

        // Find the other user
        final otherUserId = participants.firstWhere(
              (id) => id != user.uid,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        // Get other user's profile
        try {
          final userDoc = await _firestore.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;

            connections.add({
              'connectionId': doc.id,
              'otherUserId': otherUserId,
              'name': userData['name'] ?? 'Unknown User',
              'profileImage': userData['profileImage'],
              'isOnline': userData['isOnline'] ?? false,
              'lastMessage': data['lastMessage'] ?? '',
              'lastMessageTime': data['lastMessageTime'],
              'unreadCount': data['unreadCount']?[user.uid] ?? 0,
            });
          }
        } catch (e) {
          print('⚠️ Error getting user data for $otherUserId: $e');
          continue;
        }
      }

      // Method 2: Get accepted connection requests and create missing connections
      final acceptedRequests = await _getAcceptedConnectionRequests(user.uid);

      for (var request in acceptedRequests) {
        final otherUserId = request['otherUserId'];

        // Check if we already have this connection from Method 1
        final existingConnection = connections.firstWhere(
              (conn) => conn['otherUserId'] == otherUserId,
          orElse: () => <String, dynamic>{},
        );

        if (existingConnection.isEmpty) {
          // Create connection document for this accepted request
          try {
            final connectionId = await createOrGetConnection(otherUserId);

            // Get other user's profile
            final userDoc = await _firestore.collection('users').doc(otherUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;

              connections.add({
                'connectionId': connectionId,
                'otherUserId': otherUserId,
                'name': userData['name'] ?? 'Unknown User',
                'profileImage': userData['profileImage'],
                'isOnline': userData['isOnline'] ?? false,
                'lastMessage': '',
                'lastMessageTime': null,
                'unreadCount': 0,
              });
            }
          } catch (e) {
            print('⚠️ Error creating connection for request: $e');
            continue;
          }
        }
      }

      print('✅ Found ${connections.length} connections');
      return connections;
    } catch (e) {
      print('⚠️ Error fetching connections: $e');
      return [];
    }
  }

  // Helper method to get accepted connection requests
  static Future<List<Map<String, dynamic>>> _getAcceptedConnectionRequests(String userId) async {
    try {
      List<Map<String, dynamic>> requests = [];

      // Get requests where user is sender
      final sentRequests = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in sentRequests.docs) {
        final data = doc.data();
        requests.add({
          'requestId': doc.id,
          'otherUserId': data['toUserId'],
        });
      }

      // Get requests where user is receiver
      final receivedRequests = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in receivedRequests.docs) {
        final data = doc.data();
        requests.add({
          'requestId': doc.id,
          'otherUserId': data['fromUserId'],
        });
      }

      return requests;
    } catch (e) {
      print('⚠️ Error getting accepted requests: $e');
      return [];
    }
  }

  // Enhanced acceptConnectionRequest that creates proper connection
  static Future<bool> acceptConnectionRequest(String requestId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('🔄 Accepting connection request: $requestId');

      // Get the request document
      final requestDoc = await _firestore.collection('connection_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        print('❌ Request document not found');
        return false;
      }

      final requestData = requestDoc.data()!;
      final fromUserId = requestData['fromUserId'];
      final toUserId = requestData['toUserId'];

      // Update request status
      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Create connection document
      final connectionId = await createOrGetConnection(fromUserId == user.uid ? toUserId : fromUserId);

      print('✅ Connection request accepted and connection created: $connectionId');
      return true;
    } catch (e) {
      print('❌ Error accepting connection request: $e');
      return false;
    }
  }

  // ========== ENHANCED MENTORSHIP SYSTEM ==========

  // Accept mentorship and create connection
  static Future<bool> acceptMentorship(Map<String, dynamic> mentorshipData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('🔄 Accepting mentorship: ${mentorshipData['id']}');

      // 1. Update mentorship status
      if (mentorshipData['id'] != null) {
        await _firestore.collection('mentorship_opportunities').doc(mentorshipData['id']).update({
          'status': 'accepted',
          'acceptedBy': user.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Create connection with mentor if mentorId is available
      if (mentorshipData['mentorId'] != null) {
        final connectionId = await createOrGetConnection(mentorshipData['mentorId']);
        print('✅ Connection created with mentor: $connectionId');
      }

      // 3. Update mentorship streak
      await updateMentorshipStreak();

      // 4. Create a notification for the mentor (if applicable)
      if (mentorshipData['mentorId'] != null) {
        await _createMentorshipNotification(mentorshipData);
      }

      print('✅ Mentorship accepted successfully');
      return true;
    } catch (e) {
      print('❌ Error accepting mentorship: $e');
      return false;
    }
  }

  // Create notification for mentorship acceptance
  static Future<void> _createMentorshipNotification(Map<String, dynamic> mentorshipData) async {
    try {
      final user = _auth.currentUser;
      if (user == null || mentorshipData['mentorId'] == null) return;

      await _firestore.collection('notifications').add({
        'type': 'mentorship_accepted',
        'fromUserId': user.uid,
        'toUserId': mentorshipData['mentorId'],
        'mentorshipId': mentorshipData['id'],
        'message': 'Someone accepted your mentorship opportunity!',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Error creating mentorship notification: $e');
    }
  }

  // ========== MESSAGING SYSTEM ==========

  // Send a message with enhanced error handling
  static Future<bool> sendMessage({
    required String connectionId,
    required String receiverId,
    required String message,
    String messageType = 'text',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('🔄 Sending message to connection: $connectionId');

      // Ensure connection document exists before sending message
      await _ensureConnectionExists(connectionId, receiverId);

      print('🔄 Adding message to Firestore...');

      // Create message data
      final messageData = {
        'connectionId': connectionId,
        'senderId': user.uid,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': messageType,
      };

      print('📋 Message data: $messageData');

      // Add message to Firestore
      final messageRef = await _firestore.collection('messages').add(messageData);
      print('✅ Message added with ID: ${messageRef.id}');

      // Update connection with last message
      print('🔄 Updating connection document...');
      await _firestore.collection('connections').doc(connectionId).set({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.$receiverId': FieldValue.increment(1),
        'participants': [user.uid, receiverId],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Message sent successfully');
      return true;
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  // Ensure connection document exists
  static Future<void> _ensureConnectionExists(String connectionId, String receiverId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final connectionDoc = await _firestore.collection('connections').doc(connectionId).get();

      if (!connectionDoc.exists) {
        print('⚠️ Connection document does not exist, creating...');

        await _firestore.collection('connections').doc(connectionId).set({
          'participants': [user.uid, receiverId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': {
            user.uid: 0,
            receiverId: 0,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Connection document created');
      }
    } catch (e) {
      print('❌ Error ensuring connection exists: $e');
      throw e;
    }
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String connectionId, String otherUserId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🔄 Marking messages as read for connection: $connectionId');

      // Mark all messages in this chat as read
      final unreadMessages = await _firestore
          .collection('messages')
          .where('connectionId', isEqualTo: connectionId)
          .where('senderId', isEqualTo: otherUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in unreadMessages.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();

        // Update connection unread count
        await _firestore.collection('connections').doc(connectionId).update({
          'unreadCount.${user.uid}': 0,
        });

        print('✅ Marked ${unreadMessages.docs.length} messages as read');
      }
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  // ========== ORIGINAL METHODS (Enhanced) ==========

  // Get suggested connections
  static Future<List<Map<String, dynamic>>> getSuggestedConnections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      print('🔄 Fetching suggested connections...');

      // Get users excluding current user and existing connections
      final existingConnections = await getUserConnections();
      final existingUserIds = existingConnections.map((c) => c['otherUserId']).toSet();

      // Also exclude users with pending requests
      final pendingRequests = await _getPendingRequests(user.uid);
      existingUserIds.addAll(pendingRequests);

      final querySnapshot = await _firestore
          .collection('users')
          .where('profileComplete', isEqualTo: true)
          .limit(20)
          .get();

      final connections = querySnapshot.docs
          .where((doc) => doc.id != user.uid && !existingUserIds.contains(doc.id))
          .take(10)
          .map((doc) {
        final data = doc.data();
        data['userId'] = doc.id;
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

  // Get pending requests
  static Future<Set<String>> _getPendingRequests(String userId) async {
    try {
      final sentRequests = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      return sentRequests.docs.map((doc) => doc.data()['toUserId'] as String).toSet();
    } catch (e) {
      print('⚠️ Error getting pending requests: $e');
      return <String>{};
    }
  }

  // Enhanced get mentorship opportunities
  static Future<List<Map<String, dynamic>>> getMentorshipOpportunities() async {
    try {
      print('🔄 Fetching mentorship opportunities...');

      final querySnapshot = await _firestore
          .collection('mentorship_opportunities')
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

      // Check if request already exists
      final existingRequest = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .where('toUserId', isEqualTo: targetUserId)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        print('⚠️ Connection request already exists');
        return false;
      }

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

  // ========== DEBUG AND MAINTENANCE ==========

  // Debug all data
  static Future<void> debugAllData() async {
    try {
      print('🐛 === FIREBASE DEBUG START ===');

      final user = _auth.currentUser;
      print('🐛 Current user: ${user?.email}');
      print('🐛 Current user ID: ${user?.uid}');

      if (user != null) {
        // Debug profile
        final profile = await getUserProfile();
        print('🐛 Profile data: $profile');

        // Debug connections
        final connections = await getUserConnections();
        print('🐛 Connections count: ${connections.length}');
        for (var conn in connections) {
          print('🐛   - ${conn['name']} (${conn['connectionId']})');
        }

        // Debug connection requests
        final requests = await _firestore
            .collection('connection_requests')
            .where('toUserId', isEqualTo: user.uid)
            .get();
        print('🐛 Incoming requests: ${requests.docs.length}');

        // Debug messages
        final messages = await _firestore
            .collection('messages')
            .where('senderId', isEqualTo: user.uid)
            .limit(5)
            .get();
        print('🐛 Recent messages sent: ${messages.docs.length}');
      }

      print('🐛 === FIREBASE DEBUG END ===');
    } catch (e) {
      print('🐛 Debug error: $e');
    }
  }

  // Fix existing connections - run this once to fix your data
  static Future<void> fixExistingConnections() async {
    print('🔧 Fixing existing connections...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      final acceptedRequests = await _getAcceptedConnectionRequests(user.uid);

      for (var request in acceptedRequests) {
        final otherUserId = request['otherUserId'];
        try {
          await createOrGetConnection(otherUserId);
          print('✅ Fixed connection with: $otherUserId');
        } catch (e) {
          print('⚠️ Error fixing connection with $otherUserId: $e');
        }
      }

      print('✅ Finished fixing connections');
    } catch (e) {
      print('❌ Error fixing connections: $e');
    }
  }

  // ========== PRIVATE HELPER METHODS ==========

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
    // Enhanced match calculation
    int baseScore = 50;

    if (userData['skillsOffered'] != null && userData['skillsWanted'] != null) {
      baseScore += 25;
    }

    if (userData['availableForMentoring'] == true) {
      baseScore += 15;
    }

    if (userData['experienceLevel'] != null) {
      baseScore += 10;
    }

    // Add some randomness but keep it consistent per user
    final randomFactor = userData.hashCode % 20 - 10;
    return (baseScore + randomFactor).clamp(30, 95);
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