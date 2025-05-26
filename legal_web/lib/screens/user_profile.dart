import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _professionController;
  late TextEditingController _districtController;
  late TextEditingController _nicController;
  late TextEditingController _genderController;
  late TextEditingController _languageController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Initialize with sample data
    _fullNameController = TextEditingController(text: 'John Doe');
    _addressController = TextEditingController(text: '12/A Kaleniya, Colombo');
    _contactController = TextEditingController(text: '0780232301');
    _professionController = TextEditingController(text: 'Doctor');
    _districtController = TextEditingController(text: 'Colombo');
    _nicController = TextEditingController(text: '200106903360');
    _genderController = TextEditingController(text: 'Male');
    _languageController = TextEditingController(text: 'Sinhala');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _professionController.dispose();
    _districtController.dispose();
    _nicController.dispose();
    _genderController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A554)),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                if (_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile saved successfully'),
                      backgroundColor: Color(0xFFD0A554),
                    ),
                  );
                }
              }
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFFD0A554),
                child: Icon(Icons.person, size: 50, color: Color(0xFF353E55)),
              ),
              const SizedBox(height: 20),
              _buildProfileField('Full Name', _fullNameController, Icons.person),
              _buildProfileField('Address', _addressController, Icons.location_on),
              _buildProfileField('Contact', _contactController, Icons.phone),
              _buildProfileField('Profession', _professionController, Icons.work),
              _buildProfileField('District', _districtController, Icons.map),
              _buildProfileField('NIC', _nicController, Icons.credit_card),
              _buildProfileField('Gender', _genderController, Icons.transgender),
              _buildProfileField('Language', _languageController, Icons.language),
              const SizedBox(height: 30),
              if (_isEditing)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0A554),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Save profile logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile saved successfully'),
                          backgroundColor: Color(0xFFD0A554),
                        ),
                      );
                      setState(() {
                        _isEditing = false;
                      });
                    }
                  },
                  child: const Text(
                    'SAVE CHANGES',
                    style: TextStyle(
                      color: Color(0xFF353E55),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF353E55),
        selectedItemColor: const Color(0xFFD0A554),
        unselectedItemColor: const Color(0xFFD9D9D9),
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/user-home');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        enabled: _isEditing,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFD0A554)),
          prefixIcon: Icon(icon, color: const Color(0xFFD0A554)),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD0A554)),
          ),
          disabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }
}