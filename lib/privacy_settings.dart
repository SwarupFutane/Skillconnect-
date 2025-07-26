import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _profileVisible = true;
  bool _showOnlineStatus = true;
  bool _allowDirectMessages = true;
  bool _showSkills = true;
  bool _showLocation = true;
  bool _showExperience = true;
  bool _dataAnalytics = false;
  bool _personalization = true;
  String _whoCanConnect = 'everyone'; // everyone, mutual_connections, no_one
  String _whoCanMessage = 'connections'; // everyone, connections, no_one

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileVisible = prefs.getBool('privacy_profile_visible') ?? true;
      _showOnlineStatus = prefs.getBool('privacy_online_status') ?? true;
      _allowDirectMessages = prefs.getBool('privacy_direct_messages') ?? true;
      _showSkills = prefs.getBool('privacy_show_skills') ?? true;
      _showLocation = prefs.getBool('privacy_show_location') ?? true;
      _showExperience = prefs.getBool('privacy_show_experience') ?? true;
      _dataAnalytics = prefs.getBool('privacy_analytics') ?? false;
      _personalization = prefs.getBool('privacy_personalization') ?? true;
      _whoCanConnect = prefs.getString('privacy_who_connect') ?? 'everyone';
      _whoCanMessage = prefs.getString('privacy_who_message') ?? 'connections';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_profile_visible', _profileVisible);
    await prefs.setBool('privacy_online_status', _showOnlineStatus);
    await prefs.setBool('privacy_direct_messages', _allowDirectMessages);
    await prefs.setBool('privacy_show_skills', _showSkills);
    await prefs.setBool('privacy_show_location', _showLocation);
    await prefs.setBool('privacy_show_experience', _showExperience);
    await prefs.setBool('privacy_analytics', _dataAnalytics);
    await prefs.setBool('privacy_personalization', _personalization);
    await prefs.setString('privacy_who_connect', _whoCanConnect);
    await prefs.setString('privacy_who_message', _whoCanMessage);

    // Update Firestore with privacy settings
    await _updateFirestorePrivacy();
  }

  Future<void> _updateFirestorePrivacy() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'privacy': {
            'profileVisible': _profileVisible,
            'showOnlineStatus': _showOnlineStatus,
            'allowDirectMessages': _allowDirectMessages,
            'showSkills': _showSkills,
            'showLocation': _showLocation,
            'showExperience': _showExperience,
            'whoCanConnect': _whoCanConnect,
            'whoCanMessage': _whoCanMessage,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating privacy settings: $e');
    }
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
          'Privacy Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),

          _buildSectionHeader('Profile Visibility'),
          _buildPrivacyTile(
            'Profile Visible to Others',
            'Allow other users to find and view your profile',
            _profileVisible,
                (value) {
              setState(() => _profileVisible = value);
              _saveSettings();
            },
          ),
          _buildPrivacyTile(
            'Show Online Status',
            'Let others see when you\'re active',
            _showOnlineStatus,
                (value) {
              setState(() => _showOnlineStatus = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Profile Information'),
          _buildPrivacyTile(
            'Show Skills',
            'Display your skills and interests',
            _showSkills,
                (value) {
              setState(() => _showSkills = value);
              _saveSettings();
            },
          ),
          _buildPrivacyTile(
            'Show Location',
            'Display your location to others',
            _showLocation,
                (value) {
              setState(() => _showLocation = value);
              _saveSettings();
            },
          ),
          _buildPrivacyTile(
            'Show Experience Level',
            'Display your experience and background',
            _showExperience,
                (value) {
              setState(() => _showExperience = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Communication'),
          _buildDropdownTile(
            'Who Can Connect With You',
            'Control who can send connection requests',
            _whoCanConnect,
            [
              ('everyone', 'Everyone'),
              ('mutual_connections', 'Friends of Friends'),
              ('no_one', 'No One'),
            ],
                (value) {
              setState(() => _whoCanConnect = value);
              _saveSettings();
            },
          ),
          _buildDropdownTile(
            'Who Can Message You',
            'Control who can send you direct messages',
            _whoCanMessage,
            [
              ('everyone', 'Everyone'),
              ('connections', 'My Connections Only'),
              ('no_one', 'No One'),
            ],
                (value) {
              setState(() => _whoCanMessage = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Data & Analytics'),
          _buildPrivacyTile(
            'Usage Analytics',
            'Help improve the app with anonymous usage data',
            _dataAnalytics,
                (value) {
              setState(() => _dataAnalytics = value);
              _saveSettings();
            },
          ),
          _buildPrivacyTile(
            'Personalized Experience',
            'Use your data to personalize recommendations',
            _personalization,
                (value) {
              setState(() => _personalization = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 32),
          _buildActionButton(
            'Download My Data',
            Icons.download,
                () => _downloadData(),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            'Delete Account',
            Icons.delete_forever,
                () => _showDeleteAccountDialog(),
            isDestructive: true,
          ),

          const SizedBox(height: 24),
          _buildLegalLinks(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.security,
              color: Color(0xFF667eea),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Control how your information is shared and used on SkillConnect.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF667eea),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPrivacyTile(
      String title,
      String subtitle,
      bool value,
      Function(bool) onChanged,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF667eea),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDropdownTile(
      String title,
      String subtitle,
      String value,
      List<(String, String)> options,
      Function(String) onChanged,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: value,
              onChanged: (newValue) => onChanged(newValue!),
              dropdownColor: const Color(0xFF1D1E33),
              style: const TextStyle(color: Color(0xFF667eea)),
              underline: Container(),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option.$1,
                  child: Text(option.$2),
                );
              }).toList(),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildActionButton(
      String title,
      IconData icon,
      VoidCallback onTap, {
        bool isDestructive = false,
      }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDestructive ? Colors.red.withOpacity(0.2) : const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDestructive ? Colors.red : const Color(0xFF2A2D3A),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive ? Colors.red : Colors.white,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isDestructive ? Colors.red : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDestructive ? Colors.red : Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Column(
      children: [
        _buildLinkTile('Privacy Policy', () => _openPrivacyPolicy()),
        const SizedBox(height: 8),
        _buildLinkTile('Terms of Service', () => _openTermsOfService()),
        const SizedBox(height: 8),
        _buildLinkTile('Data Usage Policy', () => _openDataPolicy()),
      ],
    );
  }

  Widget _buildLinkTile(String title, VoidCallback onTap) {
    return Container(
      width: double.infinity,
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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF667eea),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.open_in_new,
                  color: Color(0xFF667eea),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _downloadData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Download Data',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'We\'ll prepare your data and send a download link to your email within 24 hours.',
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export request submitted'),
                  backgroundColor: Color(0xFF667eea),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea)),
            child: const Text('Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This action cannot be undone. All your data, connections, and messages will be permanently deleted.',
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
              // Implement account deletion
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    // Implement account deletion logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account deletion initiated. You will be contacted within 24 hours.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openPrivacyPolicy() {
    // Open privacy policy URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Privacy Policy...'),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }

  void _openTermsOfService() {
    // Open terms of service URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Terms of Service...'),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }

  void _openDataPolicy() {
    // Open data usage policy URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Data Usage Policy...'),
        backgroundColor: Color(0xFF667eea),
      ),
    );
  }
}