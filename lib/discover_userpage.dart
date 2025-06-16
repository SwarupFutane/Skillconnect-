import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DiscoverUsersPage extends StatefulWidget {
  const DiscoverUsersPage({Key? key}) : super(key: key);

  @override
  State<DiscoverUsersPage> createState() => _DiscoverUsersPageState();
}

class _DiscoverUsersPageState extends State<DiscoverUsersPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<String> _selectedSkillFilters = [];
  String _locationFilter = '';
  String _experienceFilter = '';
  bool _isLoading = true;
  Map<String, dynamic> _userProfile = {};

  final List<String> _skillCategories = [
    'Programming', 'Design', 'Marketing', 'Business',
    'Languages', 'Music', 'Sports', 'Cooking', 'Other'
  ];

  final List<String> _experienceLevels = [
    'Beginner', 'Intermediate', 'Advanced', 'Expert'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileData = prefs.getString('userProfile');
    if (profileData != null) {
      setState(() {
        _userProfile = json.decode(profileData);
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get current user's connections and requests to exclude them
      final connectionsSnapshot = await _firestore
          .collection('connections')
          .where('participants', arrayContains: userId)
          .get();

      final requestsSnapshot = await _firestore
          .collection('connection_requests')
          .where('senderId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      Set<String> connectedUserIds = {};

      // Add connected users
      for (var doc in connectionsSnapshot.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        connectedUserIds.addAll(participants.where((id) => id != userId));
      }

      // Add users with pending requests
      for (var doc in requestsSnapshot.docs) {
        connectedUserIds.add(doc.data()['receiverId']);
      }

      // Fetch all users except current user and already connected
      final usersSnapshot = await _firestore.collection('users').get();

      List<Map<String, dynamic>> users = [];
      for (var doc in usersSnapshot.docs) {
        if (doc.id != userId && !connectedUserIds.contains(doc.id)) {
          final userData = doc.data();
          users.add({
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown User',
            'bio': userData['bio'] ?? '',
            'location': userData['location'] ?? '',
            'experienceLevel': userData['experienceLevel'] ?? 'Beginner',
            'profileImage': userData['profileImage'],
            'skillsOffered': userData['skillsOffered'] ?? [],
            'skillsWanted': userData['skillsWanted'] ?? [],
            'availableForMentoring': userData['availableForMentoring'] ?? false,
            'isOnline': userData['isOnline'] ?? false,
            'lastSeen': userData['lastSeen'],
            'joinedAt': userData['joinedAt'],
          });
        }
      }

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });

      _calculateMatches();
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateMatches() {
    List<String> mySkillsOffered = [];
    List<String> mySkillsWanted = [];

    if (_userProfile['skillsOffered'] != null) {
      mySkillsOffered = (_userProfile['skillsOffered'] as List)
          .map((skill) => skill['name'].toString().toLowerCase())
          .toList();
    }

    if (_userProfile['skillsWanted'] != null) {
      mySkillsWanted = (_userProfile['skillsWanted'] as List)
          .map((skill) => skill['name'].toString().toLowerCase())
          .toList();
    }

    for (var user in _allUsers) {
      List<String> theirSkillsOffered = [];
      List<String> theirSkillsWanted = [];

      if (user['skillsOffered'] != null) {
        theirSkillsOffered = (user['skillsOffered'] as List)
            .map((skill) => skill['name'].toString().toLowerCase())
            .toList();
      }

      if (user['skillsWanted'] != null) {
        theirSkillsWanted = (user['skillsWanted'] as List)
            .map((skill) => skill['name'].toString().toLowerCase())
            .toList();
      }

      // Calculate match percentage
      int matches = 0;
      int totalPossible = 0;

      // Skills I offer that they want
      for (String skill in mySkillsOffered) {
        totalPossible++;
        if (theirSkillsWanted.contains(skill)) {
          matches += 2; // Higher weight for direct matches
        }
      }

      // Skills they offer that I want
      for (String skill in mySkillsWanted) {
        totalPossible++;
        if (theirSkillsOffered.contains(skill)) {
          matches += 2;
        }
      }

      // Common skills offered (lower weight)
      for (String skill in mySkillsOffered) {
        if (theirSkillsOffered.contains(skill)) {
          matches += 1;
        }
      }

      int matchPercentage = totalPossible > 0 ? ((matches / (totalPossible * 2)) * 100).round() : 0;
      user['matchPercentage'] = matchPercentage.clamp(0, 100);
    }

    // Sort by match percentage
    _allUsers.sort((a, b) => (b['matchPercentage'] ?? 0).compareTo(a['matchPercentage'] ?? 0));
    _applyFilters();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allUsers);

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((user) {
        return user['name'].toLowerCase().contains(searchTerm) ||
            user['bio'].toLowerCase().contains(searchTerm) ||
            (user['skillsOffered'] as List).any((skill) =>
                skill['name'].toLowerCase().contains(searchTerm)) ||
            (user['skillsWanted'] as List).any((skill) =>
                skill['name'].toLowerCase().contains(searchTerm));
      }).toList();
    }

    // Skill filters
    if (_selectedSkillFilters.isNotEmpty) {
      filtered = filtered.where((user) {
        final userSkills = (user['skillsOffered'] as List)
            .map((skill) => skill['category'].toString())
            .toSet();
        return _selectedSkillFilters.any((filter) => userSkills.contains(filter));
      }).toList();
    }

    // Location filter
    if (_locationFilter.isNotEmpty) {
      filtered = filtered.where((user) =>
          user['location'].toLowerCase().contains(_locationFilter.toLowerCase())).toList();
    }

    // Experience filter
    if (_experienceFilter.isNotEmpty) {
      filtered = filtered.where((user) =>
      user['experienceLevel'] == _experienceFilter).toList();
    }

    setState(() {
      _filteredUsers = filtered;
    });
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'Discover People',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showFiltersDialog,
            icon: Stack(
              children: [
                const Icon(Icons.filter_list, color: Colors.white),
                if (_hasActiveFilters())
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF667eea),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF667eea),
          labelColor: const Color(0xFF667eea),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Recommended'),
            Tab(text: 'All Users'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, skills, bio...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF667eea)),
                ),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecommendedTab(),
                _buildAllUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedTab() {
    final recommendedUsers = _filteredUsers.where((user) =>
    (user['matchPercentage'] ?? 0) > 30).toList();

    if (recommendedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'No recommended matches',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Try updating your skills or removing filters',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(1);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Browse All Users'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recommendedUsers.length,
      itemBuilder: (context, index) {
        final user = recommendedUsers[index];
        return _buildUserCard(user, showMatchPercentage: true);
      },
    );
  }

  Widget _buildAllUsersTab() {
    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 20),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user, showMatchPercentage: false);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, {required bool showMatchPercentage}) {
    final matchPercentage = user['matchPercentage'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showMatchPercentage && matchPercentage > 70
              ? const Color(0xFF667eea)
              : const Color(0xFF2A2D3A),
          width: showMatchPercentage && matchPercentage > 70 ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              // Profile Picture
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: user['isOnline'] ? Colors.green : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: user['profileImage'] != null
                          ? Image.file(
                        File(user['profileImage']),
                        fit: BoxFit.cover,
                      )
                          : Container(
                        color: const Color(0xFF0A0E21),
                        child: const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  if (user['isOnline'])
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1D1E33), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (showMatchPercentage && matchPercentage > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getMatchColor(matchPercentage),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$matchPercentage% match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (user['location'].isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            user['location'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        const Icon(Icons.trending_up, color: Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          user['experienceLevel'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        if (user['availableForMentoring']) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Mentor',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (user['bio'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user['bio'],
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Skills Section
          if (user['skillsOffered'].isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Offers:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (user['skillsOffered'] as List)
                  .take(4)
                  .map((skill) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  skill['name'] ?? skill.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                  ),
                ),
              ))
                  .toList(),
            ),
          ],

          if (user['skillsWanted'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.school_outlined, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Learning:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (user['skillsWanted'] as List)
                  .take(4)
                  .map((skill) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  skill['name'] ?? skill.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                  ),
                ),
              ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _sendConnectionRequest(user),
                  icon: const Icon(Icons.connect_without_contact, size: 18),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _viewUserProfile(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2D3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.visibility, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return const Color(0xFF667eea);
    if (percentage >= 40) return Colors.orange;
    return Colors.grey;
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSkillFilters.clear();
                        _locationFilter = '';
                        _experienceFilter = '';
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Color(0xFF667eea)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Skills Filter
              const Text(
                'Skills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _skillCategories.map((skill) {
                  final isSelected = _selectedSkillFilters.contains(skill);
                  return FilterChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (selected) {
                      setBottomSheetState(() {
                        if (selected) {
                          _selectedSkillFilters.add(skill);
                        } else {
                          _selectedSkillFilters.remove(skill);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF667eea),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                    backgroundColor: const Color(0xFF0A0E21),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF667eea) : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Experience Filter
              const Text(
                'Experience Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _experienceFilter.isEmpty ? null : _experienceFilter,
                hint: const Text('Select experience level', style: TextStyle(color: Colors.grey)),
                style: const TextStyle(color: Colors.white),
                dropdownColor: const Color(0xFF1D1E33),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0A0E21),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                  ),
                ),
                items: _experienceLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (value) {
                  setBottomSheetState(() {
                    _experienceFilter = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 20),

              // Location Filter
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter location',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0A0E21),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                  ),
                ),
                onChanged: (value) {
                  setBottomSheetState(() {
                    _locationFilter = value;
                  });
                },
              ),
              const SizedBox(height: 30),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedSkillFilters.isNotEmpty ||
        _locationFilter.isNotEmpty ||
        _experienceFilter.isNotEmpty;
  }

  Future<void> _sendConnectionRequest(Map<String, dynamic> user) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Show message dialog
      String message = '';
      final result = await showDialog<String>(
        context: context,
        builder: (context) => _buildConnectionRequestDialog(user['name'], (msg) => message = msg),
      );

      if (result != 'send') return;

      // Send connection request
      await _firestore.collection('connection_requests').add({
        'senderId': userId,
        'receiverId': user['id'],
        'message': message,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Remove from list
      setState(() {
        _allUsers.removeWhere((u) => u['id'] == user['id']);
        _filteredUsers.removeWhere((u) => u['id'] == user['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${user['name']}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildConnectionRequestDialog(String userName, Function(String) onMessageChanged) {
    final messageController = TextEditingController();

    return AlertDialog(
      backgroundColor: const Color(0xFF1D1E33),
      title: Text(
        'Connect with $userName',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add a personal message (optional):',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Hi! I\'d love to connect and share our skills...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF0A0E21),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
              ),
            ),
            onChanged: onMessageChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            onMessageChanged(messageController.text);
            Navigator.pop(context, 'send');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Send Request'),
        ),
      ],
    );
  }

  void _viewUserProfile(Map<String, dynamic> user) {
    // TODO: Navigate to detailed user profile page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing ${user['name']}\'s profile...'),
        backgroundColor: const Color(0xFF667eea),
      ),
    );
  }
}