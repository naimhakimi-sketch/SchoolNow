# Database Field Consistency Audit

## Issues Found

### 1. LOCATION FIELDS - INCONSISTENT NAMING

**Problem**: Different collections use different field names for geographic locations

| Collection        | Field Name             | Structure                             | Issue                                                 |
| ----------------- | ---------------------- | ------------------------------------- | ----------------------------------------------------- |
| schools           | `geo_location`         | `{latitude, longitude}`               | ✅ CORRECT (just fixed)                               |
| drivers           | `service_area`         | `{center_lat, center_lng, radius_km}` | ✅ Using service_area correctly                       |
| service_requests  | `pickup_location`      | `{lat, lng}`                          | ❌ Uses `lat`/`lng` instead of `latitude`/`longitude` |
| operator_settings | `latitude`/`longitude` | Separate fields                       | ✅ Individual fields OK                               |

**Action Required**:

- Service requests should use consistent coordinate naming
- Should be `pickup_location: {latitude, longitude}` to match school geo_location

---

### 2. PHONE/CONTACT FIELDS - INCONSISTENT NAMING

**Problem**: Different field names for phone numbers across collections

| Collection                         | Field Name       | Issue               |
| ---------------------------------- | ---------------- | ------------------- |
| drivers                            | `contact_number` | ✅ Consistent       |
| parents                            | `contact_number` | ✅ Consistent       |
| operator_settings                  | `contact_phone`  | ❌ Different naming |
| service_requests (student records) | `parent_phone`   | ❌ Different naming |
| trips                              | None             | -                   |

**Action Required**:

- Standardize to `contact_number` across all collections
- Update `operator_settings` from `contact_phone` to `contact_number`
- Update `service_requests` child records from `parent_phone` to `contact_number`

---

### 3. VEHICLE CAPACITY FIELDS - INCONSISTENT NAMING

**Problem**: Bus capacity stored with different field names

| Source                      | Field Name      | Issue               |
| --------------------------- | --------------- | ------------------- |
| Buses (Firestore)           | `capacity`      | ✅ Correct in admin |
| Driver profile (Driver app) | `seat_capacity` | ❌ Different naming |

**Action Required**:

- Keep `capacity` in Firestore buses collection
- Update driver app references from `seat_capacity` to read from bus `capacity`
- Remove `seat_capacity` from driver profile if it's redundant

---

### 4. ID FIELDS - MOSTLY CONSISTENT

**Status**: ✅ Generally good

| Field                  | Usage                             | Status        |
| ---------------------- | --------------------------------- | ------------- |
| `assigned_bus_id`      | driver → bus                      | ✅ Consistent |
| `assigned_driver_id`   | bus → driver, student → driver    | ✅ Consistent |
| `assigned_school_ids`  | driver → schools (array)          | ✅ Consistent |
| `driver_id`            | trips, payments, service_requests | ✅ Consistent |
| `school_id`            | students, service_requests        | ✅ Consistent |
| `ic_number`            | drivers, parents, students        | ✅ Consistent |
| `ic_number_normalized` | drivers, parents                  | ✅ Consistent |
| `license_number`       | drivers                           | ✅ Consistent |

---

## Summary of Changes Needed

### Critical (Data Quality) - ALL FIXED ✅

1. ✅ **schools**: `pin_location` → `geo_location`
2. ✅ **service_requests**: `pickup_location.lat/lng` → `pickup_location.latitude/longitude`
3. ✅ **operator_settings**: `contact_phone` → `contact_number`
4. ✅ **service_requests child docs**: `parent_phone` → `contact_number`
5. ✅ **Driver app**: Updated field references for consistency

### Medium (Consistency)

- ✅ Audit all three apps (admin, parent, driver) for field references
- ✅ Update data models to match Firebase field names

### Files Updated

1. ✅ **school_service.dart**: Changed to save `geo_location` with latitude/longitude
2. ✅ **operator_service.dart**: Changed parameter from `contactPhone` to `contactNumber`
3. ✅ **operator_settings_screen.dart**: Updated controller and field names
4. ✅ **auth_service.dart** (school_now): Changed pickup_location coordinates from lat/lng to latitude/longitude
5. ✅ **manage_service_requests_screen.dart**: Updated display to use latitude/longitude and contact_number
6. ✅ **demo_auth_service.dart** (school_now_driver): Updated test data to use contact_number and latitude/longitude
7. ✅ **student_management_service.dart**: Updated to store contact_number instead of parent_phone
