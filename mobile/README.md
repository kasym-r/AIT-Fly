# Airline Booking System - Flutter Mobile App

This is the Flutter mobile application for the Airline Booking & Operations System.

## What is Flutter?

Flutter is Google's UI toolkit for building beautiful, natively compiled applications for mobile, web, and desktop from a single codebase. We're using it here to build a mobile app.

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models.dart            # Data models (matches API schemas)
│   ├── api_service.dart       # All API communication
│   └── screens/
│       ├── login_screen.dart
│       ├── register_screen.dart
│       ├── flight_search_screen.dart
│       ├── flight_details_screen.dart
│       ├── booking_screen.dart
│       ├── my_trips_screen.dart
│       └── announcements_screen.dart
├── pubspec.yaml               # Dependencies
└── README.md                  # This file
```

## Setup Instructions

> **⚠️ NEW TO FLUTTER?** If you've never installed Flutter before, see the complete setup guide: [FLUTTER_SETUP.md](../FLUTTER_SETUP.md)

### 1. Install Flutter

**Quick Install (macOS with Homebrew):**
```bash
brew install --cask flutter
```

**Or Manual Install:**
- Download from: https://docs.flutter.dev/get-started/install/macos
- Extract and add to PATH

**Verify installation:**
```bash
flutter doctor
```

**If you see errors**, follow the complete guide: [FLUTTER_SETUP.md](../FLUTTER_SETUP.md)

### 2. Install Dependencies

Navigate to the mobile directory:
```bash
cd mobile
```

Install Flutter packages:
```bash
flutter pub get
```

### 3. Configure API URL

Open `lib/api_service.dart` and update the `baseUrl`:

**For Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:8000';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://127.0.0.1:8000';
```

**For Physical Device:**
1. Find your computer's IP address:
   - macOS/Linux: `ifconfig` or `ip addr`
   - Windows: `ipconfig`
2. Use that IP address:
```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS:8000';
```

**Important:** Make sure your backend server is running and both devices are on the same network.

### 4. Run the App

**On Android:**
```bash
flutter run
```

**On iOS (macOS only):**
```bash
flutter run
```

**On a specific device:**
```bash
flutter devices  # List available devices
flutter run -d <device_id>
```

## How It Works

### Navigation Flow

1. **Login Screen** → User logs in or registers
2. **Flight Search Screen** → User searches for flights
3. **Flight Details Screen** → User selects a seat
4. **Booking Screen** → User completes payment
5. **My Trips Screen** → User views bookings and checks in
6. **Announcements Screen** → User views airline announcements

### Key Concepts

#### Models (`models.dart`)
- Dart classes that represent data from the API
- Each model has a `fromJson` method to convert API responses
- Some models have `toJson` methods to send data to the API

#### API Service (`api_service.dart`)
- Central place for all HTTP requests
- Handles authentication tokens automatically
- Converts errors to user-friendly messages
- Stores JWT token in shared preferences

#### Screens
- Each screen is a separate file
- Uses `StatefulWidget` for screens that need to update
- Uses `Navigator.push` to go to next screen
- Uses `Navigator.pop` to go back

### State Management

This app uses simple state management:
- `setState()` to update UI when data changes
- No complex state management libraries (like Provider, Bloc, etc.)
- Perfect for learning and simple apps

### API Communication Flow

1. User performs an action (e.g., searches for flights)
2. Screen calls `ApiService.searchFlights()`
3. API Service makes HTTP request to backend
4. Backend responds with JSON
5. API Service converts JSON to Dart models
6. Screen updates UI with new data

### Authentication Flow

1. User logs in → API returns JWT token
2. Token is saved in shared preferences
3. Every API request includes token in `Authorization` header
4. Backend validates token and identifies user
5. If token is invalid/expired → User must login again

## Features

### Passenger Features
- ✅ Register and login
- ✅ Search flights (origin, destination, date)
- ✅ View flight details
- ✅ Select seat from seat map
- ✅ Complete booking
- ✅ Mock payment (CARD, APPLE_PAY, GOOGLE_PAY)
- ✅ View bookings
- ✅ Check in for flights
- ✅ View boarding pass
- ✅ View announcements

