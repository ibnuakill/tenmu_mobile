import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/theme_toggle_button.dart';
import '../auth/login_screen.dart';
import 'umkm_detail_screen.dart';

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

  String _searchQuery = '';

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TenMu',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Temukan tempat nongkrong favoritmu',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                  const SizedBox(width: 8),
                  StreamBuilder<AuthState>(
                    stream: Supabase.instance.client.auth.onAuthStateChange,
                    builder: (ctx, snapshot) {
                      final isLoggedIn =
                          Supabase.instance.client.auth.currentUser != null;
                      if (isLoggedIn) {
                        // ── Tombol Logout (user sudah login) ────────────
                        return GestureDetector(
                          onTap: () => _signOut(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.bgElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.border),
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              color: theme.iconColor,
                              size: 20,
                            ),
                          ),
                        );
                      } else {
                        // ── Tombol Login (guest) ─────────────────────────
                        return GestureDetector(
                          onTap: () => _goToLogin(ctx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: theme.btnPrimary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  color: theme.btnLabel,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: theme.btnLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── SEARCH BAR ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  style: TextStyle(color: theme.textPrimary),
                  cursorColor: theme.borderFocus,
                  decoration: InputDecoration(
                    hintText: 'Cari nama tempat atau alamat...',
                    hintStyle: TextStyle(
                      color: theme.textHint,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.iconColor,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── LIST ───────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _umkmStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.iconColor,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Terjadi kesalahan.',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                    );
                  }

                  final raw = snapshot.data ?? [];
                  final umkmList = _searchQuery.isEmpty
                      ? raw
                      : raw.where((u) {
                          final nama = (u['nama_tempat'] ?? '').toLowerCase();
                          final alamat = (u['alamat'] ?? '').toLowerCase();
                          return nama.contains(_searchQuery) ||
                              alamat.contains(_searchQuery);
                        }).toList();

                  if (umkmList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 56,
                            color: theme.textHint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada tempat ditemukan.',
                            style: TextStyle(color: theme.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: umkmList.length,
                    itemBuilder: (context, index) {
                      final umkm = umkmList[index];
                      return _UmkmCard(
                        umkm: umkm,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UmkmDetailScreen(umkm: umkm),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UmkmCard extends StatelessWidget {
  final Map<String, dynamic> umkm;
  final VoidCallback onTap;

  const _UmkmCard({required this.umkm, required this.onTap});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            if (umkm['gambar_url'] != null)
              Stack(
                children: [
                  Image.network(
                    umkm['gambar_url'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 180,
                      color: theme.bgElevated,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: theme.textHint,
                        ),
                      ),
                    ),
                  ),
                  if (umkm['is_featured'] == true)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.bgBase.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: theme.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rekomendasi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                height: 120,
                color: theme.bgElevated,
                child: Center(
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 40,
                    color: theme.textHint,
                  ),
                ),
              ),

            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    umkm['nama_tempat'] ?? 'Tanpa Nama',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (umkm['deskripsi'] != null)
                    Text(
                      umkm['deskripsi'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.iconColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          umkm['alamat'] ?? 'Alamat tidak diketahui',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
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
  }
}
