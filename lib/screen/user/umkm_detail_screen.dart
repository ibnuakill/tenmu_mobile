import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme_provider.dart';
import 'route_map_screen.dart';
import 'review_section.dart';

class UmkmDetailScreen extends StatefulWidget {
  final Map<String, dynamic> umkm;

  const UmkmDetailScreen({super.key, required this.umkm});

  @override
  State<UmkmDetailScreen> createState() => _UmkmDetailScreenState();
}

class _UmkmDetailScreenState extends State<UmkmDetailScreen> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingFavorite = false);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('umkm_id', widget.umkm['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorite = response != null;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk menyimpan favorit.')),
      );
      return;
    }

    // Optimistic UI update
    setState(() => _isFavorite = !_isFavorite);

    try {
      if (_isFavorite) {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': user.id,
          'umkm_id': widget.umkm['id'],
        });
      } else {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('umkm_id', widget.umkm['id']);
      }
    } catch (e) {
      // Rollback on failure
      setState(() => _isFavorite = !_isFavorite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui favorit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final double? lat = widget.umkm['latitude'] != null
        ? (widget.umkm['latitude'] is int
              ? (widget.umkm['latitude'] as int).toDouble()
              : widget.umkm['latitude'])
        : null;
    final double? lng = widget.umkm['longitude'] != null
        ? (widget.umkm['longitude'] is int
              ? (widget.umkm['longitude'] as int).toDouble()
              : widget.umkm['longitude'])
        : null;
    final bool hasLocation = lat != null && lng != null;
    final String? nomorTelepon = widget.umkm['nomor_telepon'];
    final String? jamBuka = widget.umkm['jam_buka'];
    final String? jamTutup = widget.umkm['jam_tutup'];

    bool isOpen = false;
    if (jamBuka != null && jamTutup != null) {
      try {
        final now = TimeOfDay.now();
        final currentMinutes = now.hour * 60 + now.minute;

        final openParts = jamBuka.split(':');
        final closeParts = jamTutup.split(':');

        final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
        final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

        if (closeMinutes < openMinutes) {
          // Buka melewati tengah malam
          isOpen = currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
        } else {
          isOpen = currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
        }
      } catch (_) {}
    }

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
              background: widget.umkm['gambar_url'] != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.umkm['gambar_url'], fit: BoxFit.cover),
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
            actions: [
              if (!_isLoadingFavorite)
                GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.bgBase.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.border),
                    ),
                    child: Icon(
                      _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                      color: _isFavorite ? Colors.amber : theme.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
            ],
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
                          widget.umkm['nama_tempat'] ?? 'Tanpa Nama',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.umkm['is_featured'] == true) ...[
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
                          widget.umkm['alamat'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Jam Operasional
                  if (jamBuka != null && jamTutup != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 16,
                          color: theme.iconColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$jamBuka - $jamTutup',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOpen ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOpen ? Colors.green : Colors.red,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            isOpen ? 'Buka' : 'Tutup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOpen ? Colors.green : Colors.red,
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
                    widget.umkm['deskripsi'] ?? 'Tidak ada deskripsi yang tersedia.',
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
                                destinationName: widget.umkm['nama_tempat'] ?? '',
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
                  if (widget.umkm['id'] != null)
                    ReviewSection(umkmId: widget.umkm['id'] as int),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
