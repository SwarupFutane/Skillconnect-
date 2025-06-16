import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profilepage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'connectionpage.dart';
import 'discover_userpage.dart';
import 'firebase_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _userProfile = {};
  List<Map<String, dynamic>> _suggestedConnections = [];
  List<Map<String, dynamic>> _mentorshipOpportunities = [];
  int _currentStreak = 0;
  bool _isLoading = true;
  int _notificationCount = 0;

  Future<void> _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(currentProfile: _userProfile),
      ),
    );

    // If profile was updated, refresh the UI
    if (result != null) {
      setState(() {
        _userProfile = result;
      });

      // Refresh other data that might depend on profile
      await _loadSuggestedConnections();
      await _loadNotificationCount();

      print('✅ Profile updated and UI refreshed');
    }
  }


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeApp();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    print('🐛 Starting debug...');
    await FirebaseHelper.debugAllData();
    await FirebaseHelper.initializeApp();
    await _loadUserData();
    await _loadSuggestedConnections();
    await _loadNotificationCount();
  }

  Future<void> _loadUserData() async {
    try {
      // First try to get from Firebase
      final firebaseProfile = await FirebaseHelper.getUserProfile();

      if (firebaseProfile != null) {
        setState(() {
          _userProfile = firebaseProfile;
        });

        // Also sync to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userProfile', json.encode(firebaseProfile));
      } else {
        // Fallback to local storage
        final prefs = await SharedPreferences.getInstance();
        final profileData = prefs.getString('userProfile');

        if (profileData != null) {
          setState(() {
            _userProfile = json.decode(profileData);
          });
        }
      }

      // Load streak
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentStreak = prefs.getInt('mentorStreak') ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final count = await FirebaseHelper.getNotificationCount();
      setState(() {
        _notificationCount = count;
      });
    } catch (e) {
      print('Error loading notification count: $e');
    }
  }

  Future<void> _loadSuggestedConnections() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load real suggested connections
      final suggestions = await FirebaseHelper.getSuggestedConnections();

      // Load real mentorship opportunities
      final opportunities = await FirebaseHelper.getMentorshipOpportunities();

      setState(() {
        _suggestedConnections = suggestions;
        _mentorshipOpportunities = opportunities;
        _isLoading = false;
      });

      print('✅ Loaded ${suggestions.length} suggestions and ${opportunities.length} opportunities');
    } catch (e) {
      print('⚠️ Error loading connections: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendConnectionRequest(Map<String, dynamic> user) async {
    try {
      // Show dialog to add a message
      String? message = await _showConnectionRequestDialog(user['name']);
      if (message == null) return;

      final success = await FirebaseHelper.sendConnectionRequest(
        user['userId'],
        message,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection request sent to ${user['name']}! 🚀'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh suggestions
        await _loadSuggestedConnections();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send connection request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showConnectionRequestDialog(String userName) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: Text(
          'Connect with $userName',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send a message with your connection request:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Hi! I'd love to connect and learn from you...",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF667eea)),
                ),
                filled: true,
                fillColor: const Color(0xFF0A0E21),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final message = controller.text.trim();
              if (message.isNotEmpty) {
                Navigator.pop(context, message);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
            ),
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          const ConnectionsPage(),
          _buildMentorshipTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E21),
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
            child: const Icon(Icons.connect_without_contact, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'SkillConnect',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // Streak Counter
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange[600],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_currentStreak',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Notifications
        Stack(
          children: [
            IconButton(
              onPressed: () {
                // Navigate to notifications or connections page
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            ),
            if (_notificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _notificationCount > 99 ? '99+' : _notificationCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // Profile
        GestureDetector(
          onTap: () => _tabController.animateTo(3),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1D1E33),
              border: Border.all(color: const Color(0xFF667eea), width: 1),
            ),
            child: _userProfile['profileImage'] != null
                ? ClipOval(
              child: Image.file(
                File(_userProfile['profileImage']),
                fit: BoxFit.cover,
              ),
            )
                : const Icon(Icons.person, color: Colors.grey, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D1E33),
        border: Border(top: BorderSide(color: Color(0xFF2A2D3A), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF667eea),
        labelColor: const Color(0xFF667eea),
        unselectedLabelColor: Colors.grey,
        tabs: [
          Tab(
            icon: Stack(
              children: [
                const Icon(Icons.explore),
                if (_notificationCount > 0 && _tabController.index != 1)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            text: 'Discover',
          ),
          Tab(
            icon: Stack(
              children: [
                const Icon(Icons.people),
                if (_notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            text: 'Connections',
          ),
          const Tab(icon: Icon(Icons.school), text: 'Mentorship'),
          const Tab(icon: Icon(Icons.person), text: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeCard(),
          const SizedBox(height: 24),

          // Quick Stats
          _buildQuickStats(),
          const SizedBox(height: 24),

          // Suggested Connections
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Suggested Connections',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DiscoverUsersPage(),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF667eea)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Connection Cards
          if (_suggestedConnections.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.people_outline,
                    size: 60,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No suggestions yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete your profile to see suggested connections',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...(_suggestedConnections.take(2).map((connection) =>
                _buildConnectionCard(connection)).toList()),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, ${_userProfile['name']?.split(' ')[0] ?? 'User'}! 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to connect and learn something new today?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DiscoverUsersPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: const Text('Quick Match'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DiscoverUsersPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.search),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Skills Offered',
            '${(_userProfile['skillsOffered'] as List?)?.length ?? 0}',
            Icons.lightbulb_outline,
            Colors.green[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Learning',
            '${(_userProfile['skillsWanted'] as List?)?.length ?? 0}',
            Icons.school_outlined,
            Colors.orange[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Connections',
            '${_suggestedConnections.length}',
            Icons.people_outline,
            const Color(0xFF667eea),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(Map<String, dynamic> connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A0E21),
                  border: Border.all(color: const Color(0xFF667eea), width: 2),
                ),
                child: connection['avatar'] != null
                    ? ClipOval(child: Image.file(File(connection['avatar'])))
                    : Icon(
                  Icons.person,
                  color: Colors.grey[400],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          connection['name'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (connection['isOnline'] == true)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      connection['location'] ?? 'Unknown location',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Match percentage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${connection['matchPercentage'] ?? 0}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            connection['bio'] ?? 'No bio available',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),

          // Skills
          if (connection['skillsOffered'] != null && (connection['skillsOffered'] as List).isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (connection['skillsOffered'] as List).take(2).join(', '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          if (connection['skillsWanted'] != null && (connection['skillsWanted'] as List).isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.school_outlined, color: Colors.orange, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    (connection['skillsWanted'] as List).take(2).join(', '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendConnectionRequest(connection),
                  icon: const Icon(Icons.connect_without_contact, size: 16),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile view coming soon!'),
                      backgroundColor: Color(0xFF667eea),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2D3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.visibility, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMentorshipTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mentorship Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.orange[600]!, Colors.deepOrange[600]!],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mentorship Hub 🎓',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share knowledge, earn streaks, build connections',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Current Streak: $_currentStreak days',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Mentorship Opportunities
          const Text(
            'Available Opportunities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Show real mentorship opportunities
          if (_mentorshipOpportunities.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.school_outlined,
                    size: 60,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No mentorship opportunities yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._mentorshipOpportunities.map((opportunity) =>
                _buildMentorshipCard(opportunity)).toList(),
        ],
      ),
    );
  }

  Widget _buildMentorshipCard(Map<String, dynamic> opportunity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  opportunity['title'] ?? 'Mentorship Opportunity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${opportunity['points'] ?? 0} pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            opportunity['description'] ?? 'No description available',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip('👤 ${opportunity['requester'] ?? 'Unknown'}'),
              const SizedBox(width: 8),
              _buildInfoChip('📊 ${opportunity['skillLevel'] ?? 'Any Level'}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip('⏰ ${opportunity['timeCommitment'] ?? 'Flexible'}'),
              const SizedBox(width: 8),
              _buildInfoChip('📅 ${opportunity['duration'] ?? 'Ongoing'}'),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              _acceptMentorship(opportunity);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Accept Mentorship'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2D3A)),
            ),
            child: Column(
              children: [
                // Profile Picture
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF667eea), width: 3),
                  ),
                  child: _userProfile['profileImage'] != null
                      ? ClipOval(
                    child: Image.file(
                      File(_userProfile['profileImage']),
                      fit: BoxFit.cover,
                    ),
                  )
                      : const Icon(Icons.person, color: Colors.grey, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  _userProfile['name'] ?? 'User Name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (_userProfile['bio'] != null && _userProfile['bio'].toString().isNotEmpty)
                  Text(
                    _userProfile['bio'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 8),
                if (_userProfile['location'] != null && _userProfile['location'].toString().isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _userProfile['location'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),

                // Edit Profile Button
                ElevatedButton.icon(
                  onPressed: () => _editProfile(),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Skills Summary
          if (_userProfile['skillsOffered'] != null && (_userProfile['skillsOffered'] as List).isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2D3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Skills I Offer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_userProfile['skillsOffered'] as List).take(6).map<Widget>((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Text(
                          skill['name'],
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_userProfile['skillsWanted'] != null && (_userProfile['skillsWanted'] as List).isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2D3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.school, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Skills I Want to Learn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (_userProfile['skillsWanted'] as List).take(6).map<Widget>((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Text(
                          skill['name'],
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Settings Options
          _buildSettingsOption(
            Icons.notifications_outlined,
            'Notifications',
            'Manage your notification preferences',
                () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings coming soon!'),
                  backgroundColor: Color(0xFF667eea),
                ),
              );
            },
          ),
          _buildSettingsOption(
            Icons.privacy_tip_outlined,
            'Privacy',
            'Control your privacy settings',
                () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy settings coming soon!'),
                  backgroundColor: Color(0xFF667eea),
                ),
              );
            },
          ),
          _buildSettingsOption(
            Icons.help_outline,
            'Help & Support',
            'Get help or contact support',
                () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Help & Support coming soon!'),
                  backgroundColor: Color(0xFF667eea),
                ),
              );
            },
          ),
          _buildSettingsOption(
            Icons.logout,
            'Sign Out',
            'Sign out of your account',
                () async {
              await _signOut();
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOption(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap, {
        bool isDestructive = false,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF667eea),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        tileColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2D3A)),
        ),
      ),
    );
  }

  void _acceptMentorship(Map<String, dynamic> opportunity) async {
    try {
      // Update streak
      await FirebaseHelper.updateMentorshipStreak();
      final prefs = await SharedPreferences.getInstance();
      final newStreak = prefs.getInt('mentorStreak') ?? 0;

      setState(() {
        _currentStreak = newStreak;
        _mentorshipOpportunities.remove(opportunity);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mentorship accepted! Streak: $_currentStreak days 🔥'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting mentorship: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Replace your _signOut method in homepage.dart with this simpler version:

  Future<void> _signOut() async {
    try {
      print('🔄 Starting sign out from HomePage...');

      // Use Firebase Helper's signOut method (it handles online status)
      await FirebaseHelper.signOut();

      // Navigate to login with complete stack clear
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully. Please log in again.'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      print('HomePage sign out error: $e');

      // Even if Firebase Helper fails, navigate to login
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      }
    }
  }
}