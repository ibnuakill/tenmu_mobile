import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'role_checker.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder akan terus memantau status login (AuthState) dari Supabase
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Saat aplikasi baru dibuka, tampilkan loading sebentar sambil mengecek sesi
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Ambil data sesi (session)
        final session = snapshot.hasData ? snapshot.data!.session : null;

        // Jika session tidak kosong (artinya user sudah login)
        if (session != null) {
          return const RoleChecker(); // Lempar ke penyeleksi role
        }

        // Jika session kosong (belum login atau sudah logout), tampilkan LoginScreen
        return const LoginScreen();
      },
    );
  }
}
