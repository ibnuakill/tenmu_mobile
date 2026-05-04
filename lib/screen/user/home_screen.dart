import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'umkm_detail_screen.dart'; // Import halaman detail yang ada petanya

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _umkmStream = Supabase.instance.client
      .from('umkm')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('TenMu - Tempat Nongkrong'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _umkmStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final umkmList = snapshot.data;

          if (umkmList == null || umkmList.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada tempat nongkrong.\nTunggu Admin menambahkannya ya!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: umkmList.length,
            itemBuilder: (context, index) {
              final umkm = umkmList[index];

              // INI KUNCINYA: Membungkus Card dengan InkWell
              return InkWell(
                onTap: () {
                  // Saat diklik, arahkan ke UmkmDetailScreen dan bawa data umkm-nya
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UmkmDetailScreen(umkm: umkm),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(
                  12,
                ), // Efek sentuhan mengikuti lengkungan Card
                child: Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (umkm['gambar_url'] != null)
                        Image.network(
                          umkm['gambar_url'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    umkm['nama_tempat'] ?? 'Tanpa Nama',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (umkm['is_featured'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Rekomendasi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              umkm['deskripsi'] ?? 'Tidak ada deskripsi',
                              style: TextStyle(color: Colors.grey[800]),
                              maxLines:
                                  2, // Batasi deskripsi maksimal 2 baris agar rapi
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    umkm['alamat'] ?? 'Alamat tidak diketahui',
                                    style: const TextStyle(color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
