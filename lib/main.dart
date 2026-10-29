import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tenmu/core/theme_provider.dart';
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

// Membuat kerangka dasar aplikasi (MaterialApp)
class TenMuApp extends StatelessWidget {
  const TenMuApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF121212),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Color(0xFF121212),
        statusBarColor: Colors.transparent,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TenMu',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Nunito',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0C0C0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1ED760),
          surface: Color(0xFF141414),
        ),
      ),
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
