import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// Mentor model for real-time data
class MentorModel {
  final String id;
  final String name;
  final String skill;
  final double rating;
  final int sessions;
  final String badge;
  final String avatar;
  bool isOnline;
  final int hourlyRate;
  final String bio;
  final DateTime lastSeen;
  final String status; // 'available', 'busy', 'in_session', 'offline'
  final int responseTime; // average response time in minutes
  final List<String> activeChats;

  MentorModel({
    required this.id,
    required this.name,
    required this.skill,
    required this.rating,
    required this.sessions,
    required this.badge,
    required this.avatar,
    required this.isOnline,
    required this.hourlyRate,
    required this.bio,
    required this.lastSeen,
    required this.status,
    required this.responseTime,
    required this.activeChats,
  });

  MentorModel copyWith({
    String? id,
    String? name,
    String? skill,
    double? rating,
    int? sessions,
    String? badge,
    String? avatar,
    bool? isOnline,
    int? hourlyRate,
    String? bio,
    DateTime? lastSeen,
    String? status,
    int? responseTime,
    List<String>? activeChats,
  }) {
    return MentorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      skill: skill ?? this.skill,
      rating: rating ?? this.rating,
      sessions: sessions ?? this.sessions,
      badge: badge ?? this.badge,
      avatar: avatar ?? this.avatar,
      isOnline: isOnline ?? this.isOnline,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      bio: bio ?? this.bio,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      responseTime: responseTime ?? this.responseTime,
      activeChats: activeChats ?? this.activeChats,
    );
  }
}

// Real-time mentor service (simulates WebSocket/Firebase)
class RealTimeMentorService {
  static final RealTimeMentorService _instance = RealTimeMentorService._internal();
  factory RealTimeMentorService() => _instance;
  RealTimeMentorService._internal();

  final StreamController<List<MentorModel>> _mentorsController =
  StreamController<List<MentorModel>>.broadcast();

  final StreamController<Map<String, dynamic>> _mentorUpdatesController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<MentorModel>> get mentorsStream => _mentorsController.stream;
  Stream<Map<String, dynamic>> get mentorUpdatesStream => _mentorUpdatesController.stream;

  List<MentorModel> _mentors = [];
  Timer? _updateTimer;
  final Random _random = Random();

