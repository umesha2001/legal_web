import 'package:cloud_firestore/cloud_firestore.dart';

class Userdb {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(Map<String, dynamic> userData) async {
    try {
      // Use set with a specific document name (e.g., userData['name'])
      await _firestore.collection('user').doc(userData['nic']).set(userData);
    } catch (e) {
      print("Error adding user: $e");
    }
  }

  Future<void> updateUser(String nic, Map<String, dynamic> updateData) async {
    try {
      await _firestore.collection('user').doc(nic).update(updateData);
    } catch (e) {
      print("Error updating user: $e");
    }
  }

  Future<Map<String, dynamic>?> getUser(String nic) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('user').doc(nic).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error getting user: $e");
      return null;
    }
  }

  Future<bool> userExists(String nic) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('user').doc(nic).get();
      return doc.exists;
    } catch (e) {
      print("Error checking if user exists: $e");
      return false;
    }
  }

  Future<void> deleteUser(String nic) async {
    try {
      await _firestore.collection('user').doc(nic).delete();
    } catch (e) {
      print("Error deleting user: $e");
    }
  }
}
