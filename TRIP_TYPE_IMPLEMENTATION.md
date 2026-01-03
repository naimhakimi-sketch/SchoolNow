# Trip Type Selection Feature Implementation

## Overview

Implemented a trip type selection feature allowing parents to choose whether to request:

- **Going Only**: Morning pickup to school
- **Return Only**: School to home afternoon dropoff
- **Both**: Both going and return trips (default for existing records)

## Changes Made

### 1. Parent App (school_now)

#### Payment Page (`lib/features/payments/payment_page.dart`)

- **Added**: Trip type selection UI with 3 radio button options
- **Modified**: `PaymentResult` class to include `tripType` field (defaults to 'both')
- **Updated**: `_PaymentPageState` to include `_tripType` state variable
- **Modified**: Payment metadata now includes `trip_type` field

#### Drivers Page (`lib/features/drivers/drivers_page.dart`)

- **Modified**: `_requestDriver()` method to capture and pass `tripType` from payment result
- **Modified**: `_renewService()` method to include `trip_type` in service request payload
- **Both methods now pass `trip_type` to `createServiceRequest()`**

#### Monitor Page (`lib/features/monitor/monitor_page.dart`)

- **Major Update**: `_buildRoutePolylineStops()` method enhanced with trip type filtering
- **Implementation**:
  - Filters students based on route type (morning = going, afternoon = return)
  - Students with `trip_type: 'both'` included in all routes
  - Students with `trip_type: 'going'` only in morning routes
  - Students with `trip_type: 'return'` only in afternoon routes
- **Applied to**: Both morning and afternoon route building logic
- Creates separate `filteredStudentById` and `filteredPassengers` maps for accurate route calculation

### 2. Driver App (school_now_driver)

#### Student Management Service (`lib/services/student_management_service.dart`)

- **Modified**: `approveRequest()` method
  - Saves `trip_type` to parent's child document (defaults to 'both' if not specified)
  - Saves `trip_type` to driver's students collection (defaults to 'both' if not specified)

#### Drive Page (`lib/features/drive/drive_page.dart`)

- **Major Update**: `_startTrip()` method enhanced with trip type filtering
- **Implementation**:
  - Filters approved students based on selected route type
  - Morning route (going): includes students with `trip_type: 'going'` or 'both'
  - Afternoon routes (return): includes students with `trip_type: 'return'` or 'both'
  - Filtering happens BEFORE school type filtering to ensure accurate trip composition
- **Impact**: Trip creation now includes only relevant students for that specific route

#### Students Page (`lib/features/students/students_page.dart`)

- **Display Enhancement**: Added trip type labels to both pending requests and approved students
- **Added**: `_getTripTypeLabel()` helper method to convert trip type codes to user-friendly labels
- Shows trip type as: "Going Only", "Return Only", or "Both Ways"

### 3. Admin App (school_now_admin)

#### Service Request Service (`lib/services/service_request_service.dart`)

- **Modified**: `updateRequestStatus()` method
  - When approving requests, saves `trip_type` to child document (defaults to 'both')
  - When syncing to driver's students collection, includes `trip_type` (defaults to 'both')
  - Ensures all existing requests without trip_type default to 'both'

#### Manage Service Requests Screen (`lib/screens/manage_service_requests_screen.dart`)

- **Display Enhancement**: Shows trip type in request details
- **Added**: Trip type field in request detail rows
- **Added**: `_tripTypeLabel()` helper method for user-friendly trip type display
- Labels displayed as: "Going Only (Morning)", "Return Only (Afternoon)", "Both (Going & Return)"

## Data Model Changes

### Firestore Structure Updates

#### Parents Collection - Children Subcollection

New field added:

```
trip_type: string ('going', 'return', or 'both')
```

#### Drivers Collection - Students Subcollection

New field added:

```
trip_type: string ('going', 'return', or 'both')
```

#### Service Requests

New field stored (from payment metadata):

```
trip_type: string ('going', 'return', or 'both')
```

