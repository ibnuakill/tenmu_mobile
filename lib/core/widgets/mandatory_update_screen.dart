import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_update_provider.dart';
import '../app_update_service.dart';
import '../lucide_icons.dart';
import '../theme_provider.dart';

/// Layar kunci yang menggantikan SELURUH isi aplikasi ketika ada pembaruan
/// wajib.
///
/// Berbeda dengan [UpdateDialog] yang hanya menutupi sebagian layar, widget
/// ini dikembalikan sebagai `child` pengganti oleh `UpdateGate`, sehingga
/// pengguna benar-benar tidak bisa masuk ke aplikasi sebelum memperbarui:
/// - tombol back Android tidak menutup layar ([PopScope] dengan `canPop: false`)
/// - tidak ada tombol "Nanti"
class MandatoryUpdateScreen extends StatelessWidget {
  const MandatoryUpdateScreen({super.key, required this.update});

  final AppUpdateProvider update;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final version = update.pendingVersion;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.bgBase,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: theme.btnPrimary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: LucideIcon(
                          'download',
                          size: 34,
                          color: theme.btnPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Pembaruan Wajib',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'TenMu versi ${version?.versionName ?? 'baru'} sudah tersedia. '
                      'Kamu harus memperbarui aplikasi untuk bisa melanjutkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.textSecondary,
                      ),
                    ),
                  ),
                  if (version != null &&
                      version.changelog.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yang baru',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            version.changelog,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _status(theme, update),
                  const SizedBox(height: 18),
                  _actions(context, theme, update),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Aplikasi akan terbuka otomatis setelah pembaruan dipasang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(ThemeProvider theme, AppUpdateProvider update) {
    switch (update.status) {
      case UpdateStatus.downloading:
        final percent = (update.progress * 100)
            .clamp(0, 100)
            .toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: update.progress == 0 ? null : update.progress,
                minHeight: 8,
                backgroundColor: theme.border,
                valueColor: AlwaysStoppedAnimation<Color>(theme.btnPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mengunduh… $percent%',
              style: TextStyle(fontSize: 12, color: theme.textSecondary),
            ),
          ],
        );

      case UpdateStatus.ready:
        return Row(
          children: [
            LucideIcon('check-circle', size: 16, color: theme.btnPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unduhan selesai. Tekan "Pasang Sekarang".',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
            ),
          ],
        );

      case UpdateStatus.failed:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LucideIcon('alert', size: 16, color: theme.snackError),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                update.errorMessage ?? 'Gagal mengunduh pembaruan.',
                style: TextStyle(fontSize: 12, color: theme.snackError),
              ),
            ),
          ],
        );

      case UpdateStatus.idle:
      case UpdateStatus.checking:
      case UpdateStatus.updateAvailable:
        return const SizedBox.shrink();
    }
  }

  Widget _actions(
    BuildContext context,
    ThemeProvider theme,
    AppUpdateProvider update,
  ) {
    final isReady = update.status == UpdateStatus.ready;
    final isBusy = update.status == UpdateStatus.downloading;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isBusy
            ? null
            : () {
                if (isReady) {
                  context.read<AppUpdateProvider>().installUpdate();
                } else {
                  context.read<AppUpdateProvider>().downloadUpdate();
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.btnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          isBusy
              ? 'Mengunduh…'
              : isReady
              ? 'Pasang Sekarang'
              : update.status == UpdateStatus.failed
              ? 'Coba Lagi'
              : 'Unduh Pembaruan',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: theme.btnLabel,
          ),
        ),
      ),
    );
  }
}
