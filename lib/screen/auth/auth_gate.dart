import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
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

  // Stream disimpan sebagai field agar tidak di-subscribe ulang setiap rebuild
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();

    _authStream = Supabase.instance.client.auth.onAuthStateChange;

    // Sync OneSignal login/logout with auth state changes (Android/iOS only)
    _authStream.listen((event) {
      final session = event.session;
      if (session != null &&
          session.user.emailConfirmedAt != null &&
          (Platform.isAndroid || Platform.isIOS)) {
        NotificationService.attachUser(session.user.id);
        NotificationService.registerPush();
      } else if (session == null && (Platform.isAndroid || Platform.isIOS)) {
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

    // Ambil session yang sudah tersimpan di local storage sebagai initialData
    // agar StreamBuilder tidak flash ke LoginScreen saat stream belum emit
    final currentSession = Supabase.instance.client.auth.currentSession;

    return StreamBuilder<AuthState>(
      stream: _authStream,
      // initialData mencegah flicker: pakai session aktif yang sudah ada
      initialData: currentSession != null
          ? AuthState(AuthChangeEvent.initialSession, currentSession)
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF9E9E9E)),
            ),
          );
        }

        // Gunakan session dari stream event, fallback ke currentSession
        final session = snapshot.hasData
            ? snapshot.data!.session
            : Supabase.instance.client.auth.currentSession;

        // Belum login & onboarding belum pernah → tampilkan onboarding
        if (session == null && _showOnboarding) {
          return OnboardingScreen(
            onCompleted: () {
              setState(() {
                _showOnboarding = false;
              });
            },
          );
        }

        // Wajib login — ga ada guest mode
        if (session == null) {
          return const LoginScreen();
        }

        final effectiveUser =
            session.user;

        // Email belum diverifikasi — skip untuk user OAuth (Google, dll.)
        final provider = effectiveUser.appMetadata['provider']?.toString();
        final providers = effectiveUser.appMetadata['providers'];
        final isOAuthUser = (provider != null && provider != 'email') ||
            (providers is List &&
                providers.isNotEmpty &&
                !providers.contains('email')) ||
            (effectiveUser.identities != null &&
                effectiveUser.identities!.any((id) => id.provider != 'email'));

        if (effectiveUser.emailConfirmedAt == null && !isOAuthUser) {
          return EmailVerificationScreen(email: effectiveUser.email);
        }

        // Udah login & terverifikasi → cek role
        return RoleChecker(
          key: ValueKey(effectiveUser.id),
        );
      },
    );
  }
}
