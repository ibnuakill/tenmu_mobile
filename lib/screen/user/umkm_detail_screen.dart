import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'route_map_screen.dart';

class UmkmDetailScreen extends StatelessWidget {
  final Map<String, dynamic> umkm;

  const UmkmDetailScreen({super.key, required this.umkm});

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: CustomScrollView(
        slivers: [
          // ── HERO IMAGE APP BAR ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.bgBase,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgBase.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary,
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
                                AppColors.bgBase.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.bgSurface,
                      child: const Center(
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 64,
                          color: AppColors.textHint,
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
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
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
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderFocus),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: AppColors.textPrimary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Rekomendasi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
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
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.iconColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          umkm['alamat'] ?? '-',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 20),

                  // Deskripsi
                  const Text(
                    'Tentang Tempat Ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    umkm['deskripsi'] ?? 'Tidak ada deskripsi yang tersedia.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Tombol Rute
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
                        icon: const Icon(
                          Icons.directions_rounded,
                          color: AppColors.btnLabel,
                          size: 20,
                        ),
                        label: const Text(
                          'Lihat Rute Lokasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.btnLabel,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.btnPrimary,
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
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 16,
                            color: AppColors.textHint,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Koordinat lokasi belum tersedia.',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
