import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_umkm_screen.dart'; // Import halaman tambah UMKM
import 'manage_umkm_screen.dart'; // Import halaman manajemen UMKM (edit/hapus)

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // Fungsi untuk logout
  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin TenMu'),
        backgroundColor: Colors.blueGrey, // Warna khusus admin
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 60,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Selamat Datang, Admin!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kamu punya kendali penuh untuk mengelola data tempat nongkrong.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt),
              label: const Text(
                'Tambah Tempat Nongkrong Baru',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Navigasi ke halaman form tambah data
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddUmkmScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_document),
              label: const Text(
                'Kelola / Edit / Hapus Data',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey, // Warna teks
                side: const BorderSide(
                  color: Colors.blueGrey,
                  width: 2,
                ), // Garis pinggir
              ),
              onPressed: () {
                // Navigasi ke halaman kelola data
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageUmkmScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
