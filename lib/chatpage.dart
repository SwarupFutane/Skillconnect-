import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  final String connectionId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatPage({
    Key? key,
    required this.connectionId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isTyping = false;
  bool _otherUserTyping = false;
  Map<String, dynamic>? _otherUserData;

  @override
  void initState() {
    super.initState();
    _loadOtherUserData();
    _markMessagesAsRead();
    _listenToTypingStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _updateTypingStatus(false);
    super.dispose();
  }

  Future<void> _loadOtherUserData() async {
    try {
      final userDoc = await _firestore.collection('users').doc(widget.otherUserId).get();
      if (userDoc.exists) {
        setState(() {
          _otherUserData = userDoc.data();
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Mark all messages in this chat as read
      final unreadMessages = await _firestore
          .collection('messages')
          .where('connectionId', isEqualTo: widget.connectionId)
          .where('senderId', isEqualTo: widget.otherUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      // Update connection unread count
      await _firestore.collection('connections').doc(widget.connectionId).update({
        'unreadCount.$userId': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _listenToTypingStatus() {
    _firestore
        .collection('typing_status')
        .doc('${widget.connectionId}_${widget.otherUserId}')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        setState(() {
          _otherUserTyping = data?['isTyping'] ?? false;
        });
      }
    });
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('typing_status')
          .doc('${widget.connectionId}_$userId')
          .set({
        'isTyping': isTyping,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final messageText = _messageController.text.trim();
      _messageController.clear();
      _updateTypingStatus(false);

      // Add message to Firestore
      await _firestore.collection('messages').add({
        'connectionId': widget.connectionId,
        'senderId': userId,
        'receiverId': widget.otherUserId,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'messageType': 'text',
      });

      // Update connection with last message
      await _firestore.collection('connections').doc(widget.connectionId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });

      // Auto-scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('connectionId', isEqualTo: widget.connectionId)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
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
                          child: widget.otherUserImage != null
                              ? ClipOval(
                            child: Image.file(
                              File(widget.otherUserImage!),
                              fit: BoxFit.cover,
                            ),
                          )
                              : const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Start a conversation with ${widget.otherUserName}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Share your skills, learn something new!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_otherUserTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _otherUserTyping) {
                      return _buildTypingIndicator();
                    }

                    final messageDoc = messages[index];
                    final messageData = messageDoc.data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == _auth.currentUser?.uid;

                    return _buildMessageBubble(messageData, isMe);
                  },
                );
              },
            ),
          ),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1D1E33),
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      title: Row(
        children: [
          // Profile Picture
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _otherUserData?['isOnline'] == true ? Colors.green : Colors.grey,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: widget.otherUserImage != null
                  ? Image.file(
                File(widget.otherUserImage!),
                fit: BoxFit.cover,
              )
                  : Container(
                color: const Color(0xFF0A0E21),
                child: const Icon(
                  Icons.person,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _otherUserTyping
                      ? 'typing...'
                      : _otherUserData?['isOnline'] == true
                      ? 'Online'
                      : 'Offline',
                  style: TextStyle(
                    color: _otherUserTyping
                        ? const Color(0xFF667eea)
                        : _otherUserData?['isOnline'] == true
                        ? Colors.green
                        : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Video call functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video call coming soon!'),
                backgroundColor: Color(0xFF667eea),
              ),
            );
          },
          icon: const Icon(Icons.videocam, color: Colors.white),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF1D1E33),
          onSelected: (value) {
            switch (value) {
              case 'profile':
                _viewProfile();
                break;
              case 'block':
                _showBlockDialog();
                break;
              case 'report':
                _showReportDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Text('View Profile', style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Text('Block User', style: TextStyle(color: Colors.red)),
            ),
            const PopupMenuItem(
              value: 'report',
              child: Text('Report User', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData, bool isMe) {
    final timestamp = messageData['timestamp'] as Timestamp?;
    final isRead = messageData['isRead'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D1E33),
                border: Border.all(color: const Color(0xFF667eea), width: 1),
              ),
              child: widget.otherUserImage != null
                  ? ClipOval(
                child: Image.file(
                  File(widget.otherUserImage!),
                  fit: BoxFit.cover,
                ),
              )
                  : const Icon(Icons.person, color: Colors.grey, size: 16),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF667eea) : const Color(0xFF1D1E33),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messageData['message'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp != null ? _formatMessageTime(timestamp.toDate()) : '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 16,
                          color: isRead ? Colors.green : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1D1E33),
              border: Border.all(color: const Color(0xFF667eea), width: 1),
            ),
            child: widget.otherUserImage != null
                ? ClipOval(
              child: Image.file(
                File(widget.otherUserImage!),
                fit: BoxFit.cover,
              ),
            )
                : const Icon(Icons.person, color: Colors.grey, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -4 * value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.5 + (0.5 * value)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1D1E33),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2D3A), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed: () {
              // TODO: Implement file/image sharing
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File sharing coming soon!'),
                  backgroundColor: Color(0xFF667eea),
                ),
              );
            },
            icon: const Icon(Icons.attach_file, color: Colors.grey),
          ),

          // Message input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E21),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A2D3A)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (text) {
                  final bool nowTyping = text.isNotEmpty;
                  if (nowTyping != _isTyping) {
                    _isTyping = nowTyping;
                    _updateTypingStatus(nowTyping);
                  }
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF667eea),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _viewProfile() {
    // TODO: Navigate to user profile page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile view coming soon!'),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Block User',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to block ${widget.otherUserName}? You won\'t be able to send or receive messages from them.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement block functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Block functionality coming soon!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Report User',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Report inappropriate behavior or content. Our team will review your report.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement report functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report functionality coming soon!'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}