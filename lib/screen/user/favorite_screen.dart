import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import 'umkm_detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  final user = Supabase.instance.client.auth.currentUser;

  Future<List<Map<String, dynamic>>> _fetchFavorites() async {
    if (user == null) return [];

    final response = await Supabase.instance.client
        .from('favorites')
        .select('umkm_id, umkm(*)')
        .eq('user_id', user!.id)
        .order('created_at', ascending: false);

    return (response as List).map((fav) => fav['umkm'] as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        title: Text('Favorit Saya', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: user == null
          ? Center(child: Text('Silakan login untuk melihat favorit.', style: TextStyle(color: theme.textSecondary)))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchFavorites(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: theme.iconColor));
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Gagal memuat favorit.', style: TextStyle(color: theme.snackError)));
                }

                final favorites = snapshot.data ?? [];

                if (favorites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_border, size: 64, color: theme.textHint),
                        const SizedBox(height: 16),
                        Text('Belum ada tempat favorit.', style: TextStyle(color: theme.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final umkm = favorites[index];
                    return _FavoriteCard(
                      umkm: umkm, 
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => UmkmDetailScreen(umkm: umkm)),
                        ).then((_) => setState(() {})); // Refresh if un-favorited
                      }
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Map<String, dynamic> umkm;
  final VoidCallback onTap;

  const _FavoriteCard({required this.umkm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            if (umkm['gambar_url'] != null)
              Image.network(
                umkm['gambar_url'],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: theme.bgElevated, child: Icon(Icons.broken_image, color: theme.textHint)),
              )
            else
              Container(width: 100, height: 100, color: theme.bgElevated, child: Icon(Icons.storefront, color: theme.textHint)),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(umkm['nama_tempat'] ?? 'Tanpa Nama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: theme.iconColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            umkm['alamat'] ?? '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
