import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_design.dart';
import '../../profile/admin_profile_screen.dart';

// ── AKUN: dropdown Logout / Ubah Sandi & Email ──
Future<void> confirmAdminLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: Text('Yakin ingin logout dari akun admin?', style: GoogleFonts.plusJakartaSans()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: kAccentRed, foregroundColor: Colors.white),
          child: Text('Logout', style: GoogleFonts.plusJakartaSans()),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

void openAdminProfile(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ICON RAIL SIDEBAR (Persis Gambar Referensi Tenmu Floating Left Rail)
// ═══════════════════════════════════════════════════════════════════════════════

class IconRailSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const IconRailSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  static const _navItems = [
    (0, Icons.grid_view_rounded, 'Dashboard'),
    (1, Icons.storefront_rounded, 'Manajemen UMKM'),
    (2, Icons.category_rounded, 'Kategori & Tag'),
    (3, Icons.people_alt_rounded, 'Manajemen User'),
    (4, Icons.rate_review_rounded, 'Review & Rating'),
    (5, Icons.campaign_rounded, 'Konten & Promo'),
    (6, Icons.analytics_rounded, 'Laporan & Analitik'),
    (7, Icons.map_rounded, 'Peta Sebaran'),
    (9, Icons.timeline_rounded, 'Audit Trail'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: kSidebarBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [kShadow],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // ── Nav items ──
          for (final item in _navItems)
            _railItem(item.$1, item.$2, item.$3),

          const Spacer(),

          // ── Bottom Verifikasi ──
          // Akun (Ubah Sandi / Logout) pindah ke pojok kanan atas layar.
          _railItem(8, Icons.verified_rounded, 'Verifikasi UMKM'),
        ],
      ),
    );
  }

  Widget _railItem(int idx, IconData icon, String tooltip) {
    final active = selectedIndex == idx;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => onSelect(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                : [],
          ),
          child: Icon(
            icon,
            color: active ? Colors.white : kTextMuted,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOMBOL AKUN — pojok kanan atas layar (mode web/lebar, di luar nav rail)
// ═══════════════════════════════════════════════════════════════════════════════

class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Akun',
      child: PopupMenuButton<String>(
        color: kCardBg,
        elevation: 8,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorderColor),
        ),
        offset: const Offset(0, 52),
        onSelected: (value) {
          if (value == 'profile') openAdminProfile(context);
          if (value == 'logout') confirmAdminLogout(context);
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'profile',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_reset, size: 16, color: kPrimary),
                ),
                const SizedBox(width: 10),
                Text('Ubah Sandi / Email',
                    style: GoogleFonts.plusJakartaSans(
                      color: kTextPrimary, fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kAccentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, size: 16, color: kAccentRed),
                ),
                const SizedBox(width: 10),
                Text('Logout',
                    style: GoogleFonts.plusJakartaSans(
                      color: kAccentRed, fontSize: 13)),
              ],
            ),
          ),
        ],
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderColor),
            boxShadow: const [kShadow],
          ),
          child: const Icon(Icons.account_circle_outlined,
              color: kTextSecondary, size: 20),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE (Tenmu Dashboard Layout 100% Identik Gambar)
// ═══════════════════════════════════════════════════════════════════════════════

class AdminComingSoonPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<String> items;

  const AdminComingSoonPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.items,
  });

  factory AdminComingSoonPage.content() {
    return const AdminComingSoonPage(
      title: 'Manajemen Konten & Promo',
      description:
          'Ruang untuk banner home, editorial picks, promo, dan push notification terjadwal.',
      icon: Icons.campaign_rounded,
      items: [
        'Banner dan promo halaman utama',
        'Artikel atau rekomendasi kuliner pilihan admin',
        'Push notification promo atau UMKM baru',
        'Status publish, draft, dan arsip konten',
      ],
    );
  }

  factory AdminComingSoonPage.analytics() {
    return const AdminComingSoonPage(
      title: 'Laporan & Analitik',
      description:
          'Dashboard lanjutan untuk ekspor data, tren pencarian, dan heatmap sebaran UMKM.',
      icon: Icons.analytics_rounded,
      items: [
        'Export UMKM, review, dan user ke CSV/Excel',
        'Statistik keyword pencarian terbanyak',
        'Heatmap lokasi UMKM berbasis MapLibre',
        'Grafik tren pertumbuhan dan engagement',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: kBorderColor),
                  boxShadow: const [kShadow],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kAccentGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: kAccentGreen, size: 26),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.5,
                        color: kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: kAccentGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: kTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}