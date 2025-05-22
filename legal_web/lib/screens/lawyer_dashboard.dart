import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

class LawyerDashboard extends StatefulWidget {
  const LawyerDashboard({Key? key}) : super(key: key);

  @override
  _LawyerDashboardState createState() => _LawyerDashboardState();
}

class _LawyerDashboardState extends State<LawyerDashboard> {
  int _currentIndex = 0; // Dashboard is selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text('Lawyer Dashboard'),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A554)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildDashboardItem(
              context,
              Icons.person,
              'Profile',
              const Color(0xFFD0A554),
              () {
                Navigator.pushNamed(context, '/lawyer-profile');
              },
            ),
            _buildDashboardItem(
              context,
              Icons.calendar_today,
              'Bookings',
              const Color(0xFF6C8EBF),
              () {
                Navigator.pushNamed(context, '/lawyer-bookings');
              },
            ),
            _buildDashboardItem(
              context,
              Icons.access_time,
              'Availability',
              const Color(0xFF82B366),
              () {
                Navigator.pushNamed(context, '/lawyer-availability');
              },
            ),
            _buildDashboardItem(
              context,
              Icons.people,
              'Clients',
              const Color(0xFFD6B656),
              () {
                Navigator.pushNamed(context, '/clients-page');
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDashboardItem(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      color: const Color(0xFF3D4559),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        switch (index) {
          case 0:
            // Already on dashboard
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/lawyer-bookings');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/lawyer-availability');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/lawyer-profile');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF3D4559),
      selectedItemColor: const Color(0xFFD0A554),
      unselectedItemColor: Colors.grey[400],
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.access_time),
          label: 'Availability',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}