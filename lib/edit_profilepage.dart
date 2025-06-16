import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_helper.dart';
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> currentProfile;

  const EditProfilePage({Key? key, required this.currentProfile}) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _hasChanges = false;

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;

  // Profile data
  File? _profileImage;
  String? _currentImagePath;
  late String _experienceLevel;
  late List<Map<String, dynamic>> _skillsOffered;
  late List<Map<String, dynamic>> _skillsWanted;
  late bool _availableForMentoring;

  // Skills data
  final List<String> _skillCategories = [
    'Programming', 'Design', 'Marketing', 'Business',
    'Languages', 'Music', 'Sports', 'Cooking', 'Other'
  ];

  final Map<String, List<String>> _skillsByCategory = {
    'Programming': ['Flutter', 'React', 'Python', 'Java', 'JavaScript', 'Swift', 'Node.js', 'PHP', 'C++', 'Go'],
    'Design': ['UI/UX', 'Graphic Design', 'Web Design', 'Logo Design', 'Figma', 'Adobe Photoshop', 'Illustrator'],
    'Marketing': ['Digital Marketing', 'SEO', 'Content Marketing', 'Social Media', 'Email Marketing', 'PPC'],
    'Business': ['Management', 'Finance', 'Sales', 'Entrepreneurship', 'Strategy', 'Operations', 'Analytics'],
    'Languages': ['English', 'Spanish', 'French', 'German', 'Hindi', 'Mandarin', 'Arabic', 'Japanese'],
    'Music': ['Guitar', 'Piano', 'Singing', 'Music Production', 'Drums', 'Violin', 'DJing'],
    'Sports': ['Football', 'Basketball', 'Tennis', 'Swimming', 'Yoga', 'Running', 'Gym Training'],
    'Cooking': ['Italian', 'Indian', 'Chinese', 'Baking', 'Healthy Cooking', 'Vegan', 'BBQ'],
    'Other': ['Photography', 'Writing', 'Public Speaking', 'Teaching', 'Video Editing', 'Animation']
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initializeProfile() {
    // Initialize controllers with current data
    _nameController = TextEditingController(text: widget.currentProfile['name'] ?? '');
    _bioController = TextEditingController(text: widget.currentProfile['bio'] ?? '');
    _locationController = TextEditingController(text: widget.currentProfile['location'] ?? '');

    // Initialize profile data
    _currentImagePath = widget.currentProfile['profileImage'];
    _experienceLevel = widget.currentProfile['experienceLevel'] ?? 'Beginner';
    _skillsOffered = List<Map<String, dynamic>>.from(widget.currentProfile['skillsOffered'] ?? []);
    _skillsWanted = List<Map<String, dynamic>>.from(widget.currentProfile['skillsWanted'] ?? []);
    _availableForMentoring = widget.currentProfile['availableForMentoring'] ?? false;

    // Add listeners to detect changes
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Tab Bar
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1D1E33),
                border: Border(bottom: BorderSide(color: Color(0xFF2A2D3A), width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF667eea),
                labelColor: const Color(0xFF667eea),
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Basic Info'),
                  Tab(text: 'Skills'),
                  Tab(text: 'Preferences'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildSkillsTab(),
                  _buildPreferencesTab(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E21),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => _onWillPop().then((canPop) {
          if (canPop) Navigator.pop(context);
        }),
      ),
      title: const Text(
        'Edit Profile',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (_hasChanges)
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Save',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Picture Section
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1D1E33),
                      border: Border.all(color: const Color(0xFF667eea), width: 3),
                    ),
                    child: _profileImage != null
                        ? ClipOval(
                      child: Image.file(
                        _profileImage!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                        : _currentImagePath != null
                        ? ClipOval(
                      child: Image.file(
                        File(_currentImagePath!),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(
                      Icons.camera_alt,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.edit, size: 16, color: Color(0xFF667eea)),
                      label: const Text(
                        'Change Photo',
                        style: TextStyle(color: Color(0xFF667eea)),
                      ),
                    ),
                    if (_profileImage != null || _currentImagePath != null) ...[
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Name Field
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person,
            required: true,
          ),
          const SizedBox(height: 20),

          // Bio Field
          _buildTextField(
            controller: _bioController,
            label: 'Bio',
            icon: Icons.description,
            maxLines: 4,
            hint: 'Tell others about yourself, your interests, and what you\'re passionate about...',
          ),
          const SizedBox(height: 20),

          // Location Field
          _buildTextField(
            controller: _locationController,
            label: 'Location',
            icon: Icons.location_on,
            hint: 'City, Country',
          ),
          const SizedBox(height: 20),

          // Experience Level
          const Text(
            'Experience Level',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2D3A)),
            ),
            child: DropdownButtonFormField<String>(
              value: _experienceLevel,
              style: const TextStyle(color: Colors.white),
              dropdownColor: const Color(0xFF1D1E33),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.trending_up, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: ['Beginner', 'Intermediate', 'Advanced', 'Expert']
                  .map((level) => DropdownMenuItem(
                value: level,
                child: Text(level, style: const TextStyle(color: Colors.white)),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _experienceLevel = value!;
                });
                _markAsChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1D1E33),
              border: Border(bottom: BorderSide(color: Color(0xFF2A2D3A), width: 1)),
            ),
            child: const TabBar(
              indicatorColor: Color(0xFF667eea),
              labelColor: Color(0xFF667eea),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Skills I Offer'),
                Tab(text: 'Skills I Want'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSkillsList(true),
                _buildSkillsList(false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsList(bool isOffered) {
    final skills = isOffered ? _skillsOffered : _skillsWanted;
    final color = isOffered ? Colors.green[600]! : Colors.orange[600]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Skill Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showAddSkillDialog(isOffered),
              icon: const Icon(Icons.add),
              label: Text('Add ${isOffered ? "Skill I Offer" : "Skill I Want"}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Skills List
          if (skills.isNotEmpty)
            Column(
              children: skills.map((skill) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2D3A)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOffered ? Icons.lightbulb : Icons.school,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      skill['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${skill['category']} • ${skill[isOffered ? 'proficiency' : 'interest']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                          onPressed: () => _editSkill(skill, isOffered),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _removeSkill(skill, isOffered),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: const EdgeInsets.all(60),
              child: Column(
                children: [
                  Icon(
                    isOffered ? Icons.lightbulb_outline : Icons.school_outlined,
                    size: 60,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No skills added yet',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isOffered
                        ? 'Add skills you can teach others'
                        : 'Add skills you want to learn',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mentoring Preferences',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Mentoring Toggle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2D3A)),
            ),
            child: SwitchListTile(
              title: const Text(
                'Available for Mentoring',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Allow others to request mentoring from you',
                style: TextStyle(color: Colors.grey),
              ),
              value: _availableForMentoring,
              onChanged: (value) {
                setState(() {
                  _availableForMentoring = value;
                });
                _markAsChanged();
              },
              activeColor: const Color(0xFF667eea),
              secondary: const Icon(
                Icons.school,
                color: Color(0xFF667eea),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Profile Summary
          const Text(
            'Profile Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2D3A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(Icons.person, 'Name', _nameController.text.isEmpty ? 'Not set' : _nameController.text),
                _buildSummaryRow(Icons.location_on, 'Location', _locationController.text.isEmpty ? 'Not set' : _locationController.text),
                _buildSummaryRow(Icons.trending_up, 'Experience', _experienceLevel),
                _buildSummaryRow(Icons.lightbulb, 'Skills Offered', '${_skillsOffered.length} skills'),
                _buildSummaryRow(Icons.school, 'Skills Wanted', '${_skillsWanted.length} skills'),
                _buildSummaryRow(Icons.people, 'Mentoring', _availableForMentoring ? 'Available' : 'Not available'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF667eea), size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: Icon(icon, color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea)),
            ),
            filled: true,
            fillColor: const Color(0xFF1D1E33),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (!_hasChanges) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1D1E33),
        border: Border(top: BorderSide(color: Color(0xFF2A2D3A), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _discardChanges,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Discard Changes'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Save Changes',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
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
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
        _currentImagePath = null;
      });
      _markAsChanged();
    }
  }

  void _removeImage() {
    setState(() {
      _profileImage = null;
      _currentImagePath = null;
    });
    _markAsChanged();
  }

  void _showAddSkillDialog(bool isOffered) {
    String selectedCategory = _skillCategories[0];
    String selectedSkill = _skillsByCategory[selectedCategory]![0];
    String proficiencyOrInterest = isOffered ? 'Beginner' : 'Casual Interest';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              title: Text(
                isOffered ? 'Add Skill You Offer' : 'Add Skill You Want',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogDropdown(
                      'Category',
                      selectedCategory,
                      _skillCategories,
                          (value) {
                        setDialogState(() {
                          selectedCategory = value!;
                          selectedSkill = _skillsByCategory[selectedCategory]![0];
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDialogDropdown(
                      'Skill',
                      selectedSkill,
                      _skillsByCategory[selectedCategory]!,
                          (value) {
                        setDialogState(() {
                          selectedSkill = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDialogDropdown(
                      isOffered ? 'Proficiency' : 'Interest Level',
                      proficiencyOrInterest,
                      isOffered
                          ? ['Beginner', 'Intermediate', 'Advanced', 'Expert']
                          : ['Casual Interest', 'Actively Learning', 'Urgent Need'],
                          (value) {
                        setDialogState(() {
                          proficiencyOrInterest = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Check if skill already exists
                    final skills = isOffered ? _skillsOffered : _skillsWanted;
                    if (skills.any((skill) => skill['name'] == selectedSkill)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This skill is already added'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      if (isOffered) {
                        _skillsOffered.add({
                          'name': selectedSkill,
                          'category': selectedCategory,
                          'proficiency': proficiencyOrInterest,
                        });
                      } else {
                        _skillsWanted.add({
                          'name': selectedSkill,
                          'category': selectedCategory,
                          'interest': proficiencyOrInterest,
                        });
                      }
                    });
                    _markAsChanged();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editSkill(Map<String, dynamic> skill, bool isOffered) {
    String selectedCategory = skill['category'];
    String selectedSkill = skill['name'];
    String proficiencyOrInterest = skill[isOffered ? 'proficiency' : 'interest'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              title: Text(
                'Edit ${skill['name']}',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogDropdown(
                      'Category',
                      selectedCategory,
                      _skillCategories,
                          (value) {
                        setDialogState(() {
                          selectedCategory = value!;
                          if (!_skillsByCategory[selectedCategory]!.contains(selectedSkill)) {
                            selectedSkill = _skillsByCategory[selectedCategory]![0];
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDialogDropdown(
                      'Skill',
                      selectedSkill,
                      _skillsByCategory[selectedCategory]!,
                          (value) {
                        setDialogState(() {
                          selectedSkill = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDialogDropdown(
                      isOffered ? 'Proficiency' : 'Interest Level',
                      proficiencyOrInterest,
                      isOffered
                          ? ['Beginner', 'Intermediate', 'Advanced', 'Expert']
                          : ['Casual Interest', 'Actively Learning', 'Urgent Need'],
                          (value) {
                        setDialogState(() {
                          proficiencyOrInterest = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      skill['name'] = selectedSkill;
                      skill['category'] = selectedCategory;
                      if (isOffered) {
                        skill['proficiency'] = proficiencyOrInterest;
                      } else {
                        skill['interest'] = proficiencyOrInterest;
                      }
                    });
                    _markAsChanged();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeSkill(Map<String, dynamic> skill, bool isOffered) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Remove Skill?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove "${skill['name']}" from your ${isOffered ? 'offered' : 'wanted'} skills?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (isOffered) {
                  _skillsOffered.remove(skill);
                } else {
                  _skillsWanted.remove(skill);
                }
              });
              _markAsChanged();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDropdown(
      String label,
      String value,
      List<String> items,
      ValueChanged<String?> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E21),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2D3A)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color(0xFF1D1E33),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _discardChanges() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'All your unsaved changes will be lost. This action cannot be undone.',
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
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.red,
        ),
      );
      _tabController.animateTo(0);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare profile data
      Map<String, dynamic> profileData = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'experienceLevel': _experienceLevel,
        'skillsOffered': _skillsOffered,
        'skillsWanted': _skillsWanted,
        'availableForMentoring': _availableForMentoring,
        'profileImage': _profileImage?.path ?? _currentImagePath,
        'profileComplete': true,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userProfile', json.encode(profileData));

      // Try to sync with Firebase
      try {
        await FirebaseHelper.syncProfileToFirestore();
        print('✅ Profile synced to Firestore');
      } catch (e) {
        print('⚠️ Failed to sync to Firestore: $e');
        // Continue anyway - local save is successful
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully! 🚀'),
            backgroundColor: Colors.green,
          ),
        );

        // Return updated profile data
        Navigator.pop(context, profileData);
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}