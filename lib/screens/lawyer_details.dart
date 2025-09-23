import 'package:complete/screens/lawyer_bookings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:complete/screens/chat_screen.dart';


class LawyerDetailsScreen extends StatefulWidget {
  final String lawyerId;

  const LawyerDetailsScreen({
    Key? key,
    required this.lawyerId,
  }) : super(key: key);

  @override
  State<LawyerDetailsScreen> createState() => _LawyerDetailsScreenState();
}

class _LawyerDetailsScreenState extends State<LawyerDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _lawyerData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLawyerDetails();
  }

  Future<void> _loadLawyerDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final DocumentSnapshot doc = await _firestore
          .collection('lawyers')
          .doc(widget.lawyerId)
          .get();

      if (doc.exists) {
        setState(() {
          _lawyerData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Lawyer not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading lawyer details: $e');
      setState(() {
        _error = 'Failed to load lawyer details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text(
          'Lawyer Details',
          style: TextStyle(
            color: Color(0xFFD0A554),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD0A554)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFD0A554)),
            onPressed: _loadLawyerDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD0A554)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLawyerDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD0A554),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Color(0xFF353E55)),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      _buildProfileHeader(),
                      const SizedBox(height: 24),

                      // Contact Information
                      _buildSection(
                        title: 'Contact Information',
                        icon: Icons.contact_phone,
                        content: _buildContactInfo(),
                      ),
                      const SizedBox(height: 24),

                      // Professional Information
                      _buildSection(
                        title: 'Professional Information',
                        icon: Icons.work,
                        content: _buildProfessionalInfo(),
                      ),
                      const SizedBox(height: 24),

                      // Education & Experience
                      _buildSection(
                        title: 'Education & Experience',
                        icon: Icons.school,
                        content: _buildEducationInfo(),
                      ),
                      const SizedBox(height: 24),

                      // Availability
                      if (_lawyerData!['availability'] != null)
                        _buildSection(
                          title: 'Availability',
                          icon: Icons.schedule,
                          content: _buildAvailabilityInfo(),
                        ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          // Book Appointment button
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD0A554),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LawyerBookings(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Book Appointment',
                                style: TextStyle(
                                  color: Color(0xFF353E55),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Chat button
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C8EBF),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      lawyerId: widget.lawyerId,
                                      lawyerName:
                                          _lawyerData!['name'] ?? 'Unknown Lawyer',
                                      lawyerProfileImage:
                                          _lawyerData!['profileImage'],
                                    ),
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Chat',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3D4559),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // Profile Picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFD0A554),
              shape: BoxShape.circle,
              image: _lawyerData!['profileImageUrl'] != null
                  ? DecorationImage(
                      image: NetworkImage(_lawyerData!['profileImageUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _lawyerData!['profileImageUrl'] == null
                ? const Icon(
                    Icons.person,
                    size: 50,
                    color: Color(0xFF353E55),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            _lawyerData!['name'] ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Specialization
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD0A554),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _lawyerData!['specialization'] ?? 'General Practice',
              style: const TextStyle(
                color: Color(0xFF353E55),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rating and Experience
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                Icons.star,
                '${_lawyerData!['rating'] ?? 0.0}',
                'Rating',
              ),
              _buildStatItem(
                Icons.work_history,
                '${_lawyerData!['experience'] ?? 0}',
                'Years Exp.',
              ),
              _buildStatItem(
                Icons.cases,
                '${_lawyerData!['casesWon'] ?? 0}',
                'Cases Won',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFD0A554), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3D4559),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD0A554), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFD0A554),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        _buildInfoRow(Icons.email, 'Email', _lawyerData!['email'] ?? 'Not provided'),
        _buildInfoRow(Icons.phone, 'Phone', _lawyerData!['phone'] ?? 'Not provided'),
        _buildInfoRow(Icons.location_on, 'Address', _lawyerData!['address'] ?? 'Not provided'),
        _buildInfoRow(Icons.location_city, 'City', _lawyerData!['city'] ?? 'Not provided'),
      ],
    );
  }

  Widget _buildProfessionalInfo() {
    return Column(
      children: [
        _buildInfoRow(Icons.business, 'Law Firm', _lawyerData!['lawFirm'] ?? 'Independent Practice'),
        _buildInfoRow(Icons.badge, 'Bar Council ID', _lawyerData!['barCouncilId'] ?? 'Not provided'),
        _buildInfoRow(Icons.calendar_today, 'Years of Experience', '${_lawyerData!['experience'] ?? 0} years'),
        _buildInfoRow(Icons.language, 'Languages', _lawyerData!['languages'] ?? 'English'),
        if (_lawyerData!['courtsPracticing'] != null)
          _buildInfoRow(Icons.account_balance, 'Courts Practicing', _lawyerData!['courtsPracticing']),
      ],
    );
  }

  Widget _buildEducationInfo() {
    return Column(
      children: [
        _buildInfoRow(Icons.school, 'Education', _lawyerData!['education'] ?? 'Not provided'),
        _buildInfoRow(Icons.emoji_events, 'Achievements', _lawyerData!['achievements'] ?? 'Not provided'),
        if (_lawyerData!['certifications'] != null)
          _buildInfoRow(Icons.verified, 'Certifications', _lawyerData!['certifications']),
      ],
    );
  }

  Widget _buildAvailabilityInfo() {
    final availability = _lawyerData!['availability'];
    if (availability is Map) {
      return Column(
        children: availability.entries.map((entry) {
          return _buildInfoRow(
            Icons.access_time,
            entry.key.toString().toUpperCase(),
            entry.value.toString(),
          );
        }).toList(),
      );
    }
    return _buildInfoRow(Icons.schedule, 'Availability', availability.toString());
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFD0A554), size: 20),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}