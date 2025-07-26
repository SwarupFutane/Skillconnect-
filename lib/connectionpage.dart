import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_helper.dart';
import 'chatpage.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({Key? key}) : super(key: key);

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add stream subscriptions for real-time updates
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<QuerySnapshot>? _connectionsSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupRealTimeListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _requestsSubscription?.cancel();
    _connectionsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app becomes active
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  // Setup real-time listeners for automatic updates
  void _setupRealTimeListeners() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to connection requests in real-time
    _requestsSubscription = _firestore
        .collection('connection_requests')
        .where('toUserId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _loadPendingRequests();
      }
    }, onError: (error) {
      print('Error listening to requests: $error');
    });

    // Listen to connections in real-time
    _connectionsSubscription = _firestore
        .collection('connections')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _loadConnections();
      }
    }, onError: (error) {
      print('Error listening to connections: $error');
    });
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadConnections(),
      _loadPendingRequests(),
    ]);
  }

  Future<void> _loadConnections() async {
    try {
      print('🔄 Loading connections...');
      final connections = await FirebaseHelper.getUserConnections();

      if (mounted) {
        setState(() {
          _connections = connections;
          _isLoading = false;
        });
      }

      print('✅ Loaded ${connections.length} connections');
    } catch (e) {
      print('Error loading connections: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      print('🔄 Loading pending requests...');
      final user = _auth.currentUser;
      if (user == null) return;

      final requestsQuery = await _firestore
          .collection('connection_requests')
          .where('toUserId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      List<Map<String, dynamic>> requests = [];

      for (var doc in requestsQuery.docs) {
        final data = doc.data();

        // Get sender's profile
        try {
          final senderDoc = await _firestore.collection('users').doc(data['fromUserId']).get();
          if (!senderDoc.exists) continue;

          final senderData = senderDoc.data()!;

          // Safely extract skills with proper type checking
          List<String> skillsOffered = [];
          List<String> skillsWanted = [];

          if (senderData['skillsOffered'] != null) {
            if (senderData['skillsOffered'] is List) {
              for (var skill in senderData['skillsOffered']) {
                if (skill is Map<String, dynamic> && skill['name'] != null) {
                  skillsOffered.add(skill['name'].toString());
                } else if (skill is String) {
                  skillsOffered.add(skill);
                }
              }
            }
          }

          if (senderData['skillsWanted'] != null) {
            if (senderData['skillsWanted'] is List) {
              for (var skill in senderData['skillsWanted']) {
                if (skill is Map<String, dynamic> && skill['name'] != null) {
                  skillsWanted.add(skill['name'].toString());
                } else if (skill is String) {
                  skillsWanted.add(skill);
                }
              }
            }
          }

          requests.add({
            'requestId': doc.id,
            'fromUserId': data['fromUserId'],
            'name': senderData['name'] ?? 'Unknown User',
            'bio': senderData['bio'] ?? '',
            'profileImage': senderData['profileImage'],
            'message': data['message'] ?? '',
            'createdAt': data['createdAt'],
            'skillsOffered': skillsOffered,
            'skillsWanted': skillsWanted,
          });
        } catch (e) {
          print('Error processing request ${doc.id}: $e');
          continue;
        }
      }

      // Sort in memory instead of in query
      requests.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }

      print('✅ Loaded ${requests.length} pending requests');
    } catch (e) {
      print('Error loading pending requests: $e');
    }
  }

  Future<void> _acceptConnectionRequest(String requestId) async {
    try {
      print('🔄 Accepting connection request: $requestId');

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          ),
        ),
      );

      final success = await FirebaseHelper.acceptConnectionRequest(requestId);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request accepted! 🎉'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload data immediately
        await _loadData();

        // Also trigger a broader refresh to update other parts of the app
        if (context.mounted) {
          // You can add a callback here to notify parent widgets
          // For now, we'll rely on the real-time listeners
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error accepting connection request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectConnectionRequest(String requestId) async {
    try {
      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'Reject Connection Request',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to reject this connection request?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await _firestore.collection('connection_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection request rejected'),
            backgroundColor: Colors.orange,
          ),
        );

        // Reload data
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat(Map<String, dynamic> connection) async {
    try {
      print('🔄 Opening chat with: ${connection['name']}');
      print('📋 Connection data: $connection');

      // Ensure connection document exists with proper ID
      String connectionId;

      if (connection['connectionId'] != null && connection['connectionId'].isNotEmpty) {
        connectionId = connection['connectionId'];
        print('✅ Using existing connection ID: $connectionId');
      } else {
        // Create new connection if ID is missing
        connectionId = await FirebaseHelper.createOrGetConnection(connection['otherUserId']);
        print('✅ Created new connection ID: $connectionId');
      }

      // Navigate to chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            connectionId: connectionId,
            otherUserId: connection['otherUserId'],
            otherUserName: connection['name'],
            otherUserImage: connection['profileImage'],
          ),
        ),
      ).then((_) {
        // Reload connections when returning from chat
        _loadConnections();
      });

    } catch (e) {
      print('❌ Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
        ),
      );
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1D1E33),
            border: Border(bottom: BorderSide(color: Color(0xFF2A2D3A))),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF667eea),
            labelColor: const Color(0xFF667eea),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                text: 'Connections (${_connections.length})',
              ),
              Tab(
                text: 'Requests (${_pendingRequests.length})',
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildConnectionsList(),
              _buildRequestsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionsList() {
    if (_connections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF667eea),
        backgroundColor: const Color(0xFF1D1E33),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1D1E33),
                      border: Border.all(color: const Color(0xFF667eea), width: 2),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Connections Yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Start connecting with other users\nto expand your network!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to discover page
                      DefaultTabController.of(context)?.animateTo(0);
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Discover People'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF667eea),
      backgroundColor: const Color(0xFF1D1E33),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _connections.length,
        itemBuilder: (context, index) {
          final connection = _connections[index];
          return _buildConnectionCard(connection);
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_pendingRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF667eea),
        backgroundColor: const Color(0xFF1D1E33),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1D1E33),
                      border: Border.all(color: const Color(0xFF667eea), width: 2),
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Pending Requests',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Connection requests will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF667eea),
      backgroundColor: const Color(0xFF1D1E33),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildConnectionCard(Map<String, dynamic> connection) {
    final hasUnread = (connection['unreadCount'] ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUnread ? const Color(0xFF667eea) : const Color(0xFF2A2D3A),
          width: hasUnread ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (connection['isOnline'] ?? false) ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: connection['profileImage'] != null
                    ? Image.file(
                  File(connection['profileImage']),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF0A0E21),
                      child: const Icon(
                        Icons.person,
                        color: Colors.grey,
                        size: 24,
                      ),
                    );
                  },
                )
                    : Container(
                  color: const Color(0xFF0A0E21),
                  child: const Icon(
                    Icons.person,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            ),
            if (connection['isOnline'] ?? false)
              Positioned(
                right: 0,
                bottom: 0,
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                connection['name'] ?? 'Unknown User',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (hasUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${connection['unreadCount']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((connection['lastMessage'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                connection['lastMessage'],
                style: TextStyle(
                  color: hasUnread ? Colors.white : Colors.grey,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              (connection['isOnline'] ?? false) ? 'Online' : 'Offline',
              style: TextStyle(
                color: (connection['isOnline'] ?? false) ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chat_bubble_outline,
          color: Color(0xFF667eea),
        ),
        onTap: () => _openChat(connection),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF667eea), width: 2),
                ),
                child: ClipOval(
                  child: request['profileImage'] != null
                      ? Image.file(
                    File(request['profileImage']),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF0A0E21),
                        child: const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 24,
                        ),
                      );
                    },
                  )
                      : Container(
                    color: const Color(0xFF0A0E21),
                    child: const Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if ((request['bio'] ?? '').isNotEmpty)
                      Text(
                        request['bio'],
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          if ((request['message'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E21),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${request['message']}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Skills preview
          if ((request['skillsOffered'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Offers: ${(request['skillsOffered'] as List).take(3).join(', ')}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acceptConnectionRequest(request['requestId']),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rejectConnectionRequest(request['requestId']),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2D3A),
                    foregroundColor: Colors.white,
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
}