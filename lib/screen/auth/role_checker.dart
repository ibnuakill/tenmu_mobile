import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/user_role.dart';
import '../admin/dashboard/admin_home_screen.dart';
import '../user/home/home_screen.dart';

// State jelas: success, banned, error
enum _CheckResult { banned }

class RoleChecker extends StatefulWidget {
  const RoleChecker({super.key});

  @override
  State<RoleChecker> createState() => _RoleCheckerState();
}

class _RoleCheckerState extends State<RoleChecker> {
  late Future<dynamic> _userCheck; // dynamic = UserRole atau _CheckResult

  @override
  void initState() {
    super.initState();
    _userCheck = _fetchUserRole();
  }

  Future<dynamic> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }

    final response = await Supabase.instance.client
        .from('profiles')
        .select('role, status')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      final metadata = user.userMetadata ?? {};
      final fullName = metadata['full_name']?.toString() ??
          metadata['name']?.toString() ??
          'User';
      final avatarUrl = metadata['avatar_url']?.toString() ??
          metadata['picture']?.toString();

      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'nama': fullName,
        'avatar_url': avatarUrl,
        'role': 'user',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      });

      return parseUserRole('user');
    }

    final role = response['role']?.toString() ?? 'user';
    final status = response['status']?.toString() ?? 'active';

    // Cek banned
    if (status == 'banned') {
      return _CheckResult.banned;
    }

    // Auto-apply owner role
    if (role == 'user' && user.userMetadata?['pending_role'] == 'owner') {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': 'owner'})
          .eq('id', user.id);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'pending_role': null}),
      );

      return parseUserRole('owner');
    }

    return parseUserRole(role);
  }

  void _reloadRole() {
    setState(() {
      _userCheck = _fetchUserRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _userCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Banned — render BannedScreen
        if (snapshot.hasData && snapshot.data == _CheckResult.banned) {
          return const _BannedScreen();
        }

        // Error
        if (snapshot.hasError || !snapshot.hasData) {
          final message = snapshot.error?.toString().replaceFirst(
            'Exception: ',
            '',
          );
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat role akun.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message ?? 'Terjadi kesalahan tidak diketahui.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reloadRole,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final role = snapshot.data as UserRole;
        switch (role) {
          case UserRole.superadmin:
            return const AdminHomeScreen();
          case UserRole.owner:
          case UserRole.user:
            return const HomeScreen();
        }
      },
    );
  }
}

// ── Banned Screen ────────────────────────────────────────────────
class _BannedScreen extends StatelessWidget {
  const _BannedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gpp_bad_rounded, size: 40, color: Color(0xFF8B2020)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Akun Dinonaktifkan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Akun Anda telah dinonaktifkan oleh admin. '
                'Jika Anda merasa ini adalah kesalahan, silakan hubungi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () async {
                    final uri = Uri(
                      scheme: 'mailto',
                      path: 'sarkamganas406@gmail.com',
                      queryParameters: {
                        'subject': 'Banding - Akun Dinonaktifkan',
                        'body': 'Halo admin, saya ingin mengajukan banding atas penonaktifan akun saya.\n\nID Akun: ${Supabase.instance.client.auth.currentUser?.id ?? '-'}',
                      },
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'sarkamganas406@gmail.com',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade300,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white70),
                  label: const Text(
                    'Kembali ke Login',
                    style: TextStyle(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