### UI Features
- ✅ Loading indicators
- ✅ Error messages
- ✅ Empty states
- ✅ Pull to refresh
- ✅ Material Design UI

## Common Issues

### "Connection refused" or "Failed to connect"

**Problem:** App can't reach the backend server.

**Solutions:**
1. Make sure backend is running (`uvicorn main:app --reload`)
2. Check API URL in `api_service.dart`
3. For physical device: Use computer's IP address, not `127.0.0.1`
4. Check firewall settings
5. Make sure both devices are on the same network

### "Unauthorized" errors

**Problem:** Token is missing or expired.

**Solutions:**
1. Log out and log in again
2. Check if token is being saved correctly
3. Make sure backend is running

### Build errors

**Problem:** Dependencies not installed or version conflicts.

**Solutions:**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### App crashes on startup

**Problem:** Missing dependencies or configuration issues.

**Solutions:**
1. Run `flutter doctor` to check setup
2. Make sure all dependencies are installed
3. Check for syntax errors in code

## Testing the App

### Test Accounts

Use these accounts (created by seed script):
- **Passenger:** `passenger@example.com` / `password123`
- **Staff:** `staff@example.com` / `password123`

### Test Flow

1. Register a new account or login
2. Search for flights (leave filters empty to see all)
3. Tap on a flight to see details
4. Select a seat (green = available, red = booked)
5. Complete booking and payment
6. Go to "My Trips" to see your booking
7. Check in for your flight
8. View boarding pass

## Code Structure Explained

### Why Separate Files?

- **models.dart**: All data structures in one place
- **api_service.dart**: All API calls in one place (easy to update)
- **screens/**: Each screen in its own file (easy to find and edit)

### Why StatefulWidget?

- Allows screens to update when data changes
- `setState()` tells Flutter to rebuild the UI
- Perfect for loading states, error messages, etc.

### Why async/await?

- API calls take time (network requests)
- `async` functions can wait for results
- `await` pauses execution until result is ready
- Prevents UI from freezing

## Next Steps

1. Run the backend server
2. Update API URL in `api_service.dart`
3. Run the Flutter app
4. Test all features
5. Customize UI colors and styles
6. Add more features as needed

## Customization

### Change Colors

Edit `main.dart`:
```dart
theme: ThemeData(
  primarySwatch: Colors.blue,  // Change this
  // ...
)
```

### Change API URL

Edit `api_service.dart`:
```dart
static const String baseUrl = 'http://your-api-url:8000';
```

### Add New Features

1. Add new API method in `api_service.dart`
2. Add new model in `models.dart` if needed
3. Create new screen in `screens/`
4. Add navigation from existing screen

## Key Flutter Concepts Used

- **Widgets**: Everything in Flutter is a widget (buttons, text, screens)
- **State**: Data that can change (like loading status, error messages)
- **Navigation**: Moving between screens
- **HTTP Requests**: Communicating with backend API
- **JSON Parsing**: Converting API responses to Dart objects
- **Shared Preferences**: Storing data locally (like auth token)

## Beginner Tips

1. **Read error messages carefully** - They usually tell you what's wrong
2. **Use hot reload** - Press `r` in terminal to see changes instantly
3. **Check console** - Errors appear in the terminal
4. **Start simple** - Understand one screen before moving to the next
5. **Test frequently** - Run the app after each change

## Troubleshooting

### App won't build
```bash
flutter clean
flutter pub get
flutter run
```

### API not connecting
1. Check backend is running
2. Check API URL
3. Check network connection
4. Try restarting both backend and app

### Changes not showing
- Use hot reload (`r` in terminal)
- Or hot restart (`R` in terminal)
- Or stop and restart app

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [HTTP Package](https://pub.dev/packages/http)
- [Shared Preferences](https://pub.dev/packages/shared_preferences)

Happy coding! 🚀

