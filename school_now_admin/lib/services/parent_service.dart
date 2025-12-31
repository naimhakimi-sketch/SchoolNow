import 'package:cloud_firestore/cloud_firestore.dart';

class ParentService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getParents() {
    return _db.collection('parents').snapshots();
  }

  Future<Map<String, dynamic>?> getParentDetails(String parentId) async {
    final doc = await _db.collection('parents').doc(parentId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getParentChildren(String parentId) async {
    final snapshot = await _db
        .collection('parents')
        .doc(parentId)
        .collection('children')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> updateParent(String id, Map<String, dynamic> patch) async {
    await _db.collection('parents').doc(id).update(patch);
  }

  Future<void> deleteParent(String id) async {
    // Delete children subcollection
    final children = await _db
        .collection('parents')
        .doc(id)
        .collection('children')
        .get();

    for (final doc in children.docs) {
      await doc.reference.delete();
    }

    // Delete parent document
    await _db.collection('parents').doc(id).delete();
  }

  Future<int> getParentPaymentCount(String parentId) async {
    final snapshot = await _db
        .collection('payments')
        .where('parent_id', isEqualTo: parentId)
        .get();

    return snapshot.docs.length;
  }
}
