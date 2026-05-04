import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_home_screen.dart'; // Nanti kita buat
import '../user/home_screen.dart';

class RoleChecker extends StatefulWidget {
  const RoleChecker({super.key});

  @override
  State<RoleChecker> createState() => _RoleCheckerState();
}

class _RoleCheckerState extends State<RoleChecker> {
  late Future<String> _userRole;

  @override
  void initState() {
    super.initState();
    _userRole = _fetchUserRole();
  }

  // Fungsi untuk mengambil role dari tabel profiles
  Future<String> _fetchUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    // Melakukan query (SELECT role FROM profiles WHERE id = userId)
    final response = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

    return response['role'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _userRole,
      builder: (context, snapshot) {
        // Tampilkan loading saat sedang mengambil data role
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Jika terjadi error, kembalikan ke layar user biasa sebagai default keamanan
        if (snapshot.hasError || !snapshot.hasData) {
          return const HomeScreen();
        }

        final role = snapshot.data!;

        // Penyeleksian jalan:
        if (role == 'admin') {
          return const AdminHomeScreen(); // Arahkan ke Dashboard Admin
        } else {
          return const HomeScreen(); // Arahkan ke Beranda User
        }
      },
    );
  }
}
