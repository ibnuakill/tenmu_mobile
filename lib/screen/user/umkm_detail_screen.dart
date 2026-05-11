import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme_provider.dart';
import 'route_map_screen.dart';
import 'review_section.dart';

class UmkmDetailScreen extends StatelessWidget {
  final Map<String, dynamic> umkm;

  const UmkmDetailScreen({super.key, required this.umkm});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final double? lat = umkm['latitude'] != null
        ? (umkm['latitude'] is int
              ? (umkm['latitude'] as int).toDouble()
              : umkm['latitude'])
        : null;
    final double? lng = umkm['longitude'] != null
        ? (umkm['longitude'] is int
              ? (umkm['longitude'] as int).toDouble()
              : umkm['longitude'])
        : null;
    final bool hasLocation = lat != null && lng != null;
    final String? nomorTelepon = umkm['nomor_telepon'];

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: CustomScrollView(
        slivers: [
          // ── HERO IMAGE APP BAR ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.bgBase,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.bgBase.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.border),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: theme.textPrimary,
                  size: 16,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: umkm['gambar_url'] != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(umkm['gambar_url'], fit: BoxFit.cover),
                        // Gradient overlay agar teks terbaca
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                theme.bgBase.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: theme.bgSurface,
                      child: Center(
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 64,
                          color: theme.textHint,
                        ),
                      ),
                    ),
            ),
          ),

          // ── KONTEN ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama + Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          umkm['nama_tempat'] ?? 'Tanpa Nama',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      if (umkm['is_featured'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.bgElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.borderFocus),
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
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Alamat
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: theme.iconColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          umkm['alamat'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  Divider(color: theme.border),
                  const SizedBox(height: 20),

                  // Deskripsi
                  Text(
                    'Tentang Tempat Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    umkm['deskripsi'] ?? 'Tidak ada deskripsi yang tersedia.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: theme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Tombol Kontak & Rute
                  if (nomorTelepon != null && nomorTelepon.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Format nomor untuk WA (ganti 0 di awal dengan 62)
                          String formattedNumber = nomorTelepon;
                          if (formattedNumber.startsWith('0')) {
                            formattedNumber = '62${formattedNumber.substring(1)}';
                          }

                          final Uri waUri = Uri.parse('https://wa.me/$formattedNumber');
                          final Uri telUri = Uri.parse('tel:$nomorTelepon');

                          // Coba WA dulu, kalau gagal coba Telepon biasa
                          try {
                            if (await canLaunchUrl(waUri)) {
                              await launchUrl(waUri, mode: LaunchMode.externalApplication);
                            } else if (await canLaunchUrl(telUri)) {
                              await launchUrl(telUri);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Tidak dapat membuka WhatsApp atau Telepon untuk nomor $nomorTelepon'),
                                    backgroundColor: theme.snackError,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: theme.snackError,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.chat_outlined,
                          color: Colors.green,
                          size: 20,
                        ),
                        label: Text(
                          'Hubungi (WhatsApp / Telepon)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (hasLocation)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RouteMapScreen(
                                destinationLat: lat,
                                destinationLng: lng,
                                destinationName: umkm['nama_tempat'] ?? '',
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.directions_rounded,
                          color: theme.btnLabel,
                          size: 20,
                        ),
                        label: Text(
                          'Lihat Rute Lokasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.btnLabel,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.btnPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 16,
                            color: theme.textHint,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Koordinat lokasi belum tersedia.',
                            style: TextStyle(color: theme.textHint),
                          ),
                        ],
                      ),
                    ),

                  // ── Rating & Komentar ────────────────────
                  const SizedBox(height: 28),
                  if (umkm['id'] != null)
                    ReviewSection(umkmId: umkm['id'] as int),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
