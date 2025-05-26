import 'package:complete/backend/dbservice.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class LawyerAppointment extends StatefulWidget {
  const LawyerAppointment({Key? key}) : super(key: key);

  @override
  _LawyerAppointmentState createState() => _LawyerAppointmentState();
}

class _LawyerAppointmentState extends State<LawyerAppointment> {
  int _currentIndex = 0;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lawyer Profile',
          style: TextStyle(color: Color(0xFFD0A554)),
        ),
        backgroundColor: const Color(0xFF353E55),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A554),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Appointment button logic here
                Navigator.pushNamed(context, '/user-bookings');
              },
              child: const Text('Appointment'),
            ),
          ),
        ],
      ),

      backgroundColor: const Color(0xFF353E55),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFD0A554),
                  backgroundImage:
                      _profileImage != null ? FileImage(_profileImage!) : null,
                  child:
                      _profileImage == null
                          ? const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.white,
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 20),

              _buildDbDataWidget('ashan'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDbDataWidget(String userId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: Dbservice().getUserById(userId), // Pass the required userId
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Text(
            'No data found',
            style: TextStyle(color: Colors.white),
          );
        } else {
          final user = snapshot.data!;
          return Container(
            width: double.infinity,
            child: Card(
              color: const Color(0xFF454E6A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Name',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      user['name'] ?? 'No Name',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 8),
                    const Text(
                      'Specialization',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      user['specialization'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 8),
                    const Text(
                      'Gender',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      user['gender'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 8),
                    const Text(
                      'Education',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      user['education'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 8),
                    const Text(
                      'Experience',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      '${user['experience'] ?? 'N/A'} years',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 8),
                    const Text(
                      'Languages',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      user['languages'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                    const SizedBox(height: 8),
                    const Text(
                      'Practice Courts',
                      style: TextStyle(color: Color(0xFFD0A554), fontSize: 18),
                    ),
                    Text(
                      user['practiceCourts'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Divider(color: Colors.white38),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF353E55),
      selectedItemColor: const Color(0xFFD0A554),
      unselectedItemColor: const Color(0xFFD9D9D9),
      currentIndex: 0,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/user-home');
        } else if (index == 1) {
          Navigator.pushReplacementNamed(context, '/user-profile');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
