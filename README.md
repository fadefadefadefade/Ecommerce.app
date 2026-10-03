# ALVY Mobile App (Flutter)

E-commerce mobile application built with Flutter for the ALVY platform.

## Features

- ✅ **Login Screen** - User authentication
- ✅ **Multi-role Dashboard** - Different dashboards for:
  - Buyers (Home screen with product browsing)
  - Sellers (Dashboard - Coming Soon)
  - Couriers (Dashboard - Coming Soon)
  - Admins (Dashboard - Coming Soon)
  - Sorting Center Staff (Dashboard - Coming Soon)

## Tech Stack

- **Flutter** - UI framework
- **Provider** - State management
- **HTTP/Dio** - API requests
- **Flutter Secure Storage** - Secure token storage
- **Google Fonts** - Typography

## Setup Instructions

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure API Backend
Update the API base URL in `lib/config/api_config.dart`:
```dart
static const String baseUrl = 'http://your-laravel-backend.test/api';
```

### 3. Run the App
```bash
# For Android
flutter run

# For iOS
flutter run

# For Web
flutter run -d chrome
```

## Project Structure

```
lib/
├── config/
│   └── api_config.dart          # API endpoint configuration
├── models/
│   └── user.dart                # User model
├── providers/
│   └── auth_provider.dart       # Authentication state management
├── screens/
│   ├── auth/
│   │   └── login_screen.dart    # Login screen
│   ├── buyer/
│   │   └── home_screen.dart     # Buyer home screen
│   ├── seller/
│   │   └── dashboard_screen.dart
│   ├── courier/
│   │   └── dashboard_screen.dart
│   ├── admin/
│   │   └── dashboard_screen.dart
│   └── sorting_center/
│       └── dashboard_screen.dart
├── services/
│   └── api_service.dart         # API service layer
└── main.dart                    # App entry point
```

## API Integration

The app expects the following API endpoints from your Laravel backend:

- `POST /api/login` - User login
- `POST /api/logout` - User logout
- `GET /api/home` - Buyer home data (categories, featured books, best sellers)

### Expected API Response Format

#### Login Response
```json
{
  "token": "bearer_token_here",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "role": "buyer",
    "approval_status": "approved",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

#### Home Data Response
```json
{
  "featured": [...],
  "bestSellers": [...],
  "categories": [...]
}
```

## Color Scheme

- Primary: `#fa4e1c` (Orange)
- Background: `#fbeee8` (Light Peach)
- Card Background: `#FDF8F5` (Off White)
- Text: `#222222` (Dark Gray)
- Secondary Text: `#8a7a70` (Brown Gray)

## Next Steps

1. Update the API base URL in `api_config.dart`
2. Implement the remaining dashboard screens
3. Add product detail page
4. Add cart functionality
5. Add checkout flow
6. Add order history
7. Add user profile management

## Running Tests

```bash
flutter test
```

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Notes

- Make sure your Laravel backend has CORS enabled for mobile app access
- Use HTTPS for production API endpoints
- Implement proper SSL certificate pinning for security
- Test on both iOS and Android devices

## License

Proprietary - ALVY Platform
