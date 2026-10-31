import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tenmu/core/theme_provider.dart';
import 'package:tenmu/core/app_colors.dart';
import 'package:tenmu/core/app_colors_light.dart';
import 'package:tenmu/core/places_provider.dart';
import 'package:tenmu/core/notification_service.dart';
import 'package:tenmu/core/notification_center.dart';
import 'package:tenmu/core/app_update_provider.dart';
import 'package:tenmu/core/app_info.dart';
import 'package:tenmu/core/error_reporter.dart';
import 'package:tenmu/core/widgets/update_gate.dart';
import 'package:tenmu/screen/auth/auth_gate.dart';
import 'package:tenmu/screen/auth/forgot_password_screen.dart';
import 'package:tenmu/screen/splash/animated_splash_screen.dart';
import 'package:app_links/app_links.dart';

import 'platform/desktop.dart' if (dart.library.js_interop) 'platform/web.dart';

// Fungsi main() adalah titik awal berjalannya aplikasi Flutter
Future<void> main() async {
  // Memastikan bahwa framework Flutter sudah siap sebelum menjalankan kode lain
  WidgetsFlutterBinding.ensureInitialized();

  // Pasang penangkap error sedini mungkin — kalau inisialisasi di bawah gagal,
  // kegagalannya tetap tercatat dan tidak hilang begitu saja.
  ErrorReporter.install();

  await dotenv.load(fileName: '.env');

  // Versi aplikasi diambil dari build APK (bukan hardcode), supaya angka di
  // Pengaturan/Tentang selalu ikut versi yang benar-benar terpasang.
  await AppInfo.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  // Supabase siap → error boleh dikirim ke tabel app_errors.
  await ErrorReporter.markReady();

  // Init deep link handler untuk magic link & reset password
  _initDeepLinks();

  // Init OneSignal (tanpa externalUserId dulu — SDK login menyusul setelah auth)
  NotificationService.init();

  // Init window manager (untuk fullscreen di desktop)
  // Dibungkus try/catch: kegagalan init desktop TIDAK boleh menggagalkan app
  // (dulu bikin layar hitam karena exception sebelum runApp).
  try {
    await setupDesktop();
  } catch (e, s) {
    ErrorReporter.reportCaught(e, s, 'setupDesktop');
  }

  // Menjalankan aplikasi. Zona ini menangkap error async yang tidak tertangkap
  // try/catch di mana pun, supaya tidak jadi crash senyap.
  runZonedGuarded(
    () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => PlacesProvider()),
            ChangeNotifierProvider(create: (_) => AppUpdateProvider()),
            ChangeNotifierProvider(create: (_) => NotificationCenter()),
          ],
          child: const TenMuApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      ErrorReporter.reportCaught(error, stack, 'runZonedGuarded');
    },
  );
}

// Deep link handler — tangkap tenmu:// saat app sudah berjalan
void _initDeepLinks() {
  final appLinks = AppLinks();

  // Tangkap link saat app dibuka dari cold start via deep link
  appLinks
      .getInitialLink()
      .then((uri) {
        if (uri != null) _handleDeepLink(uri);
      })
      .catchError((Object e, StackTrace s) {
        ErrorReporter.reportCaught(e, s, 'deepLink.initial');
      });

  // Tangkap link saat app sudah di foreground/background
  appLinks.uriLinkStream.listen(
    (uri) => _handleDeepLink(uri),
    onError: (Object e, StackTrace s) {
      ErrorReporter.reportCaught(e, s, 'deepLink.stream');
    },
  );
}

Future<void> _handleDeepLink(Uri uri) async {
  final uriStr = uri.toString();
  // Supabase PKCE: exchange code yang ada di deep link menjadi session
  if (uriStr.contains('tenmu://login-callback') ||
      uriStr.contains('tenmu://reset-callback')) {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e, s) {
      ErrorReporter.reportCaught(e, s, 'deepLink.session');
    }
  }
}

/// Tema gelap TenMu (dipakai saat pengguna memilih mode gelap).
ThemeData _buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Nunito',
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: AppColors.bgBase,
    canvasColor: AppColors.bgBase,
    cardColor: AppColors.bgSurface,
    dividerColor: AppColors.divider,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.btnPrimary,
      onPrimary: AppColors.btnLabel,
      surface: AppColors.bgSurface,
      onSurface: AppColors.textPrimary,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgBase,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
  );
}

/// Tema terang TenMu (dipakai saat pengguna memilih mode terang).
ThemeData _buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    fontFamily: 'Nunito',
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: AppColorsLight.bgBase,
    canvasColor: AppColorsLight.bgBase,
    cardColor: AppColorsLight.bgSurface,
    dividerColor: AppColorsLight.divider,
    colorScheme: const ColorScheme.light(
      primary: AppColorsLight.btnPrimary,
      onPrimary: AppColorsLight.btnLabel,
      surface: AppColorsLight.bgSurface,
      onSurface: AppColorsLight.textPrimary,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColorsLight.textPrimary),
      bodySmall: TextStyle(color: AppColorsLight.textSecondary),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsLight.bgBase,
      foregroundColor: AppColorsLight.textPrimary,
      elevation: 0,
    ),
  );
}

// Membuat kerangka dasar aplikasi (MaterialApp).
// Root ini WAJIB mendengarkan ThemeProvider. Sebelumnya MaterialApp dibuat
// statis dengan brightness dark, sehingga tombol tema tidak pernah mengubah
// tampilan walaupun ThemeProvider sudah berganti nilai.
class TenMuApp extends StatelessWidget {
  const TenMuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: isDark
            ? AppColors.bgBase
            : AppColorsLight.bgBase,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: isDark
            ? AppColors.bgBase
            : AppColorsLight.bgBase,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TenMu',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const UpdateGate(
        child: AnimatedSplashScreen(nextScreen: AuthGate()),
      ),
      onGenerateRoute: (settings) {
        // Handle deep link reset password
        if (settings.name != null &&
            settings.name!.contains('reset-callback')) {
          return MaterialPageRoute(
            builder: (_) => const ForgotPasswordScreen(),
          );
        }
        return null;
      },
    );
  }
}
