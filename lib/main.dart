import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tenmu/core/theme_provider.dart';
import 'package:tenmu/core/places_provider.dart';
import 'package:tenmu/core/notification_service.dart';
import 'package:tenmu/screen/auth/auth_gate.dart';
import 'package:tenmu/screen/splash/animated_splash_screen.dart';

// Fungsi main() adalah titik awal berjalannya aplikasi Flutter
Future<void> main() async {
  // Memastikan bahwa framework Flutter sudah siap sebelum menjalankan kode lain
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Init OneSignal (tanpa externalUserId dulu — SDK login menyusul setelah auth)
  NotificationService.init();

  // Menjalankan aplikasi
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PlacesProvider()),
      ],
      child: const TenMuApp(),
    ),
  );
}

// Membuat kerangka dasar aplikasi (MaterialApp)
class TenMuApp extends StatelessWidget {
  const TenMuApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF121212),
      statusBarColor: Colors.transparent,
    ));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TenMu',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AnimatedSplashScreen(nextScreen: AuthGate()),
    );
  }
}
