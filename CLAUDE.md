# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Tenmu** is a Flutter mobile application for managing UMKM (Small and Medium Enterprises) with geographic mapping capabilities. The app features role-based authentication (admin/user), dark/light theme support, and integrates with Supabase for backend services.

Key tech stack:
- **Flutter** (Dart): Mobile UI framework
- **Supabase**: Authentication and real-time database
- **Provider**: State management and theme management
- **Flutter Map**: Geographic location mapping
- **Geolocator**: GPS-based location services

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

### Development Tips
```bash
flutter clean               # Clean build artifacts
flutter create .            # Regenerate project files if needed
flutter devices             # List available devices/emulators
```

## Architecture & Code Structure

### Directory Organization
```
lib/
├── main.dart              # App entry point, Supabase initialization
├── core/                  # Shared utilities and theme management
│   ├── theme_provider.dart       # ChangeNotifier for dark/light theme
│   ├── app_colors.dart           # Dark theme color constants
│   ├── app_colors_light.dart     # Light theme color constants
│   ├── app_text_styles.dart      # Typography definitions
│   └── location_permission_helper.dart
├── screen/
│   ├── auth/              # Authentication screens
│   │   ├── auth_gate.dart        # StreamBuilder checking auth state
│   │   ├── role_checker.dart     # Routes to admin/user based on role
│   │   ├── login_screen.dart     # Login UI
│   │   └── register_screen.dart  # Registration UI
│   ├── user/              # User-facing screens
│   │   ├── home_screen.dart      # Main user feed (streams UMKM data)
│   │   ├── umkm_detail_screen.dart
│   │   ├── route_map_screen.dart # Map navigation for UMKM locations
│   │   └── review_section.dart
│   ├── admin/             # Admin management screens
│   │   ├── admin_home_screen.dart
│   │   ├── add_umkm_screen.dart
│   │   ├── edit_umkm_screen.dart
│   │   ├── manage_umkm_screen.dart
│   │   └── manage_users_screen.dart
│   └── splash/
│       └── animated_splash_screen.dart
```

### Key Architectural Patterns

**1. Authentication Flow**
- `AuthGate` listens to Supabase auth state via `onAuthStateChange` stream
- Unauthenticated users see `HomeScreen` as guests
- Authenticated users route through `RoleChecker` which queries the `profiles` table for their role
- Role-based UI: admin → `AdminHomeScreen`, user → `HomeScreen`

**2. Theme System**
- `ThemeProvider` (ChangeNotifier) manages dark/light mode state
- Colors are defined in separate `AppColors` and `AppColorsLight` files
- Theme preference is persisted to `SharedPreferences` with key `'isDarkMode'`
- Screens access theme via `Provider.of<ThemeProvider>(context)`
- All color references use provider getters (e.g., `theme.bgBase`, `theme.textPrimary`)

**3. Data Management**
- Supabase real-time streams used for UMKM list (e.g., in `HomeScreen`)
- Direct queries for role checking in `RoleChecker`
- No local state management layer; screens handle data directly via Supabase client

**4. Screen Structure**
- Most screens are `StatefulWidget` (or `StatelessWidget` for admin screens)
- Use `Provider.of<ThemeProvider>` to access theme colors
- Navigation via `Navigator.push()` and `MaterialPageRoute`
- No centralized routing system

### Supabase Integration

- **Initialization**: Done in `main()` with hardcoded URL and anon key (⚠️ see secrets warning below)
- **Tables**: `profiles` (stores user role), `umkm` (stores business data)
- **Real-time streams**: Used for auto-updating UMKM list in `HomeScreen`
- **Auth**: Managed via Supabase Flutter SDK, accessible at `Supabase.instance.client.auth`

## Important Notes

### ⚠️ Security Concern
The Supabase credentials are hardcoded in `main.dart`. For production:
- Move to environment variables or a secrets management system
- Use `.env` file with flutter_dotenv package
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

### Adding New Screens
1. Create file in appropriate `screen/` subdirectory
2. Import and use `Provider.of<ThemeProvider>(context)` for colors
3. For authenticated screens, ensure proper role checking in `RoleChecker`
4. Update navigation in related screens

### Dependencies Overview
- **supabase_flutter**: Backend + auth
- **provider**: State management (theme)
- **flutter_map + latlong2**: Map visualization
- **geolocator + flutter_compass**: Location services
- **image_picker**: Photo upload
- **shared_preferences**: Local persistent storage
- **http**: Network requests
- **flutter_lints**: Code quality rules
