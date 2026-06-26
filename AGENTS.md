# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

**Tenmu** is a Flutter mobile application for discovering and managing Places of Interest (POI) such as cafes, culinary spots, tourism attractions, hotels, and UMKM. It supports geographic discovery, owner workflows, and admin supervision.

The app supports role-based access for:

- **Users**: browse POI, search, filter, view details, explore routes, and manage favorites.
- **Owners**: add and manage their own POI entries.
- **Superadmins/Admins**: manage users, POI, categories, role requests, and verify listings.

Core capabilities:

- Supabase authentication, data storage, and image handling
- Role-aware dashboard flows with `AuthGate` and `RoleChecker`
- Map-based browsing and navigation using `flutter_map`
- Real-time POI streaming and filtering
- Dark/light theming via `Provider`

Key tech stack:

- **Flutter** (Dart): Mobile UI framework
- **Supabase**: Authentication, database, storage, and real-time streams
- **Provider**: State and theme management
- **Flutter Map**: Geographic location mapping
- **Geolocator & Flutter Compass**: Location, heading, and navigation
- **Image Picker**: POI and profile image upload
- **Shared Preferences**: Local app settings
- **HTTP / URL Launcher / Intl / Flutter Dotenv**: network, deep links, formatting, and env config

## Common Development Commands

### Environment & Dependencies

```bash
flutter pub get              # install dependencies
flutter pub upgrade          # upgrade all dependencies
flutter pub outdated         # check for outdated packages
flutter analyze             # run dart analyzer for code quality
```

### Build & Run

```bash
flutter run                 # run app on connected device/emulator
flutter run -v              # run with verbose logging
flutter run --release       # run in release mode
flutter build apk           # build Android APK
flutter build ios           # build iOS app
```

### Testing & Code Quality

```bash
flutter test                          # run all tests
flutter test test/path/to/test.dart   # run specific test file
flutter test -v                       # run tests with verbose output
dart format lib/                      # format Dart code
dart fix lib/ --apply                 # apply automated fixes
```

## Architecture & Code Structure

### Directory Organization

```
lib/
├── main.dart                          # App entry point, Supabase initialization via dotenv
├── core/                              # Shared utilities, state, theming, and helpers
│   ├── theme_provider.dart
│   ├── theme_toggle_button.dart
│   ├── app_colors.dart
│   ├── app_colors_light.dart
│   ├── app_text_styles.dart
│   ├── places_provider.dart           # Centralized POI state and Supabase streaming
│   ├── poi_category.dart              # POI category constants (Cafe, Wisata, etc.)
│   ├── poi_facility.dart              # POI facility constants
│   ├── poi_image_helper.dart          # Image upload/management for POI
│   ├── umkm_category.dart             # Legacy UMKM category (being phased out)
│   ├── umkm_facility.dart             # Legacy UMKM facility
│   ├── umkm_image_helper.dart         # Legacy UMKM image helper
│   ├── umkm_provider.dart             # Legacy UMKM provider
│   ├── geocoding_service.dart         # Reverse geocoding for addresses
│   ├── haversine.dart                 # Distance calculation between coordinates
│   ├── location_permission_helper.dart
│   └── user_role.dart
├── screen/
│   ├── splash/
│   │   └── animated_splash_screen.dart
│   ├── auth/
│   │   ├── auth_gate.dart
│   │   ├── email_verification_screen.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── role_checker.dart
│   ├── user/
│   │   ├── about_screen.dart
│   │   ├── favorite_screen.dart
│   │   ├── home_screen.dart
│   │   ├── poi_detail_screen.dart
│   │   ├── profile_settings_screen.dart
│   │   ├── review_section.dart
│   │   ├── route_map_screen.dart
│   │   ├── settings_screen.dart
│   │   └── widgets/
│   │       ├── category_filter_widget.dart
│   │       ├── chat_bot.dart
│   │       └── sort_filter_widget.dart
│   ├── admin/
│   │   ├── admin_analytics_screen.dart
│   │   ├── admin_home_screen.dart
│   │   ├── admin_profile_screen.dart
│   │   ├── manage_kategori_screen.dart
│   │   ├── manage_role_requests_screen.dart
│   │   ├── manage_users_screen.dart
│   │   └── verify_place_screen.dart
│   └── owner/
│       ├── add_place_screen.dart
│       ├── edit_place_screen.dart
│       ├── manage_place_screen.dart
│       └── owner_home_screen.dart
```

### Key Architectural Patterns

**1. Role-based navigation and authentication**

- `AuthGate` listens to Supabase auth state and routes users after login.
- `RoleChecker` determines whether the signed-in account gets user, owner, or admin/superadmin access.
- `email_verification_screen.dart` handles email verification flow.

**2. Shared state management**

- `ThemeProvider` manages app theming and dark/light mode toggling.
- `PlacesProvider` centralizes POI-related state and filters, fetching from the `places` Supabase table.

**3. Real-time data and filtering**

- POI listings are streamed from Supabase and filtered locally in the home screen.
- Filters include search query, category, price range, and distance (powered by Haversine formula).

**4. Map & navigation features**

- `route_map_screen.dart` supports browse mode and navigation mode.
- Map UI uses `flutter_map`, with location data from `geolocator` and `flutter_compass`.
- `geocoding_service.dart` provides reverse geocoding for location-based features.

**5. Admin / owner workflows**

- Admin screens support user, POI, and category management plus verification and analytics.
- Owner screens allow business owners to add and update their own POI entries.

**6. Chat bot**

- A simple chat bot widget (`chat_bot.dart`) is available in the user section.

## Development Guidelines

### Image Handling (Critical for Supabase Free Tier)

To save storage space (1GB limit) and bandwidth:

- **Compression**: use `image_picker` with `maxWidth: 1024`, `maxHeight: 1024`, and `imageQuality: 80`.
- **Target size**: aim for 100KB–300KB per image.
- **Buckets**: use `umkm_images` for business photos and `profiles` for avatars.

### UI & Styling

- **Avoid hardcoded colors**: use theme values such as `theme.bgSurface`, `theme.textPrimary`, `theme.bgElevated`, and `theme.border`.
- **Consistent icons**: prefer `Icons.outlined` variants for modern UI.
- **Use themed snackbars**: maintain UX consistency with `ThemeProvider` styling.

### Supabase & Security

- **Credentials**: Supabase URL and anon key are loaded from `.env` file in `main.dart`.
- **Tables**: supported tables include `profiles`, `places`, `kategori`, `reviews`, and role request data.
- **Access control**: admin/superadmin features are gated through role checks in the UI.

### Location Services

- Always call `LocationPermissionHelper.ensureAccess(context)` before accessing GPS or navigation features.

### Platform Assets

- App icon is managed under `assets/branding/app_icon.png`.
- Android and iOS platform folders are present and configured for app build.
