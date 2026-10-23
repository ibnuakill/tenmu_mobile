import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'role_checker.dart';
import 'onboarding_screen.dart';
import 'widgets/auth_common.dart';
import '../../core/notification_service.dart';
import '../../core/session_timeout_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;
  bool _successSheetShown = false;

  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();

    _authStream = Supabase.instance.client.auth.onAuthStateChange;

    _authStream.listen((event) {
      final session = event.session;
      if (session != null && !kIsWeb) {
        NotificationService.attachUser(session.user.id);
        NotificationService.registerPush();
      } else if (session == null && !kIsWeb) {
        NotificationService.detachUser();
      }

      // Pop-up "Login Berhasil" ditampilkan dari AuthGate — parent yang STABIL.
      // (Dulu ditampilkan dari layar Login yang langsung di-dispose saat session
      // berubah, sehingga muncul DOBEL / nyangkut dan user tak sampai ke Home.)
      if (event.event == AuthChangeEvent.signedIn && session != null) {
        // Tunda sebentar supaya layar Login/OTP/Register sempat menutup dulu.
        // (Kalau pop-up muncul lebih dulu, `Navigator.pop()` dari layar itu
        // akan menutup pop-up ini — bukan menutup layarnya.)
        Future.delayed(const Duration(milliseconds: 450), _showSuccessOnce);
      }
    });
  }

  void _showSuccessOnce() {
    if (!mounted || _successSheetShown) return;
    _successSheetShown = true;
    showAuthSuccessSheet(context, onContinue: () {}).whenComplete(() {
      _successSheetShown = false;
    });
  }

  Future<void> _checkOnboardingStatus() async {
    // Periksa apakah session sudah mati karena 3 hari tidak aktif
    await SessionTimeoutService.checkAndEnforceTimeout();

    final completed = await OnboardingScreen.isCompleted();
    if (!mounted) return;
    setState(() {
      _checkingOnboarding = false;
      _showOnboarding = !completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF9E9E9E)),
        ),
      );
    }

    final currentSession = Supabase.instance.client.auth.currentSession;

    return StreamBuilder<AuthState>(
      stream: _authStream,
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

        final session = snapshot.hasData
            ? snapshot.data!.session
            : Supabase.instance.client.auth.currentSession;

        if (session == null && _showOnboarding) {
          return OnboardingScreen(
            onCompleted: () {
              setState(() {
                _showOnboarding = false;
              });
            },
          );
        }

        if (session == null) {
          return const LoginScreen();
        }

        // Update timestamp aktivitas: setiap app dibuka dengan session aktif
        // maka waktu "terakhir aktif" di-reset ke sekarang.
        SessionTimeoutService.touchActivity();

        final effectiveUser = session.user;

        // Semua user yang berhasil login (Google/Magic Link) langsung ke RoleChecker
        return RoleChecker(
          key: ValueKey(effectiveUser.id),
        );
      },
    );
  }
}
