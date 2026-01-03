import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to migrate existing student records to include trip_type field.
/// This ensures all students have explicit trip_type values, defaulting to 'both'.
class StudentMigrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Migrates all children in a parent's collection to add trip_type field if missing.
  /// This updates the parent's children subcollection.
  Future<int> migrateParentChildren(String parentId) async {
    try {
      final childrenRef = _db
          .collection('parents')
          .doc(parentId)
          .collection('children');

      final snapshot = await childrenRef.get();
      int updatedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final assignedDriver = (data['assigned_driver_id'] ?? '').toString();

        // Only update children that are already assigned to a driver
        if (assignedDriver.isNotEmpty) {
          final hasTripType =
              data.containsKey('trip_type') &&
              (data['trip_type'] ?? '').toString().isNotEmpty;

          if (!hasTripType) {
            await childrenRef.doc(doc.id).set({
              'trip_type': 'both', // Default to both for existing students
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            updatedCount++;
            debugPrint(
              'Migrated child $parentId/${doc.id} - set trip_type to both',
            );
          }
        }
      }

      return updatedCount;
    } catch (e, stackTrace) {
      debugPrint('Error migrating parent children: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Migrates all parents and their children to include trip_type field.
  /// This is a bulk operation that should be run sparingly.
  /// Returns a map of parentId -> number of children updated.
  Future<Map<String, int>> migrateAllParents() async {
    try {
      final parentsRef = _db.collection('parents');
      final parentsSnapshot = await parentsRef.get();
      final results = <String, int>{};

      for (final parentDoc in parentsSnapshot.docs) {
        final parentId = parentDoc.id;
        final count = await migrateParentChildren(parentId);
        if (count > 0) {
          results[parentId] = count;
        }
      }

      return results;
    } catch (e, stackTrace) {
      debugPrint('Error in bulk parent migration: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
