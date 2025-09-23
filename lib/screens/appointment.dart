import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Appointment {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createBooking(
    String lawyer,
    String date,
    String time,
    String type,
    String amount,
    String userName,
  ) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final appointmentId =
          '${currentUser.uid.substring(0, 3)}_${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';

      final bookingData = {
        'appointment_id': appointmentId,
        'user_id': currentUser.uid,
        'user_name': userName,
        'lawyer': lawyer,
        'date': date,
        'time': time,
        'type': type,
        'amount': amount,
        'status': 'confirmed',
        'created_at': FieldValue.serverTimestamp(),
      };

      print("Creating booking with data: $bookingData"); // Debug log

      await _firestore
          .collection('appointment')
          .doc(appointmentId)
          .set(bookingData);

      print(
        "Booking created successfully with ID: $appointmentId",
      ); // Debug log
    } catch (e) {
      print("Error creating booking: $e");
      rethrow;
    }
  }

  // Extract index URL from error message
  String? extractIndexUrl(String errorMessage) {
    final RegExp urlRegex = RegExp(
      r'https://console\.firebase\.google\.com/[^\s]+',
    );
    final match = urlRegex.firstMatch(errorMessage);
    return match != null ? match.group(0) : null;
  }

  // Get upcoming appointments for the current user
  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    try {
      // Get the current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current date formatted as string (YYYY-MM-DD)
      final DateTime now = DateTime.now();
      final String today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      print("Fetching appointments from date: $today onwards");

      // Query Firestore for upcoming appointments
      final QuerySnapshot snapshot =
          await _firestore
              .collection('appointment')
              .where('user_id', isEqualTo: currentUser.uid)
              .where('date', isGreaterThanOrEqualTo: today)
              .orderBy('date', descending: false)
              .get();

      // Convert to List<Map<String, dynamic>>
      final appointments =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();

      print("Found ${appointments.length} upcoming appointments");
      return appointments;
    } catch (e) {
      print(
        "Error fetching upcoming appointments: $e",
      ); // Print full error for debugging
      print("FULL ERROR: ${e.toString()}");

      // Check for Firestore index error - broadening the condition to catch more cases
      if (e.toString().contains('Failed to get documents') ||
          e.toString().contains('index') ||
          e.toString().contains('missing index') ||
          e.toString().contains('FAILED_PRECONDITION')) {
        // Extract index creation URL if present
        final String? indexUrl = extractIndexUrl(e.toString());

        if (indexUrl != null && indexUrl.isNotEmpty) {
          print('INDEX CREATION URL: $indexUrl');
          throw Exception(
            'Firestore needs an index for this query.\n'
            'Please visit this URL to create it:\n$indexUrl',
          );
        } else {
          throw Exception(
            'Firestore needs an index for this query.\n'
            'Go to Firebase Console > Firestore > Indexes and create a composite '
            'index for collection "appointment" with fields:\n'
            '1. user_id (Ascending)\n'
            '2. date (Ascending)\n'
            'Then order by date (Ascending)',
          );
        }
      }

      rethrow;
    }
  }

  // Simplified version that doesn't require an index (use as fallback)
  Future<List<Map<String, dynamic>>> getUpcomingAppointmentsSimple() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current date formatted as string (YYYY-MM-DD)
      final DateTime now = DateTime.now();
      final String today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      print(
        "Fetching appointments with simple query for user: ${currentUser.uid}",
      );

      // Query Firestore - only filter by user_id to avoid index issue
      final QuerySnapshot snapshot =
          await _firestore
              .collection('appointment')
              .where('user_id', isEqualTo: currentUser.uid)
              .get();

      print("Raw query returned ${snapshot.docs.length} documents");

      // Convert to List and filter in memory
      final appointments =
          snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {'id': doc.id, ...data};
              })
              .where(
                (appointment) =>
                    (appointment['date'] as String? ?? '').compareTo(today) >=
                    0,
              )
              .toList();

      // Sort manually
      appointments.sort(
        (a, b) =>
            (a['date'] as String? ?? '').compareTo(b['date'] as String? ?? ''),
      );

      print(
        "Found ${appointments.length} upcoming appointments using simple query",
      );
      return appointments;
    } catch (e) {
      print("Error fetching appointments simple: $e");
      rethrow;
    }
  }

  // Check if the required index exists by testing the query
  Future<bool> hasRequiredIndex() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Get current date
      final DateTime now = DateTime.now();
      final String today =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Run a small limit query to test if index exists
      await _firestore
          .collection('appointment')
          .where('user_id', isEqualTo: currentUser.uid)
          .where('date', isGreaterThanOrEqualTo: today)
          .orderBy('date', descending: false)
          .limit(1) // Just need 1 to test
          .get();

      // If we get here, the index exists
      return true;
    } catch (e) {
      if (e.toString().contains('Failed to get documents') &&
          e.toString().contains('index')) {
        return false; // Index doesn't exist
      } // For other errors, assume index is not the issue
      return true;
    }
  }

  // Create sample appointments for testing purposes
  Future<void> createSampleAppointments() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      print("Creating sample appointments for user: ${currentUser.uid}");

      // Get current date
      final DateTime now = DateTime.now();

      // Create appointments for the next few days
      for (int i = 0; i < 3; i++) {
        final DateTime appointmentDate = now.add(Duration(days: i + 1));
        final String date =
            "${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}";

        await createBooking(
          "Sample Lawyer ${i + 1}",
          date,
          "${10 + i}:00 AM",
          i == 0
              ? "Consultation"
              : i == 1
              ? "Case Review"
              : "Document Filing",
          "${100 * (i + 1)}",
          currentUser.displayName ?? "Current User",
        );

        print("Created sample appointment for date: $date");
      }

      print("Sample appointments created successfully");
    } catch (e) {
      print("Error creating sample appointments: $e");
      rethrow;
    }
  }
}
