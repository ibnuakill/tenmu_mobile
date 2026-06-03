# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

**Tenmu** is a Flutter mobile application for managing UMKM (Small and Medium Enterprises) with geographic discovery, owner workflows, and admin supervision.

The app supports role-based access for:

- **Users**: browse UMKM, search, filter, view details, and explore routes.
- **Owners**: add and manage their own UMKM entries.
- **Superadmins/Admins**: manage users, UMKM, categories, role requests, and verify listings.

Core capabilities:

- Supabase authentication, data storage, and image handling
- Role-aware dashboard flows with `AuthGate` and `RoleChecker`
- Map-based browsing and navigation using `flutter_map`
- Real-time UMKM streaming and filtering
- Dark/light theming via `Provider`

Key tech stack:

- **Flutter** (Dart): Mobile UI framework
- **Supabase**: Authentication, database, storage, and real-time streams
- **Provider**: State and theme management
- **Flutter Map**: Geographic location mapping
- **Geolocator & Flutter Compass**: Location, heading, and navigation
- **Image Picker**: UMKM and profile image upload
- **Shared Preferences**: Local app settings
- **HTTP / URL Launcher / Intl**: network, deep links, and formatting

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
├── main.dart                          # App entry point, Supabase initialization, splash/auth root
├── core/                              # Shared utilities, state, theming, and helpers
│   ├── theme_provider.dart
│   ├── theme_toggle_button.dart
│   ├── app_colors.dart
│   ├── app_colors_light.dart
│   ├── app_text_styles.dart
│   ├── umkm_provider.dart
│   ├── umkm_category.dart
│   ├── umkm_image_helper.dart
│   ├── location_permission_helper.dart
│   └── user_role.dart
├── screen/
│   ├── splash/
│   │   └── animated_splash_screen.dart
│   ├── auth/
│   │   ├── auth_gate.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── role_checker.dart
│   ├── user/
│   │   ├── favorite_screen.dart
│   │   ├── home_screen.dart
│   │   ├── profile_settings_screen.dart
│   │   ├── review_section.dart
│   │   ├── route_map_screen.dart
│   │   ├── umkm_detail_screen.dart
│   │   └── widgets/
│   ├── admin/
│   │   ├── admin_home_screen.dart
│   │   ├── admin_analytics_screen.dart
│   │   ├── admin_profile_screen.dart
│   │   ├── add_umkm_screen.dart
│   │   ├── edit_umkm_screen.dart
│   │   ├── manage_umkm_screen.dart
│   │   ├── manage_kategori_screen.dart
│   │   ├── manage_role_requests_screen.dart
│   │   ├── manage_users_screen.dart
│   │   └── verify_umkm_screen.dart
│   └── owner/
│       └── owner_home_screen.dart
```

### Key Architectural Patterns

**1. Role-based navigation and authentication**

- `AuthGate` listens to Supabase auth state and routes users after login.
- `RoleChecker` determines whether the signed-in account gets user, owner, or admin/superadmin access.

**2. Shared state management**

- `ThemeProvider` manages app theming and dark/light mode toggling.
- `UMKMProvider` centralizes UMKM-related state and filters.

**3. Real-time data and filtering**

- UMKM listings are streamed from Supabase and filtered locally in the home screen.
- Filters include search query, category, price range, and distance.

**4. Map & navigation features**

- `route_map_screen.dart` supports browse mode and navigation mode.
- Map UI uses `flutter_map`, with location data from `geolocator` and `flutter_compass`.

**5. Admin / owner workflows**

- Admin screens support user, UMKM, and category management plus verification and analytics.
- Owner screens allow business owners to add and update their own UMKM entries.

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

- **Credentials**: Supabase URL and anon key are currently initialized in `main.dart`.
- **Tables**: supported tables include `profiles`, `umkm`, `kategori`, `reviews`, and role request data.
- **Access control**: admin/superadmin features are gated through role checks in the UI.

### Location Services

- Always call `LocationPermissionHelper.ensureAccess(context)` before accessing GPS or navigation features.

### Platform Assets

- App icon is managed under `assets/branding/app_icon.png`.
- Android and iOS platform folders are present and configured for app build.
