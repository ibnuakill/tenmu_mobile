import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme_provider.dart';
import '../../../core/lucide_icons.dart';

/// Pusat Bantuan: FAQ singkat + tombol hubungi admin lewat WhatsApp.
///
/// Nomor admin dibaca dari `.env` → `ADMIN_WA` (format 62xxx, tanpa +/spasi).
/// Kalau belum diisi, tombol menampilkan pesan bahwa kontak belum diatur.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const List<({String q, String a})> _faq = [
    (
      q: 'Apa itu TenMu?',
      a:
          'TenMu adalah aplikasi untuk menemukan UMKM di sekitar kamu — kuliner, '
          'wisata, oleh-oleh, hotel, pertokoan, sampai jasa. Semua data tempat '
          'dikurasi dari pemilik usaha yang terverifikasi.',
    ),
    (
      q: 'Bagaimana cara mencari tempat?',
      a:
          'Gunakan kolom pencarian di beranda, atau pilih kategori yang tersedia. '
          'Kamu juga bisa membuka menu Peta untuk melihat tempat di sekitar posisi '
          'kamu, lalu ketuk pin untuk melihat detailnya.',
    ),
    (
      q: 'Bagaimana cara menyimpan tempat favorit?',
      a:
          'Buka detail tempat, lalu ketuk ikon hati. Semua tempat yang kamu simpan '
          'bisa dibuka lagi lewat menu Pengaturan → Favorit Saya.',
    ),
    (
      q: 'Bagaimana cara mendaftar jadi pemilik UMKM?',
      a:
          'Buka Pengaturan → Daftar Jadi Pemilik UMKM, isi data usaha kamu, lalu '
          'kirim. Setelah disetujui admin, kamu bisa menambah dan mengelola tempat '
          'milikmu sendiri.',
    ),
    (
      q: 'Kenapa tempat saya belum muncul di beranda?',
      a:
          'Tempat baru tampil setelah statusnya terverifikasi admin. Pastikan nama, '
          'alamat, kategori, koordinat, dan minimal satu foto sudah terisi. Proses '
          'verifikasi biasanya 1×24 jam kerja.',
    ),
    (
      q: 'Bagaimana cara mengubah data atau foto tempat?',
      a:
          'Masuk ke Pengaturan → Kelola Tempat Saya, pilih tempat yang ingin diubah, '
          'lalu perbarui data atau fotonya dan simpan. Perubahan langsung tersimpan '
          'di akun kamu.',
    ),
    (
      q: 'Apakah jawaban TenMu AI selalu akurat?',
      a:
          'TenMu AI merekomendasikan tempat dari data yang ada di aplikasi, tapi '
          'bisa saja salah memahami pertanyaan. Untuk info harga, jam buka, atau '
          'ketersediaan, sebaiknya konfirmasi langsung ke pihak tempat.',
    ),
  ];

  String get _adminWa {
    final raw = (dotenv.env['ADMIN_WA'] ?? '').trim();
    if (raw.isEmpty) return '';
    var n = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('0')) n = '62${n.substring(1)}';
    return n;
  }

  Future<void> _openWhatsApp(BuildContext context, ThemeProvider theme) async {
    final wa = _adminWa;
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Nomor admin belum diatur. Hubungi pengembang untuk mengisi ADMIN_WA di .env',
          ),
          backgroundColor: theme.snackError,
        ),
      );
      return;
    }

    const pesan = 'Halo admin TenMu, saya butuh bantuan terkait aplikasi.';
    final uri = Uri.parse(
      'https://wa.me/$wa?text=${Uri.encodeComponent(pesan)}',
    );

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak bisa membuka WhatsApp. Nomor admin: +$wa'),
            backgroundColor: theme.snackError,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa membuka WhatsApp. Nomor admin: +$wa'),
          backgroundColor: theme.snackError,
        ),
      );
    }
  }

  Future<void> _openEmail(BuildContext context, ThemeProvider theme) async {
    final email = (dotenv.env['ADMIN_EMAIL'] ?? '').trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email admin belum diatur (ADMIN_EMAIL di .env)'),
          backgroundColor: theme.snackError,
        ),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Bantuan TenMu',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak bisa membuka aplikasi email ($email)'),
            backgroundColor: theme.snackError,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa membuka aplikasi email ($email)'),
          backgroundColor: theme.snackError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgSurface,
        elevation: 1,
        title: Text(
          'Pusat Bantuan',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: LucideIcon('arrow-left', color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sapaan ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.btnPrimary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: LucideIcon(
                        'message-circle',
                        size: 22,
                        color: theme.btnPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ada yang bisa dibantu?',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cek pertanyaan umum di bawah. Kalau belum ketemu, '
                          'chat admin langsung ya.',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── FAQ ──
            Text(
              'Pertanyaan Umum',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < _faq.length; i++) ...[
                    if (i > 0)
                      Divider(color: theme.border, height: 1, indent: 16),
                    _FaqTile(
                      question: _faq[i].q,
                      answer: _faq[i].a,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Kontak admin ──
            Text(
              'Masih Butuh Bantuan?',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hubungi admin TenMu lewat WhatsApp. Sertakan nama akun dan '
                    'kendala kamu supaya lebih cepat ditangani.',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openWhatsApp(context, theme),
                      icon: LucideIcon('message-circle', size: 18, color: theme.btnLabel),
                      label: Text(
                        'Chat Admin via WhatsApp',
                        style: TextStyle(
                          color: theme.btnLabel,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.btnPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _openEmail(context, theme),
                      icon: LucideIcon('mail', size: 17, color: theme.textPrimary),
                      label: Text(
                        'Kirim Email',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Jam layanan admin: 08.00 – 21.00 WIB',
                    style: TextStyle(color: theme.textHint, fontSize: 11.5),
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

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  final ThemeProvider theme;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: theme.textSecondary,
        collapsedIconColor: theme.textSecondary,
        title: Text(
          question,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
