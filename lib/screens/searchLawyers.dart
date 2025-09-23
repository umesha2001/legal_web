import 'package:cloud_firestore/cloud_firestore.dart';

class Searchlawyers {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> searchUsersByName(String namePrefix) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('lawyer')
              .where('name', isGreaterThanOrEqualTo: namePrefix)
              .where('name', isLessThan: namePrefix + 'z')
              .get();

      // Only return the 'name' field from each document
      return querySnapshot.docs
          .map(
            (doc) =>
                (doc.data())['name'] as String? ?? '',
          )
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      print("Error searching users: $e");
      return [];
    }
  }
}
