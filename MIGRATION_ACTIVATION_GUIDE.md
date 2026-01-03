# How to Activate Migration Service

## Quick Start

### 1. **Driver App** - Automatic Migration on App Load

Add this to the driver's main initialization (e.g., in the main driver page or profile page):

```dart
import 'package:school_now_driver/services/student_migration_service.dart';

@override
void initState() {
  super.initState();
  _runMigrationIfNeeded();
}

Future<void> _runMigrationIfNeeded() async {
  try {
    final migrationService = StudentMigrationService();
    final count = await migrationService.migrateDriverStudents(widget.driverId);
    if (count > 0) {
      debugPrint('Migrated $count students for driver ${widget.driverId}');
    }
  } catch (e) {
    debugPrint('Migration error: $e');
  }
}
```

### 2. **Parent App** - Automatic Migration on App Load

Add to the parent's home page or profile initialization:

```dart
import 'package:school_now/services/student_migration_service.dart';

@override
void initState() {
  super.initState();
  _runMigrationIfNeeded();
}

Future<void> _runMigrationIfNeeded() async {
  try {
    final migrationService = StudentMigrationService();
    final count = await migrationService.migrateParentChildren(widget.parentId);
    if (count > 0) {
      debugPrint('Migrated $count children for parent ${widget.parentId}');
    }
  } catch (e) {
    debugPrint('Migration error: $e');
  }
}
```

### 3. **Admin App** - Manual Admin Trigger

Add a button in the admin dashboard to trigger bulk migration:

```dart
import 'package:school_now_admin/services/student_migration_service.dart';

// Add this button to admin dashboard
ElevatedButton.icon(
  icon: const Icon(Icons.sync),
  label: const Text('Migrate Student Records'),
  onPressed: _performMigration,
),

Future<void> _performMigration() async {
  setState(() => _migrating = true);
  try {
    final migrationService = StudentMigrationService();

    final driverResults = await migrationService.migrateAllDrivers();
    final parentResults = await migrationService.migrateAllParents();

    final totalDrivers = driverResults.length;
    final totalParents = parentResults.length;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Migration complete: $totalDrivers drivers, $totalParents parents',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migration error: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _migrating = false);
  }
}
```

## Migration Service API Reference

### Driver App Methods

```dart
final service = StudentMigrationService();

// Migrate one driver's students
int migratedCount = await service.migrateDriverStudents(driverId);

// Migrate all drivers' students
Map<String, int> results = await service.migrateAllDrivers();
// Returns: {'driverId1': 5, 'driverId2': 3, ...}

// Migrate one parent's children
int migratedCount = await service.migrateParentChildren(parentId);

// Migrate all parents' children
Map<String, int> results = await service.migrateAllParents();
// Returns: {'parentId1': 2, 'parentId2': 1, ...}
```

### Parent App Methods

```dart
final service = StudentMigrationService();

// Migrate one parent's children
int migratedCount = await service.migrateParentChildren(parentId);

// Migrate all parents' children
Map<String, int> results = await service.migrateAllParents();
// Returns: {'parentId1': 2, 'parentId2': 1, ...}
```

### Admin App Methods

```dart
final service = StudentMigrationService();

// Migrate all drivers' students
Map<String, int> results = await service.migrateAllDrivers();

// Migrate all parents' children
Map<String, int> results = await service.migrateAllParents();

// Migrate both (recommended)
final driverResults = await service.migrateAllDrivers();
final parentResults = await service.migrateAllParents();
```

## What Gets Migrated

The migration service:

- ✅ **Finds**: Students/children already assigned to a driver (`assigned_driver_id` not empty)
- ✅ **Checks**: If they're missing the `trip_type` field
- ✅ **Updates**: Adds `trip_type: 'both'` to maintain current behavior
- ✅ **Skips**: Records that already have `trip_type` set
- ✅ **Logs**: Each migration for audit trail

## Data Updated

### In Parents Collection → Children Subcollection

```json
{
  "trip_type": "both",
  "updated_at": "serverTimestamp"
}
```

### In Drivers Collection → Students Subcollection

```json
{
  "trip_type": "both",
  "updated_at": "serverTimestamp"
}
```

## When to Run Migration

### Option 1: Automatic (Recommended)

- Runs on app startup for each user
- Non-blocking, happens in background
- Zero user action required
- **Best for**: Seamless rollout

### Option 2: Admin Triggered

- Run once via admin dashboard
- Migrates entire database
- Provides feedback on completion
- **Best for**: One-time bulk migration after release

### Option 3: Background Service

- Schedule via Cloud Functions
- Runs daily/weekly
- Ensures all records eventually migrate
- **Best for**: Large deployments

## Verification

After running migration, verify in Firestore:

1. Go to Firestore Console
2. Navigate to `drivers → {driverId} → students → {studentId}`
3. Confirm `trip_type` field exists with value `'both'`
4. Check a few records to ensure migration worked

Debug logs will show:

```
Migrated student {driverId}/{studentId} - set trip_type to both
```

## Safety

- ✅ **Idempotent**: Running multiple times is safe (skips if already migrated)
- ✅ **Non-destructive**: Only adds `trip_type`, doesn't remove other fields
- ✅ **Selective**: Only updates students with `assigned_driver_id`
- ✅ **Reversible**: Can be undone by manually deleting `trip_type` field
- ✅ **Backwards Compatible**: Works fine if migration never runs (always defaults to 'both')
