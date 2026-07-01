import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/user_role.dart';
import '../admin/admin_home_screen.dart';
import '../user/home_screen.dart';

class RoleChecker extends StatefulWidget {
  const RoleChecker({super.key});

  @override
  State<RoleChecker> createState() => _RoleCheckerState();
}

class _RoleCheckerState extends State<RoleChecker> {
  late Future<UserRole> _userRole;

  @override
  void initState() {
    super.initState();
    _userRole = _fetchUserRole();
  }

  // Fungsi untuk mengambil role dari tabel profiles
  Future<UserRole> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('Sesi login tidak ditemukan.');
    }

    final response = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      // User baru dari Google OAuth — belum punya profile, auto-create
      final metadata = user.userMetadata ?? {};
      final fullName = metadata['full_name']?.toString() ??
          metadata['name']?.toString() ??
          'User';
      final avatarUrl = metadata['avatar_url']?.toString() ??
          metadata['picture']?.toString();

      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'nama': fullName,
        'avatar_url': avatarUrl,
        'role': 'user',
        'created_at': DateTime.now().toIso8601String(),
      });

      return parseUserRole('user');
    }

    final role = response['role']?.toString() ?? 'user';

    // Auto-apply owner role jika user daftar sebagai owner
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
      _userRole = _fetchUserRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserRole>(
      future: _userRole,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

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

        final role = snapshot.data!;
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
