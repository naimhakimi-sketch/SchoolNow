# SchoolNow - Driver Mobile Application

A robust Flutter-based mobile application designed for school transportation drivers to efficiently manage routes, track students, and maintain reliable transportation services in real-time.

![SchoolNow Driver Interface](../README_assets/schoolnowdriver_servicesreen_withnavigation.jpg)
_Driver app interface showing service management and navigation_

## Overview

SchoolNow Driver App empowers drivers with all the tools needed for safe, efficient, and reliable student transportation. The app provides real-time navigation, student management, and communication capabilities to ensure smooth daily operations and parent peace of mind.

## Key Features

### Trip Management

- **Daily Trip Planning**: View all scheduled trips with pickup and drop-off times
- **Route Optimization**: Navigate efficiently between multiple stops
- **Trip Status Updates**: Update trip status and communicate with system in real-time
- **Completed Trip Tracking**: Record completion of each trip with timestamps
- **Trip History**: Access past trips for reference and record-keeping

### Student Management

- **Student Roster**: View assigned students for each trip
- **Check-In/Check-Out**: Confirm student boarding and arrival at destination
- **Attendance Tracking**: Automatic recording of student pickup and drop-off
- **Emergency Contacts**: Quick access to student emergency contact information
- **Student Profiles**: View important information about each student (allergies, special needs)

### Real-Time Navigation

- **Turn-by-Turn Directions**: Integrated maps for route guidance
- **Polyline Visualization**: See entire route with all stops marked
- **Alternative Routes**: Choose from optimized route suggestions
- **Traffic Updates**: Awareness of traffic conditions and delays
- **ETA Calculation**: Automatic estimation of arrival times

### Location Tracking & Safety

- **Continuous GPS Tracking**: Real-time location sharing with parents and system
- **Background Location Updates**: Accurate tracking even when app is minimized
- **Geofencing**: Alerts when arriving at pickup/drop-off zones
- **Route Recording**: Complete recording of journey for safety and accountability
- **Location Permissions**: Transparent permission management

### Communication & Notifications

- **Trip Notifications**: Automatic notification of daily assignments
- **Parent Updates**: Real-time status updates sent to parents
- **System Messages**: Important alerts and operational messages
- **Delayed Trip Notifications**: Automatic notification of delays to parents
- **In-App Messaging**: Communication from admin/system

### Account Management

- **Secure Login**: Email-based authentication
- **Profile Management**: Update driver information and contact details
- **Vehicle Assignment**: View assigned bus/vehicle details
- **Service Area Map**: View service area and assigned schools
- **Account Settings**: Manage preferences and notification settings

### Advanced Features

- **Demo Mode**: Test mode for training and demonstrations
- **Offline Capability**: Some features work without internet connection
- **Auto-Update**: Automatic APK updates via Firebase Hosting
- **Performance Monitoring**: Track metrics on delivery efficiency

## Technical Architecture

### Frontend Technology Stack

- **Framework**: Flutter 3.x with Dart
- **Platform**: iOS and Android (native compilation)
- **Maps**: Flutter Map with OpenStreetMap integration
- **Location**: Geolocator and location plugins
- **State Management**: Provider pattern for efficient updates
- **Local Storage**: SharedPreferences for caching
- **Background Services**: Background task processing

### Backend & Infrastructure

- **Authentication**: Firebase Authentication (email/password)
- **Database**: Cloud Firestore for trip and student data
- **Real-time Sync**: Firebase Realtime Database for live location updates
- **Cloud Functions**: Automated trip assignments and notifications
- **Hosting**: Firebase Hosting for APK updates and manifest
- **Update System**: Custom APK updater from Firebase Hosting

### Data Synchronization

1. Driver logs in with Firebase Auth
2. App downloads assigned trips from Firestore
3. Student rosters synced to local cache
4. Real-time location updates stream continuously
5. Check-ins/check-outs uploaded to Firestore
6. Parents receive live location updates

