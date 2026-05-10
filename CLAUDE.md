# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Tenmu** is a Flutter mobile application for managing UMKM (Small and Medium Enterprises) with geographic mapping capabilities. The app features role-based authentication (admin/user), dark/light theme support, and integrates with Supabase for backend services.

Key tech stack:
- **Flutter** (Dart): Mobile UI framework
- **Supabase**: Authentication, database, and storage
- **Provider**: State management and theme management
- **Flutter Map**: Geographic location mapping & navigation
- **Geolocator & Flutter Compass**: GPS-based location services and heading

## Common Development Commands

### Environment & Dependencies
```bash
flutter pub get              # Install dependencies
flutter pub upgrade          # Upgrade all dependencies
flutter pub outdated         # Check for outdated packages
flutter analyze             # Run dart analyzer for code quality
```

### Build & Run
```bash
flutter run                 # Run app on connected device/emulator
flutter run -v              # Run with verbose logging
flutter run --release       # Run in release mode
flutter build apk           # Build Android APK
flutter build ios           # Build iOS app
```

### Testing & Code Quality
```bash
flutter test                          # Run all tests
flutter test test/path/to/test.dart   # Run specific test file
flutter test -v                       # Run tests with verbose output
dart format lib/                      # Format Dart code
dart fix lib/ --apply                 # Apply automated fixes
```

## Architecture & Code Structure

### Directory Organization
```
lib/
├── main.dart              # App entry point, Supabase initialization
├── core/                  # Shared utilities and constants
│   ├── theme_provider.dart       # ChangeNotifier for dark/light theme
│   ├── app_colors.dart           # Dark theme color constants
│   ├── app_colors_light.dart     # Light theme color constants
│   ├── umkm_category.dart        # Category definitions and helper methods
│   └── location_permission_helper.dart
├── screen/
│   ├── auth/              # Authentication screens
│   │   ├── auth_gate.dart        # StreamBuilder checking auth state
│   │   ├── role_checker.dart     # Routes to admin/user based on role
│   ├── user/              # User-facing screens
│   │   ├── widgets/              # Reusable UI components
│   │   │   ├── category_filter_widget.dart
│   │   │   └── price_range_filter_widget.dart
│   │   ├── home_screen.dart      # Main feed (Filter logic + Supabase Stream)
│   │   ├── umkm_detail_screen.dart
│   │   └── route_map_screen.dart # Interactive Map (Browse & Navigate mode)
│   ├── admin/             # Admin management screens
│   │   ├── add_umkm_screen.dart  # Form handles Location, Category, Price, Image
│   │   ├── edit_umkm_screen.dart # Auto-fill existing UMKM data
│   │   └── manage_umkm_screen.dart
```

### Key Architectural Patterns

**1. Data Filtering & Streams (HomeScreen)**
- UMKM list is streamed real-time from Supabase (`_umkmStream`).
- The stream data is loaded entirely, then filtered locally based on:
  - Search Query (Title & Address)
  - Category Selection (Multi-select via `CategoryFilterWidget`)
  - Price Range (Range slider via `PriceRangeFilterWidget`)
- The Filter UI is rendered compactly inside a `showModalBottomSheet`.

**2. Interactive Map (RouteMapScreen)**
- Acts in two main modes:
  - **Browse Mode**: Receives `umkmList`, displays all locations as red markers. Tapping a marker brings up an Info Overlay.
  - **Navigation Mode**: Triggered via "Mulai Rute". Connects to OSRM API for Polylines, turns on Compass (for map marker rotation), and tracks live GPS via Geolocator.

**3. Authentication Flow**
- `AuthGate` listens to Supabase auth state via `onAuthStateChange`.
- Unauthenticated users see `HomeScreen` as guests.
- Authenticated users route through `RoleChecker` which queries the `profiles` table for their role (admin vs user).

**4. Theme System**
- `ThemeProvider` (ChangeNotifier) manages dark/light mode state.
- Colors are defined in separate `AppColors` and `AppColorsLight` files.
- Screens access theme via `Provider.of<ThemeProvider>(context)`.

### Supabase Integration

- **Tables**: `profiles` (user role), `umkm` (business data), `reviews` (user feedback).
- **Storage**: `umkm_images` bucket for uploading venue photos.
- **Data Model Notes (`umkm` table)**:
  - Uses `latitude` and `longitude` for maps.
  - `category` (Text), `min_price` (Int), `max_price` (Int) used for filtering.

## Important Notes

### ⚠️ Security Concern
The Supabase credentials are hardcoded in `main.dart`. For production:
- Move to environment variables or a secrets management system
- Use `.env` file with `flutter_dotenv` package
- Never commit credentials to version control

### Theme Colors
When adding UI elements, always pull colors from the `ThemeProvider` instance:
```dart
final theme = Provider.of<ThemeProvider>(context);
Container(
  color: theme.bgSurface,
  child: Text('Hello', style: TextStyle(color: theme.textPrimary)),
);
```

### Map / Location Permissions
Always use `LocationPermissionHelper.ensureAccess(context)` before calling Geolocator/Map services to gracefully handle permissions and inform the user.

### Dependencies Overview
- **supabase_flutter**: Backend + auth + storage
- **provider**: State management (theme)
- **flutter_map + latlong2**: Map visualization
- **geolocator + flutter_compass**: Location services & orientation
- **image_picker**: Photo upload
- **intl**: Price / Currency formatting
- **shared_preferences**: Local persistent storage (theme prefs)
- **http**: Network requests (OSRM / Nominatim Maps API)
