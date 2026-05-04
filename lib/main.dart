import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tenmu/screen/auth/auth_gate.dart';

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
  runApp(const TenMuApp());
}

// Membuat kerangka dasar aplikasi (MaterialApp)
class TenMuApp extends StatelessWidget {
  const TenMuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TenMu Mobile',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Ubah bagian ini untuk mengarah ke LoginScreen
      home: const AuthGate(),
    );
  }
}
