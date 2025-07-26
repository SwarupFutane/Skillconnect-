import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _messageNotifications = true;
  bool _connectionRequests = true;
  bool _mentorshipUpdates = true;
  bool _skillMatches = false;
  bool _weeklyDigest = true;
  bool _marketingEmails = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _doNotDisturb = false;
  TimeOfDay _dndStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _dndEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _messageNotifications = prefs.getBool('notif_messages') ?? true;
      _connectionRequests = prefs.getBool('notif_connections') ?? true;
      _mentorshipUpdates = prefs.getBool('notif_mentorship') ?? true;
      _skillMatches = prefs.getBool('notif_skills') ?? false;
      _weeklyDigest = prefs.getBool('notif_digest') ?? true;
      _marketingEmails = prefs.getBool('notif_marketing') ?? false;
      _soundEnabled = prefs.getBool('notif_sound') ?? true;
      _vibrationEnabled = prefs.getBool('notif_vibration') ?? true;
      _doNotDisturb = prefs.getBool('notif_dnd') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_messages', _messageNotifications);
    await prefs.setBool('notif_connections', _connectionRequests);
    await prefs.setBool('notif_mentorship', _mentorshipUpdates);
    await prefs.setBool('notif_skills', _skillMatches);
    await prefs.setBool('notif_digest', _weeklyDigest);
    await prefs.setBool('notif_marketing', _marketingEmails);
    await prefs.setBool('notif_sound', _soundEnabled);
    await prefs.setBool('notif_vibration', _vibrationEnabled);
    await prefs.setBool('notif_dnd', _doNotDisturb);
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
          'Notification Settings',
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
          _buildSectionHeader('Message Notifications'),
          _buildNotificationTile(
            'New Messages',
            'Get notified when you receive new messages',
            _messageNotifications,
                (value) {
              setState(() => _messageNotifications = value);
              _saveSettings();
            },
          ),
          _buildNotificationTile(
            'Connection Requests',
            'Get notified when someone wants to connect',
            _connectionRequests,
                (value) {
              setState(() => _connectionRequests = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Learning & Growth'),
          _buildNotificationTile(
            'Mentorship Updates',
            'Updates on your mentorship sessions',
            _mentorshipUpdates,
                (value) {
              setState(() => _mentorshipUpdates = value);
              _saveSettings();
            },
          ),
          _buildNotificationTile(
            'Skill Matches',
            'When users with skills you want join',
            _skillMatches,
                (value) {
              setState(() => _skillMatches = value);
              _saveSettings();
            },
          ),
          _buildNotificationTile(
            'Weekly Digest',
            'Weekly summary of your activity',
            _weeklyDigest,
                (value) {
              setState(() => _weeklyDigest = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Notification Style'),
          _buildNotificationTile(
            'Sound',
            'Play sound for notifications',
            _soundEnabled,
                (value) {
              setState(() => _soundEnabled = value);
              _saveSettings();
            },
          ),
          _buildNotificationTile(
            'Vibration',
            'Vibrate for notifications',
            _vibrationEnabled,
                (value) {
              setState(() => _vibrationEnabled = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Do Not Disturb'),
          _buildNotificationTile(
            'Enable Do Not Disturb',
            'Silence notifications during set hours',
            _doNotDisturb,
                (value) {
              setState(() => _doNotDisturb = value);
              _saveSettings();
            },
          ),

          if (_doNotDisturb) ...[
            const SizedBox(height: 16),
            _buildTimeSelector(
              'Start Time',
              _dndStart,
                  (time) => setState(() => _dndStart = time),
            ),
            const SizedBox(height: 8),
            _buildTimeSelector(
              'End Time',
              _dndEnd,
                  (time) => setState(() => _dndEnd = time),
            ),
          ],

          const SizedBox(height: 24),
          _buildSectionHeader('Marketing'),
          _buildNotificationTile(
            'Product Updates',
            'New features and app updates',
            _marketingEmails,
                (value) {
              setState(() => _marketingEmails = value);
              _saveSettings();
            },
          ),

          const SizedBox(height: 32),
          _buildActionButton(
            'Test Notifications',
            Icons.notification_add,
                () => _testNotification(),
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

  Widget _buildNotificationTile(
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

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3A)),
      ),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          time.format(context),
          style: const TextStyle(
            color: Color(0xFF667eea),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () async {
          final newTime = await showTimePicker(
            context: context,
            initialTime: time,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF667eea),
                    surface: Color(0xFF1D1E33),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (newTime != null) {
            onChanged(newTime);
          }
        },
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _testNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent! Check your notification panel.'),
        backgroundColor: Color(0xFF667eea),
      ),
    );

    // In production, you would trigger an actual notification here
    // using flutter_local_notifications or similar package
  }
}