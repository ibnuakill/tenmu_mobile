import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'role_checker.dart';
import 'email_verification_screen.dart';
import '../user/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF9E9E9E)),
            ),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        // Sudah login → cek email verification dan role
        if (session != null) {
          final user = Supabase.instance.client.auth.currentUser;
          
          // Email belum diverifikasi → tampilkan halaman verifikasi
          if (user != null && user.emailConfirmedAt == null) {
            return EmailVerificationScreen(email: user.email);
          }
          
          // Email sudah diverifikasi → cek role
          return const RoleChecker();
        }

        // Belum login → langsung ke HomeScreen sebagai guest
        return const HomeScreen();
      },
    );
  }
}