  void startRealTimeUpdates() {
    _initializeMentors();

    // Simulate real-time updates every 3-10 seconds
    _updateTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _simulateRealTimeUpdate();
    });
  }

  void _initializeMentors() {
    _mentors = [
      MentorModel(
        id: 'mentor_1',
        name: 'Sarah Johnson',
        skill: 'React Development',
        rating: 4.8,
        sessions: 156,
        badge: 'Expert',
        avatar: 'SJ',
        isOnline: true,
        hourlyRate: 35,
        bio: 'Full-stack developer with 5+ years of React experience.',
        lastSeen: DateTime.now(),
        status: 'available',
        responseTime: 2,
        activeChats: [],
      ),
      MentorModel(
        id: 'mentor_2',
        name: 'Mike Chen',
        skill: 'Flutter Development',
        rating: 4.9,
        sessions: 203,
        badge: 'Master',
        avatar: 'MC',
        isOnline: true,
        hourlyRate: 40,
        bio: 'Mobile app developer specializing in Flutter and Dart.',
        lastSeen: DateTime.now(),
        status: 'busy',
        responseTime: 5,
        activeChats: ['user_1', 'user_2'],
      ),
      MentorModel(
        id: 'mentor_3',
        name: 'Emily Davis',
        skill: 'UI/UX Design',
        rating: 4.7,
        sessions: 89,
        badge: 'Pro',
        avatar: 'ED',
        isOnline: false,
        hourlyRate: 30,
        bio: 'Creative designer with expertise in user experience design.',
        lastSeen: DateTime.now().subtract(Duration(minutes: 15)),
        status: 'offline',
        responseTime: 10,
        activeChats: [],
      ),
      MentorModel(
        id: 'mentor_4',
        name: 'David Kim',
        skill: 'Node.js',
        rating: 4.7,
        sessions: 92,
        badge: 'Expert',
        avatar: 'DK',
        isOnline: true,
        hourlyRate: 28,
        bio: 'Backend specialist with expertise in Node.js and microservices.',
        lastSeen: DateTime.now(),
        status: 'in_session',
        responseTime: 3,
        activeChats: ['user_3'],
      ),
      MentorModel(
        id: 'mentor_5',
        name: 'Lisa Zhang',
        skill: 'Data Science',
        rating: 4.9,
        sessions: 134,
        badge: 'Master',
        avatar: 'LZ',
        isOnline: true,
        hourlyRate: 45,
        bio: 'Data scientist with experience in ML and Python.',
        lastSeen: DateTime.now(),
        status: 'available',
        responseTime: 1,
        activeChats: [],
      ),
    ];

    _mentorsController.add(_mentors);
  }

  void _simulateRealTimeUpdate() {
    if (_mentors.isEmpty) return;

    final mentorIndex = _random.nextInt(_mentors.length);
    final mentor = _mentors[mentorIndex];

    // Simulate different types of updates
    final updateType = _random.nextInt(4);

    switch (updateType) {
      case 0: // Online status change
        _mentors[mentorIndex] = mentor.copyWith(
          isOnline: !mentor.isOnline,
          lastSeen: DateTime.now(),
          status: mentor.isOnline ? 'offline' : 'available',
        );
        _mentorUpdatesController.add({
          'type': 'status_change',
          'mentorId': mentor.id,
          'isOnline': !mentor.isOnline,
        });
        break;

      case 1: // Status change (available, busy, in_session)
        final statuses = ['available', 'busy', 'in_session'];
        final newStatus = statuses[_random.nextInt(statuses.length)];
        _mentors[mentorIndex] = mentor.copyWith(
          status: newStatus,
          lastSeen: DateTime.now(),
        );
        _mentorUpdatesController.add({
          'type': 'mentor_status',
          'mentorId': mentor.id,
          'status': newStatus,
        });
        break;

      case 2: // New chat/session
        final newActiveChats = List<String>.from(mentor.activeChats);
        if (newActiveChats.length < 3) {
          newActiveChats.add('user_${_random.nextInt(100)}');
          _mentors[mentorIndex] = mentor.copyWith(
            activeChats: newActiveChats,
            status: newActiveChats.length > 1 ? 'busy' : 'in_session',
          );
          _mentorUpdatesController.add({
            'type': 'new_chat',
            'mentorId': mentor.id,
            'activeChats': newActiveChats.length,
          });
        }
        break;

      case 3: // Session completion
        if (mentor.activeChats.isNotEmpty) {
          final newActiveChats = List<String>.from(mentor.activeChats);
          newActiveChats.removeAt(0);
          _mentors[mentorIndex] = mentor.copyWith(
            activeChats: newActiveChats,
            sessions: mentor.sessions + 1,
            status: newActiveChats.isEmpty ? 'available' : 'busy',
          );
          _mentorUpdatesController.add({
            'type': 'session_completed',
            'mentorId': mentor.id,
            'totalSessions': mentor.sessions + 1,
          });
        }
        break;
    }

    _mentorsController.add(_mentors);
  }

  void dispose() {
    _updateTimer?.cancel();
    _mentorsController.close();
    _mentorUpdatesController.close();
  }
}

class RealTimeMentorsScreen extends StatefulWidget {
  @override
  State<RealTimeMentorsScreen> createState() => _RealTimeMentorsScreenState();
}

