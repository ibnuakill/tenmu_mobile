import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_umkm_screen.dart'; // Import halaman edit UMKM

class ManageUmkmScreen extends StatefulWidget {
  const ManageUmkmScreen({super.key});

  @override
  State<ManageUmkmScreen> createState() => _ManageUmkmScreenState();
}

class _ManageUmkmScreenState extends State<ManageUmkmScreen> {
  // Stream untuk mengambil data UMKM secara real-time
  final _umkmStream = Supabase.instance.client
      .from('umkm')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  // Fungsi untuk menghapus data dengan Pop-Up Konfirmasi
  Future<void> _hapusData(int id, String nama) async {
    // Tampilkan dialog konfirmasi dulu biar nggak salah pencet
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
          'Apakah kamu yakin ingin menghapus tempat "$nama"? Data yang dihapus tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // Jika user klik "Hapus" (true), eksekusi ke database
    if (confirm == true) {
      try {
        await Supabase.instance.client.from('umkm').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data berhasil dihapus.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Data UMKM'),
        backgroundColor: Colors.blueGrey,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _umkmStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final umkmList = snapshot.data;

          if (umkmList == null || umkmList.isEmpty) {
            return const Center(
              child: Text('Belum ada data tempat nongkrong.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: umkmList.length,
            itemBuilder: (context, index) {
              final umkm = umkmList[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: umkm['gambar_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            umkm['gambar_url'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey,
                          child: const Icon(Icons.image),
                        ),
                  title: Text(
                    umkm['nama_tempat'] ?? 'Tanpa Nama',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    umkm['alamat'] ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // Pindah ke halaman edit dan bawa data UMKM-nya
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditUmkmScreen(umkm: umkm),
                            ),
                          );
                        },
                      ),
                      // Tombol Hapus
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _hapusData(umkm['id'], umkm['nama_tempat']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
