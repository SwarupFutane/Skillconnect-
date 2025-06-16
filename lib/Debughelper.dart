// Add this debug helper to your project to diagnose the issues

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Debug method to check what's in your database
  static Future<void> debugDatabase() async {
    print('🔍 Starting database debug...');

    try {
      final user = _auth.currentUser;
      print('Current user: ${user?.uid} (${user?.email})');

      // 1. Check users collection
      await _debugUsersCollection();

      // 2. Check current user's data
      await _debugCurrentUserData();

      // 3. Check connection requests
      await _debugConnectionRequests();

      // 4. Check connections
      await _debugConnections();

      // 5. Check mentorship opportunities
      await _debugMentorshipOpportunities();

    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  static Future<void> _debugUsersCollection() async {
    print('\n📊 Checking users collection...');
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      print('Total users in database: ${usersSnapshot.docs.length}');

      if (usersSnapshot.docs.isEmpty) {
        print('❌ No users found in database!');
        print('💡 Solution: Make sure users are being created in Firestore when they register');
        return;
      }

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        print('User ${doc.id}:');
        print('  - Name: ${data['name']}');
        print('  - Email: ${data['email']}');
        print('  - Profile Complete: ${data['profileComplete']}');
        print('  - Skills Offered: ${data['skillsOffered']}');
        print('  - Skills Wanted: ${data['skillsWanted']}');
        print('  - Online: ${data['isOnline']}');
        print('  ---');
      }
    } catch (e) {
      print('❌ Error checking users: $e');
    }
  }

  static Future<void> _debugCurrentUserData() async {
    print('\n👤 Checking current user data...');
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user!');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('❌ Current user document does not exist in Firestore!');
        print('💡 Solution: Make sure user profile is created in Firestore during registration');
        return;
      }

      final userData = userDoc.data()!;
      print('✅ Current user found:');
      print('  - Name: ${userData['name']}');
      print('  - Profile Complete: ${userData['profileComplete']}');
      print('  - Skills Offered: ${userData['skillsOffered']}');
      print('  - Skills Wanted: ${userData['skillsWanted']}');

      if (userData['profileComplete'] != true) {
        print('⚠️ Profile is not marked as complete!');
        print('💡 Solution: Complete your profile first');
      }

    } catch (e) {
      print('❌ Error checking current user: $e');
    }
  }

  static Future<void> _debugConnectionRequests() async {
    print('\n📨 Checking connection requests...');
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check requests TO current user
      final incomingRequests = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: user.uid)
          .get();

      print('Incoming requests: ${incomingRequests.docs.length}');
      for (var doc in incomingRequests.docs) {
        final data = doc.data();
        print('  - From: ${data['fromUserId']}');
        print('  - Status: ${data['status']}');
        print('  - Message: ${data['message']}');
      }

      // Check requests FROM current user
      final outgoingRequests = await _firestore
          .collection('connection_requests')
          .where('fromUserId', isEqualTo: user.uid)
          .get();

      print('Outgoing requests: ${outgoingRequests.docs.length}');
      for (var doc in outgoingRequests.docs) {
        final data = doc.data();
        print('  - To: ${data['toUserId']}');
        print('  - Status: ${data['status']}');
        print('  - Message: ${data['message']}');
      }

    } catch (e) {
      print('❌ Error checking connection requests: $e');
    }
  }

  static Future<void> _debugConnections() async {
    print('\n🤝 Checking connections...');
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final connections = await _firestore
          .collection('connections')
          .where('participants', arrayContains: user.uid)
          .get();

      print('Total connections: ${connections.docs.length}');
      for (var doc in connections.docs) {
        final data = doc.data();
        print('  - Participants: ${data['participants']}');
        print('  - Status: ${data['status']}');
        print('  - Last Message: ${data['lastMessage']}');
      }

    } catch (e) {
      print('❌ Error checking connections: $e');
    }
  }

  static Future<void> _debugMentorshipOpportunities() async {
    print('\n🎓 Checking mentorship opportunities...');
    try {
      final opportunities = await _firestore
          .collection('mentorship_opportunities')
          .get();

      print('Total mentorship opportunities: ${opportunities.docs.length}');
      for (var doc in opportunities.docs) {
        final data = doc.data();
        print('  - Title: ${data['title']}');
        print('  - Status: ${data['status']}');
        print('  - Created by: ${data['createdBy']}');
      }

    } catch (e) {
      print('❌ Error checking mentorship opportunities: $e');
    }
  }

  // Method to create sample data for testing
  static Future<void> createSampleData() async {
    print('🔧 Creating sample data...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user for creating sample data');
        return;
      }

      // Create sample users
      await _createSampleUsers();

      // Create sample mentorship opportunities
      await _createSampleMentorshipOpportunities();

      print('✅ Sample data created successfully!');

    } catch (e) {
      print('❌ Error creating sample data: $e');
    }
  }

  static Future<void> _createSampleUsers() async {
    final sampleUsers = [
      {
        'name': 'Alice Johnson',
        'email': 'alice@example.com',
        'bio': 'Full-stack developer with 5 years experience',
        'location': 'San Francisco, CA',
        'experienceLevel': 'Advanced',
        'profileComplete': true,
        'isOnline': true,
        'availableForMentoring': true,
        'skillsOffered': [
          {'name': 'React', 'category': 'Programming'},
          {'name': 'Node.js', 'category': 'Programming'},
          {'name': 'JavaScript', 'category': 'Programming'}
        ],
        'skillsWanted': [
          {'name': 'Machine Learning', 'category': 'Programming'},
          {'name': 'Python', 'category': 'Programming'}
        ],
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Bob Smith',
        'email': 'bob@example.com',
        'bio': 'UI/UX Designer passionate about user experience',
        'location': 'New York, NY',
        'experienceLevel': 'Intermediate',
        'profileComplete': true,
        'isOnline': false,
        'availableForMentoring': false,
        'skillsOffered': [
          {'name': 'UI Design', 'category': 'Design'},
          {'name': 'Figma', 'category': 'Design'},
          {'name': 'Prototyping', 'category': 'Design'}
        ],
        'skillsWanted': [
          {'name': 'Frontend Development', 'category': 'Programming'},
          {'name': 'CSS', 'category': 'Programming'}
        ],
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Carol Davis',
        'email': 'carol@example.com',
        'bio': 'Marketing specialist with digital strategy expertise',
        'location': 'Austin, TX',
        'experienceLevel': 'Expert',
        'profileComplete': true,
        'isOnline': true,
        'availableForMentoring': true,
        'skillsOffered': [
          {'name': 'Digital Marketing', 'category': 'Marketing'},
          {'name': 'SEO', 'category': 'Marketing'},
          {'name': 'Content Strategy', 'category': 'Marketing'}
        ],
        'skillsWanted': [
          {'name': 'Data Analytics', 'category': 'Business'},
          {'name': 'Python', 'category': 'Programming'}
        ],
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      }
    ];

    for (int i = 0; i < sampleUsers.length; i++) {
      final userId = 'sample_user_$i';
      await _firestore.collection('users').doc(userId).set(sampleUsers[i]);
      print('✅ Created sample user: ${sampleUsers[i]['name']}');
    }
  }

  static Future<void> _createSampleMentorshipOpportunities() async {
    final opportunities = [
      {
        'title': 'Learn React Basics',
        'description': 'Looking for someone to help me understand React hooks and component lifecycle',
        'skillLevel': 'Beginner',
        'timeCommitment': '2-3 hours/week',
        'duration': '1 month',
        'points': 50,
        'status': 'open',
        'createdBy': 'sample_user_1',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'UI Design Review',
        'description': 'Need feedback on my mobile app design and user flow',
        'skillLevel': 'Intermediate',
        'timeCommitment': '1-2 hours/week',
        'duration': '2 weeks',
        'points': 30,
        'status': 'open',
        'createdBy': 'sample_user_2',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Marketing Strategy Help',
        'description': 'Help with creating a comprehensive digital marketing plan for a startup',
        'skillLevel': 'Advanced',
        'timeCommitment': '3-4 hours/week',
        'duration': '6 weeks',
        'points': 100,
        'status': 'open',
        'createdBy': 'sample_user_0',
        'createdAt': FieldValue.serverTimestamp(),
      }
    ];

    for (var opportunity in opportunities) {
      await _firestore.collection('mentorship_opportunities').add(opportunity);
      print('✅ Created mentorship opportunity: ${opportunity['title']}');
    }
  }

  // Fix common issues
  static Future<void> fixCommonIssues() async {
    print('🔧 Fixing common issues...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      // Fix 1: Ensure current user document exists and is complete
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('🔧 Creating user document...');
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email,
          'profileComplete': true,
          'isOnline': true,
          'bio': 'Flutter developer',
          'location': 'Unknown',
          'experienceLevel': 'Intermediate',
          'availableForMentoring': false,
          'skillsOffered': [
            {'name': 'Flutter', 'category': 'Programming'}
          ],
          'skillsWanted': [
            {'name': 'React', 'category': 'Programming'}
          ],
          'joinedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print('✅ User document created');
      } else {
        // Update existing user to ensure profileComplete is true
        await _firestore.collection('users').doc(user.uid).update({
          'profileComplete': true,
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print('✅ User document updated');
      }

    } catch (e) {
      print('❌ Error fixing issues: $e');
    }
  }
}