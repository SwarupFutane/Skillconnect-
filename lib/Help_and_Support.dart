import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String _selectedCategory = 'general';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _faqItems = [
    {
      'question': 'How do I connect with other users?',
      'answer': 'Browse suggested connections on the homepage, view profiles, and send connection requests. Once accepted, you can start messaging and learning together.',
    },
    {
      'question': 'How does skill matching work?',
      'answer': 'Our algorithm matches you with users based on skills you want to learn and skills you can teach. Update your profile to improve matches.',
    },
    {
      'question': 'Can I change my skills after setting up my profile?',
      'answer': 'Yes! Go to your profile settings to add, remove, or update your skills and interests at any time.',
    },
    {
      'question': 'How do I report inappropriate behavior?',
      'answer': 'Use the report button on user profiles or in chat conversations. We review all reports within 24 hours.',
    },
    {
      'question': 'Is my data secure?',
      'answer': 'Yes, we use industry-standard encryption and security measures. Check our Privacy Policy for detailed information.',
    },
    {
      'question': 'How do I delete my account?',
      'answer': 'Go to Settings > Privacy > Delete Account. Note that this action is permanent and cannot be undone.',
    },
    {
      'question': 'Can I use SkillConnect for business networking?',
      'answer': 'SkillConnect is designed for skill sharing and learning. While professional connections may form, please respect our community guidelines.',
    },
    {
      'question': 'How do I improve my match recommendations?',
      'answer': 'Keep your profile updated, be active in the community, and provide feedback on connections to help our algorithm learn your preferences.',
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              color: const Color(0xFF1D1E33),
              child: const TabBar(
                indicatorColor: Color(0xFF667eea),
                labelColor: Color(0xFF667eea),
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'FAQ'),
                  Tab(text: 'Contact'),
                  Tab(text: 'Resources'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildFAQTab(),
                  _buildContactTab(),
                  _buildResourcesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSearchBar(),
        const SizedBox(height: 24),
        ..._faqItems.map((item) => _buildFAQItem(
          item['question'],
          item['answer'],
        )).toList(),
        const SizedBox(height: 24),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildContactTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildContactInfo(),
        const SizedBox(height: 24),
        _buildContactForm(),
      ],
    );
  }

  Widget _buildResourcesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildResourceSection('Getting Started', [
          ('User Guide', 'Complete guide to using SkillConnect'),
          ('Profile Setup Tips', 'How to create an effective profile'),
          ('Safety Guidelines', 'Stay safe while connecting'),
        ]),
        const SizedBox(height: 24),
        _buildResourceSection('Advanced Features', [
          ('Skill Matching Algorithm', 'How we find your perfect matches'),
          ('Mentorship Program', 'Guide to mentoring others'),
          ('Community Guidelines', 'Rules for respectful interaction'),
        ]),
        const SizedBox(height: 24),
        _buildResourceSection('Troubleshooting', [
          ('Connection Issues', 'Fix common connectivity problems'),
          ('Notification Problems', 'Not receiving notifications?'),
          ('Account Recovery', 'Recover your account access'),
        ]),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search frequently asked questions...',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (query) {
          // Implement search functionality
        },
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconColor: const Color(0xFF667eea),
        collapsedIconColor: Colors.grey,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Still need help?',
          style: TextStyle(
            color: Color(0xFF667eea),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Contact Support',
                'Get personalized help',
                Icons.chat_bubble_outline,
                    () => DefaultTabController.of(context).animateTo(1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Community Forum',
                'Ask the community',
                Icons.forum,
                    () => _openCommunityForum(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF667eea), size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Get in Touch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildContactItem(Icons.email, 'Email', 'developerswarup400@gmail.com'),
          const SizedBox(height: 12),
          _buildContactItem(Icons.schedule, 'Response Time', 'Within 24 hours'),
          const SizedBox(height: 12),
          _buildContactItem(Icons.language, 'Languages', 'English, Hindi'),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: const Color(0xFF667eea), size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Send us a message',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Category Selection
          const Text(
            'Category',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E21),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2D3A)),
            ),
            child: DropdownButton<String>(
              value: _selectedCategory,
              onChanged: (value) => setState(() => _selectedCategory = value!),
              dropdownColor: const Color(0xFF1D1E33),
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General Question')),
                DropdownMenuItem(value: 'technical', child: Text('Technical Issue')),
                DropdownMenuItem(value: 'account', child: Text('Account Problem')),
                DropdownMenuItem(value: 'report', child: Text('Report User/Content')),
                DropdownMenuItem(value: 'feedback', child: Text('Feedback/Suggestion')),
                DropdownMenuItem(value: 'billing', child: Text('Billing Question')),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subject Field
          const Text(
            'Subject',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subjectController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Brief description of your issue',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
              ),
              enabledBorder: OutlineInputBorder(
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
          const SizedBox(height: 16),

          // Message Field
          const Text(
            'Message',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            style: const TextStyle(color: Colors.white),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Please provide as much detail as possible...',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
              ),
              enabledBorder: OutlineInputBorder(
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
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSupportRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Send Message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceSection(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF667eea),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildResourceItem(item.$1, item.$2)).toList(),
      ],
    );
  }

  Widget _buildResourceItem(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openResource(title),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.article, color: Color(0xFF667eea), size: 16),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSupportRequest() async {
    if (_subjectController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'category': _selectedCategory,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      _subjectController.clear();
      _messageController.clear();
      setState(() => _selectedCategory = 'general');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support request submitted successfully!'),
          backgroundColor: Color(0xFF667eea),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _openCommunityForum() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Community Forum...'),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }

  void _openResource(String resourceTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $resourceTitle...'),
        backgroundColor: const Color(0xFF667eea),
      ),
    );
  }
}