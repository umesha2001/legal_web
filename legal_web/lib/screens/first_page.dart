import 'package:flutter/material.dart';

class FirstPage extends StatelessWidget {
  const FirstPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55), // Background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo and Title
            Column(
              children: [
                Image.asset(
                  'assets/images/legal_web_1.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  'LEGAL WEB',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD0A554), // Gold color
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome to Legal Web App...',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFFD9D9D9), // Light gray
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            // Client Option
            SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9D9D9), // Light gray
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/user-home');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_outline, color: Color(0xFF353E55)),
                    const SizedBox(width: 10),
                    Text(
                      'For Client',
                      style: TextStyle(
                        fontSize: 18,
                        color: const Color(0xFF353E55), // Dark blue
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Lawyer Option
            SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0A554), // Gold
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/lawyer-dashboard');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gavel, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'For Lawyer',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}