## Core Modules

### Authentication Module

- Email-based driver login
- Session management
- Account recovery flow
- Login state persistence

### Trip Management Module

- Fetch daily trip assignments
- Display trip details and routes
- Update trip status
- Record completion timestamps

### Student Management Module

- Display student roster per trip
- Student check-in interface
- Student check-out confirmation
- View student emergency information

### Location Service Module

- Continuous GPS tracking
- Background location streaming
- Permission handling
- Location accuracy optimization

### Navigation Module

- Integration with OpenStreetMap
- Route polyline rendering
- Stop markers display
- Turn-by-turn directions

### Update Module

- Check for APK updates
- Download updates from Firebase Hosting
- Install updates automatically
- Update notifications

## Platform Support

- **Android**: Full support with background location
- **iOS**: Full support with background location permissions
- **Versions**: Android 6.0+, iOS 11.0+

## Installation & Setup

### Requirements

- Flutter SDK (3.x or higher)
- Dart SDK (2.19+)
- Firebase project setup
- Android SDK / Xcode for builds

### Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd school_now_driver

# Install dependencies
flutter pub get

# Run development app
flutter run

# Build production APK
flutter build apk --release

# Build iOS app
flutter build ios
```

### Firebase Configuration

1. Set up Firebase project
2. Create Android and iOS apps
3. Download google-services.json and GoogleService-Info.plist
4. Configure Firestore rules
5. Set up Cloud Functions for trip assignment

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── core/
│   ├── firebase_options.dart
│   └── constants.dart
├── features/
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── school_map_picker_page.dart
│   ├── trips/                          # Trip management
│   ├── monitoring/                     # Real-time tracking
│   └── students/                       # Student management
├── services/
│   ├── demo_auth_service.dart
│   ├── driver_location_service.dart
│   ├── live_location_service.dart
│   ├── osrm_routing_service.dart
│   └── student_migration_service.dart
├── models/                             # Data models
└── widgets/                            # Reusable widgets
```

## Key Workflows

### Starting a Shift

1. Driver logs in with credentials
2. App downloads today's trip assignments
3. Trip list displayed with stop sequence
4. Map shows all stops and route
5. Location tracking begins automatically

### During a Trip

1. Driver navigates to first stop using map
2. Student boarding confirmed (check-in)
3. Navigation to next stop
4. Process repeats for all stops
5. Final stop completion ends trip

### Location Sharing

1. Background location service updates from GPS
2. Location streamed to Realtime Database
3. Parents see live position on their map
4. Automatic check-in/check-out updates

## Technical Considerations

### Battery Optimization

- Efficient background location updates
- Interval-based location uploads
- Power-aware sync strategy
- Battery status monitoring

### Network Resilience

- Offline caching of trips and students
- Automatic retry of failed uploads
- Queue-based location updating
- Graceful degradation

### Location Accuracy

- GPS accuracy verification
- Geofence-based confirmation
- Noise filtering
- Fallback positioning

## Security Features

- Firebase authentication enforcement
- Encrypted location transmission
- Secure check-in/check-out logging
- Audit trail for all actions
- Role-based data access

## Performance Optimizations

- Efficient Firestore queries with limits
- Local caching of student data
- Background task optimization
- Map rendering performance
- Image compression and caching

## Auto-Update System

The app includes automatic APK updates from Firebase Hosting:

1. App checks manifest.json for new versions
2. Downloads updated APK if available
3. Prompts user to install
4. Automatic installation on next launch
5. Zero downtime update experience

## Testing

### Demo Mode

- Simulated trip data without real drivers
- Test parent app without running driver app
- Training and demonstration purposes
- Sample location data generation

## Future Enhancements

- Vehicle telemetry integration (fuel, maintenance)
- Advanced routing optimization
- Voice-guided navigation
- Incident reporting system
- Driver performance analytics
- Offline trip completion
- Multi-language support
