import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgSurface,
        elevation: 1,
        title: Text(
          'Tentang Aplikasi',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo/Icon Section
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.border, width: 2),
                    ),
                    child: Icon(Icons.store, size: 60, color: theme.btnPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TenMu',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'v1.0.0',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Description Section
            Text(
              'Tentang Kami',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TenMu adalah aplikasi mobile yang dirancang untuk membantu Anda menemukan dan mengelola UMKM (Usaha Mikro, Kecil, dan Menengah) di sekitar Anda.',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // Features Section
            Text(
              'Fitur Utama',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _FeatureItem(
              icon: Icons.location_on_outlined,
              title: 'Penemuan Geografis',
              description: 'Temukan UMKM berdasarkan lokasi Anda',
              theme: theme,
            ),
            _FeatureItem(
              icon: Icons.search_outlined,
              title: 'Pencarian & Filter',
              description: 'Cari UMKM berdasarkan kategori, harga, dan jarak',
              theme: theme,
            ),
            _FeatureItem(
              icon: Icons.map_outlined,
              title: 'Navigasi Peta',
              description: 'Navigasi ke lokasi UMKM dengan mudah',
              theme: theme,
            ),
            _FeatureItem(
              icon: Icons.star_outline,
              title: 'Ulasan & Rating',
              description: 'Baca ulasan dan berikan rating untuk UMKM',
              theme: theme,
            ),
            const SizedBox(height: 24),

            // Technology Section
            Text(
              'Teknologi',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _TechItem(label: 'Flutter', theme: theme),
            _TechItem(label: 'Dart', theme: theme),
            _TechItem(label: 'Supabase', theme: theme),
            _TechItem(label: 'OpenStreetMaps API', theme: theme),
            const SizedBox(height: 24),

            // Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Aplikasi',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Versi:', value: '1.0.0', theme: theme),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Pembuat:',
                    value: 'TenMu Team',
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Platform:',
                    value: 'Android & iOS',
                    theme: theme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ThemeProvider theme;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border, width: 1),
            ),
            child: Icon(icon, color: theme.btnPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechItem extends StatelessWidget {
  final String label;
  final ThemeProvider theme;

  const _TechItem({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.bgBase,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeProvider theme;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
