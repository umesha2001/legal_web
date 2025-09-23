import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserBookingsScreen extends StatefulWidget {
  const UserBookingsScreen({Key? key}) : super(key: key);

  @override
  _UserBookingsScreenState createState() => _UserBookingsScreenState();
}

class _UserBookingsScreenState extends State<UserBookingsScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Tab controller for switching between New Booking and My Bookings
  late TabController _tabController;
  
  // Existing booking form variables
  Map<String, dynamic>? _currentUserData;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String _bookingReason = '';
  String _bookingType = 'ON Call';
  String? _selectedLawyer;
  List<Map<String, dynamic>> _lawyers = [];
  bool _isLoadingLawyers = true;
  Map<String, dynamic>? _selectedLawyerData;
  
  // My Bookings variables
  List<Map<String, dynamic>> _userBookings = [];
  bool _isLoadingBookings = true;

  // Updated availability variables
  List<DateTime> _availableDates = [];
  List<String> _availableTimeSlots = [];
  bool _isLoadingAvailability = false;
  String? _selectedAvailabilityId; // Track which availability slot is selected

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCurrentUserData();
    _fetchLawyers();
    _fetchUserBookings();
    
    // Check if we received lawyer data from lawyer details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      if (args != null && args['selectedLawyer'] != null) {
        // Pre-select this lawyer for booking
        setState(() {
          _selectedLawyer = args['selectedLawyer'];
        });
        // Load availability for pre-selected lawyer
        _loadLawyerAvailability(args['selectedLawyer']);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLawyers() async {
    setState(() => _isLoadingLawyers = true);
    
    try {
      final QuerySnapshot snapshot = await _firestore.collection('lawyers').get();
      
      List<Map<String, dynamic>> lawyers = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> lawyerData = doc.data() as Map<String, dynamic>;
        lawyerData['id'] = doc.id;
        lawyers.add(lawyerData);
      }
      
      setState(() {
        _lawyers = lawyers;
        _isLoadingLawyers = false;
      });
      
      print('Fetched ${lawyers.length} lawyers');
    } catch (e) {
      print('Error fetching lawyers: $e');
      setState(() => _isLoadingLawyers = false);
    }
  }

  Future<void> _fetchCurrentUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          setState(() {
            _currentUserData = userDoc.data();
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _fetchUserBookings() async {
    setState(() => _isLoadingBookings = true);
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final bookingsSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('bookings')
            .orderBy('createdAt', descending: true)
            .get();

        List<Map<String, dynamic>> bookings = [];
        for (var doc in bookingsSnapshot.docs) {
          Map<String, dynamic> booking = doc.data();
          booking['id'] = doc.id;
          bookings.add(booking);
        }

        setState(() {
          _userBookings = bookings;
          _isLoadingBookings = false;
        });
      }
    } catch (e) {
      print('Error fetching user bookings: $e');
      setState(() => _isLoadingBookings = false);
    }
  }

  // Updated method to load lawyer's actual availability - simplified to avoid index requirements
  Future<void> _loadLawyerAvailability(String lawyerId) async {
    if (lawyerId.isEmpty) return;
    
    try {
      setState(() {
        _isLoadingAvailability = true;
        _availableDates = [];
        _availableTimeSlots = [];
        _selectedDate = null;
        _selectedTimeSlot = null;
        _selectedAvailabilityId = null;
      });
      
      print('Loading availability for lawyer: $lawyerId');
      
      // Use simple query to avoid index requirements
      final QuerySnapshot snapshot = await _firestore
          .collection('lawyer_availability')
          .where('lawyerId', isEqualTo: lawyerId)
          .get();

      print('Found ${snapshot.docs.length} total availability slots');

      // Filter and process locally
      final DateTime today = DateTime.now();
      final DateTime startOfDay = DateTime(today.year, today.month, today.day);
      
      Set<DateTime> uniqueDates = {};
      List<Map<String, dynamic>> validSlots = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if available
        final isAvailable = data['isAvailable'] ?? false;
        if (!isAvailable) continue;
        
        // Check date
        final timestamp = data['date'];
        if (timestamp == null) continue;
        
        DateTime slotDate;
        if (timestamp is Timestamp) {
          slotDate = timestamp.toDate();
        } else {
          continue; // Skip if date format is unexpected
        }
        
        // Only include future dates
        final dateOnly = DateTime(slotDate.year, slotDate.month, slotDate.day);
        if (dateOnly.isBefore(startOfDay)) continue;
        
        // Add to valid slots
        data['docId'] = doc.id;
        data['dateOnly'] = dateOnly;
        validSlots.add(data);
        uniqueDates.add(dateOnly);
      }

      // Sort dates locally
      List<DateTime> sortedDates = uniqueDates.toList()..sort();

      setState(() {
        _availableDates = sortedDates;
        _isLoadingAvailability = false;
      });
      
      print('Available dates after filtering: ${_availableDates.length}');
      
      // If no availability found, create sample data
      if (_availableDates.isEmpty) {
        print('No availability found, creating sample data...');
        _createSampleAvailability(lawyerId);
      }
      
    } catch (e) {
      print('Error loading lawyer availability: $e');
      setState(() => _isLoadingAvailability = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading availability. Creating sample data...'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // Create sample data on error
      _createSampleAvailability(lawyerId);
    }
  }

  // Updated method to create sample availability
  Future<void> _createSampleAvailability(String lawyerId) async {
    try {
      print('Creating sample availability for lawyer: $lawyerId');
      
      final batch = _firestore.batch();
      
      // Create availability for next 7 days
      for (int i = 1; i <= 7; i++) {
        final date = DateTime.now().add(Duration(days: i));
        final dateOnly = DateTime(date.year, date.month, date.day);
        
        // Morning slot
        final morningRef = _firestore.collection('lawyer_availability').doc();
        batch.set(morningRef, {
          'lawyerId': lawyerId,
          'date': Timestamp.fromDate(dateOnly),
          'startTime': '9:00 AM',
          'endTime': '10:00 AM',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Afternoon slot
        final afternoonRef = _firestore.collection('lawyer_availability').doc();
        batch.set(afternoonRef, {
          'lawyerId': lawyerId,
          'date': Timestamp.fromDate(dateOnly),
          'startTime': '2:00 PM',
          'endTime': '3:00 PM',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Evening slot
        final eveningRef = _firestore.collection('lawyer_availability').doc();
        batch.set(eveningRef, {
          'lawyerId': lawyerId,
          'date': Timestamp.fromDate(dateOnly),
          'startTime': '5:00 PM',
          'endTime': '6:00 PM',
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print('Sample availability created successfully');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample availability created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Reload availability after creating sample data
      _loadLawyerAvailability(lawyerId);
      
    } catch (e) {
      print('Error creating sample availability: $e');
      
      // Fallback: Show static dates if even sample creation fails
      setState(() {
        _availableDates = [
          DateTime.now().add(const Duration(days: 1)),
          DateTime.now().add(const Duration(days: 2)),
          DateTime.now().add(const Duration(days: 3)),
        ];
        _isLoadingAvailability = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using fallback dates. Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Updated load time slots method - simplified
  Future<void> _loadTimeSlotsForDate(DateTime selectedDate) async {
    if (_selectedLawyer == null) return;
    
    try {
      setState(() {
        _isLoadingAvailability = true;
        _availableTimeSlots = [];
        _selectedTimeSlot = null;
        _selectedAvailabilityId = null;
      });
      
      print('Loading time slots for date: $selectedDate');
      
      // Use simple query
      final QuerySnapshot snapshot = await _firestore
          .collection('lawyer_availability')
          .where('lawyerId', isEqualTo: _selectedLawyer)
          .get();

      print('Found ${snapshot.docs.length} total slots for lawyer');

      // Filter locally for the selected date
      final DateTime startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final DateTime endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
      
      List<Map<String, dynamic>> timeSlotData = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if available
        final isAvailable = data['isAvailable'] ?? false;
        if (!isAvailable) continue;
        
        // Check date
        final timestamp = data['date'];
        if (timestamp == null) continue;
        
        DateTime slotDate;
        if (timestamp is Timestamp) {
          slotDate = timestamp.toDate();
        } else {
          continue;
        }
        
        // Check if this slot is for the selected date
        final slotDateOnly = DateTime(slotDate.year, slotDate.month, slotDate.day);
        if (slotDateOnly.year != selectedDate.year || 
            slotDateOnly.month != selectedDate.month || 
            slotDateOnly.day != selectedDate.day) {
          continue;
        }
        
        final startTime = data['startTime'] ?? '';
        final endTime = data['endTime'] ?? '';
        
        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          timeSlotData.add({
            'docId': doc.id,
            'timeSlot': '$startTime - $endTime',
            'startTime': startTime,
            'endTime': endTime,
          });
        }
      }

      // Sort time slots locally by start time
      timeSlotData.sort((a, b) {
        final aTime = a['startTime'] as String;
        final bTime = b['startTime'] as String;
        return aTime.compareTo(bTime);
      });

      List<String> timeSlots = timeSlotData.map((slot) => slot['timeSlot'] as String).toList();

      setState(() {
        _availableTimeSlots = timeSlots;
        _isLoadingAvailability = false;
      });
      
      print('Found ${timeSlots.length} time slots for selected date');
      
      if (timeSlots.isEmpty) {
        // Create sample time slots for this date if none exist
        await _createSampleTimeSlotsForDate(selectedDate);
      }
      
    } catch (e) {
      print('Error loading time slots: $e');
      setState(() => _isLoadingAvailability = false);
      
      // Fallback: provide static time slots
      setState(() {
        _availableTimeSlots = ['9:00 AM - 10:00 AM', '2:00 PM - 3:00 PM', '5:00 PM - 6:00 PM'];
        _isLoadingAvailability = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Using fallback time slots. Error: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Helper method to create sample time slots for a specific date
  Future<void> _createSampleTimeSlotsForDate(DateTime selectedDate) async {
    if (_selectedLawyer == null) return;
    
    try {
      final batch = _firestore.batch();
      final dateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      
      // Morning slot
      final morningRef = _firestore.collection('lawyer_availability').doc();
      batch.set(morningRef, {
        'lawyerId': _selectedLawyer,
        'date': Timestamp.fromDate(dateOnly),
        'startTime': '9:00 AM',
        'endTime': '10:00 AM',
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Afternoon slot
      final afternoonRef = _firestore.collection('lawyer_availability').doc();
      batch.set(afternoonRef, {
        'lawyerId': _selectedLawyer,
        'date': Timestamp.fromDate(dateOnly),
        'startTime': '2:00 PM',
        'endTime': '3:00 PM',
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Evening slot
      final eveningRef = _firestore.collection('lawyer_availability').doc();
      batch.set(eveningRef, {
        'lawyerId': _selectedLawyer,
        'date': Timestamp.fromDate(dateOnly),
        'startTime': '5:00 PM',
        'endTime': '6:00 PM',
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Reload time slots
      _loadTimeSlotsForDate(selectedDate);
      
    } catch (e) {
      print('Error creating sample time slots: $e');
    }
  }

  // Updated get availability ID method - simplified
  Future<String?> _getAvailabilityId(DateTime selectedDate, String timeSlot) async {
    if (_selectedLawyer == null) return null;
    
    try {
      // Use simple query
      final QuerySnapshot snapshot = await _firestore
          .collection('lawyer_availability')
          .where('lawyerId', isEqualTo: _selectedLawyer)
          .get();

      // Filter locally
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if available
        final isAvailable = data['isAvailable'] ?? false;
        if (!isAvailable) continue;
        
        // Check date
        final timestamp = data['date'];
        if (timestamp == null) continue;
        
        DateTime slotDate;
        if (timestamp is Timestamp) {
          slotDate = timestamp.toDate();
        } else {
          continue;
        }
        
        // Check if this slot is for the selected date
        final slotDateOnly = DateTime(slotDate.year, slotDate.month, slotDate.day);
        if (slotDateOnly.year != selectedDate.year || 
            slotDateOnly.month != selectedDate.month || 
            slotDateOnly.day != selectedDate.day) {
          continue;
        }
        
        final startTime = data['startTime'] ?? '';
        final endTime = data['endTime'] ?? '';
        final docTimeSlot = '$startTime - $endTime';
        
        if (docTimeSlot == timeSlot) {
          return doc.id;
        }
      }
    } catch (e) {
      print('Error getting availability ID: $e');
    }
    
    return null;
  }

  // Update the lawyer selection to load availability
  void _onLawyerSelected(String? lawyerId) {
    if (lawyerId != null) {
      final selectedLawyerData = _lawyers.firstWhere(
        (lawyer) => lawyer['id'] == lawyerId,
        orElse: () => {},
      );
      
      setState(() {
        _selectedLawyer = lawyerId;
        _selectedLawyerData = selectedLawyerData;
        _selectedDate = null;
        _selectedTimeSlot = null;
        _availableTimeSlots = [];
        _selectedAvailabilityId = null;
      });
      
      _loadLawyerAvailability(lawyerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text('Bookings'),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A554)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD0A554),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFD0A554),
          tabs: const [
            Tab(text: 'New Booking'),
            Tab(text: 'My Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewBookingTab(),
          _buildMyBookingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF353E55),
        selectedItemColor: const Color(0xFFD0A554),
        unselectedItemColor: const Color(0xFFD9D9D9),
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/user-home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/user-profile');
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

  // Updated New Booking Tab with availability integration
  Widget _buildNewBookingTab() {
    return _isLoadingLawyers 
      ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFD0A554)),
        )
      : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Lawyer Section
                      _buildSection(
                        icon: Icons.person,
                        title: 'Select Lawyer',
                        child: _lawyers.isEmpty
                          ? const Text(
                              'No lawyers available',
                              style: TextStyle(color: Colors.grey),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedLawyer,
                              dropdownColor: const Color(0xFF3D4559),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Choose a lawyer',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              items: _lawyers.map((lawyer) {
                                return DropdownMenuItem<String>(
                                  value: lawyer['id'],
                                  child: Text(
                                    lawyer['name'] ?? 'Unknown Lawyer',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _onLawyerSelected,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a lawyer';
                                }
                                return null;
                              },
                            ),
                      ),
                      
                      // Display selected lawyer info
                      if (_selectedLawyerData != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3447),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedLawyerData!['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Color(0xFFD0A554),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_selectedLawyerData!['specialization'] != null)
                                      Text(
                                        _selectedLawyerData!['specialization'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (_selectedLawyerData!['experience'] != null)
                                    Text(
                                      '${_selectedLawyerData!['experience']} yrs',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (_selectedLawyerData!['rating'] != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        Text(
                                          ' ${_selectedLawyerData!['rating']}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Date Selection - Updated to show only available dates
                      _buildSection(
                        icon: Icons.calendar_today,
                        title: 'Available Dates',
                        child: _selectedLawyer == null
                            ? const Text(
                                'Please select a lawyer first',
                                style: TextStyle(color: Colors.grey),
                              )
                            : _isLoadingAvailability
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(color: Color(0xFFD0A554)),
                                    ),
                                  )
                                : _availableDates.isEmpty
                                    ? const Text(
                                        'No available dates for this lawyer',
                                        style: TextStyle(color: Colors.grey),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _availableDates.map((date) {
                                          final isSelected = _selectedDate != null &&
                                              date.year == _selectedDate!.year &&
                                              date.month == _selectedDate!.month &&
                                              date.day == _selectedDate!.day;
                                          
                                          return SizedBox(
                                            width: (MediaQuery.of(context).size.width - 80) / 3,
                                            child: ChoiceChip(
                                              label: Text(
                                                '${date.day}/${date.month}',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? const Color(0xFF353E55)
                                                      : Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              selected: isSelected,
                                              selectedColor: const Color(0xFFD0A554),
                                              backgroundColor: const Color(0xFF3D4559),
                                              onSelected: (selected) {
                                                if (selected) {
                                                  setState(() {
                                                    _selectedDate = date;
                                                  });
                                                  _loadTimeSlotsForDate(date);
                                                }
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                      ),
                      const SizedBox(height: 20),

                      // Time Selection - Updated to show lawyer's available times
                      _buildSection(
                        icon: Icons.access_time,
                        title: 'Available Time Slots',
                        child: _selectedDate == null
                            ? const Text(
                                'Please select a date first',
                                style: TextStyle(color: Colors.grey),
                              )
                            : _isLoadingAvailability
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(color: Color(0xFFD0A554)),
                                    ),
                                  )
                                : _availableTimeSlots.isEmpty
                                    ? const Text(
                                        'No available time slots for this date',
                                        style: TextStyle(color: Colors.grey),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _availableTimeSlots.map((time) {
                                          return SizedBox(
                                            width: (MediaQuery.of(context).size.width - 80) / 2,
                                            child: ChoiceChip(
                                              label: Text(
                                                time,
                                                style: TextStyle(
                                                  color: _selectedTimeSlot == time
                                                      ? const Color(0xFF353E55)
                                                      : Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              selected: _selectedTimeSlot == time,
                                              selectedColor: const Color(0xFFD0A554),
                                              backgroundColor: const Color(0xFF3D4559),
                                              onSelected: (selected) async {
                                                if (selected && _selectedDate != null) {
                                                  final availabilityId = await _getAvailabilityId(_selectedDate!, time);
                                                  setState(() {
                                                    _selectedTimeSlot = time;
                                                    _selectedAvailabilityId = availabilityId;
                                                  });
                                                }
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ),
                      ),
                      const SizedBox(height: 20),

                      // Reason Section
                      _buildSection(
                        icon: Icons.note,
                        title: 'Reason',
                        child: TextFormField(
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Briefly describe your legal issue',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _bookingReason = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter booking reason';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Type Section
                      _buildSection(
                        icon: Icons.phone,
                        title: 'Type',
                        child: DropdownButtonFormField<String>(
                          value: _bookingType,
                          dropdownColor: const Color(0xFF3D4559),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          items: ['ON Call', 'In Person'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _bookingType = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Submit Button
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD0A554),
                            minimumSize: const Size(200, 50),
                          ),
                          onPressed: _submitBooking,
                          child: const Text(
                            'PROCEED TO PAYMENT',
                            style: TextStyle(
                              color: Color(0xFF353E55),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
  }

  // My Bookings Tab (existing implementation)
  Widget _buildMyBookingsTab() {
    return _isLoadingBookings
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFD0A554)),
          )
        : _userBookings.isEmpty
            ? _buildEmptyBookingsState()
            : RefreshIndicator(
                onRefresh: _fetchUserBookings,
                color: const Color(0xFFD0A554),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userBookings.length,
                  itemBuilder: (context, index) {
                    final booking = _userBookings[index];
                    return _buildBookingCard(booking);
                  },
                ),
              );
  }

  Widget _buildEmptyBookingsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 20),
          Text(
            'No bookings yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your consultation bookings will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A554),
              minimumSize: const Size(200, 50),
            ),
            onPressed: () {
              _tabController.animateTo(0); // Switch to New Booking tab
            },
            child: const Text(
              'BOOK CONSULTATION',
              style: TextStyle(
                color: Color(0xFF353E55),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    Color statusColor = _getStatusColor(booking['status'] ?? 'pending');
    IconData statusIcon = _getStatusIcon(booking['status'] ?? 'pending');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF3D4559),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with lawyer name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking['lawyerName'] ?? 'Unknown Lawyer',
                        style: const TextStyle(
                          color: Color(0xFFD0A554),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (booking['transactionId'] != null)
                        Text(
                          'ID: ${booking['transactionId']}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(booking['status'] ?? 'pending'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Booking details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3447),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Date',
                    booking['date'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    Icons.access_time,
                    'Time',
                    booking['time'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    Icons.phone,
                    'Type',
                    booking['type'] ?? 'N/A',
                  ),
                  _buildDetailRow(
                    Icons.note,
                    'Reason',
                    booking['reason'] ?? 'N/A',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Payment info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A4D3A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.payment,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        booking['paymentStatus'] ?? 'Pending',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'LKR ${booking['amount']?.toString() ?? '0'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD0A554), size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'CONFIRMED';
      case 'accepted':
        return 'ACCEPTED';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      case 'cancelled':
        return 'CANCELLED';
      case 'completed':
        return 'COMPLETED';
      default:
        return 'UNKNOWN';
    }
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFD0A554), size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD0A554),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3D4559),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }

  void _submitBooking() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTimeSlot == null || _selectedLawyer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all fields'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String clientName = 'N/A';
      String clientPhone = 'N/A';
      String clientEmail = 'N/A';
      
      if (_currentUserData != null) {
        clientName = _currentUserData!['firstName'] ?? 
                     _currentUserData!['name'] ?? 
                     'N/A';
        
        clientPhone = _currentUserData!['contact'] ?? 
                      _currentUserData!['phone'] ?? 
                      'N/A';
        
        clientEmail = _currentUserData!['email'] ?? 
                      _auth.currentUser?.email ?? 
                      'N/A';
      }

      double consultationFee = _selectedLawyerData?['consultationFee']?.toDouble() ?? 150.0;

      Navigator.pushNamed(
        context,
        '/payment-gateway',
        arguments: {
          'lawyerId': _selectedLawyer,
          'lawyer': _selectedLawyerData?['name'] ?? 'Unknown Lawyer',
          'lawyerData': _selectedLawyerData,
          'date': _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : '',
          'time': _selectedTimeSlot ?? '',
          'type': _bookingType,
          'reason': _bookingReason,
          'amount': consultationFee,
          'clientName': clientName,
          'clientEmail': clientEmail,
          'clientPhone': clientPhone,
          'availabilityId': _selectedAvailabilityId, // Include availability ID for booking
        },
      ).then((_) {
        // Refresh bookings when returning from payment
        _fetchUserBookings();
        // Switch to My Bookings tab to show the new booking
        _tabController.animateTo(1);
      });
    }
  }
}