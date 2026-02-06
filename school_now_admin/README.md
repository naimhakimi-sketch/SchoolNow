# SchoolNow - Admin Panel

A powerful Flutter-based administrative dashboard for managing all aspects of the SchoolNow transportation platform. Built for desktop and mobile, enabling complete control over drivers, routes, vehicles, and transportation operations.

![SchoolNow Admin Dashboard](../README_assets/admin_dashboard.jpeg)
_Comprehensive admin dashboard for fleet and service management_

## Overview

The SchoolNow Admin Panel is an enterprise-grade management system that provides administrators with complete oversight and control of the entire transportation network. It enables efficient driver management, route planning, vehicle fleet management, and real-time monitoring of all transportation services.

## Key Features

### Driver Management

- **Driver Registration & Verification**: Add new drivers with ID verification and background checks
- **License Management**: Track driver licenses, expiry dates, and renewal reminders
- **Performance Monitoring**: View driver ratings, trip history, and performance metrics
- **Contact Directory**: Maintain driver contact information and emergency contacts
- **Account Status Control**: Activate/deactivate driver accounts as needed

### Fleet & Vehicle Management

- **Vehicle Registration**: Add and manage buses and transportation vehicles
- **Capacity Tracking**: Monitor vehicle capacity and current occupancy
- **Maintenance Scheduling**: Track vehicle maintenance records and schedule servicing
- **Vehicle Assignment**: Assign vehicles to drivers and routes
- **Fuel Management**: Monitor fuel consumption and efficiency

### Route & Service Planning

- **Interactive Service Area Mapping**: Define and visualize service areas on maps
- **Route Optimization**: Plan optimal pickup/drop-off sequences
- **School Management**: Add and manage school locations and addresses
- **Distance Calculation**: Automatic calculation of distances and estimated times
- **Student-to-Driver Assignment**: Intelligently assign students based on route proximity

### Real-Time Operations

- **Live Trip Monitoring**: Watch active trips with real-time location updates
- **Trip Dashboard**: Overview of all ongoing, completed, and scheduled trips
- **Alert System**: Receive notifications for delays, emergencies, or unusual activities
- **Occupancy Tracking**: Monitor student count and vehicle capacity in real-time

### Business Management

- **Payment Tracking**: Monitor all payments and outstanding invoices
- **User Management**: Manage parent, student, and staff accounts
- **Analytics & Reports**: Generate comprehensive business reports and insights
- **Billing System**: Automated billing and invoice generation
- **Commission Tracking**: Track driver earnings and commission payments

### System Administration

- **Data Migration Tools**: Migrate student data and update trip_type fields
- **Backup & Recovery**: Automated data backup and recovery mechanisms
- **Audit Logs**: Track all administrative actions for compliance
- **Role-Based Access**: Multiple admin permission levels

## Technical Architecture

### Frontend Technology Stack

- **Framework**: Flutter 3.x with Dart
- **Platform Support**: Windows, macOS, Linux, iOS, Android, Web
- **State Management**: Provider pattern for reactive updates
- **UI Design**: Material Design 3 for professional appearance
- **Maps Integration**: Flutter Map for geospatial visualization
- **Data Tables**: Complex data grids for fleet and driver management

### Backend & Infrastructure

- **Database**: Cloud Firestore (primary data store)
- **Real-time Updates**: Firebase Realtime Database for live data
- **Authentication**: Firebase Authentication with custom claims for role-based access
- **Cloud Functions**: Serverless functions for automated tasks
- **Storage**: Cloud Storage for driver documents and receipts
- **Hosting**: Firebase Hosting for web deployment

### Advanced Features

- **Geospatial Queries**: Find drivers and vehicles within service areas
- **Real-time Synchronization**: Live updates across all connected clients
- **Data Aggregation**: Automated analytics and report generation
- **Notification System**: Push notifications for critical events

## Core Modules

### Authentication & Authorization

- Admin login with email and password
- Role-based permission system
- Session management and timeout handling

### Driver Management System

- CRUD operations for driver profiles
- Document verification workflow
- Performance rating calculation
- Schedule and availability management

### Fleet Management System

- Vehicle inventory management
- Assignment and scheduling
- Maintenance tracking
- Capacity and occupancy monitoring

### Route Management System

- Service area definition and editing
- School location management
- Route optimization algorithm
- Student assignment logic

### Monitoring & Analytics

- Real-time dashboard with key metrics
- Trip analytics and reporting
- Revenue and payment tracking
- Performance dashboards

### Data Management

- Firestore data migration utilities
- Batch operations for bulk updates
- Data consistency checks
- Automated backups

## Platform Capabilities

### Desktop (Windows, macOS, Linux)

- Full-featured interface for comprehensive management
- Large displays for detailed data visualization
- Keyboard shortcuts for efficient workflow

### Mobile (iOS, Android)

- Touch-optimized interface
- On-the-go management capabilities
- Responsive design for various screen sizes

### Web

- Cloud-based access from any browser
- No installation required
- Real-time synchronization

## Installation & Setup

### Requirements

- Flutter SDK (3.x or higher)
- Dart SDK
- Firebase project with Firestore enabled
- Development tools for target platform

### Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd school_now_admin

# Install dependencies
flutter pub get

# Run on desired platform
flutter run -d windows    # Windows
flutter run -d macos      # macOS
flutter run -d linux      # Linux
flutter run -d chrome     # Web
```

### Firebase Configuration

1. Create Firebase project
2. Enable Firestore Database
3. Configure authentication providers
4. Set up Firestore security rules
5. Create service accounts for backend services

## Project Structure

```
lib/
├── main.dart              # Application entry point
├── firebase_options.dart  # Firebase configuration
├── screens/
│   ├── admin_login_screen.dart
│   ├── driver_form_screen.dart
│   ├── manage_drivers_screen.dart
│   ├── driver_details_page.dart
│   └── service_area_picker_screen.dart
├── services/
│   ├── admin_driver_service.dart
│   ├── bus_from_driver_service.dart
│   └── student_migration_service.dart
└── models/
    └── [Data models]
```

## Key Workflows

### Adding a New Driver

1. Navigate to "Manage Drivers"
2. Click "Add Driver" button
3. Fill in driver information (ID, name, contact)
4. Select bus/vehicle assignment
5. Define service area on map
6. Select schools in service area
7. System assigns students based on proximity

### Monitoring Active Trips

1. Access "Monitoring" dashboard
2. View all active trips on map
3. Click trip to see details
4. Receive automatic alerts for events
5. Monitor student check-ins and drop-offs

## Performance & Scalability

- Efficient Firestore indexing for fast queries
- Pagination for large datasets
- Image optimization and caching
- Background job processing

## Security Considerations

- Firebase security rules enforcing role-based access
- Admin authentication and session management
- Encrypted data transmission
- Audit logging of all admin actions
- Data privacy compliance features

## Future Enhancements

- Advanced AI-powered route optimization
- Predictive analytics for demand forecasting
- Automated driver scheduling
- Integration with external navigation APIs
- Advanced reporting and business intelligence
- Mobile app notifications system
