import 'package:flutter/material.dart';

class UserBookingsScreen extends StatefulWidget {
  const UserBookingsScreen({Key? key}) : super(key: key);

  @override
  _UserBookingsScreenState createState() => _UserBookingsScreenState();
}

class _UserBookingsScreenState extends State<UserBookingsScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String _bookingReason = '';
  String _bookingType = 'ON Call';
  String? _selectedLawyer;

  final List<String> _timeSlots = [
    '10.00 AM',
    '10.30 AM',
    '11.00 AM',
    '11.30 AM',
  ];
  final List<Map<String, dynamic>> _lawyers = [
    {'name': 'John Doe', 'specialization': 'Corporate Law'},
    {'name': 'Jane Smith', 'specialization': 'Family Law'},
    {'name': 'Robert Johnson', 'specialization': 'Criminal Law'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text(
          'New Booking',
          style: TextStyle(color: Color(0xFFD0A554)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD0A554)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A554)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lawyer Selection
              _buildSection(
                icon: Icons.person,
                title: 'Select Lawyer',
                child: DropdownButtonFormField<String>(
                  value: _selectedLawyer,
                  dropdownColor: const Color(0xFF3D4559),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Choose a lawyer',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  items:
                      _lawyers.map((lawyer) {
                        return DropdownMenuItem<String>(
                          value: lawyer['name'],
                          child: Text(
                            '${lawyer['name']} - ${lawyer['specialization']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLawyer = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a lawyer';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Date Selection
              _buildSection(
                icon: Icons.calendar_today,
                title: 'Date',
                child: InkWell(
                  onTap: _selectDate,
                  child: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Select Date',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time Selection
              _buildSection(
                icon: Icons.access_time,
                title: 'Time',
                child: Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          _timeSlots.map((time) {
                            return ChoiceChip(
                              label: Text(time),
                              selected: _selectedTimeSlot == time,
                              selectedColor: const Color(0xFFD0A554),
                              backgroundColor: const Color(0xFF3D4559),
                              labelStyle: TextStyle(
                                color:
                                    _selectedTimeSlot == time
                                        ? const Color(0xFF353E55)
                                        : Colors.white,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTimeSlot = selected ? time : null;
                                });
                              },
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason
              _buildSection(
                icon: Icons.note,
                title: 'Reason',
                child: TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Briefly describe your legal issue',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
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

              // Type
              _buildSection(
                icon: Icons.phone,
                title: 'Type',
                child: DropdownButtonFormField<String>(
                  value: _bookingType,
                  dropdownColor: const Color(0xFF3D4559),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none),
                  items:
                      ['ON Call', 'In Person'].map((String value) {
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF353E55),
        selectedItemColor: const Color(0xFFD0A554),
        unselectedItemColor: const Color.fromARGB(255, 217, 217, 217),
        currentIndex: 0,
        onTap: (index) {
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
      ),
    );
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
            Icon(icon, color: const Color(0xFFD0A554)),
            const SizedBox(width: 10),
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
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3D4559),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD0A554),
              onPrimary: Color.fromRGBO(53, 62, 85, 1),
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
      });
    }
  }

  void _submitBooking() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null ||
          _selectedTimeSlot == null ||
          _selectedLawyer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all fields'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.pushNamed(
        context,
        '/payment-gateway',
        arguments: {
          'lawyer': _selectedLawyer,
          'date':
              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          'time': _selectedTimeSlot,
          'type': _bookingType,
          'reason': _bookingReason,
        },
      );
    }
  }
}
