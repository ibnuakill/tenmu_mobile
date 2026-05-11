import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tenmu/core/theme_provider.dart';
import 'package:tenmu/core/umkm_provider.dart';
import 'package:tenmu/screen/auth/auth_gate.dart';
import 'package:tenmu/screen/splash/animated_splash_screen.dart';

// Fungsi main() adalah titik awal berjalannya aplikasi Flutter
Future<void> main() async {
  // Memastikan bahwa framework Flutter sudah siap sebelum menjalankan kode lain
  WidgetsFlutterBinding.ensureInitialized();

  // Menginisialisasi koneksi ke Supabase
  await Supabase.initialize(
    url: 'https://axtkquxgojewinwdndtt.supabase.co',
    anonKey: 'sb_publishable_ZREX99FnrmwrdqSn4x7Afw_qFLnjP9F',
  );

  // Menjalankan aplikasi
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UMKMProvider()),
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TenMu',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AnimatedSplashScreen(nextScreen: AuthGate()),
    );
  }
}
