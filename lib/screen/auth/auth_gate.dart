import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'role_checker.dart';
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

        // Sudah login → cek role (admin / user biasa)
        if (session != null) {
          return const RoleChecker();
        }

        // Belum login → langsung ke HomeScreen sebagai guest
        return const HomeScreen();
      },
    );
  }
}
