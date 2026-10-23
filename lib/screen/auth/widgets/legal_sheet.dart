import 'package:flutter/material.dart';

import 'auth_common.dart';

/// Jenis dokumen legal.
enum LegalDoc { terms, privacy }

/// Menampilkan Syarat & Ketentuan / Kebijakan Privasi sebagai pop-up
/// (bottom sheet) yang bisa di-scroll. Dipakai dari link di checkbox login.
Future<void> showLegalSheet(BuildContext context, LegalDoc doc) {
  final isTerms = doc == LegalDoc.terms;
  final title = isTerms ? 'Ketentuan Layanan' : 'Kebijakan Privasi';
  final subtitle = isTerms
      ? 'Syarat & ketentuan penggunaan aplikasi TenMu'
      : 'Bagaimana TenMu mengumpulkan & melindungi datamu';
  final sections = isTerms ? _terms : _privacy;

  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.85;
      return Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AuthPalette.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuthPalette.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AuthPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AuthPalette.grey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: AuthPalette.grey),
                  ),
                ],
              ),
            ),
            const Divider(color: AuthPalette.divider, height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  Text(
                    'Terakhir diperbarui: $_lastUpdated',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AuthPalette.hint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final s in sections) ...[
                    Text(
                      s.$1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AuthPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.$2,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AuthPalette.grey,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AuthPalette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AuthPalette.border),
                    ),
                    child: const Text(
                      'Dengan mencentang persetujuan & masuk ke TenMu, kamu menyatakan telah membaca dan menyetujui dokumen ini.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: AuthPalette.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

const String _lastUpdated = '15 Oktober 2026';

typedef _Section = (String, String);

const List<_Section> _terms = [
  (
    '1. Penerimaan Ketentuan',
    'Dengan mengakses atau menggunakan aplikasi TenMu, kamu menyetujui untuk terikat pada Ketentuan Layanan ini. Jika kamu tidak setuju, mohon untuk tidak menggunakan aplikasi.',
  ),
  (
    '2. Akun Pengguna',
    'Kamu bertanggung jawab menjaga kerahasiaan akun (email, password, atau kode OTP) dan seluruh aktivitas yang terjadi di dalamnya. Kamu wajib memberikan informasi yang benar dan tidak menggunakan akun milik orang lain tanpa izin.',
  ),
  (
    '3. Konten & Ulasan Pengguna',
    'Kamu bertanggung jawab penuh atas konten, ulasan, foto, atau komentar yang kamu unggah. Dilarang mengunggah konten yang menyesatkan, melanggar hukum, mengandung ujaran kebencian, atau melanggar hak pihak lain. TenMu berhak menghapus konten yang melanggar.',
  ),
  (
    '4. Informasi Tempat & UMKM',
    'Data tempat, harga, jam buka, dan fasilitas bersifat informatif dan dapat berubah sewaktu-waktu. TenMu tidak menjamin seluruh informasi selalu akurat dan tidak bertanggung jawab atas keputusan yang kamu ambil berdasarkan informasi tersebut.',
  ),
  (
    '5. Penggunaan yang Dilarang',
    'Dilarang menyalahgunakan aplikasi, termasuk namun tidak terbatas pada: mengakses data secara otomatis (scraping), menyebar spam, mencoba meretas sistem, atau menggunakan aplikasi untuk tindakan yang melanggar hukum.',
  ),
  (
    '6. Batasan Tanggung Jawab',
    'TenMu disediakan "sebagaimana adanya". Kami tidak bertanggung jawab atas kerugian langsung maupun tidak langsung yang timbul dari penggunaan aplikasi, sejauh diizinkan oleh hukum yang berlaku.',
  ),
  (
    '7. Perubahan Ketentuan',
    'TenMu dapat memperbarui Ketentuan Layanan ini dari waktu ke waktu. Perubahan akan ditampilkan di halaman ini, dan penggunaan aplikasi setelah perubahan berarti kamu menyetujuinya.',
  ),
];

const List<_Section> _privacy = [
  (
    '1. Data yang Kami Kumpulkan',
    'Kami mengumpulkan data yang kamu berikan (nama, email), data akun (metode login), serta data penggunaan seperti lokasi (dengan izinmu), favorit, dan ulasan untuk menampilkan tempat terdekat.',
  ),
  (
    '2. Penggunaan Data',
    'Data digunakan untuk: menjalankan & meningkatkan layanan, menampilkan tempat/UMKM di sekitarmu, memproses login & keamanan akun, serta mengirim notifikasi yang relevan. Kami tidak menjual data pribadimu.',
  ),
  (
    '3. Penyimpanan & Keamanan',
    'Data disimpan secara aman pada infrastruktur cloud (Supabase) dengan enkripsi saat transit. Password disimpan dalam bentuk hash. Kami menerapkan pembatasan akses (rate limit) untuk melindungi akunmu.',
  ),
  (
    '4. Berbagi Data',
    'Kami hanya membagikan data kepada penyedia layanan yang diperlukan untuk menjalankan aplikasi (mis. layanan autentikasi, email OTP, peta, dan push notification), dan bila diwajibkan oleh hukum.',
  ),
  (
    '5. Hak Pengguna',
    'Kamu berhak mengakses, memperbarui, atau menghapus data akunmu melalui menu Profil/Pengaturan. Untuk penghapusan akun, hubungi kami melalui kontak di bawah.',
  ),
  (
    '6. Izin Perangkat',
    'Aplikasi dapat meminta izin lokasi (untuk fitur sekitar) dan notifikasi. Kamu dapat menolak atau mencabut izin tersebut kapan saja melalui pengaturan perangkat.',
  ),
  (
    '7. Kontak',
    'Jika ada pertanyaan mengenai privasi, hubungi kami melalui menu Tentang Aplikasi atau email resmi TenMu.',
  ),
];
