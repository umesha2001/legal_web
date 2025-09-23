import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBooking extends StatefulWidget {
  final String? preSelectedLawyerId;
  final String? preSelectedLawyerName;
  final Map<String, dynamic>? preSelectedLawyerData;

  const UserBooking({
    Key? key,
    this.preSelectedLawyerId,
    this.preSelectedLawyerName,
    this.preSelectedLawyerData,
  }) : super(key: key);

  @override
  State<UserBooking> createState() => _UserBookingState();
}

class _UserBookingState extends State<UserBooking> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Selected lawyer data
  Map<String, dynamic>? _selectedLawyer;
  bool _lawyerPreSelected = false;
  
  // Booking form data
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedTimeSlot = '';
  String _consultationType = 'In-Person';
  List<Map<String, dynamic>> _availableDates = [];
  List<String> _availableTimeSlots = [];
  String? _selectedAvailabilityId;
  bool _isLoading = false;
  
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _consultationTypes = ['In-Person', 'Video Call', 'Phone Call'];

  @override
  void initState() {
    super.initState();
    
    // If lawyer is pre-selected, set it up
    if (widget.preSelectedLawyerId != null && widget.preSelectedLawyerData != null) {
      _selectedLawyer = {
        'id': widget.preSelectedLawyerId!,
        'name': widget.preSelectedLawyerName!,
        ...widget.preSelectedLawyerData!,
      };
      _loadAvailableDates(); // Load available dates for the pre-selected lawyer
    }
    
  }

  void _checkForPreSelectedLawyer() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args != null && args['selectedLawyer'] != null) {
      setState(() {
        _selectedLawyer = args['selectedLawyer'];
        _lawyerPreSelected = true;
      });
      
      // Optionally show booking form immediately
      if (args['autoBook'] == true) {
        _showBookingDialog();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text(
          'Book Appointment',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Lawyer Card (if pre-selected)
            if (_lawyerPreSelected && _selectedLawyer != null)
              _buildSelectedLawyerCard(),
            
            if (_lawyerPreSelected && _selectedLawyer != null)
              const SizedBox(height: 24),
            
            // Booking Form
            if (_lawyerPreSelected && _selectedLawyer != null)
              _buildBookingForm()
            else
              _buildLawyerSelectionPrompt(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLawyerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3D4559),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD0A554), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_pin,
                color: Color(0xFFD0A554),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Selected Lawyer',
                style: TextStyle(
                  color: Color(0xFFD0A554),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedLawyer = null;
                    _lawyerPreSelected = false;
                  });
                },
                child: const Text(
                  'Change',
                  style: TextStyle(color: Color(0xFFD0A554)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Profile Picture
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0A554),
                  shape: BoxShape.circle,
                  image: _selectedLawyer!['profileImageUrl'] != null
                      ? DecorationImage(
                          image: NetworkImage(_selectedLawyer!['profileImageUrl']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedLawyer!['profileImageUrl'] == null
                    ? const Icon(
                        Icons.person,
                        size: 30,
                        color: Color(0xFF353E55),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Lawyer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLawyer!['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedLawyer!['specialization'] ?? 'General Practice',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFD0A554), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedLawyer!['rating'] ?? 0.0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedLawyer!['experience'] ?? 0} years exp.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selection
        _buildFormSection(
          title: 'Select Date',
          icon: Icons.calendar_today,
          child: _buildDateSelection(),
        ),
        const SizedBox(height: 20),

        // Time Slot Selection
        if (_selectedDate != null) ...[
          _buildFormSection(
            title: 'Available Time Slots',
            icon: Icons.access_time,
            child: _buildTimeSelection(),
          ),
          const SizedBox(height: 20),
        ],

        // Consultation Type
        _buildFormSection(
          title: 'Consultation Type',
          icon: Icons.video_call,
          child: _buildConsultationTypeSelection(),
        ),
        const SizedBox(height: 20),

        // Description
        _buildFormSection(
          title: 'Describe Your Legal Issue',
          icon: Icons.description,
          child: TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Briefly describe your legal matter...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD0A554)),
              ),
              filled: true,
              fillColor: const Color(0xFF2A3447),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Book Appointment Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context, 
                '/user/booking',
                arguments: {
                  'lawyerId': _selectedLawyer!['id'],
                  'lawyerName': _selectedLawyer!['name'] ?? 'Unknown Lawyer',
                  'lawyerData': _selectedLawyer,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A554),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Color(0xFF353E55))
                : const Text(
                    'Book Appointment',
                    style: TextStyle(
                      color: Color(0xFF353E55),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLawyerSelectionPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search,
            size: 80,
            color: Color(0xFFD0A554),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Lawyer Selected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please select a lawyer first to book an appointment',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/user_home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A554),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Browse Lawyers',
              style: TextStyle(
                color: Color(0xFF353E55),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFD0A554), size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD0A554),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date',
          style: TextStyle(
            color: Color(0xFFD0A554),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_selectedLawyer == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3D4559),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Please select a lawyer first',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFD0A554)),
          )
        else if (_availableDates.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3D4559),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No available dates for this lawyer',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableDates.length,
              itemBuilder: (context, index) {
                final availability = _availableDates[index];
                final date = (availability['date'] as Timestamp).toDate();
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == date.year &&
                    _selectedDate!.month == date.month &&
                    _selectedDate!.day == date.day;
                
                final availableSlots = List<String>.from(availability['availableSlots'] ?? []);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                    _loadAvailableTimeSlots(date);
                  },
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFFD0A554)
                          : const Color(0xFF3D4559),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD0A554),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected 
                                ? const Color(0xFF353E55)
                                : Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getMonthName(date.month),
                          style: TextStyle(
                            color: isSelected 
                                ? const Color(0xFF353E55)
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${availableSlots.length} slots',
                          style: TextStyle(
                            color: isSelected 
                                ? const Color(0xFF353E55)
                                : const Color(0xFFD0A554),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Time Slot',
          style: TextStyle(
            color: Color(0xFFD0A554),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_selectedDate == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3D4559),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Please select a date first',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else if (_availableTimeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF3D4559),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No available time slots for selected date',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTimeSlots.map((slot) {
              final isSelected = _selectedTime == slot;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTime = _parseTimeOfDay(slot);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFD0A554)
                        : const Color(0xFF3D4559),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD0A554),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      color: isSelected 
                          ? const Color(0xFF353E55)
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildConsultationTypeSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _consultationTypes.map((type) {
        final isSelected = _consultationType == type;
        return InkWell(
          onTap: () {
            setState(() {
              _consultationType = type;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD0A554) : const Color(0xFF2A3447),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFFD0A554) : Colors.grey[600]!,
              ),
            ),
            child: Text(
              type,
              style: TextStyle(
                color: isSelected ? const Color(0xFF353E55) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD0A554),
              onPrimary: Color(0xFF353E55),
              surface: Color(0xFF3D4559),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = ''; // Reset time slot when date changes
      });
      _loadAvailableTimeSlots(_selectedDate!);
    }
  }

  Future<void> _loadAvailableDates() async {
    if (_selectedLawyer == null) return;
    
    try {
      setState(() => _isLoading = true);
      
      final QuerySnapshot snapshot = await _firestore
          .collection('lawyer_availability')
          .where('lawyerId', isEqualTo: _selectedLawyer!['id'])
          .where('isAvailable', isEqualTo: true)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('date')
          .get();

      setState(() {
        _availableDates = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList();
        _isLoading = false;
        
        // Reset selections when lawyer changes
        _selectedDate = null;
        _selectedTime = null;
        _availableTimeSlots = [];
        _selectedAvailabilityId = null;
      });
      
      print('Found ${_availableDates.length} available dates for lawyer');
    } catch (e) {
      print('Error loading available dates: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadAvailableTimeSlots(DateTime selectedDate) {
    try {
      final availability = _availableDates.firstWhere(
        (avail) {
          final date = (avail['date'] as Timestamp).toDate();
          return date.year == selectedDate.year && 
                 date.month == selectedDate.month && 
                 date.day == selectedDate.day;
        },
      );
      
      setState(() {
        _availableTimeSlots = List<String>.from(availability['availableSlots'] ?? []);
        _selectedAvailabilityId = availability['id'];
        _selectedTime = null; // Reset time selection
      });
      
      print('Available time slots: $_availableTimeSlots');
    } catch (e) {
      print('No availability found for selected date');
      setState(() {
        _availableTimeSlots = [];
        _selectedAvailabilityId = null;
        _selectedTime = null;
      });
    }
  }

  // Update your lawyer selection method to load dates:
  void _selectLawyer(Map<String, dynamic> lawyer) {
    setState(() {
      _selectedLawyer = lawyer;
    });
    _loadAvailableDates(); // Load available dates when lawyer is selected
  }

  Future<void> _bookAppointment() async {
    if (_selectedDate == null || _selectedTimeSlot.isEmpty || _selectedLawyer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final String userId = _auth.currentUser!.uid;
      
      // Create booking document
      await _firestore.collection('bookings').add({
        'userId': userId,
        'lawyerId': _selectedLawyer!['id'],
        'lawyerName': _selectedLawyer!['name'],
        'lawyerEmail': _selectedLawyer!['email'],
        'date': Timestamp.fromDate(_selectedDate!),
        'timeSlot': _selectedTimeSlot,
        'consultationType': _consultationType,
        'description': _descriptionController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update lawyer availability - remove the booked slot
      if (_selectedAvailabilityId != null) {
        List<String> updatedSlots = List<String>.from(_availableTimeSlots);
        updatedSlots.remove(_selectedTime);
        
        await _firestore
            .collection('lawyer_availability')
            .doc(_selectedAvailabilityId!)
            .update({
          'availableSlots': updatedSlots,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Color(0xFFD0A554),
          ),
        );
        
        // Navigate back to user home or bookings
        Navigator.pushReplacementNamed(context, '/user_home');
      }
    } catch (e) {
      print('Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBookingDialog() {
    // You can implement a dialog version if needed
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D4559),
        title: const Text(
          'Book Appointment',
          style: TextStyle(color: Color(0xFFD0A554)),
        ),
        content: const Text(
          'Would you like to book an appointment with this lawyer?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Scroll to booking form or take other action
            },
            child: const Text(
              'Yes',
              style: TextStyle(color: Color(0xFFD0A554)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Helper method for month names:
  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // Helper to parse time slot string (e.g., "10:30 AM") to TimeOfDay
  TimeOfDay _parseTimeOfDay(String timeString) {
    final format = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false);
    final match = format.firstMatch(timeString.trim());
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      String period = match.group(3)!.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    // fallback to 0:00 if parsing fails
    return const TimeOfDay(hour: 0, minute: 0);
  }

  // Helper method for snackbar:
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}