#### Payments Collection

Updated metadata to include:

```
metadata.trip_type: string ('going', 'return', or 'both')
```

## Default Behavior

For **existing users and records without trip_type field**:

- System automatically defaults to **'both'** (going and return trips) when reading the field
- This ensures backward compatibility and no service disruption
- Default is applied at:
  1. Request approval (admin/driver side)
  2. Request creation (when trip_type not specified in payment)
  3. Route building (when trip_type not found in student record)

### Migration for Existing Students

**Problem**: Existing students already connected to drivers won't have the `trip_type` field in Firestore.

**Solution**: Three new `StudentMigrationService` classes handle this:

- **Parent App**: `school_now/lib/services/student_migration_service.dart`
- **Driver App**: `school_now_driver/lib/services/student_migration_service.dart`
- **Admin App**: `school_now_admin/lib/services/student_migration_service.dart`

**Key Features**:

- ✅ Selective: Only migrates students assigned to a driver
- ✅ Idempotent: Only adds `trip_type` if missing
- ✅ Logged: Prints debug info for audit trail
- ✅ Defaults to 'both': Maintains current behavior for all existing students
- ✅ Backward Compatible: Works with or without migration

**Usage Examples**:

Driver App migration:

```dart
final migrationService = StudentMigrationService();
// Migrate one driver's students
await migrationService.migrateDriverStudents(driverId);
// Migrate all drivers
final results = await migrationService.migrateAllDrivers();
```

Parent App migration:

```dart
final migrationService = StudentMigrationService();
// Migrate one parent's children
await migrationService.migrateParentChildren(parentId);
// Migrate all parents
final results = await migrationService.migrateAllParents();
```

## Route Building Logic

### Morning Route (Going)

- Includes students where `trip_type IN ('going', 'both')`
- Route: Driver → Student pickups → School(s)
- Afternoon-only students are excluded

### Afternoon Routes (Return)

- Includes students where `trip_type IN ('return', 'both')`
- Route: School(s) → Student dropoffs → Driver home
- Morning-only students are excluded

### Trip Filtering Precedence

1. Student approval status (already approved)
2. School type filtering (if applicable)
3. Trip type filtering (new)
4. Attendance overrides (existing)

## Testing Recommendations

1. **New Request Flow**:

   - Test trip type selection during payment
   - Verify different trip types are correctly stored in Firestore

2. **Trip Creation**:

   - Start morning trip, verify only 'going' and 'both' students are included
   - Start afternoon trip, verify only 'return' and 'both' students are included

3. **Route Building**:

   - Monitor page should show routes with filtered students
   - Verify driver sees correct students for each trip type

4. **Backward Compatibility**:

   - Request approval of old requests without trip_type should default to 'both'
   - Existing student records should work with default 'both' value

5. **UI Display**:
   - Payment page shows trip type selection clearly
   - Request details in admin and driver apps display trip type
   - Student list shows trip type for each student

## Files Modified

1. `school_now/lib/features/payments/payment_page.dart`
2. `school_now/lib/features/drivers/drivers_page.dart`
3. `school_now/lib/features/monitor/monitor_page.dart`
4. `school_now/lib/services/student_migration_service.dart` (NEW)
5. `school_now_driver/lib/services/student_management_service.dart`
6. `school_now_driver/lib/features/drive/drive_page.dart`
7. `school_now_driver/lib/features/students/students_page.dart`
8. `school_now_driver/lib/services/student_migration_service.dart` (NEW)
9. `school_now_admin/lib/services/service_request_service.dart`
10. `school_now_admin/lib/screens/manage_service_requests_screen.dart`
11. `school_now_admin/lib/services/student_migration_service.dart` (NEW)

## Future Enhancements

1. Allow parents to modify trip type after initial request
2. Track usage analytics by trip type
3. Implement pricing variations based on trip type
4. Add trip type to payment receipts and invoices
5. Monthly renewal with trip type modification option
