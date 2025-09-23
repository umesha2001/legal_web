import 'package:cloud_firestore/cloud_firestore.dart';

class Dbservice {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to add a new user
  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      // Use set with a specific document name (e.g., userData['name'])
      await _firestore.collection('lawyer').doc(userData['name']).set(userData);
    } catch (e) {
      print("Error adding user: $e");
    }
  }

  // Function to get all users
  // Function to get a user by specific ID
  // Function to get all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('lawyer').get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Error getting users: $e");
      return [];
    }
  }

  // Function to get a user by specific ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('lawyer').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting user: $e");
      return null;
    }
  }

  // Function to update a user
  Future<void> updateUser(
    String userId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update(updatedData);
    } catch (e) {
      print("Error updating user: $e");
    }
  }

  // Function to delete a user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      print("Error deleting user: $e");
    }
  }
}
