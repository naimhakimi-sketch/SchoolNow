# SchoolNow - Parent/Guardian Mobile Application

A comprehensive Flutter-based mobile application for parents and guardians to monitor and manage student transportation services in real-time.

![SchoolNow Parent Monitoring](..//README_assets/schoolnow_parents_monitor_page.jpg)
_Real-time monitoring interface for tracking student location during trips_

## Overview

SchoolNow Parent App is a cutting-edge solution designed to provide parents with complete visibility and control over their children's school transportation. The app leverages modern mobile technologies to deliver real-time location tracking, trip management, and seamless payment processing.

## Key Features

### Real-Time Monitoring

- **Live GPS Tracking**: Track your child's exact location during pickup and drop-off
- **Trip Map Display**: Interactive map showing route, current location, and estimated arrival time
- **Location Notifications**: Receive alerts when driver approaches pickup or arrives at destination

### Child & Trip Management

- **Multiple Children Support**: Manage transportation for multiple children under one account
- **Trip History**: Access complete history of all trips with timestamps and routes
- **Child Profiles**: Store important information about each child including emergency contacts
- **Preferred Routes**: Save and manage favorite pickup/drop-off locations

### Payment Integration

- **Secure Payment Processing**: Integrated payment gateway for transportation fees
- **Payment History**: Track all payments and invoices
- **Multiple Payment Methods**: Support for various payment options
- **Receipt Management**: Digital receipts for all transactions

### Security & Communication

- **Secure Authentication**: Firebase-based authentication with email/password login
- **Home Address Verification**: Confirm and manage home location
- **Driver Information**: View driver details, contact information, and ratings

## Technical Architecture

### Frontend Technology Stack

- **Framework**: Flutter 3.x with Dart
- **State Management**: Provider pattern for efficient state handling
- **UI Components**: Material Design 3 for modern, responsive UI
- **Maps Integration**: Flutter Map for interactive location display
- **Location Services**: Geolocator plugin for GPS functionality

### Backend & Infrastructure

- **Authentication**: Firebase Authentication (email-based)
- **Database**: Cloud Firestore for real-time data synchronization
- **Realtime Database**: Firebase Realtime Database for live location updates
- **Cloud Functions**: Automated trip management and notifications
- **Hosting**: Firebase Hosting for web deployment

### Data Flow

1. Parent authenticates and logs in
2. App fetches child profiles and assigned drivers from Firestore
3. Real-time location updates stream from driver's device
4. Map interface updates continuously with live position
5. Payment requests are processed securely

## Core Modules

### Authentication Module

- Email-based registration and login
- Account recovery functionality
- Session management

### Child Management

- Add/edit child profiles
- Assign drivers and routes
- Emergency contact management

### Real-Time Tracking

- Live map with polyline route visualization
- Location permission handling
- Background location streaming

### Payment Processing

- Integrated payment API
- Transaction history
- Invoice generation

## Platform Support

- **Mobile**: iOS and Android (native-like performance)
- **Web**: Web application via Firebase Hosting
- **Responsive Design**: Works seamlessly on all screen sizes

## Installation & Setup

### Requirements

- Flutter SDK (3.x or higher)
- Dart SDK
- Firebase project setup
- Android SDK / Xcode (for native builds)

### Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd school_now

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Configuration

1. Set up a Firebase project
2. Add iOS and Android apps to the project
3. Download and add configuration files
4. Configure Firestore security rules
5. Enable required Firebase services (Auth, Firestore, RTDB)

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── features/
│   ├── auth/                # Authentication screens
│   ├── home/                # Home and child list
│   ├── monitor/             # Real-time tracking
│   ├── payments/            # Payment processing
│   ├── children/            # Child management
│   └── location/            # Location selection
├── services/                # Business logic & APIs
├── models/                  # Data models
└── core/                    # Configuration and utilities
```

## Performance Optimizations

- Efficient Firestore queries with proper indexing
- Background location updates without draining battery
- Map optimization for smooth performance
- Image caching for faster loading

## Security Measures

- Encrypted authentication tokens
- Firestore security rules enforcement
- HTTPS for all API communications
- User permission management for location access

## Future Enhancements

- Offline mode with sync capability
- Advanced notifications and push alerts
- Parent-to-driver messaging
- Trip delay alerts and notifications
