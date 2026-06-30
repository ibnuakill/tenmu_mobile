import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'role_checker.dart';
import 'email_verification_screen.dart';
import 'onboarding_screen.dart';
import '../../core/notification_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();

    // Sync OneSignal login/logout with auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      if (session != null && session.user.emailConfirmedAt != null) {
        NotificationService.attachUser(session.user.id);
      } else if (session == null) {
        NotificationService.detachUser();
      }
    });
  }

  Future<void> _checkOnboardingStatus() async {
    final completed = await OnboardingScreen.isCompleted();
    if (!mounted) return;
    setState(() {
      _checkingOnboarding = false;
      _showOnboarding = !completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Still checking SharedPreferences ────────────────────────────
    if (_checkingOnboarding) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9E9E9E)),
        ),
      );
    }

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

        // Belum login & onboarding belum pernah → tampilkan onboarding
        if (session == null && _showOnboarding) {
          return const OnboardingScreen();
        }

        // Wajib login — ga ada guest mode
        if (session == null) {
          return const LoginScreen();
        }

        final user = Supabase.instance.client.auth.currentUser;

        // Email belum diverifikasi
        if (user != null && user.emailConfirmedAt == null) {
          return EmailVerificationScreen(email: user.email);
        }

        // Udah login & terverifikasi → cek role
        return const RoleChecker();
      },
    );
  }
}