class _RealTimeMentorsScreenState extends State<RealTimeMentorsScreen>
    with SingleTickerProviderStateMixin {
  final RealTimeMentorService _mentorService = RealTimeMentorService();
  late AnimationController _pulseController;
  String searchQuery = '';
  String selectedStatus = 'All';
  List<MentorModel> mentors = [];
  List<MentorModel> filteredMentors = [];

  final List<String> statusOptions = ['All', 'Available', 'Busy', 'In Session', 'Online'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _mentorService.startRealTimeUpdates();

    // Listen to mentor updates
    _mentorService.mentorsStream.listen((updatedMentors) {
      setState(() {
        mentors = updatedMentors;
        _applyFilters();
      });
    });

    // Listen to real-time updates for notifications
    _mentorService.mentorUpdatesStream.listen((update) {
      _showUpdateNotification(update);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    filteredMentors = mentors.where((mentor) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!mentor.name.toLowerCase().contains(query) &&
            !mentor.skill.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      switch (selectedStatus) {
        case 'Available':
          return mentor.status == 'available' && mentor.isOnline;
        case 'Busy':
          return mentor.status == 'busy' && mentor.isOnline;
        case 'In Session':
          return mentor.status == 'in_session' && mentor.isOnline;
        case 'Online':
          return mentor.isOnline;
        default:
          return true;
      }
    }).toList();
  }

  void _showUpdateNotification(Map<String, dynamic> update) {
    String message = '';
    switch (update['type']) {
      case 'status_change':
        final mentor = mentors.firstWhere((m) => m.id == update['mentorId']);
        message = '${mentor.name} is now ${update['isOnline'] ? 'online' : 'offline'}';
        break;
      case 'mentor_status':
        final mentor = mentors.firstWhere((m) => m.id == update['mentorId']);
        message = '${mentor.name} is now ${update['status']}';
        break;
      case 'new_chat':
        final mentor = mentors.firstWhere((m) => m.id == update['mentorId']);
        message = '${mentor.name} started a new session';
        break;
      case 'session_completed':
        final mentor = mentors.firstWhere((m) => m.id == update['mentorId']);
        message = '${mentor.name} completed a session';
        break;
    }

    if (message.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Color(0xFF667eea),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'Live Mentors',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(_pulseController.value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          StreamBuilder<List<MentorModel>>(
            stream: _mentorService.mentorsStream,
            builder: (context, snapshot) {
              final onlineCount = snapshot.data?.where((m) => m.isOnline).length ?? 0;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    '$onlineCount online',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusFilters(),
          _buildMentorsCounter(),
          Expanded(child: _buildMentorsList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(20),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: TextField(
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search live mentors...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: Icon(Icons.wifi, color: Colors.green),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: statusOptions.map((status) {
          final isSelected = selectedStatus == status;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedStatus = status;
                _applyFilters();
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF667eea) : Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Color(0xFF667eea) : Colors.grey[800]!,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status != 'All') ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                  ],
                  Text(
                    status,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'in session':
        return Colors.red;
      case 'online':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMentorsCounter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${filteredMentors.length} mentors found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              Icon(Icons.update, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text(
                'Live Updates',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMentorsList() {
    if (filteredMentors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.grey[400], size: 64),
            SizedBox(height: 16),
            Text(
              'No mentors found',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredMentors.length,
      itemBuilder: (context, index) {
        final mentor = filteredMentors[index];
        return _buildMentorCard(mentor);
      },
    );
  }

  Widget _buildMentorCard(MentorModel mentor) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mentor.isOnline ? Color(0xFF667eea) : Colors.grey[800]!,
          width: mentor.isOnline ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF667eea),
                    child: Text(
                      mentor.avatar,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: mentor.isOnline
                                ? _getStatusColor(mentor.status)
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Color(0xFF1A1A1A), width: 2),
                            boxShadow: mentor.isOnline ? [
                              BoxShadow(
                                color: _getStatusColor(mentor.status).withOpacity(
                                    0.5 + 0.5 * _pulseController.value),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ] : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mentor.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            mentor.badge,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      mentor.skill,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: _getStatusColor(mentor.status),
                          size: 8,
                        ),
                        SizedBox(width: 4),
                        Text(
                          mentor.status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(mentor.status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (mentor.activeChats.isNotEmpty) ...[
                          SizedBox(width: 12),
                          Icon(Icons.chat, color: Colors.orange, size: 12),
                          SizedBox(width: 2),
                          Text(
                            '${mentor.activeChats.length}',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.star, color: Color(0xFFffd700), size: 16),
              SizedBox(width: 4),
              Text(
                mentor.rating.toString(),
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              SizedBox(width: 16),
              Icon(Icons.school, color: Colors.grey[400], size: 16),
              SizedBox(width: 4),
              Text(
                '${mentor.sessions} sessions',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              SizedBox(width: 16),
              Icon(Icons.access_time, color: Colors.grey[400], size: 16),
              SizedBox(width: 4),
              Text(
                '~${mentor.responseTime}min',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              Spacer(),
              Text(
                '\$${mentor.hourlyRate}/hr',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: mentor.isOnline && mentor.status != 'offline'
                      ? () => _startInstantChat(mentor) : null,
                  icon: Icon(Icons.chat, color: Colors.white),
                  label: Text(
                    mentor.status == 'available' ? 'Chat Now' :
                    mentor.status == 'busy' ? 'Join Queue' : 'Unavailable',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mentor.isOnline && mentor.status != 'offline'
                        ? Color(0xFF667eea) : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: mentor.isOnline ? () => _bookSession(mentor) : null,
                  icon: Icon(Icons.video_call, color: Colors.white),
                  label: Text('Book Session', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mentor.isOnline ? Color(0xFF764ba2) : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startInstantChat(MentorModel mentor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting live chat with ${mentor.name}...'),
        backgroundColor: Color(0xFF667eea),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to chat screen
          },
        ),
      ),
    );
  }

  void _bookSession(MentorModel mentor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking session with ${mentor.name}...'),
        backgroundColor: Color(0xFF764ba2),
      ),
    );
  }
}