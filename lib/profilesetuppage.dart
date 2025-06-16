import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileSetupPage extends StatefulWidget {
  @override
  _ProfileSetupPageState createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Controllers for form fields
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  // Profile data
  File? _profileImage;
  String _experienceLevel = 'Beginner';
  List<Map<String, dynamic>> _skillsOffered = [];
  List<Map<String, dynamic>> _skillsWanted = [];
  bool _availableForMentoring = false;

  // Skills data
  final List<String> _skillCategories = [
    'Programming', 'Design', 'Marketing', 'Business',
    'Languages', 'Music', 'Sports', 'Cooking', 'Other'
  ];

  final Map<String, List<String>> _skillsByCategory = {
    'Programming': ['Flutter', 'React', 'Python', 'Java', 'JavaScript', 'Swift'],
    'Design': ['UI/UX', 'Graphic Design', 'Web Design', 'Logo Design'],
    'Marketing': ['Digital Marketing', 'SEO', 'Content Marketing', 'Social Media'],
    'Business': ['Management', 'Finance', 'Sales', 'Entrepreneurship'],
    'Languages': ['English', 'Spanish', 'French', 'German', 'Hindi', 'Mandarin'],
    'Music': ['Guitar', 'Piano', 'Singing', 'Music Production'],
    'Sports': ['Football', 'Basketball', 'Tennis', 'Swimming', 'Yoga'],
    'Cooking': ['Italian', 'Indian', 'Chinese', 'Baking', 'Healthy Cooking'],
    'Other': ['Photography', 'Writing', 'Public Speaking', 'Teaching']
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
        backgroundColor: const Color(0xFF0A0E21),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(4, (index) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index <= _currentPage ? const Color(0xFF667eea) : const Color(0xFF2A2D3A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Page Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildBasicInfoPage(),
                _buildSkillsOfferedPage(),
                _buildSkillsWantedPage(),
                _buildPreferencesPage(),
              ],
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _currentPage > 0
                    ? TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF667eea),
                  ),
                  child: const Text('Back'),
                )
                    : const SizedBox(),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < 3) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _saveProfile();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage < 3 ? 'Next' : 'Complete Setup',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Profile Picture
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D1E33),
                  border: Border.all(color: const Color(0xFF667eea), width: 2),
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
                    : const Icon(
                  Icons.camera_alt,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Tap to add profile picture',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 30),

          // Name Field
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.person, color: Colors.grey),
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
            ),
          ),
          const SizedBox(height: 20),

          // Bio Field
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Bio (Tell us about yourself)',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.description, color: Colors.grey),
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
            ),
          ),
          const SizedBox(height: 20),

          // Location Field
          TextFormField(
            controller: _locationController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Location',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
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
            ),
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
          DropdownButtonFormField<String>(
            value: _experienceLevel,
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color(0xFF1D1E33),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.trending_up, color: Colors.grey),
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsOfferedPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills You Offer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'What skills can you teach or help others with?',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Add Skill Button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showAddSkillDialog(true),
              icon: const Icon(Icons.add),
              label: const Text('Add Skill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Skills List
          if (_skillsOffered.isNotEmpty)
            Column(
              children: _skillsOffered.map((skill) {
                return Card(
                  color: const Color(0xFF1D1E33),
                  child: ListTile(
                    title: Text(
                      skill['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${skill['category']} • ${skill['proficiency']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _skillsOffered.remove(skill);
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: const EdgeInsets.all(40),
              child: const Column(
                children: [
                  Icon(Icons.lightbulb_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No skills added yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsWantedPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills You Want to Learn',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'What skills would you like to learn or improve?',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Add Skill Button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showAddSkillDialog(false),
              icon: const Icon(Icons.add),
              label: const Text('Add Skill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Skills List
          if (_skillsWanted.isNotEmpty)
            Column(
              children: _skillsWanted.map((skill) {
                return Card(
                  color: const Color(0xFF1D1E33),
                  child: ListTile(
                    title: Text(
                      skill['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${skill['category']} • ${skill['interest']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _skillsWanted.remove(skill);
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: const EdgeInsets.all(40),
              child: const Column(
                children: [
                  Icon(Icons.school_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No skills added yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferences',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Let us know your preferences',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Mentoring Toggle
          Card(
            color: const Color(0xFF1D1E33),
            child: SwitchListTile(
              title: const Text(
                'Available for Mentoring',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Help others learn skills you know',
                style: TextStyle(color: Colors.grey),
              ),
              value: _availableForMentoring,
              onChanged: (value) {
                setState(() {
                  _availableForMentoring = value;
                });
              },
              activeColor: const Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 20),

          // Summary
          Card(
            color: const Color(0xFF1D1E33),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Name: ${_nameController.text.isEmpty ? "Not set" : _nameController.text}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Skills Offered: ${_skillsOffered.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Skills Wanted: ${_skillsWanted.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Mentoring: ${_availableForMentoring ? "Yes" : "No"}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
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
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1D1E33),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF667eea)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0E21),
                    ),
                    items: _skillCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value!;
                        selectedSkill = _skillsByCategory[selectedCategory]![0];
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedSkill,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1D1E33),
                    decoration: InputDecoration(
                      labelText: 'Skill',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF667eea)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0E21),
                    ),
                    items: _skillsByCategory[selectedCategory]!.map((skill) {
                      return DropdownMenuItem(
                        value: skill,
                        child: Text(skill, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSkill = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: proficiencyOrInterest,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1D1E33),
                    decoration: InputDecoration(
                      labelText: isOffered ? 'Proficiency' : 'Interest Level',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2A2D3A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF667eea)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0E21),
                    ),
                    items: (isOffered
                        ? ['Beginner', 'Intermediate', 'Advanced', 'Expert']
                        : ['Casual Interest', 'Actively Learning', 'Urgent Need']
                    ).map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(level, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        proficiencyOrInterest = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
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
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  void _saveProfile() async {
    // Validate required fields
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Save to SharedPreferences for now
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> profileData = {
      'name': _nameController.text,
      'bio': _bioController.text,
      'location': _locationController.text,
      'experienceLevel': _experienceLevel,
      'skillsOffered': _skillsOffered,
      'skillsWanted': _skillsWanted,
      'availableForMentoring': _availableForMentoring,
      'profileImage': _profileImage?.path,
      'profileComplete': true,
    };

    await prefs.setString('userProfile', json.encode(profileData));

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile setup complete! 🚀'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate to home screen
    Navigator.pushReplacementNamed(context, '/home');
  }
}